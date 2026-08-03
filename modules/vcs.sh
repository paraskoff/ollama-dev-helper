#!/usr/bin/env bash
# @category: Git & Repository Management

# Version control integration, project meta-files, and documentation outlines.

# ==============================================================================
# Git & Version Control Utilities
# ==============================================================================

# @cmd: ai-commit
# @desc: Generate a Conventional Commit message string based on currently staged git changes
# @usage: ai-commit
ai-commit() {
    local diff
    diff=$(git diff --cached)
    if [ -z "$diff" ]; then
        echo "Error: No staged changes found. Run 'git add' first."
        return 1
    fi
    echo "$diff" | _ollama_exec "Write a concise, single-line conventional commit message based on this diff. Output ONLY the commit message string, no quotes, no explanation."
}

# @cmd: ai-ignore
# @desc: Generate a complete .gitignore file populated for specified technologies
# @usage: ai-ignore <tech1> <tech2>...
ai-ignore() {
    if [ -z "$1" ]; then
        echo "Usage: ai-ignore <technologies...>"
        echo "Example: ai-ignore python vscode linux"
        return 1
    fi
    _ollama_exec "Generate a complete .gitignore file for the following technologies: $*. Output raw gitignore content only."
}

# ==============================================================================
# Documentation
# ==============================================================================

# @cmd: ai-changelog
# @desc: Aggregate recent git commits into a clean Markdown CHANGELOG
# @usage: ai-changelog
ai-changelog() {
    local commits
    commits=$(git log -n 15 --oneline)
    if [ -z "$commits" ]; then
        echo "Error: Not a git repository or no recent commits found."
        return 1
    fi
    echo "$commits" | _ollama_exec "Group these recent git commits into a clean Markdown CHANGELOG categorized by Features, Fixes, and Maintenance."
}

# @cmd: ai-readme
# @desc: Generate a structured Markdown README.md outline for a file or directory
# @usage: cat <file> | ai-readme
ai-readme() {
    _ollama_exec "Generate a concise Markdown README.md outline for this project/code snippet including Overview, Installation, and Usage sections." "$1"
}
