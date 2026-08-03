#!/usr/bin/env python3
"""
AST Skeletonizer Threshold Benchmark Tool with Visual Bar Charts
Measures token counts and context reduction across different function line thresholds
and renders ASCII/Unicode visualizations in the terminal.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

try:
    from py_skeleton import skeletonize
except ImportError:
    print("Error: Could not import 'skeletonize' from py_skeleton.py", file=sys.stderr)
    sys.exit(1)


def count_tokens_ollama(text: str, model: str) -> int:
    """Queries Ollama local REST API for exact token count."""
    ollama_host = os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434")
    url = f"{ollama_host}/api/tokenize"
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


def make_bar(val: int, max_val: int, width: int = 20) -> str:
    """Generates a Unicode horizontal fill bar."""
    if max_val <= 0:
        return "░" * width
    fill = int(round(width * (val / float(max_val))))
    fill = min(max(fill, 0), width)
    return "█" * fill + "░" * (width - fill)


def run_benchmark(code: str, thresholds: list[int], model: str):
    raw_lines = len(code.splitlines())
    raw_chars = len(code)
    raw_tokens = count_tokens_ollama(code, model)

    print("\n\033[1;34m=== AST Threshold Benchmark & Visualizer ===\033[0m")
    print(f"\033[1mActive Model:\033[0m {model}")
    print(
        f"\033[1mRaw File Stats:\033[0m {raw_lines} lines | {raw_chars} chars | ~{raw_tokens} tokens\n"
    )

    header_fmt = "%-12s %-10s %-12s %-8s %-22s %-8s"
    row_fmt = "%-12s %-10s %-12s %-8s \033[0;32m%-22s\033[0m \033[1;33m%-8s\033[0m"

    print(
        header_fmt
        % (
            "Threshold",
            "Lines Left",
            "Chars Left",
            "Tokens",
            "Context Visual",
            "Savings",
        )
    )
    print("-" * 78)

    # Baseline (Raw file)
    raw_bar = make_bar(raw_tokens, raw_tokens)
    print(
        row_fmt
        % (
            "Raw (None)",
            str(raw_lines),
            str(raw_chars),
            str(raw_tokens),
            raw_bar,
            "0.0%",
        )
    )

    for thresh in thresholds:
        skel_code = skeletonize(code, min_lines=thresh)
        s_lines = len(skel_code.splitlines())
        s_chars = len(skel_code)
        s_tokens = count_tokens_ollama(skel_code, model)

        savings_pct = 0.0
        if raw_tokens > 0:
            savings_pct = ((raw_tokens - s_tokens) / raw_tokens) * 100

        bar_chart = make_bar(s_tokens, raw_tokens)

        print(
            row_fmt
            % (
                f">= {thresh} lines",
                str(s_lines),
                str(s_chars),
                str(s_tokens),
                bar_chart,
                f"{savings_pct:.1f}%",
            )
        )
    print("\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Benchmark AST skeletonizer thresholds with visual charts."
    )
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
        print(
            "Error: No source code provided via file argument or pipe.",
            file=sys.stderr,
        )
        sys.exit(1)

    threshold_list = [
        int(x.strip()) for x in args.steps.split(",") if x.strip().isdigit()
    ]
    run_benchmark(source, sorted(threshold_list), args.model)
