#!/usr/bin/env python3
"""
Python AST Skeletonizer with Line-Length Thresholds
Preserves: Classes, function signatures, type hints, docstrings, imports.
Preserves FULL BODY: Functions shorter than --min-lines.
Skeletonizes: Functions with total line spans >= --min-lines.
"""
import argparse
import ast
import os
import sys


class ASTSkeletonizer(ast.NodeTransformer):
    def __init__(self, min_lines: int = 10, keep_docstrings: bool = True):
        self.min_lines = min_lines
        self.keep_docstrings = keep_docstrings

    def _is_long_function(self, node: ast.AST) -> bool:
        """Calculate line span of a function node."""
        if hasattr(node, "end_lineno") and hasattr(node, "lineno"):
            line_span = node.end_lineno - node.lineno + 1
            return line_span >= self.min_lines
        # Fallback for older nodes without end_lineno
        return len(node.body) >= self.min_lines

    def _skeletonize_body(self, node):
        docstring = ast.get_docstring(node, clean=False)
        new_body = []

        # Preserve docstring if present
        if docstring and self.keep_docstrings:
            new_body.append(ast.Expr(value=ast.Constant(value=docstring)))

        # Replace execution body with Ellipsis (...)
        new_body.append(ast.Expr(value=ast.Constant(value=Ellipsis)))
        return new_body

    def visit_FunctionDef(self, node):
        self.generic_visit(node)
        if self._is_long_function(node):
            node.body = self._skeletonize_body(node)
        return node

    def visit_AsyncFunctionDef(self, node):
        self.generic_visit(node)
        if self._is_long_function(node):
            node.body = self._skeletonize_body(node)
        return node


def skeletonize(code: str, min_lines: int = 10) -> str:
    try:
        tree = ast.parse(code)
        transformer = ASTSkeletonizer(min_lines=min_lines, keep_docstrings=True)
        skeleton_tree = transformer.visit(tree)
        ast.fix_missing_locations(skeleton_tree)
        return ast.unparse(skeleton_tree)
    except Exception:
        # Fallback to original text if code fails to parse (e.g. syntax error or partial snippet)
        return code


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Skeletonize long Python functions.")
    parser.add_argument(
        "--min-lines",
        type=int,
        default=int(os.getenv("SKEL_MIN_LINES", "10")),
        help="Minimum line length threshold to skeletonize a function (default: 10)",
    )
    args, _ = parser.parse_known_args()

    input_data = sys.stdin.read()
    if input_data.strip():
        print(skeletonize(input_data, min_lines=args.min_lines))