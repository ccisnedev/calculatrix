#!/usr/bin/env python3
"""Generates the Giac reference fixtures used by the core matrix tests.

This script shells out to Giac (via WSL) and writes 30-digit decimal
reference values as JSON. It has two modes, selected by an optional
command-line argument:

    python generate_fixtures.py          # exp(A) fixtures (default, issue #13)
    python generate_fixtures.py exp      # same as above, explicit
    python generate_fixtures.py sqrt     # sqrt(A) fixtures (issue #19)

Giac is the black-box reference, not Julia or numpy.

exp mode: for matrices whose closed form goes through approximate
(irrational) eigenvalues, Giac's own symbolic exp() can lose digits, so
those cases instead use an exact rational Taylor sum computed inside Giac
(see the "taylor" case entries below), which is decisive because Giac does
exact rational arithmetic on the matrix entries themselves. Writes to
../../test/fixtures/matrix_exp_giac_reference.json.

sqrt mode: uses `matpow(<matrix>, 1/2)`, which forces Giac's exact-rational
jordanisation path (rather than a float exponent such as `^(0.5)`, which
only carries double precision internally regardless of `Digits`). Not
every singular matrix has a real principal square root: Giac itself
refuses matrices whose zero eigenvalue is not semisimple (for example
`matpow([[0,1],[0,0]], 1/2)` -> "Unable to transpose Error: Bad Argument
Value"), which is why such cases have no numeric fixture entry and are
instead asserted directly in the Dart test. Writes to
../../test/fixtures/matrix_sqrt_singular_giac_reference.json.

Requires WSL with Ubuntu and `giac` installed. Not part of the Dart test
suite or CI: the Dart tests read only the committed JSON output.
"""
from __future__ import annotations

import json
import math
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUTPUT = os.path.normpath(
    os.path.join(HERE, "..", "..", "test", "fixtures", "matrix_exp_giac_reference.json")
)
SQRT_OUTPUT = os.path.normpath(
    os.path.join(
        HERE, "..", "..", "test", "fixtures", "matrix_sqrt_singular_giac_reference.json"
    )
)

PI4 = math.pi / 4

# Each case: (name, kind, giac_matrix_expr, matrix_as_doubles)
#   kind == "direct": evalf(mat2list(exp(<giac_matrix_expr>)))
#   kind == "taylor": exact rational Taylor sum (400 terms) inside Giac,
#                      used when Giac's own symbolic exp() would go through
#                      approximate eigenvalues and lose digits.
#
# The first 13 cases are every case in the exploration catalog
# (scratchpad cases.py) except the two out-of-scope cases filed as separate
# issues (the nonFinite-despite-representable case, and the subnormal-range
# case). The last 4 are new: x10-scaled versions of the I+N, diag(I+N,2)
# and Jordan 5I+N cases (to test scaling-and-squaring / exact-nilpotent
# accuracy at larger magnitude), plus a 4x4 with two independent
# Jordan-type blocks interleaved by a permutation, to exercise connected
# component detection.
CASES: list[tuple[str, str, str, list[list[float]]]] = [
    ("10I", "direct", "[[10,0],[0,10]]", [[10, 0], [0, 10]]),
    (
        "general 3x3 norm~30",
        "taylor",
        "[[10,-7,3],[5,12,-8],[-6,4,9]]",
        [[10, -7, 3], [5, 12, -8], [-6, 4, 9]],
    ),
    ("[[1 2][3 4]] (taylor)", "taylor", "[[1,2],[3,4]]", [[1, 2], [3, 4]]),
    ("[[1 2][3 4]]", "direct", "[[1,2],[3,4]]", [[1, 2], [3, 4]]),
    (
        "4x4 binary fractions",
        "taylor",
        "[[1/2,-5/4,2,0],[1,3/4,-1/2,3/2],[-2,1,1/4,-1],[1/2,-1/2,1,-3/4]]",
        [
            [0.5, -1.25, 2, 0],
            [1, 0.75, -0.5, 1.5],
            [-2, 1, 0.25, -1],
            [0.5, -0.5, 1, -0.75],
        ],
    ),
    ("[[-50 20][10 -60]]", "taylor", "[[-50,20],[10,-60]]", [[-50, 20], [10, -60]]),
    (
        "rotation (pi/4)J",
        "direct",
        "[[0,-pi/4],[pi/4,0]]",
        [[0, -PI4], [PI4, 0]],
    ),
    (
        "N: [[400.1 400.1][-400.1 -400.1]]",
        "direct",
        "[[4001/10,4001/10],[-4001/10,-4001/10]]",
        [[400.1, 400.1], [-400.1, -400.1]],
    ),
    (
        "diag(N,1)",
        "direct",
        "[[400,400,0],[-400,-400,0],[0,0,1]]",
        [[400, 400, 0], [-400, -400, 0], [0, 0, 1]],
    ),
    (
        "I+N: [[401 400][-400 -399]]",
        "direct",
        "[[401,400],[-400,-399]]",
        [[401, 400], [-400, -399]],
    ),
    (
        "I+N x10: [[4001 4000][-4000 -3999]]",
        "direct",
        "[[4001,4000],[-4000,-3999]]",
        [[4001, 4000], [-4000, -3999]],
    ),
    (
        "Jordan 5I+N 3x3",
        "direct",
        "[[5,1,0],[0,5,1],[0,0,5]]",
        [[5, 1, 0], [0, 5, 1], [0, 0, 5]],
    ),
    (
        "Jordan -100I+N",
        "direct",
        "[[-100,1],[0,-100]]",
        [[-100, 1], [0, -100]],
    ),
    (
        "diag(I+N,2)",
        "direct",
        "[[401,400,0],[-400,-399,0],[0,0,2]]",
        [[401, 400, 0], [-400, -399, 0], [0, 0, 2]],
    ),
    # --- New cases for the A+ acceptance catalog (not in cases.py) ---
    (
        "I+N scaled x10: 10*[[401 400][-400 -399]]",
        "direct",
        "[[4010,4000],[-4000,-3990]]",
        [[4010, 4000], [-4000, -3990]],
    ),
    (
        "diag(I+N,2) scaled x10",
        "direct",
        "[[4010,4000,0],[-4000,-3990,0],[0,0,20]]",
        [[4010, 4000, 0], [-4000, -3990, 0], [0, 0, 20]],
    ),
    (
        "Jordan 5I+N 3x3 scaled x10",
        "direct",
        "[[50,10,0],[0,50,10],[0,0,50]]",
        [[50, 10, 0], [0, 50, 10], [0, 0, 50]],
    ),
    (
        "4x4 two Jordan blocks permuted (component detection)",
        "direct",
        "[[5,0,1,0],[0,-100,0,1],[0,0,5,0],[0,0,0,-100]]",
        [
            [5, 0, 1, 0],
            [0, -100, 0, 1],
            [0, 0, 5, 0],
            [0, 0, 0, -100],
        ],
    ),
]

# Excluded from cases.py (filed as separate GitHub issues instead):
#   "[[710 -pi/4][pi/4 710]]"  -> nonFinite raised though representable
#   "[[-746 1000][0 -746]]"    -> subnormal result, ~1.6e-3 relative error


# --- sqrt mode (issue #19: Matrix.sqrt() on singular matrices) ---
#
# Each case: (name, giac_matrix_expr, matrix_as_doubles, issue_giac_expr)
SQRT_CASES: list[tuple[str, str, list[list[float]], str]] = [
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
    (
        "regression: complex eigenvalues +-i with a real principal root "
        "(block-embedded rotation)",
        "[[0,0,0],[0,0,-1],[0,1,0]]",
        [[0, 0, 0], [0, 0, -1], [0, 1, 0]],
        "evalf(mat2list([[0,0,0],[0,0,-1],[0,1,0]]^(0.5)))",
    ),
    (
        "regression: tiny nonzero eigenvalue misrouted as singular by rank()",
        "[[1/10^13,0],[0,1]]",
        [[1e-13, 0], [0, 1]],
        "evalf(mat2list([[1e-13,0],[0,1]]^(0.5)))",
    ),
]

# Not fixtured (no numeric reference; Giac itself refuses this matrix,
# which is the reference confirmation that it has no real square root):
#   nilpotent Jordan block [[0,1],[0,0]] (eigenvalues 0, 0, geometric
#   multiplicity 1: not semisimple)
#   matpow([[0,1],[0,0]], 1/2) -> "Unable to transpose Error: Bad Argument
#   Value"
#
# Also not fixtured (Giac's matpow returns undef, so this case is checked
# in the Dart test only by exact X*X = A reconstruction, not against a
# Giac numeric reference):
#   [[0,0,0],[0,1,1],[0,0,1]] (zero eigenvalue is semisimple, but the
#   Jordan block sits on eigenvalue 1, which Newton handles directly)


def build_giac_script() -> str:
    lines = ["Digits:=30;"]
    for _, kind, expr, _ in CASES:
        if kind == "taylor":
            lines.append(
                f"M:={expr}:;T:=idn(rowdim(M)):;S:=T:;"
                "for k from 1 to 400 do T:=T*M/k; S:=S+T; od:;"
            )
            lines.append("evalf(mat2list(S));")
        else:
            lines.append(f"evalf(mat2list(exp({expr})));")
    return "\n".join(lines) + "\n"


def build_sqrt_giac_script() -> str:
    lines = ["Digits:=30;"]
    for _, expr, _, _ in SQRT_CASES:
        lines.append(f"evalf(mat2list(matpow({expr},1/2)));")
    return "\n".join(lines) + "\n"


NUMBER_RE = re.compile(
    r"^([-+]?[0-9.]+(?:e[-+]?[0-9]+)?)(?:[-+][0-9.]+(?:e[-+]?[0-9]+)?\*i)?$"
)


def parse_real(token: str) -> str:
    token = token.strip()
    m = NUMBER_RE.match(token)
    if not m:
        raise ValueError(f"could not parse Giac output token: {token!r}")
    return m.group(1)


def run_giac(script: str, case_count: int, in_name: str) -> list[list[str]]:
    in_path = os.path.join(HERE, in_name)
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
    if len(vectors) != case_count:
        raise AssertionError(
            f"expected {case_count} result lines from Giac, got {len(vectors)}\n"
            f"--- giac output tail ---\n{out[-3000:]}"
        )
    return [[parse_real(tok) for tok in v.strip("[]").split(",")] for v in vectors]


def generate_exp_fixtures() -> None:
    script = build_giac_script()
    flat_results = run_giac(script, len(CASES), "_giac_fixture_in.txt")

    fixtures = []
    for (name, kind, expr, matrix), flat in zip(CASES, flat_results):
        n = len(matrix)
        if len(flat) != n * n:
            raise AssertionError(
                f"case {name!r}: expected {n * n} entries, got {len(flat)}"
            )
        reference = [flat[row * n : row * n + n] for row in range(n)]
        fixtures.append(
            {
                "name": name,
                "giacKind": kind,
                "giacExpr": expr,
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


def generate_sqrt_fixtures() -> None:
    script = build_sqrt_giac_script()
    flat_results = run_giac(script, len(SQRT_CASES), "_giac_sqrt_fixture_in.txt")

    fixtures = []
    for (name, expr, matrix, issue_expr), flat in zip(SQRT_CASES, flat_results):
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

    os.makedirs(os.path.dirname(SQRT_OUTPUT), exist_ok=True)
    with open(SQRT_OUTPUT, "w", newline="\n") as f:
        json.dump(fixtures, f, indent=2)
        f.write("\n")

    print(f"Wrote {len(fixtures)} fixtures to {SQRT_OUTPUT}")


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "exp"
    if mode == "exp":
        generate_exp_fixtures()
    elif mode == "sqrt":
        generate_sqrt_fixtures()
    else:
        raise SystemExit(f"unknown mode {mode!r}: expected 'exp' or 'sqrt'")


if __name__ == "__main__":
    main()
