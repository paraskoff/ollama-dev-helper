#!/usr/bin/env bash

# =============================
# --- Central Configuration ---
# =============================

# Change default model here or override dynamically using 'ai-model <name>'
export AI_MODEL="${AI_MODEL:-qwen2.5-coder:1.5b}"
export OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"

# Execution Limits (tuned for CPU execution)
export AI_NUM_CTX="${AI_NUM_CTX:-2048}"
export AI_NUM_THREAD="${AI_NUM_THREAD:-3}"

# Performance timing output toggle (default: true)
export AI_SHOW_PERF="${AI_SHOW_PERF:-true}"

# Enable/disable compaction filter (default: true)
export AI_COMPACT="${AI_COMPACT:-true}"

# Set default minimum line threshold for function skeletonization (default: 10 lines)
export AI_SKEL_MIN_LINES="${AI_SKEL_MIN_LINES:-10}"

# Session & Memory Management Variables
export AI_SESSION_FILE="${TMPDIR:-/tmp}/llamalias_session_$(whoami).json"
export AI_SESSION="${AI_SESSION:-false}" # Default: off for isolated commands

# Maximum number of interactive turns (1 turn = 1 User prompt + 1 Assistant response)
# Default: 5 turns (10 total messages)
export AI_SESSION_MAX_TURNS="${AI_SESSION_MAX_TURNS:-5}"

# Persistent Named Session Storage (~/.llamalias/)
export AI_SESSIONS_DIR="${HOME}/.llamalias"

# Enable or disable automatic session restoration on shell launch (default: true)
export AI_AUTO_RESTORE="${AI_AUTO_RESTORE:-true}"