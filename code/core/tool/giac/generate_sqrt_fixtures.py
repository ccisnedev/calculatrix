#!/usr/bin/env python3
"""Generates the Giac reference fixture for Matrix.sqrt() on singular
matrices (issue #19).

This script shells out to Giac (via WSL) to compute a 30-digit decimal
reference for the principal square root of a fixed catalog of singular
matrices, and writes the result as JSON to
../../test/fixtures/matrix_sqrt_singular_giac_reference.json.

Giac is the black-box reference, not Julia or numpy. For each case the
expression is `matpow(<matrix>, 1/2)`, which forces Giac's exact-rational
jordanisation path (rather than a float exponent, which only carries
double precision internally regardless of `Digits`). The plain `^(0.5)`
form from the issue report is included in each fixture's `giacExpr` field
purely for documentation; the actual reference values are the 30-digit
`matpow(..., 1/2)` output.

Not every singular matrix has a real principal square root: the nilpotent
Jordan block [[0,1],[0,0]] is a case in point, and Giac itself refuses it
(`matpow([[0,1],[0,0]], 1/2)` -> "Unable to transpose Error: Bad Argument
Value"). That confirms the expected calculatrix behavior (raise
MatrixDomainError) but produces no numeric reference, so it is recorded
separately as a comment here and in the Dart test, not in the JSON
fixture.

Run from anywhere (paths are resolved relative to this file):
    python generate_sqrt_fixtures.py

Requires WSL with Ubuntu and `giac` installed. Not part of the Dart test
suite or CI: the Dart test reads only the committed JSON output.
"""
from __future__ import annotations

import json
import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUTPUT = os.path.normpath(
    os.path.join(
        HERE, "..", "..", "test", "fixtures", "matrix_sqrt_singular_giac_reference.json"
    )
)

# Each case: (name, giac_matrix_expr, matrix_as_doubles, issue_giac_expr)
CASES: list[tuple[str, str, list[list[float]], str]] = [
    (
        "singular 2x2 rank-1 PSD: [[1,2],[2,4]] (eigenvalues 0, 5)",
        "[[1,2],[2,4]]",
        [[1, 2], [2, 4]],
        "evalf(mat2list([[1,2],[2,4]]^(0.5)))",
    ),
    (
        "ones(3): rank-1 3x3 PSD (eigenvalues 0, 0, 3)",
        "[[1,1,1],[1,1,1],[1,1,1]]",
        [[1, 1, 1], [1, 1, 1], [1, 1, 1]],
        "evalf(mat2list([[1,1,1],[1,1,1],[1,1,1]]^(0.5)))",
    ),
    (
        "zero matrix 2x2",
        "[[0,0],[0,0]]",
        [[0, 0], [0, 0]],
        "evalf(mat2list([[0,0],[0,0]]^(0.5)))",
    ),
]

# Not fixtured (no numeric reference; Giac itself refuses this matrix,
# which is the reference confirmation that it has no real square root):
#   nilpotent Jordan block [[0,1],[0,0]] (eigenvalues 0, 0, geometric
#   multiplicity 1: not semisimple)
#   matpow([[0,1],[0,0]], 1/2) -> "Unable to transpose Error: Bad Argument
#   Value"


def build_giac_script() -> str:
    lines = ["Digits:=30;"]
    for _, expr, _, _ in CASES:
        lines.append(f"evalf(mat2list(matpow({expr},1/2)));")
    return "\n".join(lines) + "\n"


NUMBER_RE = re.compile(r"^([-+]?[0-9.]+(?:e[-+]?[0-9]+)?)$")


def parse_real(token: str) -> str:
    token = token.strip()
    m = NUMBER_RE.match(token)
    if not m:
        raise ValueError(f"could not parse Giac output token: {token!r}")
    return m.group(1)


def run_giac(script: str) -> list[list[str]]:
    in_path = os.path.join(HERE, "_giac_sqrt_fixture_in.txt")
    with open(in_path, "w", newline="\n") as f:
        f.write(script)
    wsl_path = "/mnt/c" + in_path[2:].replace("\\", "/")
    result = subprocess.run(
        ["wsl", "-d", "Ubuntu", "--", "bash", "-c", f"giac < '{wsl_path}'"],
        capture_output=True,
    )
    os.remove(in_path)
    out = result.stdout.decode("utf-8", "ignore").replace("\x00", "")
    vectors = [line.strip() for line in out.splitlines() if line.strip().startswith("[")]
    if len(vectors) != len(CASES):
        raise AssertionError(
            f"expected {len(CASES)} result lines from Giac, got {len(vectors)}\n"
            f"--- giac output tail ---\n{out[-3000:]}"
        )
    return [[parse_real(tok) for tok in v.strip("[]").split(",")] for v in vectors]


def main() -> None:
    script = build_giac_script()
    flat_results = run_giac(script)

    fixtures = []
    for (name, expr, matrix, issue_expr), flat in zip(CASES, flat_results):
        n = len(matrix)
        if len(flat) != n * n:
            raise AssertionError(
                f"case {name!r}: expected {n * n} entries, got {len(flat)}"
            )
        reference = [flat[row * n : row * n + n] for row in range(n)]
        fixtures.append(
            {
                "name": name,
                "giacExpr": f"matpow({expr},1/2)",
                "issueGiacExpr": issue_expr,
                "matrix": matrix,
                "referenceDigits": 30,
                "reference": reference,
            }
        )

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", newline="\n") as f:
        json.dump(fixtures, f, indent=2)
        f.write("\n")

    print(f"Wrote {len(fixtures)} fixtures to {OUTPUT}")


if __name__ == "__main__":
    main()
