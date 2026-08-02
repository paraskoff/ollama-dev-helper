#!/usr/bin/env bash
# @category: Code Quality & Engineering

# Software engineering workflows, code review, bug fixes, refactoring, and test generation.

# ==============================================================================
# Code Quality, Refactoring & Diagnostics
# ==============================================================================

# @cmd: ai-review
# @desc: Analyze code for logical bugs, performance bottlenecks, and security vulnerabilities
# @usage: cat <file> | ai-review
# @example: cat main.py | ai-review
ai-review() {
    _ollama_exec "Perform a concise code review on this snippet. Identify logical bugs, performance bottlenecks, or security issues in 3 bullet points." "$1"
}

# @cmd: ai-refactor
# @desc: Refactor code for modern best practices, improved readability, and efficiency
# @usage: cat <file> | ai-refactor
# @example: cat utils.py | ai-refactor
ai-refactor() {
    _ollama_exec "Refactor this code for efficiency, readability, and modern best practices. Output only the refactored code." "$1"
}

# @cmd: ai-fix
# @desc: Analyze build errors, tracebacks, or terminal logs and propose a direct fix
# @usage: <command> 2>&1 | ai-fix
# @example: python3 script.py 2>&1 | ai-fix
ai-fix() {
    _ollama_exec "Identify the root cause of this build/runtime error and provide a 1-line solution with the corrected command or code." "$1"
}

# @cmd: ai-test
# @desc: Write unit tests covering happy paths and standard edge cases
# @usage: cat <file> | ai-test
# @example: cat models.py | ai-test
ai-test() {
    _ollama_exec "Write comprehensive unit tests covering standard edge cases for this code." "$1"
}

# ==============================================================================
# Code Optimization & Benchmarking
# ==============================================================================

# @cmd: ai-bench
# @desc: Generate benchmark script/test to measure its execution time, memory usage, and performance under load
# @usage: cat <file> | ai-bench
# @example: cat heavy_algo.py | ai-bench
ai-bench() {
    _ollama_exec "Generate a standalone benchmark script/test for this code to measure its execution time, memory usage, and performance under load." "$1"
}

# @cmd: ai-deps
# @desc: Audit dependency file for potential security vulnerabilities, bloated/redundant libraries, and modern alternatives
# @usage: cat <file> | ai-deps
# @example: cat requirements.txt | ai-deps
ai-deps() {
    _ollama_exec "Audit this dependency file. Identify potential security vulnerabilities, bloated/redundant libraries, and modern alternatives." "$1"
}

# ==============================================================================
# Documentation, Translation & Knowledge Management
# ==============================================================================

# @cmd: ai-doc
# @desc: Add Google-style docstrings and explicit type annotations to functions and classes
# @usage: cat <file> | ai-doc
# @example: cat api.py | ai-doc
ai-doc() {
    _ollama_exec "Add clear docstrings and precise type annotations to this code. Return only the updated code snippet." "$1"
}

# @cmd: ai-explain
# @desc: Explain complex code snippets, configuration files, or logs in plain language
# @usage: cat <file> | ai-explain
# @example: cat main.py | ai-explain
ai-explain() {
    _ollama_exec "Explain what this code or text does in plain, concise technical terms." "$1"
}

# @cmd: ai-convert
# @desc: Translate code snippets from one programming language to another
# @usage: cat <file> | ai-convert <lang>
# @example: cat legacy.js | ai-convert python
ai-convert() {
    if [ -z "$1" ]; then
        echo "Usage: cat code.js | ai-convert python"
        return 1
    fi
    _ollama_exec "Translate this code into clean, idiomatic $1 code. Preserve exact business logic and return code only."
}

# @cmd: ai-meta
# @desc: Generate Markdown YAML frontmatter & tags
# @usage: cat <file> | ai-meta
# @example: cat note.md | ai-meta
ai-meta() {
    _ollama_exec "Extract key concepts from this text and generate YAML frontmatter with tags (lowercase, hyphenated), summary, and related topics. Return ONLY the YAML block." "$1"
}

# @cmd: ai-proof
# @desc: Proofread technical docs and comments for grammar, typos, and technical clarity
# @usage: cat <file> | ai-proof
# @example: cat docs/api.md | ai-proof
ai-proof() {
    _ollama_exec "Proofread this text for grammar, typos, and technical clarity. Maintain original technical terms and output the corrected version directly." "$1"
}
