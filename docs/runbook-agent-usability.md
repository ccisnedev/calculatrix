# Runbook: agent usability

Removes the usability frictions of `cx` 0.15.0 for humans and AI agents
(issue #80, which resolves #68, #56, #72, #73 and #70, closes #49 and #51 and
references #74). Spec-driven: the decisions are recorded here before any
code changes. Update it as work lands: tick the step, add the PR, and append
a line to the progress log.

Decision numbers continue the global sequence of `docs/runbook-trust.md`
(the last one in its decisions table is D60), so a decision number means the
same thing in every document. See the numbering note in the decisions log.

## Problem

Benchmark rounds r2 and r3 and the agent trials (PR #53, PR #69) show five
frictions:

- The `cx <program>` shortcut rejects `--json` and `-q`, which `cx eval rpn`
  accepts (#68).
- The banner, the help and the install scripts do not say what `cx` can do:
  RPN, infix, matrices, exact and approximate values (#72, #56).
- Two syntax slips cost a round trip each: `inverse([[1 2] [3 4]])` in infix
  and a `--` inside a program (#73).
- `power` does not document its exactness (#73).
- `pi`, `e` and `i` do not exist as names (#70).

## Decisions

| # | Decision | Source |
|---|---|---|
| D61 | **One quoted argument (#49).** A program is always one quoted argument. Operands are never joined. `cx 5 7 power` keeps failing with `extra-argument` and the actionable message already implemented (`cx received 3 arguments; quote the program as one argument: cx '5 7 power'`). The table of #49 is below. The agent trials (PR #53, benchmark r3 PR #69) show no agent trying the unquoted form. | Issue #80 |
| D62 | **Global options on the shortcut (#68).** Amends spec G4: the `cx <program>` shortcut accepts the global output options `--json` and `--quiet`/`-q`, before or after the program, exactly as `cx eval rpn` does. Every other option that `cx eval rpn` has and the shortcut does not (`--file`, `--stdin`) is rejected (U1). | Issue #80 |
| D63 | **One overview text (#72).** Defined once in code, shown by the banner, the help epilog (U2) and the install scripts. It presents RPN, infix, matrices and exact/approximate with equal weight. The symbolic form is not mentioned until it exists. | Issue #80 |
| D64 | **No `batch` route (#74).** Several results in one call are already possible (one program leaves several values on the stack) and are documented in the overview. Labels (`tag`, HP `->TAG`) and isolated evaluation (HP `IFERR`) depend on name literals and program values and are analyzed in #79. | Issue #80 |
| D65 | **Name table (#70).** Model B: a name table in core. RPN and infix resolve names through it. It holds only system constants, read-only. Variables and programs are #79. | Issue #80 |
| D66 | **Constants (#70).** `pi` (alias `π`, approximate), `e` (approximate), `i` (exact, `[[0 -1] [1 0]]`), with the lexing rules of U5. | Issue #80 |
| D67 | **Syntax friction (#73).** `--` inside a program and infix calls of RPN words get errors naming the exact form to type (U4). | Issue #80 |

### D61: what `cx` receives and does, per shell

Run for real on Windows 11 with `cx` 0.15.0: bash is Git Bash, PowerShell is
7, cmd.exe runs a `.bat` file. zsh cells are "documented, not run" (no zsh on
this machine). "Unquoted" means the program is typed as written in the first
column. Every unquoted cell that reaches `cx` with more than one argument is
rejected with exit 64 and the message above.

| Typed | bash (Git Bash) | zsh (documented, not run) | PowerShell | cmd.exe |
|---|---|---|---|---|
| `cx 5 7 power` | `cx` receives 3 arguments: `extra-argument`, exit 64 | same as bash | same as bash | same as bash |
| `cx 2 3 *` | `*` is a glob: with files in the directory it becomes their names (`2 3 a b`), with none it stays `*`; either way several arguments, exit 64 | `*` is a glob; with no match zsh stops with "no matches found" and `cx` does not run | 3 arguments (`*` is not a glob for a native command), exit 64 | 3 arguments, exit 64 |
| `cx [[1 2] [3 4]] inverse` | 5 arguments (`[[1`, `2]`, `[3`, `4]]`, `inverse`; bracket globs do not match), exit 64 | `[[1` is a glob with no match: "no matches found", `cx` does not run | 5 arguments, exit 64 | 5 arguments, exit 64 |
| `cx 5 -1 power` | 3 arguments, exit 64 | same as bash | same as bash | same as bash |
| `cx 2 3 ^` | 3 arguments, exit 64 | 3 arguments; with `EXTENDED_GLOB` a bare `^` is a glob operator and may stop the line | 3 arguments, exit 64 | `^` is cmd's escape: at the end of the line it escapes the end of line (the next line continues the command), before a space it escapes the space; `cx` received 2 arguments, `2 3`, exit 64 (and `^^` arrives as the literal `^^`) |
| quoted: `cx '5 7 power'` | 1 argument, `78125`, exit 0 | same | same | cmd has no single quotes: `'5 7 power'` arrives as 3 arguments, exit 64; use double quotes: `cx "5 7 power"` gives `78125` |
| quoted: `cx '2 3 *'` / `cx '2 3 ^'` | `6` / `8`, exit 0 | same | `6` / `8` | `cx "2 3 *"` gives `6`; `cx "2 3 ^"` gives `8` (inside double quotes `^` is literal) |
| quoted: `cx '[[1 2] [3 4]] inverse'` | `[[-2 1] [1.5 -0.5]]` | same | same | `cx "[[1 2] [3 4]] inverse"`: same |
| quoted: `cx '5 -1 power'` | `0.2` | same | `0.2` | `cx "5 -1 power"`: `0.2` |

The only way to give `cx` a program that works in every shell is one quoted
argument, which is D61.

## Discarded

- **Joining unquoted operands** (`cx 5 7 power` as `5 7 power`). It would
  need no quotes in PowerShell, but in Git Bash `*` is expanded to file
  names before `cx` sees it, so the join would silently run a program the
  user did not type. It stays an error (D61).
- **A `batch` route** (D64): the stack already returns several results.

## Steps (one PR)

| Step | Issues | Content | Depends on |
|---|---|---|---|
| U0 | #49 | This runbook and the update of spec G4. | Nothing |
| U1 | #68 | Global options on the shortcut. | U0 |
| U3 | #72 | The overview text: banner, install scripts. | U0 |
| U4 | #73 | Syntax friction: infix call of an RPN word, `--` in a program, `power` documentation. | U0 |
| U5 | #70 | Name table and the constants `pi`, `e`, `i`. | U0 |
| U2 | #56 | Help after `modular_cli_sdk` 0.10.0 (ccisnedev/modular_cli_sdk#50). Not part of the first delivery. | SDK release |

## Experiments (U5)

Recorded before the production code of U5, with `cx` 0.15.0 (Windows 11).

**E1, lexing today.** `unknown-word` and `syntax-error` are both exit 65.

| Token | RPN | Infix | Matrix literal |
|---|---|---|---|
| `e`, `E` | `unknown-word` | `syntax-error`: "e" is a name, not a number | not run (names are not numbers) |
| `1e3`, `1E3` | `1000` | `1000` | not run |
| `2e` | `unknown-word` | `syntax-error`: Invalid numeric literal: 2e | not run |
| `e3` | `unknown-word` | `syntax-error`: "e3" is a name, not a number | not run |
| `-e` | `unknown-word` "Did you mean subtract" (as `-e` after `--`); without `--` the shortcut's parser says `unknown option '-e'` | `syntax-error`: "e" is a name, not a number | not run |
| `~pi` | `unknown-word: ~pi` | `syntax-error`: the approximate mark must be followed by a number or a matrix literal | not run |
| `pi` | `unknown-word` | `syntax-error`: "pi" is a name, not a number | not run |
| `π` | `unknown-word` | `syntax-error`: Unexpected token near "π" | not run |
| `[[pi 0] [0 1]]` | `syntax-error`: Invalid matrix literal | `syntax-error`: Invalid matrix literal | `syntax-error` |

No result contradicts D65 or D66. `1e3` is a number today and stays one.

**E2, collisions.** `pi`, `e`, `i` and `π` against the 48 registry entries
(names, aliases, search terms) and the reserved route words (`eval`,
`commands`, `version`, `upgrade`, `uninstall`, `doctor`, `help`): no
collision. `lookup` finds none of the four. Suggestions today: `pii` gives
`power`, `pick`, `eigenvalues`; `pi`, `e`, `i` and `π` give none. No
contradiction.

**E3, precision.** Giac 1.9.0 (WSL Ubuntu): `evalf(pi,30)` =
3.14159265358979323846264338328 and `evalf(e,30)` =
2.71828182845904523536028747135. Rounded to double they equal `math.pi`
(3.141592653589793) and `math.e` (2.718281828459045) exactly. The residue of
`[[0 -1] [1 0]] ~3.141592653589793 * exp` is
`[[-0.9999999999999971 -6.33e-15] [6.33e-15 -0.9999999999999971]]`: the
largest deviation from `[[-1 0] [0 -1]]` is 6.33e-15, under the `1e-14` of
the spec. No contradiction.

## Decisions log

| Date | Decision |
|---|---|
| 2026-10-02 | D61 to D67 from issue #80. Numbering note: `docs/runbook-trust.md` already used the number D61 in its decisions log, for the infix unary minus of issue #66. The numbers D61 to D67 in this runbook are those of issue #80; a reference to "D61" is ambiguous across the two documents and names the file. |

## Progress log

- 2026-10-02: runbook created (U0). Spec G4 amended to D62.
- 2026-10-02: U1 done (#68), U3 done (#72), U4 done (#73).
- 2026-10-02: U5 done (#70). Experiments E1 to E3 recorded above, no contradiction. Name table in `code/core/lib/src/names/`, constants entries in the registry (category `constants`).
- 2026-10-02: `cx` 0.16.0 (pubspec, `cxVersion`, root and core CHANGELOG).
