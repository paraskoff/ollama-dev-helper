#!/usr/bin/env bash
# @category: DevOps & Security

# Command-line translation, containerization, environment security, and job scheduling.

# ==============================================================================
# DevOps & System Administration
# ==============================================================================

# @cmd: ai-cmd
# @desc: Translate natural language instructions into a single Linux bash command
# @usage: ai-cmd <description>
# @example: ai-cmd "find all pdf files modified in last 24h"
ai-cmd() {
    if [ -z "$1" ]; then
        echo "Usage: ai-cmd <description of terminal action>"
        return 1
    fi
    _ollama_exec "Translate this request into a single Linux bash command line: '$*'. Output ONLY the command, no markdown, no quotes."
}

# @cmd: ai-docker
# @desc: Generate a minimal production Dockerfile or docker-compose setup
# @usage: ai-docker <stack info>
# @example: ai-docker "Python FastAPI with PostgreSQL"
ai-docker() {
    _ollama_exec "Generate a minimal, production-ready, multi-stage Dockerfile or docker-compose file for this project setup: '$*'. Output raw code only."
}

# @cmd: ai-cron
# @desc: Convert human-readable schedules to crontab syntax or explain existing cron lines
# @usage: ai-cron <schedule>
# @example: ai-cron "every 15 minutes on weekdays"
ai-cron() {
    if [ -z "$1" ]; then
        echo "Usage: ai-cron <description or expression>"
        return 1
    fi
    _ollama_exec "If this is a natural language request, convert it to a valid crontab expression. If it is a crontab expression, explain its schedule: '$*'. Output concisely."
}

# @cmd: ai-sec
# @desc: Scan code diffs or text for hardcoded API keys, passwords, and tokens
# @usage: cat <file> | ai-sec
# @example: git diff | ai-sec
ai-sec() {
    _ollama_exec "Scan this code or text for hardcoded secrets, API tokens, passwords, or insecure permissions. List any findings in bullet points, or output 'NO SECRETS DETECTED'." "$1"
}

# @cmd: ai-env
# @desc: Extract all referenced environment variables into a sanitized .env.example file
# @usage: cat <file> | ai-env
# @example: cat src/config.py | ai-env
ai-env() {
    _ollama_exec "Analyze this file/code and extract all environment variable references into a clean .env.example file with place-holder values. Output raw file content only." "$1"
}
