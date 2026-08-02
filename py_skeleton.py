#!/usr/bin/env python3
"""
Python AST Skeletonizer
Preserves: Classes, function signatures, type hints, docstrings, imports.
Replaces: Function/method implementation bodies with `...`.
"""
import ast
import sys


class ASTSkeletonizer(ast.NodeTransformer):
    def __init__(self, keep_docstrings: bool = True):
        self.keep_docstrings = keep_docstrings

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
        node.body = self._skeletonize_body(node)
        return node

    def visit_AsyncFunctionDef(self, node):
        self.generic_visit(node)
        node.body = self._skeletonize_body(node)
        return node


def skeletonize(code: str) -> str:
    try:
        tree = ast.parse(code)
        transformer = ASTSkeletonizer(keep_docstrings=True)
        skeleton_tree = transformer.visit(tree)
        ast.fix_missing_locations(skeleton_tree)
        return ast.unparse(skeleton_tree)
    except Exception:
        # Fallback to original text if code fails to parse (e.g. syntax error or partial snippet)
        return code


if __name__ == "__main__":
    input_data = sys.stdin.read()
    if input_data.strip():
        print(skeletonize(input_data))