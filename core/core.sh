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

# Core runner with built-in token & execution metrics
_ollama_exec() {
    local system_prompt="$1"
    local extra_arg="$2"
    local input_data=""

    # Read from standard input and compact if enabled
    if [ ! -t 0 ]; then
        input_data=$(cat | _compact_text)
    fi

    # Construct prompt with compacted context
    local full_prompt="${system_prompt}"
    if [ -n "$extra_arg" ]; then
        full_prompt="${full_prompt} [Context: ${extra_arg}]"
    fi
    if [ -n "$input_data" ]; then
        full_prompt="${full_prompt}:\n\n${input_data}"
    fi

    local start_time
    start_time=$(date +%s.%N 2>/dev/null || date +%s)

    # Use HTTP API with streaming if jq is installed for exact metrics
    if command -v jq >/dev/null 2>&1; then
        local json_prompt
        json_prompt=$(jq -n --arg p "$full_prompt" '$p')

        local tmp_file
        tmp_file=$(mktemp)

        # Stream response while logging raw JSON to temporary file for metrics extraction
        curl -s -N ${OLLAMA_HOST}/api/generate -d "{
          \"model\": \"${OLLAMA_MODEL}\",
          \"prompt\": ${json_prompt},
          \"stream\": true,
          \"options\": {
            \"num_ctx\": 2048,
            \"num_thread\": 3
          }
        }" | while read -r line; do
            echo "$line" >> "$tmp_file"
            # FIX: Changed 'jq -r' to 'jq -j' to prevent adding newlines after each streamed token
            echo -n "$line" | jq -j '.response // empty' 2>/dev/null
        done
        echo "" # Newline after output completion

        local end_time
        end_time=$(date +%s.%N 2>/dev/null || date +%s)

        if [ "$AI_SHOW_PERF" = "true" ]; then
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
            if [ "$eval_dur" -gt 0 ]; then
                gen_tps=$(awk "BEGIN {printf \"%.2f\", ($eval_count / ($eval_dur / 1000000000))}")
            fi

            local prompt_tps="0.00"
            if [ "$prompt_dur" -gt 0 ]; then
                prompt_tps=$(awk "BEGIN {printf \"%.2f\", ($prompt_count / ($prompt_dur / 1000000000))}")
            fi

            echo -e "\033[0;36m[Perf] ${wall_time}s total | Gen: ${eval_count} tok (${gen_tps} tok/s) | Prompt: ${prompt_count} tok (${prompt_tps} tok/s)\033[0m"
        fi

        rm -f "$tmp_file"
    else
        # Fallback to standard CLI if jq is not present
        ollama run "$OLLAMA_MODEL" "$full_prompt"
        local end_time
        end_time=$(date +%s.%N 2>/dev/null || date +%s)

        if [ "$AI_SHOW_PERF" = "true" ]; then
            local wall_time
            wall_time=$(awk "BEGIN {printf \"%.2f\", $end_time - $start_time}")
            echo -e "\033[0;36m[Perf] Completed in ${wall_time}s\033[0m"
        fi
    fi
}

# ==============================================================================
# Model & Environment Management
# ==============================================================================

# @cmd: ai-model
# @desc: View currently active model or switch to a new local model dynamically across all helpers
# @usage: ai-model [model_name]
ai-model() {
    if [ -z "$1" ]; then
        echo "Active Ollama Model: ${OLLAMA_MODEL}"
        echo "Available local models:"
        ollama list
    else
        export OLLAMA_MODEL="$1"
        echo "Switched active AI model to: ${OLLAMA_MODEL}"
    fi
}

# @cmd: ai-status
# @desc: Display active helper configuration, Ollama API endpoint, and loaded runners
# @usage: ai-status
ai-status() {
    echo "=== Active Configuration ==="
    echo "Model: ${OLLAMA_MODEL}"
    echo "Ollama Endpoint: ${OLLAMA_HOST}"
    echo ""
    echo "=== Loaded Runners (ps) ==="
    ollama ps
}

# ==============================================================================
# Performance Tracking & Execution Engine
# ==============================================================================

# @cmd: ai-perf
# @desc: Toggle real-time execution timing, token generation speed (tok/s), and prompt evaluation metrics on or off
# @usage: ai-perf [on|off]
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
# Context Compaction Settings & Filters
# ==============================================================================

# @cmd: ai-compact
# @desc: Toggle automatic prompt context minification (AST skeletonization + whitespace/comment stripping) on or off
# @usage: ai-compact [on|off]
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

# ==============================================================================
# Utility & Reference Generators
# ==============================================================================

# @cmd: ai-ask
# @desc: Send a direct, raw prompt to the active Ollama model
# @usage: ai-ask <prompt>
ai-ask() {
    _ollama_exec "$*"
}
