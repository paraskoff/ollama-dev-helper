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