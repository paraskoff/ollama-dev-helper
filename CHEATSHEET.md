# Llamalias - CLI Cheat Sheet
Auto-generated command documentation.

## System & Runtime Control

| Command | Description | Usage |
| :--- | :--- | :--- |
| `ai-model` | View currently active model or switch to a new local model dynamically across all helpers | `ai-model [model_name]` |
| `ai-status` | Display active helper configuration, Ollama API endpoint, and loaded runners | `ai-status` |
| `ai-perf` | Toggle real-time execution timing, token generation speed (tok/s), and prompt evaluation metrics on or off | `ai-perf [on\|off]` |
| `ai-compact` | Toggle automatic prompt context minification (AST skeletonization + whitespace/comment stripping) on or off | `ai-compact [on\|off]` |
| `ai-skeleton` | Run Python code through the local AST skeletonizer to preview stripped function bodies without sending a request to Ollama | `cat <file> \| ai-skeleton [min_lines]` |
| `ai-skeleton-bench` | Runs code through AST skeletonizer across multiple threshold steps (0, 5, 10, 20...) and measures token reduction | `ai-skeleton-bench [file] OR cat <file> \| ai-skeleton-bench` |
| `ai-ask` | Send a direct, raw prompt to the active Ollama model | `ai-ask <prompt>` |
| `ai-help` | Display overview or detail help for registered CLI commands | `ai-help [command_name]` |
| `ai-cheatsheet` | Generate a Markdown cheat sheet for all commands across core and modules | `ai-cheatsheet [--save]` |
| `ai-lint` | Lint module and core files for properly formatted docstrings | `ai-lint` |

## Code Quality & Engineering

| Command | Description | Usage |
| :--- | :--- | :--- |
| `ai-review` | Analyze code for logical bugs, performance bottlenecks, and security vulnerabilities | `cat <file> \| ai-review` |
| `ai-refactor` | Refactor code for modern best practices, improved readability, and efficiency | `cat <file> \| ai-refactor` |
| `ai-fix` | Analyze build errors, tracebacks, or terminal logs and propose a direct fix | `<command> 2>&1 \| ai-fix` |
| `ai-test` | Write unit tests covering happy paths and standard edge cases | `cat <file> \| ai-test` |
| `ai-doc` | Add Google-style docstrings and explicit type annotations to functions and classes | `cat <file> \| ai-doc` |
| `ai-explain` | Explain complex code snippets, configuration files, or logs in plain language | `cat <file> \| ai-explain` |
| `ai-convert` | Translate code snippets from one programming language to another | `cat <file> \| ai-convert <lang>` |

## Data Models & Converters

| Command | Description | Usage |
| :--- | :--- | :--- |
| `ai-regex` | Generate a new regex pattern or explain an existing regular expression | `ai-regex <request>` |
| `ai-sql` | Translate natural language data requests into clean SQL queries | `ai-sql <query request>` |
| `ai-json` | Validate, format, and fix syntax errors in malformed JSON or YAML data | `cat <file> \| ai-json` |
| `ai-type` | Convert JSON payload structures into TypeScript interfaces or Pydantic models | `cat <json> \| ai-type [lang]` |
| `ai-curl` | Convert cURL HTTP commands into executable code snippets (Python, Node, Go) | `echo \"curl...\" \| ai-curl [lang]` |
| `ai-mock` | Generate realistic mock JSON record arrays matching a given schema | `ai-mock <description>` |

## DevOps & Security

| Command | Description | Usage |
| :--- | :--- | :--- |
| `ai-cmd` | Translate natural language instructions into a single Linux bash command | `ai-cmd <description>` |
| `ai-docker` | Generate a minimal production Dockerfile or docker-compose setup | `ai-docker <stack info>` |
| `ai-cron` | Convert human-readable schedules to crontab syntax or explain existing cron lines | `ai-cron <schedule>` |
| `ai-sec` | Scan code diffs or text for hardcoded API keys, passwords, and tokens | `cat <file> \| ai-sec` |
| `ai-env` | Extract all referenced environment variables into a sanitized .env.example file | `cat <file> \| ai-env` |

## Git & Repository Management

| Command | Description | Usage |
| :--- | :--- | :--- |
| `ai-commit` | Generate a Conventional Commit message string based on currently staged git changes | `ai-commit` |
| `ai-ignore` | Generate a complete .gitignore file populated for specified technologies | `ai-ignore <tech1> <tech2>...` |
| `ai-changelog` | Aggregate recent git commits into a clean Markdown CHANGELOG | `ai-changelog` |
| `ai-readme` | Generate a structured Markdown README.md outline for a file or directory | `cat <file> \| ai-readme` |

