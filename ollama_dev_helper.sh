#!/usr/bin/env bash
# ==============================================================================
# Ollama CLI Development Helper Library
# ==============================================================================

# --- Central Configuration ---
# Change default model here or override dynamically using 'ai-model <name>'
export OLLAMA_MODEL="${OLLAMA_MODEL:-qwen2.5-coder:1.5b}"

# --- Internal Execution Engine ---
_ollama_exec() {
    local system_prompt="$1"
    local extra_arg="$2"
    local input_data=""

    # Read from standard input if data is piped
    if [ ! -t 0 ]; then
        input_data=$(cat)
    fi

    # Construct the query payload
    local full_prompt="${system_prompt}"
    if [ -n "$extra_arg" ]; then
        full_prompt="${full_prompt} [Context: ${extra_arg}]"
    fi
    if [ -n "$input_data" ]; then
        full_prompt="${full_prompt}:\n\n${input_data}"
    fi

    # Run Ollama streaming response directly to stdout
    ollama run "$OLLAMA_MODEL" "$full_prompt"
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
