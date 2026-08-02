# Ollama CLI Development Helper Library

This is a modular, standalone shell library for [Ollama](https://github.com/ollama/ollama) containing 14 high-utility development helpers.

It is designed around a central configuration variable (`OLLAMA_MODEL`), allowing you to switch models instantly across all functions or override the model per session.

## Load the Library into Your Shell
To automatically load these commands whenever you open a terminal, source the file in your `~/.bashrc`:
```bash
echo "source ~/ollama_dev_helper.sh" >> ~/.bashrc
source ~/.bashrc
```

## Command Reference Cheat Sheet
| Command Usage | Example Primary | Input Method |
|---|---|---| 
| ai-model | `ai-model qwen2.5-coder:1.5b` | Argument (Sets global model) |
| ai-status | `ai-status` | None (Displays active stats)|
| ai-commit | `ai-commit` | Staged Git diff (git diff --cached) | 
| ai-cmd | `ai-cmd "find all pdf files modified in last 24h"` | Direct Argument string|
| ai-fix | `python script.py 2>&1 \| ai-fix` | Piped stdout/stderr|
| ai-review | `cat main.py \| ai-review` | Piped file or stdin|
| ai-refactor | `ai-refactor main.py < main.py` |Pipe or file redirection |
| ai-doc | `cat utils.py \| ai-doc` | Piped file or stdin | 
| ai-test | `cat models.py \| ai-test` | Piped file or stdin
| ai-ignore | `ai-ignore python docker vscode` |  Arguments | 
| ai-sql | `ai-sql "get top 5 users by purchase volume in 2026"` | Direct Argument string |
| ai-regex | `ai-regex "match valid email addresses"` | Direct Argument string | 
| ai-json | `cat config.json \| ai-json` | Piped JSON/YAML payload
| ai-ask | `ai-ask "Explain difference between processes and threads"` | Direct Argument string |

## How to Switch Models on the Fly

**Temporary Switch (Current Shell Session Only):**
```bash
ai-model llama3.2:3b
```

**One-Off Command Override:**
```bash
OLLAMA_MODEL="qwen2.5-coder:3b-instruct-q4_K_M" ai-commit
```

**Permanent Default**: Edit export `OLLAMA_MODEL="..."` at the top of `~/ollama_dev_helper.sh`.


## License

Ollama CLI Development Helper Library is licensed under the terms of the [MIT License](LICENSE).