#!/usr/bin/env bash
# @category: Data Models & Converters

# Data payload formatting, database queries, type generation, and mock generation.

# @cmd: ai-regex
# @desc: Generate a new regex pattern or explain an existing regular expression
# @usage: ai-regex <request>
# @example: ai-regex "match valid email addresses"
ai-regex() {
    _ollama_exec "Create or explain a regex pattern based on this request. Output the pattern and a brief regex breakdown." "$1"
}

# @cmd: ai-sql
# @desc: Translate natural language data requests into clean SQL queries
# @usage: ai-sql <query request>
# @example: ai-sql "get top 5 users by purchase volume"
ai-sql() {
    _ollama_exec "Write a clean SQL query to satisfy this requirement. Output the SQL code block only." "$1"
}

# @cmd: ai-json
# @desc: Validate, format, and fix syntax errors in malformed JSON or YAML data
# @usage: cat <file> | ai-json
# @example: cat config.json | ai-json
ai-json() {
    _ollama_exec "Format and fix any syntax errors in this JSON/YAML data. Output clean, valid formatted JSON only."
}

# @cmd: ai-type
# @desc: Convert JSON payload structures into TypeScript interfaces or Pydantic models
# @usage: cat <json> | ai-type [lang]
# @example: cat data.json | ai-type pydantic
ai-type() {
    local target_lang="${1:-typescript}"
    _ollama_exec "Convert this JSON structure into explicit ${target_lang} type definitions (interfaces or classes). Output code only."
}

# @cmd: ai-curl
# @desc: Convert cURL HTTP commands into executable code snippets (Python, Node, Go)
# @usage: echo \"curl...\" | ai-curl [lang]
# @example: echo \"curl https://api.com\" | ai-curl python
ai-curl() {
    local target_lang="${1:-python}"
    _ollama_exec "Convert this cURL command into an idiomatic ${target_lang} HTTP request snippet using modern libraries. Output code only."
}

# @cmd: ai-mock
# @desc: Generate realistic mock JSON record arrays matching a given schema
# @usage: ai-mock <description>
# @example: ai-mock "users with id, email, created_at, role"
ai-mock() {
    if [ -z "$1" ]; then
        echo "Usage: ai-mock <description of desired mock data>"
        return 1
    fi
    _ollama_exec "Generate a realistic mock JSON array (5-10 records) matching this specification: '$*'. Output valid formatted JSON only."
}
