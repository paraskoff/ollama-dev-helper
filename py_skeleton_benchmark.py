#!/usr/bin/env python3
"""
AST Skeletonizer Threshold Benchmark Tool
Measures token counts and context reduction across different function line thresholds.
"""
import sys
import os
import json
import argparse
import urllib.request
import urllib.error

try:
    from py_skeleton import skeletonize
except ImportError:
    print("Error: Could not import 'skeletonize' from py_skeleton.py", file=sys.stderr)
    sys.exit(1)


def count_tokens_ollama(text: str, model: str) -> int:
    """Queries Ollama local REST API for exact token count."""
    url = "http://127.0.0.1:11434/api/tokenize"
    payload = json.dumps({"model": model, "prompt": text}).encode("utf-8")
    req = urllib.request.Request(
        url, data=payload, headers={"Content-Type": "application/json"}
    )

    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            res_data = json.loads(response.read().decode("utf-8"))
            tokens = res_data.get("tokens", [])
            return len(tokens)
    except Exception:
        # Fallback estimation if tokenization API is unavailable (~4 chars per token)
        return len(text) // 4


def run_benchmark(code: str, thresholds: list[int], model: str):
    raw_lines = len(code.splitlines())
    raw_chars = len(code)
    raw_tokens = count_tokens_ollama(code, model)

    print(f"\n\033[1;34m=== AST Threshold Benchmark ===\033[0m")
    print(f"\033[1mActive Model:\033[0m {model}")
    print(f"\033[1mRaw File Stats:\033[0m {raw_lines} lines | {raw_chars} chars | ~{raw_tokens} tokens\n")

    printf_fmt = "%-12s %-12s %-12s %-14s %-12s\n"
    print(printf_fmt % ("Threshold", "Lines Left", "Chars Left", "Token Count", "Token Savings"))
    print("-" * 65)

    # Always baseline raw un-skeletonized
    print(printf_fmt % ("Raw (None)", str(raw_lines), str(raw_chars), str(raw_tokens), "0.0%"))

    for thresh in thresholds:
        skel_code = skeletonize(code, min_lines=thresh)
        s_lines = len(skel_code.splitlines())
        s_chars = len(skel_code)
        s_tokens = count_tokens_ollama(skel_code, model)

        savings_pct = 0.0
        if raw_tokens > 0:
            savings_pct = ((raw_tokens - s_tokens) / raw_tokens) * 100

        print(
            printf_fmt
            % (
                f">= {thresh} lines",
                str(s_lines),
                str(s_chars),
                str(s_tokens),
                f"{savings_pct:.1f}%",
            )
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Benchmark AST skeletonizer thresholds.")
    parser.add_argument("file", nargs="?", help="Path to Python file to benchmark")
    parser.add_argument(
        "--model",
        default=os.getenv("OLLAMA_MODEL", "qwen2.5-coder:1.5b"),
        help="Ollama model name for tokenization",
    )
    parser.add_argument(
        "--steps",
        default="0,5,10,15,20,30,50",
        help="Comma-separated threshold steps (default: 0,5,10,15,20,30,50)",
    )
    args = parser.parse_args()

    if args.file and os.path.isfile(args.file):
        with open(args.file, "r", encoding="utf-8") as f:
            source = f.read()
    else:
        source = sys.stdin.read()

    if not source.strip():
        print("Error: No source code provided via file argument or pipe.", file=sys.stderr)
        sys.exit(1)

    threshold_list = [int(x.strip()) for x in args.steps.split(",") if x.strip().isdigit()]
    run_benchmark(source, sorted(threshold_list), args.model)