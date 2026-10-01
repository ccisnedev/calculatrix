# Runbook: Trust stage, exact arithmetic

Stage 1 of `docs/mission.md` ("Trust"): `cx` never returns a wrong result
silently. This runbook covers its largest piece, exact arithmetic (issue
#54), and records the decisions before any code changes (acceptance
criterion 1 of #54). Update it as work lands: tick the step, add the PR,
and append a line to the progress log.

Decision numbers continue the sequence of `docs/runbook-cli-stage-0.md`
(D1 to D47), so a decision number means the same thing in every document.

Parent plans: `docs/mission.md` (stage 1) and `docs/runbook-1.0.0.md`
(Phase 5 planned exact literals for Stage 11; this runbook brings exact
numbers forward and leaves symbolic values to Stage 11).

## Problem

Every value in core is a `Matrix` of `double`: a scalar is a 1x1 matrix and
a complex number is the 2x2 matrix `[[a, -b], [b, a]]` (spec
`calculatrix_mathematics.md` section 2). Literals are parsed with
`double.tryParse`, and matrix literals with `jsonDecode`. So:

| Program | `cx` 0.8.3 | Exact value |
|---|---|---|
| `3 40 ^` | `12157665459056929000.0` | 12157665459056928801 |
| `10 16 ^ 1 + 10 16 ^ -` | `0` | 1 |
| `0.1 0.2 + 0.3 -` | `5.551115123125783e-17` | 0 |
| inverse of the 4x4 Hilbert matrix | `15.999999999999693 ...` | integer matrix (16, -120, ...) |

None of these raises an error. In the agent trial of PR #53, agents told to
use `cx` got 88% and 81% of the trap set right, while agents free to use
anything else made one error.

## Decisions

| # | Decision | Source |
|---|---|---|
| D48 | **Engine in Dart, Giac as the judge.** Exact arithmetic is implemented in core, in pure Dart (`BigInt` is part of the language), so the same engine runs in the CLI, the app (Android, web) and the MCP server. Giac is never linked: it is GPL-3 while core is MIT, and linking would need FFI and native builds of Giac, GMP and MPFR on every platform. Giac only judges, in differential tests (D57). | User, 2026-10-01 (issue #54, decision 1) |
| D49 | **Number tower, exactness per value.** A value on the stack is either exact or approximate, as a whole. An exact value is a matrix whose entries are rationals: a pair of `BigInt`, always reduced, with a positive denominator; an integer is a rational with denominator 1. An approximate value is today's `Matrix` of `double`, unchanged. Complex numbers keep their 2x2 form, so a complex number with rational parts is an exact 2x2 matrix with no extra work. A value never mixes exact and approximate entries: a result that would mix them is approximate as a whole. | User, 2026-10-01 (issue #54, decision 2; per value instead of per entry) |
| D50 | **Literals are exact.** A numeric literal, in RPN, infix or inside a matrix literal, is the exact rational it spells: `0.1` is 1/10, `1e-3` is 1/1000, `1e400` is 10^400 (no longer `non-finite`). Matrix literals stop going through `jsonDecode`, which cannot hold either. | User, 2026-10-01 (issue #54, decision 3) |
| D51 | **Approximation is contagious, never the other way. No global mode.** Exact with exact gives exact; an approximate operand makes the result approximate. Unlike the EXACT/APPROX flag of the HP 50g, exactness depends only on the values, never on hidden state: the same program always gives the same kind of result. | User, 2026-10-01 (issue #54, decisions 4 and 5) |
| D52 | **Conversion words.** `approx` (alias `num`) makes a value approximate: `1 3 / approx` gives `~0.333333333333`. `exact` makes a value exact, entry by entry, with the simplest rational (smallest denominator) among those that round to the same `double`, as the HP 50g `→Q` and Giac's `exact` do; it never guesses beyond the precision of the `double`, so `0.1 approx exact` gives `0.1` and `1 3 / approx exact` gives `1/3`. Applied to a value already of the target kind, both words leave it unchanged. | User, 2026-10-01 (issue #54, decision 6) |
| D53 | **Which words are exact.** A word returns an exact value when every operand is exact and the result is rational (or complex with rational parts) and can be checked exactly; otherwise it returns an approximate value, marked (D54). Stack words (`drop`, `duplicate`, `swap`, `pick`, `roll`, ...) and structure words (`transpose`, `vector`, `rows`, `append-*`, `delete-*`, `duplicate-*`, `move-*`, `zeros`, `ones`, `identity`) keep the exactness of their operands. Exact on exact input: `+ - * /`, `negate`, `percent`, integer powers, `inverse`, `determinant`, `rref`, `rank`, `trace`, `adjugate`, `cofactors`, `lu`, `dot`, `cross`; elimination on exact matrices is fraction-free (Bareiss). `sqrt` and fractional powers compute, convert to a rational and verify exactly (`9/4 sqrt` gives `3/2`, `-4 sqrt` gives `2i`, `8 1 3 / ^` gives `2`); otherwise approximate. `eigenvalues` computes the exact characteristic polynomial; when every root is rational, or complex with rational parts (`[[0 -1] [1 0]]` gives `i` and `-i`), the result is exact; when any root is irrational, the whole result is approximate (D49). `exp` and `ln` are exact only in trivial cases (`0 exp`, `1 ln`). `frobenius-norm` follows the `sqrt` rule. `spectral-norm`, `qr`, `diagonalize`, `svd` and the general `exp`, `ln` are approximate. Until a word becomes exact in its step (below), it converts its exact operands to approximate, which is correct and marked, never silent. Exact radicals (`3+√3`) are out of scope: that is a CAS (Stage 11). | User, 2026-10-01 (issue #54, decision 7; `eigenvalues` amended by D49) |
| D54 | **Output.** Exact values print in full, never rounded: integers as integers; rationals with a finite decimal expansion of at most 20 digits after the point as decimals (`0.6`, `0.0009765625`); every other rational as a fraction (`1/3`, `1/1073741824`). Approximate values go through the display formatter (D45) and always carry the mark `~` in front of the value, once per value (`~0.333333333333`, `~[[1 1.41421356237]]`). In `--json`, each stack level of D47 gains `"exact": true` or `false`; exact numbers are strings in the text form above (`"3/5"`, `"12157665459056928801"`), because a JSON number cannot hold them, and approximate numbers stay JSON numbers with the full `double`. | User, 2026-10-01 (issue #54, decision 8; shape follows D47) |
| D55 | **Size limit, as an error.** Before an exact operation, core estimates the number of digits of the result from the sizes of its operands (`a^n` has about `n * log10 abs(a)` digits; a determinant or inverse is bounded by Hadamard's bound). Over the limit, it raises the new id `limit-exceeded` (exit 65) before computing, never an approximate result instead. `details` carry `limit` and `estimated`, and the message gives the next step: "3^1000000 has about 477122 digits, over the limit of 10000; for an approximate result: cx '3 approx 1000000 ^'". The limit counts digits of each numerator or denominator; the default is 10 000. The local CLI raises it with `--max-digits <n>` on `eval rpn`, `eval infix` and the shortcut; the MCP server and an HTTP API set stricter limits of their own. Other limits (matrix size, time) belong to issue #48 and reuse the same id. | User, 2026-10-01 (issue #54, decision 9) |
| D56 | **`~` as input.** `~` before a numeric literal, its sign included, makes it an approximate literal, so every text output can be typed back: `~0.1 0.1 +` gives `~0.2`, `~-0.1 0.1 +` gives `~0`. `~` before a matrix literal makes the whole matrix approximate; a `~` on an entry inside a matrix literal makes the whole matrix approximate too (D49, D51). The mark belongs to the literal: `-~0.1` is `syntax-error`, and the message shows `~-0.1`. The same rules apply in infix. A pasted text value has the 12 digits of D45, not the full `double`; `--json` keeps the full `double` for a lossless round trip. | User, 2026-10-01 (issue #54, decision 10) |
| D57 | **Differential tests against Giac.** Every exact word has a test that runs it on generated exact inputs (fixed seeds, sizes from trivial to near the limit) and compares its result with Giac's, entry by entry, as exact rationals. The tests run in CI, in a Linux job that installs Giac from the distribution packages; on a developer machine they run through WSL (`wsl -d Ubuntu -- giac`) and are skipped, with a message, where Giac is missing. Giac is never shipped and never called at run time. | User, 2026-10-01 (issue #54, decisions 1 and acceptance 3) |
| D58 | **One step at a time, always honest.** Exact arithmetic lands in the steps below, one PR each. After each step every word is either exact (D53) or returns an approximate value with its mark, so no intermediate release returns a silent wrong result. The app keeps working on approximate values until step T5, which shows exact values there too. | User, 2026-10-01 |

## Discarded

- **`rationalize` with a tolerance** (Mathematica `Rationalize[x, dx]`).
  With exact literals and exact operations, a rational result is already
  exact, so turning a short decimal into a "likely" fraction is guessing,
  against the trust principle. It can be reconsidered if a real case
  appears.
- **Exactness per entry.** Would let `eigenvalues` mix exact and
  approximate roots in one result, but every double algorithm of core
  (`exp`, `ln`, `svd`, eigenvalues, about 3000 lines) would have to move to
  a generic entry type, and every approximate computation would get slower.
  Replaced by exactness per value (D49).

## Steps (one PR each)

| Step | Content | Depends on |
|---|---|---|
| T0 | This runbook: decisions D48 to D58. | Nothing |
| T1 | Step S4f of `runbook-cli-stage-0.md`: text through the core display formatter (D45), `eval rpn` prints the whole stack (D47). | Nothing |
| T2 | Exact numbers in core and `cx`: the value model of D49, exact literals (D50), `~` input (D56), contagion (D51), `+ - * /`, `negate`, `percent`, integer powers, stack and structure words, `approx`/`num` and `exact` (D52), `limit-exceeded` and `--max-digits` (D55), the output of D54, the Giac test harness and its CI job (D57) for these words. Every other word converts to approximate (D53). | T0, T1 |
| T3 | Exact linear algebra (D53): `inverse`, `determinant`, `rref`, `rank`, `trace`, `adjugate`, `cofactors`, `lu`, `dot`, `cross`, fraction-free elimination, Hadamard bound for D55, Giac tests. | T2 |
| T4 | Roots and eigenvalues (D53): `sqrt`, fractional powers, `frobenius-norm`, `eigenvalues` through the characteristic polynomial, the trivial cases of `exp` and `ln`, Giac tests. | T3 |
| T5 | The app shows exact values and the `~` mark through the same formatter. | T2 |
| T6 | The trap set moves into the repository benchmark and passes 8 of 8 through `cx` (acceptance 2 of #54); `docs/spec` updated (mathematics sections 1, 2 and 4; CLI section 6). | T4 |

## Acceptance (issue #54)

1. The decisions are recorded here before implementation (T0).
2. The trap set passes 8 of 8 through `cx` (T6).
3. Differential tests against Giac run in CI for every exact word (T2 to
   T4).
4. No word returns an approximate value without the mark, in text or JSON
   (T2 on).
5. `limit-exceeded` is raised before any oversized computation starts (T2,
   T3).

## Decisions log

| Date | Decision |
|---|---|
| 2026-10-01 | D48 to D58, from issue #54. D49 sets exactness per value instead of per entry, which amends the `eigenvalues` rule of #54 decision 7 (D53). T1 (S4f) comes before T2 so the exact output is built on the final stack shape. |

## Progress log

- 2026-10-01: runbook created (T0).
- 2026-10-01: T1 (S4f) in PR #PRNUM: text through the core display formatter, `eval rpn` prints the whole stack, one `{"level", "value"}` object per level in JSON, `cx` 0.9.0. An empty stack prints an empty line, not nothing: the SDK always ends a text output with a newline. An overflowing word is now `non-finite` (spec section 6) instead of printing `Infinity`.
