#!/usr/bin/env bash
# @category: System & Runtime Control

# Core environment controls, model toggles, performance flags, and raw model interactions.

# Internal text minifier: AST skeletonization + whitespace/comment stripping
_compact_text() {
    local input
    input=$(cat)

    if [ "$AI_COMPACT" = "true" ]; then
        if [ -f "${LLAMALIAS_DIR}/core/py_skeleton.py" ]; then
            local skeletonized
            skeletonized=$(printf '%s\n' "$input" | python3 "${LLAMALIAS_DIR}/core/py_skeleton.py" --min-lines "$AI_SKEL_MIN_LINES" 2>/dev/null)
            if [ -n "$skeletonized" ]; then
                input="$skeletonized"
            fi
        fi

        printf '%s\n' "$input" | sed -E '
            /^\s*$/d;                 # Delete empty/whitespace-only lines
            /^\s*(#|\/\/|\/\*|\*)/d;  # Delete lines that are purely comments (#, //, /*, *)
            s/[[:space:]]+$//;        # Strip trailing whitespace
        '
    else
        # Pass through unmodified if compaction is disabled
        printf '%s\n' "$input"
    fi
}

# Prepare and compact input content from stdin or file arguments
_prepare_user_content() {
    local user_arg="$1"
    local stdin_input=""
    [ ! -t 0 ] && stdin_input=$(cat)

    local content=""
    if [ -n "$user_arg" ] && [ -f "$user_arg" ]; then
        content="File (${user_arg}):\n$(cat "$user_arg")"
        [ -n "$stdin_input" ] && content="${content}\n\n${stdin_input}"
    elif [ -n "$user_arg" ] && [ -n "$stdin_input" ]; then
        content="Context: ${user_arg}\n\n${stdin_input}"
    elif [ -n "$stdin_input" ]; then
        content="$stdin_input"
    else
        content="$user_arg"
    fi

    if declare -f _compact_text >/dev/null; then
        content=$(printf '%s\n' "$content" | _compact_text)
    fi
    printf '%s' "$content"
}

# Construct JSON payload for Ollama /api/chat
_build_ollama_payload() {
    local system_prompt="$1"
    local user_content="$2"
    local history_length
    history_length=$(jq 'length' "$AI_SESSION_FILE" 2>/dev/null || echo 0)

    if [ "$AI_SESSION" = "true" ] && [ "$history_length" -gt 0 ]; then
        jq --arg user "$user_content" \
           --arg model "$AI_MODEL" \
           --argjson num_ctx "$AI_NUM_CTX" \
           --argjson num_thread "$AI_NUM_THREAD" \
           '{
               model: $model,
               stream: true,
               options: { num_ctx: $num_ctx, num_thread: $num_thread },
               messages: (. + [{"role": "user", "content": $user}])
           }' "$AI_SESSION_FILE"
    else
        jq -n --arg sys "$system_prompt" \
              --arg user "$user_content" \
              --arg model "$AI_MODEL" \
              --argjson num_ctx "$AI_NUM_CTX" \
              --argjson num_thread "$AI_NUM_THREAD" \
              '{
                  model: $model,
                  stream: true,
                  options: { num_ctx: $num_ctx, num_thread: $num_thread },
                  messages: [
                      {"role": "system", "content": $sys},
                      {"role": "user", "content": $user}
                  ]
              }'
    fi
}

# Compute and output execution metrics
_print_ollama_perf() {
    local tmp_file="$1"
    local start_time="$2"
    local end_time="$3"

    [ "$AI_SHOW_PERF" != "true" ] && return

    local last_line
    last_line=$(tail -n 1 "$tmp_file")

    local eval_count eval_dur prompt_count prompt_dur
    eval_count=$(echo "$last_line" | jq -r '.eval_count // 0')
    eval_dur=$(echo "$last_line" | jq -r '.eval_duration // 0')
    prompt_count=$(echo "$last_line" | jq -r '.prompt_eval_count // 0')
    prompt_dur=$(echo "$last_line" | jq -r '.prompt_eval_duration // 0')

    local wall_time
    wall_time=$(awk "BEGIN {printf \"%.2f\", $end_time - $start_time}")

    local gen_tps="0.00"
    [ -n "$eval_dur" ] && [ "$eval_dur" -gt 0 ] && \
        gen_tps=$(awk "BEGIN {printf \"%.2f\", ($eval_count / ($eval_dur / 1000000000))}")

    local prompt_tps="0.00"
    [ -n "$prompt_dur" ] && [ "$prompt_dur" -gt 0 ] && \
        prompt_tps=$(awk "BEGIN {printf \"%.2f\", ($prompt_count / ($prompt_dur / 1000000000))}")

    echo -e "\033[0;36m[Perf] ${wall_time}s total | Gen: ${eval_count} tok (${gen_tps} tok/s) | Prompt: ${prompt_count} tok (${prompt_tps} tok/s)\033[0m"
}

# Slice session history to keep system prompt + last N messages
_prune_ollama_session() {
    [ ! -f "$AI_SESSION_FILE" ] && return

    local max_messages=$(( ${AI_SESSION_MAX_TURNS:-5} * 2 ))

    jq --argjson max "$max_messages" '
        if length > $max then
            if .[0].role == "system" then
                [.[0]] + .[-($max - 1):]
            else
                .[-$max:]
            end
        else
            .
        end
    ' "$AI_SESSION_FILE" > "${AI_SESSION_FILE}.tmp" && mv "${AI_SESSION_FILE}.tmp" "$AI_SESSION_FILE"
}

# Persist conversation turn to session history file
_update_ollama_session() {
    local system_prompt="$1"
    local user_content="$2"
    local tmp_file="$3"

    [ "$AI_SESSION" != "true" ] && return

    local assistant_response
    assistant_response=$(jq -r -s '[.[].message.content // ""] | join("")' "$tmp_file" 2>/dev/null)
    [ -z "$assistant_response" ] && return

    local history_length
    history_length=$(jq 'length' "$AI_SESSION_FILE" 2>/dev/null || echo 0)

    if [ "$history_length" -eq 0 ]; then
        jq -n --arg sys "$system_prompt" --arg user "$user_content" --arg assistant "$assistant_response" \
            '[{"role": "system", "content": $sys}, {"role": "user", "content": $user}, {"role": "assistant", "content": $assistant}]' \
            > "${AI_SESSION_FILE}.tmp" && mv "${AI_SESSION_FILE}.tmp" "$AI_SESSION_FILE"
    else
        jq --arg user "$user_content" --arg assistant "$assistant_response" \
            '. + [{"role": "user", "content": $user}, {"role": "assistant", "content": $assistant}]' \
            "$AI_SESSION_FILE" > "${AI_SESSION_FILE}.tmp" && mv "${AI_SESSION_FILE}.tmp" "$AI_SESSION_FILE"
    fi

    # Prune context to prevent out-of-memory or window overflow
    _prune_ollama_session
}

# Core runner with built-in token & execution metrics
_ollama_exec() {
    local system_prompt="$1"
    local user_arg="$2"

    _init_session_file
    
    local full_user_content
    full_user_content=$(_prepare_user_content "$user_arg")

    local payload
    payload=$(_build_ollama_payload "$system_prompt" "$full_user_content")

    local start_time tmp_file
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    tmp_file=$(mktemp)

    # Stream HTTP response directly to terminal
    curl -s -N -X POST "${OLLAMA_HOST}/api/chat" \
        -H "Content-Type: application/json" \
        -d "$payload" | while read -r line; do
            echo "$line" >> "$tmp_file"
            echo -n "$line" | jq -j '.message.content // empty' 2>/dev/null
        done
    echo ""

    local end_time
    end_time=$(date +%s.%N 2>/dev/null || date +%s)

    _print_ollama_perf "$tmp_file" "$start_time" "$end_time"
    _update_ollama_session "$system_prompt" "$full_user_content" "$tmp_file"

    rm -f "$tmp_file"
}

# @cmd: ai-ask
# @desc: Send a direct, raw prompt to the active Ollama model
# @usage: ai-ask <prompt>
# @example: ai-ask "Explain async/await in Python"
ai-ask() {
    _ollama_exec "$*"
}

# ==============================================================================
# Model & Environment Management
# ==============================================================================

# @cmd: ai-model
# @desc: View currently active model or switch to a new local model dynamically across all helpers
# @usage: ai-model [model_name]
# @example: ai-model qwen2.5-coder:1.5b
ai-model() {
    if [ -z "$1" ]; then
        echo "Active Ollama Model: ${AI_MODEL}"
        echo "Available local models:"
        ollama list
    else
        export AI_MODEL="$1"
        echo "Switched active AI model to: ${AI_MODEL}"
    fi
}

# @cmd: ai-status
# @desc: Display active helper configuration, Ollama API endpoint, and loaded runners
# @usage: ai-status
# @example: ai-status
ai-status() {
    echo "=== Active Configuration ==="
    echo "Model: ${AI_MODEL}"
    echo "Ollama Endpoint: ${OLLAMA_HOST}"
    echo ""
    echo "=== Loaded Runners (ps) ==="
    ollama ps
}

# ==============================================================================
# @category: Session Management
# ==============================================================================

# Initialize empty session file if missing
_init_session_file() {
    if [ ! -f "$AI_SESSION_FILE" ]; then
        echo "[]" > "$AI_SESSION_FILE"
    fi
}

# Helper to ensure sessions directory exists
_init_sessions_dir() {
    mkdir -p "$AI_SESSIONS_DIR"
}

# @cmd: ai-session-save
# @desc: Save active session memory under a named profile
# @usage: ai-session-save <session_name>
# @example: ai-session-save write-unit-tests"
ai-session-save() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Usage: ai-session-save <session_name>"
        return 1
    fi

    _init_sessions_dir
    _init_session_file

    if [ "$(jq 'length' "$AI_SESSION_FILE")" -eq 0 ]; then
        echo -e "\033[0;33m[Warning]\033[0m Current session memory is empty. Nothing to save."
        return 1
    fi

    local target_file="${AI_SESSIONS_DIR}/${name}.json"
    cp "$AI_SESSION_FILE" "$target_file"
    echo -e "\033[0;32m[Session Saved]\033[0m Saved active memory as \033[1m${name}\033[0m (\`${target_file}\`)"
}

# @cmd: ai-session-load
# @desc: Load a named session profile into active memory
# @usage: ai-session-load <sesion_name>
# @example: ai-session-load write-unit-tests
ai-session-load() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Usage: ai-session-load <session_name>"
        return 1
    fi

    local source_file="${AI_SESSIONS_DIR}/${name}.json"
    if [ ! -f "$source_file" ]; then
        echo -e "\033[0;31m[Error]\033[0m Saved session '\033[1m${name}\033[0m' not found in \`${AI_SESSIONS_DIR}\`."
        return 1
    fi

    _init_session_file
    cp "$source_file" "$AI_SESSION_FILE"
    export AI_SESSION="true"

    local turn_count
    turn_count=$(jq 'length / 2 | floor' "$AI_SESSION_FILE")
    echo -e "\033[0;32m[Session Loaded]\033[0m Loaded \033[1m${name}\033[0m (${turn_count} turns). Session mode is now \033[1mENABLED\033[0m."
}

# @cmd: ai-session-list
# @desc: List all saved named session profiles
# @usage: ai-session-list
# @example: ai-session-list
ai-session-list() {
    _init_sessions_dir
    
    # Check for json files in directory
    shopt -s nullglob
    local files=("${AI_SESSIONS_DIR}"/*.json)
    shopt -u nullglob

    if [ ${#files[@]} -eq 0 ]; then
        echo "No saved sessions found in \`${AI_SESSIONS_DIR}\`."
        return 0
    fi

    echo -e "\033[1;34m=== Saved Llamalias Sessions ===\033[0m"
    printf "%-50s %-12s %-20s\n" "Session Name" "Turns" "Last Modified"
    echo "----------------------------------------------------------------------------------"

    for file in "${files[@]}"; do
        local sname
        sname=$(basename "$file" .json)
        local turns
        turns=$(jq 'length / 2 | floor' "$file" 2>/dev/null || echo "0")
        local mod_time
        mod_time=$(date -r "$file" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")

        printf "%-50s %-12s %-20s\n" "$sname" "$turns" "$mod_time"
    done
}

# @cmd: ai-session-rm
# @desc: Delete a saved named session profile
# @usage: ai-session-rm <session_name>
# @example: ai-session-rm write-unit-tests
ai-session-rm() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Usage: ai-session-rm <session_name>"
        return 1
    fi

    local target_file="${AI_SESSIONS_DIR}/${name}.json"
    if [ -f "$target_file" ]; then
        rm -f "$target_file"
        echo -e "\033[0;32m[Session Deleted]\033[0m Removed session '\033[1m${name}\033[0m'."
    else
        echo -e "\033[0;31m[Error]\033[0m Session '\033[1m${name}\033[0m' does not exist."
        return 1
    fi
}

# @cmd: ai-session
# @desc: Unified Session Manager Dispatcher (`ai-session`)
# @usage: ai-session [save|load|list|ls|rm|del|clear|show|toggle|cap]
# @example: ai-session ls
ai-session() {
    case "$1" in
        save)   shift; ai-session-save "$@" ;;
        load)   shift; ai-session-load "$@" ;;
        list|ls) ai-session-list ;;
        rm|del) shift; ai-session-rm "$@" ;;
        clear)  ai-session-clear ;;
        show)   ai-session-show ;;
        toggle) ai-session-toggle ;;
        cap)    shift; ai-session-cap "$@" ;;
        *)
            echo -e "\033[1m🦙 Llamalias Session Manager\033[0m"
            echo "Usage: ai-session <command> [args]"
            echo ""
            echo "Commands:"
            echo "  save <name>    Save active session memory to ${AI_SESSIONS_DIR}/<name>.json"
            echo "  load <name>    Load named session profile into active memory"
            echo "  list | ls      List all saved sessions with turn counts"
            echo "  rm <name>      Delete a saved session profile"
            echo "  clear          Clear active in-memory session"
            echo "  show           Print active session conversation history"
            echo "  toggle         Enable/Disable automatic session sharing mode"
            echo "  cap [n]        View or update max sliding window turn limit"
            ;;
    esac
}

# @cmd: ai-session-clear
# @desc: Clear active session memory
# @usage: ai-session-clear
# @example: ai-session-clear
ai-session-clear() {
    echo "[]" > "$AI_SESSION_FILE"
    echo -e "\033[0;32m[Session Memory Cleared]\033[0m"
}

# @cmd: ai-session-toggle
# @desc: Toggle persistent session mode on/off
# @usage: ai-session-toggle [on|off]
# @example: ai-session-toggle on
ai-session-toggle() {
    if [ "$AI_SESSION" = "true" ]; then
        export AI_SESSION="false"
        echo -e "\033[0;33mSession Memory:\033[0m DISABLED (Commands run independently)"
    else
        export AI_SESSION="true"
        _init_session_file
        echo -e "\033[0;32mSession Memory:\033[0m ENABLED (Commands share previous context)"
    fi
}

# @cmd: ai-session-show
# @desc: Show current session memory history
# @usage: ai-session-show
# @example: ai-session-show
ai-session-show() {
    _init_session_file
    if [ "$(jq 'length' "$AI_SESSION_FILE")" -eq 0 ]; then
        echo "Session memory is currently empty."
    else
        echo -e "\033[1;34m=== Active Session History ===\033[0m"
        jq -r '.[] | "\u001b[1m[" + .role + "]:\u001b[0m\n" + .content + "\n---"' "$AI_SESSION_FILE"
    fi
}

# @cmd: ai-chat
# @desc: Multi-turn session-based interactive conversation
# @usage: ai-chat [--clear|--show|--toggle]
# @example: ai-chat --show
ai-chat() {
    case "$1" in
        --clear|-c)
            ai-session-clear
            ;;
        --show|-s)
            ai-session-show
            ;;
        --toggle|-t)
            ai-session-toggle
            ;;
        *)
            # Enable session mode for chat command
            local old_session="$AI_SESSION"
            export AI_SESSION="true"
            
            _ollama_exec "You are a helpful programming assistant in a multi-turn terminal session." "$*"
            
            export AI_SESSION="$old_session"
            ;;
    esac
}

# @cmd: ai-session-cap
# @desc: Dynamic command to change or view turn limits on the fly
# @usage: ai-session-cap <max-session-turns>
# @example: ai-session-cap 10
ai-session-cap() {
    if [ -n "$1" ]; then
        export AI_SESSION_MAX_TURNS="$1"
        echo -e "\033[0;32m[Session Cap Updated]\033[0m Sliding window set to last \033[1m${AI_SESSION_MAX_TURNS}\033[0m turns ($(( AI_SESSION_MAX_TURNS * 2 )) messages)."
    else
        echo -e "\033[0;36m[Session Cap]\033[0m Active window limit: \033[1m${AI_SESSION_MAX_TURNS}\033[0m turns ($(( AI_SESSION_MAX_TURNS * 2 )) messages)."
    fi
}

# ==============================================================================
# @category: Performance Tracking & Execution Engine
# ==============================================================================

# @cmd: ai-perf
# @desc: Toggle real-time execution timing, token generation speed (tok/s), and prompt evaluation metrics on or off
# @usage: ai-perf [on|off]
# @example: ai-perf off
ai-perf() {
    if [ "$1" = "on" ] || [ "$1" = "true" ]; then
        export AI_SHOW_PERF="true"
        echo "Performance timing: ENABLED"
    elif [ "$1" = "off" ] || [ "$1" = "false" ]; then
        export AI_SHOW_PERF="false"
        echo "Performance timing: DISABLED"
    else
        echo "Performance timing status: ${AI_SHOW_PERF}"
        echo "Usage: ai-perf [on|off]"
    fi
}

# ==============================================================================
# @category: Context Compaction Settings & Filters
# ==============================================================================

# @cmd: ai-compact
# @desc: Toggle automatic prompt context minification (AST skeletonization + whitespace/comment stripping) on or off
# @usage: ai-compact [on|off]
# @example: ai-compact on
ai-compact() {
    if [ "$1" = "on" ] || [ "$1" = "true" ]; then
        export AI_COMPACT="true"
        echo "Context compaction: ENABLED"
    elif [ "$1" = "off" ] || [ "$1" = "false" ]; then
        export AI_COMPACT="false"
        echo "Context compaction: DISABLED"
    else
        echo "Context compaction status: ${AI_COMPACT}"
        echo "Usage: ai-compact [on|off]"
    fi
}

# @cmd: ai-skeleton
# @desc: Run Python code through the local AST skeletonizer to preview stripped function bodies without sending a request to Ollama
# @usage: cat <file> | ai-skeleton [min_lines]
# @example: cat main.py | ai-skeleton 15
ai-skeleton() {
    local min_lines="${1:-$AI_SKEL_MIN_LINES}"
    python3 "${LLAMALIAS_DIR}/core/py_skeleton.py" --min-lines "$min_lines"
}

# @cmd: ai-skeleton-bench
# @desc: Runs code through AST skeletonizer across multiple threshold steps (0, 5, 10, 20...) and measures token reduction
# @usage: ai-skeleton-bench [file] OR cat <file> | ai-skeleton-bench
# @example: ai-skeleton-bench src/app.py
ai-skeleton-bench() {
    if [ -t 0 ] && [ -n "$1" ]; then
        python3 "${LLAMALIAS_DIR}/core/py_skeleton_benchmark.py" "$1" --model "$AI_MODEL"
    else
        python3 "${LLAMALIAS_DIR}/core/py_skeleton_benchmark.py" --model "$AI_MODEL"
    fi
}

# ==============================================================================
# Terminal Prompt Indicator (PS1 Integration)
# ==============================================================================

# Generates a dynamic prompt status badge with active model and session state
_ai_ps1() {
    # 1. Active Model Indicator
    local model_name="${AI_MODEL:-mistral}"
    
    # Strip tag if desired (e.g., display 'mistral' instead of 'mistral:latest')
    # model_name="${model_name%%:*}"

    local model_badge="\033[0;36m🤖[${model_name}]\033[0m"

    # 2. Session Indicator (if AI_SESSION is true)
    local session_badge=""
    if [ "$AI_SESSION" = "true" ]; then
        local turns=0
        if [ -f "$AI_SESSION_FILE" ]; then
            turns=$(jq 'length / 2 | floor' "$AI_SESSION_FILE" 2>/dev/null || echo "0")
        fi
        session_badge="\033[1;35m🦙[${turns}t]\033[0m"
    fi

    # Print badges followed by a space
    printf "${model_badge}${session_badge} "
}

# Safely prepends the prompt indicator to PS1 if not already present
_enable_ai_ps1_hook() {
    if [[ ! "$PS1" =~ _ai_ps1 ]]; then
        export PS1="\$( _ai_ps1 )$PS1"
    fi
}

# Register prompt hook upon sourcing
_enable_ai_ps1_hook

# ==============================================================================
# Terminal Exit Hook (Auto-Save Active Session)
# ==============================================================================

_ai_session_exit_hook() {
    # Check if session mode was active and history exists
    if [ "$AI_SESSION" = "true" ] && [ -f "$AI_SESSION_FILE" ]; then
        local msg_count
        msg_count=$(jq 'length' "$AI_SESSION_FILE" 2>/dev/null || echo "0")

        if [ "$msg_count" -gt 0 ]; then
            _init_sessions_dir

            # 1. Update primary 'autosave' profile (for easy one-command restoration)
            cp "$AI_SESSION_FILE" "${AI_SESSIONS_DIR}/autosave.json"

            # 2. Save a timestamped copy to prevent accidental overwrites over time
            local timestamp
            timestamp=$(date "+%Y%m%d_%H%M%S")
            cp "$AI_SESSION_FILE" "${AI_SESSIONS_DIR}/autosave_${timestamp}.json"
        fi
    fi
}

# Register signal handler to execute when the shell process terminates
trap _ai_session_exit_hook EXIT
