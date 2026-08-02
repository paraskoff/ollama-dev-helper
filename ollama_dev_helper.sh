#!/usr/bin/env bash
# ==============================================================================
# Ollama CLI Development Helper Library
# ==============================================================================

# --- Central Configuration ---
# Change default model here or override dynamically using 'ai-model <name>'
export OLLAMA_MODEL="${OLLAMA_MODEL:-qwen2.5-coder:1.5b}"

# ==============================================================================
# Performance Tracking & Execution Engine
# ==============================================================================

# Performance timing output toggle (default: true)
export AI_SHOW_PERF="${AI_SHOW_PERF:-true}"

# Toggle or view performance tracking mode
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

# Enable/disable compaction filter (default: true)
export AI_COMPACT="${AI_COMPACT:-true}"

# Toggle context compaction on/off
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

# Internal text minifier: strips blank lines, pure comment lines, and trailing spaces
_compact_text() {
    if [ "$AI_COMPACT" = "true" ]; then
        sed -E '
            /^\s*$/d;                 # Delete empty/whitespace-only lines
            /^\s*(#|\/\/|\/\*|\*)/d;  # Delete lines that are purely comments (#, //, /*, *)
            s/[[:space:]]+$//;        # Strip trailing whitespace
        '
    else
        cat # Pass through unmodified if compaction is disabled
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
        curl -s -N http://127.0.0.1:11434/api/generate -d "{
          \"model\": \"${OLLAMA_MODEL}\",
          \"prompt\": ${json_prompt},
          \"stream\": true,
          \"options\": {
            \"num_ctx\": 2048,
            \"num_thread\": 3
          }
        }" | while read -r line; do
            echo "$line" >> "$tmp_file"
            echo -n "$line" | jq -r '.response // empty' 2>/dev/null
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

# View or dynamically switch the active model
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

# Check system status and loaded runner memory
ai-status() {
    echo "=== Active Configuration ==="
    echo "Model: ${OLLAMA_MODEL}"
    echo "Ollama Endpoint: http://127.0.0.1:11434"
    echo ""
    echo "=== Loaded Runners (ps) ==="
    ollama ps
}

# ==============================================================================
# Git & Version Control Utilities
# ==============================================================================

# Generate Conventional Commit message from staged git changes
ai-commit() {
    local diff
    diff=$(git diff --cached)
    if [ -z "$diff" ]; then
        echo "Error: No staged changes found. Run 'git add' first."
        return 1
    fi
    echo "$diff" | _ollama_exec "Write a concise, single-line conventional commit message based on this diff. Output ONLY the commit message string, no quotes, no explanation."
}

# Generate a .gitignore file for specified tech stacks
ai-ignore() {
    if [ -z "$1" ]; then
        echo "Usage: ai-ignore <technologies...>"
        echo "Example: ai-ignore python vscode linux"
        return 1
    fi
    _ollama_exec "Generate a complete .gitignore file for the following technologies: $*. Output raw gitignore content only."
}

# ==============================================================================
# Code Quality, Refactoring & Diagnostics
# ==============================================================================

# Analyze code or git diff for bugs and security vulnerabilities
ai-review() {
    _ollama_exec "Perform a concise code review on this snippet. Identify logical bugs, performance bottlenecks, or security issues in 3 bullet points." "$1"
}

# Refactor code for cleanliness, modern standards, and efficiency
ai-refactor() {
    _ollama_exec "Refactor this code for efficiency, readability, and modern best practices. Output only the refactored code." "$1"
}

# Add Google-style docstrings and explicit type hints
ai-doc() {
    _ollama_exec "Add clear docstrings and precise type annotations to this code. Return only the updated code snippet." "$1"
}

# Generate unit tests for a code snippet or file
ai-test() {
    _ollama_exec "Write comprehensive unit tests covering standard edge cases for this code." "$1"
}

# Analyze terminal error logs, tracebacks, or build outputs
ai-fix() {
    _ollama_exec "Identify the root cause of this build/runtime error and provide a 1-line solution with the corrected command or code." "$1"
}

# ==============================================================================
# Utility & Reference Generators
# ==============================================================================

# Translate natural language into a Linux terminal command
ai-cmd() {
    if [ -z "$1" ]; then
        echo "Usage: ai-cmd <description of terminal action>"
        return 1
    fi
    _ollama_exec "Translate this request into a single Linux bash command line: '$*'. Output ONLY the command, no markdown, no quotes."
}

# Explain code, logs, or complex configs in plain english
ai-explain() {
    _ollama_exec "Explain what this code or text does in plain, concise technical terms." "$1"
}

# Build or explain regular expressions
ai-regex() {
    _ollama_exec "Create or explain a regex pattern based on this request. Output the pattern and a brief regex breakdown." "$1"
}

# Convert plain text requirements into SQL queries
ai-sql() {
    _ollama_exec "Write a clean SQL query to satisfy this requirement. Output the SQL code block only." "$1"
}

# Clean, repair, or format malformed JSON or YAML
ai-json() {
    _ollama_exec "Format and fix any syntax errors in this JSON/YAML data. Output clean, valid formatted JSON only."
}

# Generic quick prompt
ai-ask() {
    _ollama_exec "$*"
}

# ==============================================================================
# DevOps & System Administration
# ==============================================================================

# Generate an optimized Dockerfile or docker-compose setup
ai-docker() {
    _ollama_exec "Generate a minimal, production-ready, multi-stage Dockerfile or docker-compose file for this project setup: '$*'. Output raw code only."
}

# Generate or explain cron expressions
ai-cron() {
    if [ -z "$1" ]; then
        echo "Usage: ai-cron <description or expression>"
        return 1
    fi
    _ollama_exec "If this is a natural language request, convert it to a valid crontab expression. If it is a crontab expression, explain its schedule: '$*'. Output concisely."
}

# Scan codebase or text for hardcoded API keys, passwords, or secrets
ai-sec() {
    _ollama_exec "Scan this code or text for hardcoded secrets, API tokens, passwords, or insecure permissions. List any findings in bullet points, or output 'NO SECRETS DETECTED'." "$1"
}

# Generate a sanitized .env.example file from code or configuration files
ai-env() {
    _ollama_exec "Analyze this file/code and extract all environment variable references into a clean .env.example file with place-holder values. Output raw file content only." "$1"
}

# ==============================================================================
# Type Generation & Data Conversion
# ==============================================================================

# Convert raw JSON into TypeScript interfaces or Pydantic models
ai-type() {
    local target_lang="${1:-typescript}"
    _ollama_exec "Convert this JSON structure into explicit ${target_lang} type definitions (interfaces or classes). Output code only."
}

# Convert cURL commands into clean Python/Node.js/Go code snippets
ai-curl() {
    local target_lang="${1:-python}"
    _ollama_exec "Convert this cURL command into an idiomatic ${target_lang} HTTP request snippet using modern libraries. Output code only."
}

# Generate realistic mock JSON or CSV fixtures from a schema/description
ai-mock() {
    if [ -z "$1" ]; then
        echo "Usage: ai-mock <description of desired mock data>"
        return 1
    fi
    _ollama_exec "Generate a realistic mock JSON array (5-10 records) matching this specification: '$*'. Output valid formatted JSON only."
}

# ==============================================================================
# Documentation & Translation
# ==============================================================================

# Generate release notes / changelog entries from git log history
ai-changelog() {
    local commits
    commits=$(git log -n 15 --oneline)
    if [ -z "$commits" ]; then
        echo "Error: Not a git repository or no recent commits found."
        return 1
    fi
    echo "$commits" | _ollama_exec "Group these recent git commits into a clean Markdown CHANGELOG categorized by Features, Fixes, and Maintenance."
}

# Translate code snippets from one programming language to another
ai-convert() {
    if [ -z "$1" ]; then
        echo "Usage: cat code.js | ai-convert python"
        return 1
    fi
    _ollama_exec "Translate this code into clean, idiomatic $1 code. Preserve exact business logic and return code only."
}

# Generate a clean Markdown README section for a module or script
ai-readme() {
    _ollama_exec "Generate a concise Markdown README.md outline for this project/code snippet including Overview, Installation, and Usage sections." "$1"
}

# ==============================================================================
# Helper Documentation & Cheat Sheet
# ==============================================================================

# Internal helper to print formatted detail view
_ai_help_detail() {
    echo -e "\033[1;34m=== Help: $1 ===\033[0m"
    echo -e "\033[1mDescription:\033[0m $2"
    echo -e "\033[1mUsage:\033[0m       $3"
    echo -e "\033[1mExample:\033[0m     $4"
    echo -e "\033[1mInput Type:\033[0m  $5"
}

# Display command cheat sheet with descriptions or detailed help for a specific command
ai-help() {
    local cmd="${1#ai-}" # Strip 'ai-' prefix if present

    if [ -z "$cmd" ]; then
        echo -e "\033[1;34m=== Ollama CLI Helper Commands Cheat Sheet ===\033[0m\n"
        printf "\033[1m%-12s %-46s %-35s\033[0m\n" "Command" "Description" "Example Usage"
        printf "%-12s %-46s %-35s\n" "-------" "-----------" "-------------"
        printf "%-12s %-46s %-35s\n" "ai-model" "View or dynamically switch active Ollama model" "ai-model qwen2.5-coder:1.5b"
        printf "%-12s %-46s %-35s\n" "ai-status" "Display active config, endpoint, and runners" "ai-status"
        printf "%-12s %-46s %-35s\n" "ai-commit" "Generate Conventional Commit from staged diff" "ai-commit"
        printf "%-12s %-46s %-35s\n" "ai-ignore" "Generate .gitignore for specified tech stacks" "ai-ignore python docker"
        printf "%-12s %-46s %-35s\n" "ai-review" "Audit code for bugs, bottlenecks, & security" "cat main.py | ai-review"
        printf "%-12s %-46s %-35s\n" "ai-refactor" "Optimize code for clarity and performance" "cat main.py | ai-refactor"
        printf "%-12s %-46s %-35s\n" "ai-doc" "Add docstrings and explicit type hints" "cat utils.py | ai-doc"
        printf "%-12s %-46s %-35s\n" "ai-test" "Generate unit tests with edge-case coverage" "cat models.py | ai-test"
        printf "%-12s %-46s %-35s\n" "ai-fix" "Diagnose terminal errors, tracebacks, or logs" "python script.py 2>&1 | ai-fix"
        printf "%-12s %-46s %-35s\n" "ai-cmd" "Convert natural language to Linux bash command" "ai-cmd \"find pdfs from last 24h\""
        printf "%-12s %-46s %-35s\n" "ai-explain" "Explain complex code or configs in plain text" "cat main.py | ai-explain"
        printf "%-12s %-46s %-35s\n" "ai-regex" "Create or explain regular expression patterns" "ai-regex \"match email address\""
        printf "%-12s %-46s %-35s\n" "ai-sql" "Translate natural language to SQL queries" "ai-sql \"top 5 users by spend\""
        printf "%-12s %-46s %-35s\n" "ai-json" "Repair and format messy JSON/YAML data" "cat bad.json | ai-json"
        printf "%-12s %-46s %-35s\n" "ai-docker" "Generate production Dockerfile or Compose setup" "ai-docker \"FastAPI with Postgres\""
        printf "%-12s %-46s %-35s\n" "ai-cron" "Convert to or explain crontab schedule syntax" "ai-cron \"every 15m on weekdays\""
        printf "%-12s %-46s %-35s\n" "ai-sec" "Scan code diffs for hardcoded secrets & keys" "git diff | ai-sec"
        printf "%-12s %-46s %-35s\n" "ai-env" "Extract env vars into a .env.example file" "cat config.py | ai-env"
        printf "%-12s %-46s %-35s\n" "ai-type" "Convert JSON to TypeScript/Pydantic types" "cat data.json | ai-type pydantic"
        printf "%-12s %-46s %-35s\n" "ai-curl" "Convert cURL requests to Python/Node code" "echo \"curl...\" | ai-curl python"
        printf "%-12s %-46s %-35s\n" "ai-mock" "Generate realistic mock JSON array fixtures" "ai-mock \"users with email, role\""
        printf "%-12s %-46s %-35s\n" "ai-changelog" "Build Markdown CHANGELOG from git log history" "ai-changelog"
        printf "%-12s %-46s %-35s\n" "ai-convert" "Translate code to another programming language" "cat script.js | ai-convert python"
        printf "%-12s %-46s %-35s\n" "ai-readme" "Generate structured Markdown README.md outline" "cat main.py | ai-readme"
        printf "%-12s %-46s %-35s\n" "ai-ask" "Send arbitrary raw prompt directly to model" "ai-ask \"Explain async/await\""
        printf "%-12s %-46s %-35s\n" "ai-perf" "Toggle performance metrics & execution timing" "ai-perf [on|off]"
        printf "%-12s %-46s %-35s\n" "ai-compact" "Toggle automatic prompt context minification" "ai-compact [on|off]"
        echo -e "\n\033[0;33mTip: Type 'ai-help <command>' for detailed usage (e.g., 'ai-help commit').\033[0m"
        return 0
    fi

    case "$cmd" in
        model)     _ai_help_detail "ai-model" "View currently active model or switch to a new local model dynamically across all helpers." "ai-model [model_name]" "ai-model qwen2.5-coder:1.5b" "Command argument (optional)" ;;
        status)    _ai_help_detail "ai-status" "Display active helper configuration, Ollama API endpoint, and loaded runners." "ai-status" "ai-status" "None" ;;
        commit)    _ai_help_detail "ai-commit" "Generate a Conventional Commit message string based on currently staged git changes." "ai-commit" "git add . && ai-commit" "Staged Git diff (git diff --cached)" ;;
        ignore)    _ai_help_detail "ai-ignore" "Generate a complete .gitignore file populated for specified technologies." "ai-ignore <tech1> <tech2>..." "ai-ignore python docker vscode" "Command arguments" ;;
        review)    _ai_help_detail "ai-review" "Analyze code for logical bugs, performance bottlenecks, and security vulnerabilities." "cat <file> | ai-review" "cat main.py | ai-review" "Piped code or stdin" ;;
        refactor)  _ai_help_detail "ai-refactor" "Refactor code for modern best practices, improved readability, and efficiency." "cat <file> | ai-refactor" "cat utils.py | ai-refactor" "Piped code or stdin" ;;
        doc)       _ai_help_detail "ai-doc" "Add Google-style docstrings and explicit type annotations to functions and classes." "cat <file> | ai-doc" "cat api.py | ai-doc" "Piped code or stdin" ;;
        test)      _ai_help_detail "ai-test" "Write unit tests covering happy paths and standard edge cases." "cat <file> | ai-test" "cat models.py | ai-test" "Piped code or stdin" ;;
        fix)       _ai_help_detail "ai-fix" "Analyze build errors, tracebacks, or terminal logs and propose a direct fix." "<command> 2>&1 | ai-fix" "python3 script.py 2>&1 | ai-fix" "Piped stdout/stderr" ;;
        cmd)       _ai_help_detail "ai-cmd" "Translate natural language instructions into a single Linux bash command." "ai-cmd <description>" "ai-cmd \"find all pdf files modified in last 24h\"" "Direct Argument string" ;;
        explain)   _ai_help_detail "ai-explain" "Explain complex code snippets, configuration files, or logs in plain language." "cat <file> | ai-explain" "cat main.py | ai-explain" "Piped code or stdin" ;;
        regex)     _ai_help_detail "ai-regex" "Generate a new regex pattern or explain an existing regular expression." "ai-regex <request>" "ai-regex \"match valid email addresses\"" "Direct Argument string" ;;
        sql)       _ai_help_detail "ai-sql" "Translate natural language data requests into clean SQL queries." "ai-sql <query request>" "ai-sql \"get top 5 users by purchase volume\"" "Direct Argument string" ;;
        json)      _ai_help_detail "ai-json" "Validate, format, and fix syntax errors in malformed JSON or YAML data." "cat <file> | ai-json" "cat config.json | ai-json" "Piped JSON/YAML payload" ;;
        docker)    _ai_help_detail "ai-docker" "Generate a minimal production Dockerfile or docker-compose setup." "ai-docker <stack info>" "ai-docker \"Python FastAPI with PostgreSQL\"" "Direct Argument string" ;;
        cron)      _ai_help_detail "ai-cron" "Convert human-readable schedules to crontab syntax or explain existing cron lines." "ai-cron <schedule>" "ai-cron \"every 15 minutes on weekdays\"" "Direct Argument string" ;;
        sec)       _ai_help_detail "ai-sec" "Scan code diffs or text for hardcoded API keys, passwords, and tokens." "cat <file> | ai-sec" "git diff | ai-sec" "Piped code / text" ;;
        env)       _ai_help_detail "ai-env" "Extract all referenced environment variables into a sanitized .env.example file." "cat <file> | ai-env" "cat src/config.py | ai-env" "Piped code" ;;
        type)      _ai_help_detail "ai-type" "Convert JSON payload structures into TypeScript interfaces or Pydantic models." "cat <json> | ai-type [lang]" "cat data.json | ai-type pydantic" "Piped JSON (Optional arg: lang)" ;;
        curl)      _ai_help_detail "ai-curl" "Convert cURL HTTP commands into executable code snippets (Python, Node, Go)." "echo \"curl...\" | ai-curl [lang]" "echo \"curl https://api.com\" | ai-curl python" "Piped cURL string" ;;
        mock)      _ai_help_detail "ai-mock" "Generate realistic mock JSON record arrays matching a given schema." "ai-mock <description>" "ai-mock \"users with id, email, created_at, role\"" "Direct Argument string" ;;
        changelog) _ai_help_detail "ai-changelog" "Aggregate recent git commits into a clean Markdown CHANGELOG." "ai-changelog" "ai-changelog" "Local git log history" ;;
        convert)   _ai_help_detail "ai-convert" "Translate code snippets from one programming language to another." "cat <file> | ai-convert <lang>" "cat legacy.js | ai-convert python" "Piped code + Target lang arg" ;;
        readme)    _ai_help_detail "ai-readme" "Generate a structured Markdown README.md outline for a file or directory." "cat <file> | ai-readme" "cat main.py | ai-readme" "Piped code or file" ;;
        ask)       _ai_help_detail "ai-ask" "Send a direct, raw prompt to the active Ollama model." "ai-ask <prompt>" "ai-ask \"Explain async/await in Python\"" "Direct Argument string" ;;
        perf)      _ai_help_detail "ai-perf" "Toggle real-time execution timing, token generation speed (tok/s), and prompt evaluation metrics on or off." "ai-perf [on|off]" "ai-perf off" "Command argument (optional)" ;;
        compact)   _ai_help_detail "ai-compact" "Toggle automatic prompt context minification (AST skeletonization + whitespace/comment stripping) on or off." "ai-compact [on|off]" "ai-compact on" "Command argument (optional)" ;;
        *)         echo "Unknown command: 'ai-$cmd'. Run 'ai-help' to list all commands." ;;
    esac
}