# Calculatrix Core Package Specification

Status: Describes core 0.8.0
Package: `calculatrix`, in `code/core`

## 1. Purpose and scope

`calculatrix` is the computation engine of Calculatrix. It reads programs in
RPN and infix, evaluates them over matrices, and documents its own
vocabulary. The app (`calculatrix_app`) and the CLI (`calculatrix_cli`)
depend on it and never duplicate its math.

This spec owns the language as the engine reads it: literals, the two
notations, the command registry, the name table, errors and the size limit.
Other documents own the rest:

- `calculatrix_mathematics.md`: numeric semantics (exact and approximate
  values, the power table, matrix functions, tolerances).
- `calculatrix_cli.md`: the `cx` command line, output formats, exit codes.
- `engine-api-contract.md`: the draft of a future host-neutral engine API.

## 2. Design principles

1. **Pure Dart.** No Flutter, no native code, no runtime dependencies
   (`pubspec.yaml` has dev dependencies only). Giac is never linked,
   shipped or called at run time; see ADR 0004.
2. **Everything is a matrix.** A scalar is a 1x1 matrix, a vector is an
   n x 1 column matrix, a complex number is a 2x2 real matrix. There is no
   separate scalar or vector type.
3. **Closed language.** Programs contain literals, words of the registry
   and names of the name table. There are no user variables or user
   programs yet.
4. **Immutable values, deterministic results.** The same program gives the
   same result in every consumer.
5. **Errors are values with stable ids**, never silent fallbacks: an exact
   computation that is too large fails, it is not replaced by an
   approximation; RPN never falls back to infix.

## 3. Package structure and public API

`lib/calculatrix.dart` exports every library below. Paths are relative to
`lib/src/`.

| Library | Main types | Role |
|---|---|---|
| `matrix/matrix.dart` | `Matrix`, `LuDecomposition`, `QrDecomposition`, `Diagonalization`, `SvdDecomposition` | Immutable matrix value, exact (rationals) or approximate (doubles), with the linear algebra |
| `matrix/matrix_display_formatter.dart` | `MatrixDisplayFormatter` | Display text shared by app and CLI |
| `exact/*.dart` | `Rational`, `ExactArithmetic`, exact linear algebra and roots | Exact arithmetic on `BigInt` rationals, with the size limit |
| `numeric/numeric_policy.dart` | `CalculatrixNumericPolicy` | Default tolerances of the approximate path |
| `rpn/rpn_engine.dart` | `RpnEngine`, `RpnBinaryOperator`, `RpnUnaryOperator` | The stack: push, pop, peek, drop, pick, roll, clear |
| `machine/*.dart` | `CalculatrixMachine`, `CalculatrixCommand`, `CalculatrixProgram`, `CalculatrixMacro`, the command classes | Executes commands on an engine; a failing command leaves the stack as it was |
| `evaluation/calculatrix.dart` | `Calculatrix` | Entry points: `evaluateRpn`, `evaluateRpnStack`, `evaluateInfix`, `compileInfix`, `tokenizeRpnLine`, `executeWordOn` |
| `registry/command_registry.dart` | `CalculatrixCommandRegistry`, `CalculatrixCommandEntry`, `CalculatrixCommandExample`, `CalculatrixCommandCategory` | The vocabulary (section 7) |
| `names/name_table.dart` | `CalculatrixNameTable`, `CalculatrixNameBinding` | Names and constants (section 8) |
| `errors/errors.dart` | `CalculatrixError` and subclasses, `CalculatrixErrorId` | Errors (section 9) |
| `session/calculatrix_session.dart` | `CalculatrixSession`, `CalculatrixMode` | The app's keypad session: drafts, stack, memory |

The entry points take an optional `maxDigits` (section 10).
`evaluateRpn` and `evaluateInfix` require the program to leave exactly one
value and fail with `syntax-error` otherwise; `evaluateRpnStack` returns the
whole stack, bottom to top. An empty program is `syntax-error`.

## 4. Literals

Literals are the same in RPN, in infix and inside matrix literals, except
where noted.

**Numbers** are exact rationals: `3`, `-2`, `+3`, `0.1` (1/10), `.5`, `5.`,
`1e-3` (1/1000), `1E400` (10^400). Grammar:
`[+-]? (digits [. digits*] | . digits) ([eE] [+-]? digits)?`.

**Fractions** `p/q` are one exact literal in RPN and inside matrix
literals: `1/3`, `-5/3`, `[[1/3 2]]`. Both parts are integers, the sign
goes only on `p`, no spaces. `p/0` is `non-finite`. `1.5/2`, `1/2/3`,
`1/-2` and `1e2/3` are not literals: `unknown-word` in RPN, `syntax-error`
inside a matrix literal. In infix `/` is always division, so `1/3` gives
the same value and `2^1/3` is (2^1)/3.

**Approximate mark.** `~` in front of a literal, before its sign, makes it
approximate (the nearest double): `~0.1`, `~-0.1`, `~1/3`, `~[[1 2]]`. The
mark belongs to the literal: `-~0.1` is `syntax-error` and the message
shows `~-0.1`. One `~` anywhere in a matrix literal, in front of it or on
any entry, makes the whole matrix approximate. A marked literal outside the
double range is `non-finite`. What exact and approximate mean is in
`calculatrix_mathematics.md`.

**Matrix literals.**

- Rows in brackets inside brackets: `[[1 2] [3 4]]`. A flat list is one
  row: `[1 2 3]` is 1x3.
- Entries are separated by whitespace, commas or both; rows may touch:
  `[[0 -1][1 0]]` and `[[1,2],[3,4]]` read as `[[0 -1] [1 0]]` and
  `[[1 2] [3 4]]`.
- A sign or `~` in front applies to the whole matrix: `-[[1 2]]`.
- Entries are numbers or fractions only: no names, no expressions, no
  nesting deeper than two levels. `[[pi 0] [0 1]]` is `syntax-error` and the
  message says `pi` is a constant.
- `[]` and ragged rows are `dimension-mismatch`; unbalanced brackets are
  `syntax-error`, whose token is the input from the opening bracket (from
  the start of its RPN token) and whose position is that start:
  `1 [[1 2]` gives token `[[1 2]` at position 3.

**Not literals:** `NaN` and `Infinity` are recognized only to fail as
`non-finite`. `0x10`, `1_000` and `1e` are not numbers (`unknown-word` in
RPN, `syntax-error` in infix).

## 5. RPN evaluation

A program is a sequence of tokens separated by any whitespace; whitespace
inside matrix brackets belongs to the literal. Stack level 1 is the top.

Each token is resolved in this order:

1. A literal is pushed.
2. A name or alias of the registry, case-insensitively, runs that entry
   (constants are registry entries, section 8).
3. Anything else is `unknown-word`, with:
   - up to three "did you mean" suggestions: an exact search-term match
     first, then the closest names by restricted edit distance (at most 2,
     less for short words), prefix matches preferred;
   - the infix form to type when the token looks like infix (parentheses,
     or an operator between operands: `3.7^2.5`);
   - the word to use when a constant carries a sign or mark (`-pi` gives
     `pi negate`, `~pi` gives `pi approx`).

`--` inside a program is `unknown-word` and the message gives the program
to type without it (`--` ends the options of a command line and goes before
the quoted program).

Before a word runs, the stack depth is checked against the arity of the
word the user wrote, not of its expansion: `sqrt` on an empty stack reports
"sqrt needs 1 value on the stack, found 0." After a word runs, a non-finite
approximate value it produced is `non-finite`, reported on that word.

## 6. Infix evaluation

Infix compiles to the same RPN commands (shunting-yard), so both notations
share one implementation of every operation. Positions in errors are
1-based offsets into the original input.

**Operands:** numbers, matrix literals, parenthesized expressions and the
constants `pi`, `π`, `e`, `i` (any case). A constant is recognized only as
a whole name: `e3` and `pi2` are not constants, `pi-e` is a subtraction.
There is no implicit multiplication (`2pi` is `syntax-error`).

**Operators**, from loosest to tightest:

1. `+ -` (left-associative)
2. `* /` (left-associative)
3. unary minus
4. `^` (right-associative: `2^3^2` is 512)

A unary minus negates the operand that follows, whatever it is, and binds
looser than `^`: `-2^2` is -4, `(-2)^2` is 4, `2^-2` is 1/4, `-(2+3)*4` is
-20, `-√9` is -3. A signed number that is not the base of `^` is one
literal (`3*-2`). Prefix `√` takes the operand after it; a bare argument
must be parenthesized to combine it with further operators (`√(4)*2`).
Postfix `%` divides the operand just before it by 100 (`2*50%` is 1).

**Names.** Infix has no function calls. A name that is not a constant is
`syntax-error`; the message says what infix accepts (numbers, matrix
literals, the constants pi (π) e i, `+ - * / ^ √ %` and parentheses) and
names the form to type:

- a registry word called with literal arguments gives the RPN program:
  `inverse([[1 2] [3 4]])` says `cx eval rpn "[[1 2] [3 4]] inverse"`,
  `power(2, 3)` says `cx eval rpn "2 3 power"`;
- a registry word with other arguments says the argument comes first
  (`x sqrt`);
- any other name says it is a name, not a number.

## 7. Command registry

`CalculatrixCommandRegistry.standard` is the whole vocabulary. Each entry
holds its name, aliases, search terms, an informative HP 50g reference,
category, stack effect, arity, preconditions, description, executable
examples, the error ids it can raise, related entries, and either a builder
(primitive) or a definition (defined). `cx commands list` and
`cx commands show <word>` print it; this spec does not repeat the list.

**Names.**

- A name is a lowercase word, or words joined by hyphens, spelled as in
  common mathematical usage: `add`, `power`, `determinant`,
  `frobenius-norm`.
- A name for an action on a subject uses `<verb>-<subject>`:
  `append-cols`, `delete-row`, `move-col`.
- Symbols and short forms are aliases, never names: `+`, `^`, `√`, `%`,
  `pwr`, `inv`, `dup`, `det`.
- `exp` is e^x; x^y is `power` (aliases `pwr`, `^`); `ln` is the natural
  logarithm, and `log` stays free for base 10.
- Lookup is case-insensitive by name or alias. Each name and alias belongs
  to one entry; a collision is rejected when the registry is built.

**Aliases and search terms are different.** An alias is a word of the
language. A search term (`hcat` for `append-cols`, `plus` for `add`) only
finds the entry in `cx commands search` and in suggestions; in a program it
is `unknown-word`. The HP 50g reference is never a word either:
`1 2 2 ->ARRY` is `unknown-word`.

**Search.** `CalculatrixCommandRegistry.search(text)` (and
`CalculatrixCommandEntry.matchesSearch`) finds the entries whose name, an
alias, HP 50g reference, a search term or description contains `text`,
case-insensitively, reading `->` and `→` as the same arrow: `->arry` finds
the entry whose HP reference is `→ARRY`.

**Primitive and defined words.** A primitive entry builds a core command.
A defined entry is an RPN program over other words: `inverse` is
`-1 power`, `sqrt` is `0.5 power`, `duplicate` is `1 pick`, `over` is
`2 pick`, `swap` is `2 roll`, `rotate` is `3 roll`. When the registry is
built, every non-literal word of a definition must resolve, and a
definition that reaches itself, directly or through other words, is
rejected. An error raised inside a defined word reports the word the user
wrote and its position.

**One implementation per concept.** A defined word and its definition give
bitwise identical results; a word stays primitive until its definition
does. `power` uses the exact algorithm of an exponent that has one
(repeated multiplication for an integer, the inverse for -1, the matrix
square root for 1/2). Words that take arguments from the stack, and the
app's session keys, run through the same engine operations and the same
compile path as everything else.

**Indices are 1-based**: stack levels (level 1 is the top) and rows and
columns of a matrix. The conversion to 0-based happens once, inside the
word. A non-positive or non-integer index is `type-mismatch`; an index past
the end is `dimension-mismatch` (rows, columns) or `stack-underflow` (stack
levels).

**Construction words take explicit sizes.** `vector` always takes the
element count (`0 1 2 vector` is `[[0] [1]]`); `zeros` and `ones` take rows
and columns; a zero size is `dimension-mismatch`.

**Registry text** (descriptions, examples) speaks to the user: no
references to planning documents, issue numbers or spec sections. Every
example is a program a test runs, so the documentation cannot drift from
the behavior.

## 8. Name table and constants

`CalculatrixNameTable` maps a name, case-insensitively, to a binding: a
value, aliases and a read-only flag. `CalculatrixNameTable.standard` holds
only the system constants and has no way to add a binding at run time:

| Name | Alias | Value | Kind |
|---|---|---|---|
| `pi` | `π` | nearest double to pi | approximate |
| `e` | none | nearest double to e | approximate |
| `i` | none | `[[0 -1] [1 0]]` | exact |

Each constant is also a registry entry (category `constants`, primitive,
arity 0) that pushes the value read from the name table, so the value has
one source and `cx commands` documents it. A constant is a name, not a
number: `1e3` is the number 1000, `2e` and `e3` are unknown, `-pi` and
`~pi` are invalid in RPN, and matrix literals accept no names.

## 9. Errors

Every domain error is a `CalculatrixError` with a `message` and, where
known, a stable `errorId`, the offending `token`, its 1-based `position`
in the input, the `name` it resolved to, and `suggestions`.

| Id | Raised for |
|---|---|
| `unknown-word` | an RPN token that is no literal, word or name; `--` in a program |
| `syntax-error` | malformed input: infix grammar, misplaced `~`, malformed matrix literal, a program that does not leave exactly one value |
| `stack-underflow` | a word with fewer values on the stack than it needs |
| `type-mismatch` | an operand of the wrong kind: division by a non-scalar, a non-positive or non-integer index |
| `dimension-mismatch` | incompatible or impossible shapes, an index out of range |
| `singular-matrix` | inverting a singular matrix |
| `non-finite` | a result or literal that is not a finite number (`1/0`, `NaN`) |
| `log-undefined` | a logarithm, square root or fractional power with no real principal value that is not complex (a zero eigenvalue where the case needs log B, a nilpotent square root) |
| `ambiguous-power` | a power of matrix operands whose logarithm branch is not determined (`calculatrix_mathematics.md`, power) |
| `complex-result` | a real word whose result would be complex (eigenvalues of a rotation; the square root or a non-integer power of a matrix with a negative real eigenvalue) |
| `not-diagonalizable` | `diagonalize`, or a word built on it (`ln`, a non-integer power of a matrix larger than 2x2), on a defective matrix: fewer independent eigenvectors than its size |
| `limit-exceeded` | an exact result over the size limit (section 10) |

Class hierarchy: `MatrixShapeError`, `MatrixDomainError`,
`MatrixIndexError`, `RpnStackError` (with `RpnStackUnderflowError`, which
carries `needed` and `found`, and `RpnStackRangeError`),
`ExpressionSyntaxError`, `UnsupportedCalculatrixOperationError`,
`UnknownWordError`, `LimitExceededError` (carries `limit` and
`estimated`), and `EmptyMemoryError` (session only, no id). The id, not
the class, is the contract. Programming errors, such as an invalid
registry or a zero `Rational` denominator, are `ArgumentError`. The CLI
maps ids to exit codes (`calculatrix_cli.md`, "Output and errors").

## 10. Size limit

Before an exact operation, and when reading an exact literal, core
estimates the digits of each numerator and denominator of the result. Over
the limit (default 10000 digits, `ExactArithmetic.defaultMaxDigits`,
changed with `maxDigits`) it raises `limit-exceeded` with `limit` and
`estimated`, before computing anything. Approximate values and literals
marked `~` are not limited. The hint shown to the user is the CLI's.

## 11. Quality requirements

1. Test-driven: a behavior change starts with a failing test.
2. `dart analyze` is clean and `dart test` is green in CI.
3. Every registry example runs as a test, and each defined word is tested
   bitwise identical to its definition.
4. Shape coverage: 1x1, vectors, square and non-square matrices go through
   the same operations.
5. Differential tests against Giac: every exact word runs on generated
   exact inputs (fixed seeds, sizes up to near the limit) and its result is
   compared with Giac's, entry by entry, as exact rationals. They run in
   the CI job `core` on Linux with Giac from the distribution packages
   (`CALCULATRIX_REQUIRE_GIAC=1` makes a missing Giac a failure), locally
   through WSL, and are skipped with a message where Giac is missing. Test
   expectations come from mathematics; Giac only detects disagreement. The
   policy is ADR 0004.

## 12. Versioning

The package follows SemVer and stays on `0.x` until its API is stable.
Version and changelog rules are in ADR 0002.
