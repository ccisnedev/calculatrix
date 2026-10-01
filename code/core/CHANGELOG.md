# Changelog
All notable changes to package calculatrix will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the package adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- A core command registry (spec section 7): `CalculatrixCommandRegistry`
  resolves an RPN word to a `CalculatrixCommandEntry` by name or alias,
  case-insensitively, carrying the documentation fields spec section 7
  requires (search terms, HP 50g reference, definition, category, stack effect,
  preconditions, description, executable examples, errors, see also) plus
  how to build its `CalculatrixCommand`. `Calculatrix._compileRpnToken` now
  resolves every non-literal RPN word through
  `CalculatrixCommandRegistry.standard` instead of a hardcoded switch; a
  word the registry does not know still raises `unknown-word` as before.
  This PR registers the operators the compiler already knew, named per
  runbook D41 (names are words, symbols are aliases): `add` (`+`),
  `subtract` (`-`), `multiply` (`*`), `divide` (`/`), `percent` (`%`), and
  `power`, with aliases `pwr` and `^` (runbook D14, D18). `sqrt` (alias
  `√`) is also registered, still as a primitive command; its defined-word
  form (`0.5 power`, runbook D43, D44) is left to a follow-up PR, along
  with `vector`, `rows`, `append-rows`, `append-cols`, the `cx commands`
  route and "did you mean" (issue #32). The entry field `hp50gEquivalent`
  is named `hp50gReference` instead: purely informative, never resolved as
  a word (runbook D42, "the HP 50g is inspiration, not adoption"). The
  `definition` field is null for a primitive entry (`isPrimitive`); every
  entry registered here is primitive (runbook D43).
- Defined words (runbook D43, D44; issue #35): a `CalculatrixCommandEntry`
  is now either primitive (`build`, no `definition`) or defined (a
  `definition` RPN program over other registry words, no `build`), never
  both or neither. `Calculatrix._compileWord` expands a defined entry into
  the compiled commands of its own definition, recursively, through the
  exact same compiler path any other RPN input goes through, so a defined
  word's result is bitwise identical to typing its definition by hand.
  Every compiled command carries the original input token, so an error
  raised while executing a defined word's expansion still reports the word
  the user actually typed (e.g. `inverse`), not a word from inside its
  definition (e.g. `power`). `CalculatrixCommandRegistry`'s construction
  now also validates every definition: a non-literal word it uses must
  resolve in the registry, and no definition may reach itself, directly or
  through other defined words; either violation raises `ArgumentError` at
  construction. `inverse` (alias `inv`, definition `-1 power`) is a new
  registry entry; `sqrt` (alias `√`) is converted from primitive to
  defined (`0.5 power`), both sharing `power`'s exact algorithm for those
  exponents instead of a separate implementation (D44, one implementation
  per concept).
- `vector`, `rows`, `append-cols` and `append-rows` (runbook step S4c, issue
  #37): four new primitive registry entries in the new `matrix` category
  (`CalculatrixCommandCategory`), none of them aliased (runbook D29, R12).
  `vector` (`x1 ... xn n -> [[x1] ... [xn]]`, HP 50g reference `→ARRY`)
  builds a column matrix from `n` scalars, reading the stack depth at run
  time; `n` must be a non-negative integer scalar (`type-mismatch`
  otherwise), fewer than `n` items below it is `stack-underflow`, and `0
  vector` raises `dimension-mismatch`, since an empty matrix has no
  representation (`Matrix`'s own constructor already rejects zero rows).
  `rows` (`[[...]] -> [row1] ... [rown] n`, HP 50g reference `ROW→`)
  splits a matrix into its rows plus their count. `append-cols` (`A B ->
  [A B]`, search terms `hcat`, `horzcat`, `concatenate`, `column`) and
  `append-rows` (`A B -> A over B`, search terms `vcat`, `vertcat`,
  `concatenate`, `row`) generalize the existing single-row/column append to
  any operand of matching size, raising `dimension-mismatch` otherwise.
  `Matrix.appendRows`/`Matrix.appendColumns` are the single implementation
  behind these two words and behind the existing `appendRow`/`appendColumn`
  (and their commands), which keep their current single-row/column results
  and error cases exactly (D44, one implementation per concept). A search
  term is never a resolvable word: using one in a program still raises
  `unknown-word`.
- The rest of the core RPN vocabulary, 1-based indices (runbook step S4d,
  decision D46, issue #39): every remaining command from the runbook's
  "Command names" table is now a registry entry, in four new categories
  (`CalculatrixCommandCategory.stack`, `construction`, `structure`,
  `linearAlgebra`). Stack words: `pick` and `roll` (both 1-based, level 1
  is the top; a malformed index is `type-mismatch`, an in-range-but-too-deep
  index is `stack-underflow`, never `stack-range`) and `drop`, all
  primitive, backed by the existing `RpnEngine.pick`/`roll`/`drop`.
  `duplicate` (alias `dup`), `over`, `swap` and `rotate` (alias `rot`) are
  now defined words (`1 pick`, `2 pick`, `2 roll`, `3 roll`), with no
  implementation of their own: the app's typed `PickCommand`/`RollCommand`
  and `CalculatrixSession.dupRpn`/`overRpn`/`swapRpn`/`rotRpn` all execute
  the registered word by name through the one shared compile path, so an
  app action and its RPN word always agree, including on errors (D44,
  "one implementation per concept"). This removes the former dedicated
  `DupCommand`/`OverCommand`/`SwapCommand`/`RotCommand` classes and
  `RpnEngine.dup`/`over`/`swap`/`rot` methods; the HP 50g calls its
  malformed-index case for `PICK`/`ROLL` a plain "bad argument value",
  which this package maps to `type-mismatch`, not a new error id.
  Construction words: `zeros`, `ones` and `identity` build new matrices
  from scalar dimensions (HP 50g `CON`/`IDN`); `0 zeros`/`0 ones`/`0
  identity` raise `dimension-mismatch`, like `0 vector`. Structure words:
  `transpose`, and the 1-based `delete-row`, `delete-col`, `duplicate-row`,
  `duplicate-col`, `move-row` and `move-col`, sharing `Matrix`'s existing
  0-based row/column methods after converting the index (D46, AC2).
  Linear algebra words: `determinant` (alias `det`), `trace`, `rank`,
  `frobenius-norm` (alias `norm`), `spectral-norm`, `eigenvalues` (alias
  `eig`), `diagonalize`, `cofactors`, `adjugate` (alias `adj`), `dot`,
  `cross`, `rref`, `lu` and `qr`, all primitive, each backed by the
  existing `Matrix` method of the same computation, with no new algorithm.
  `diagonalize` and `lu`/`qr` push several results at once (`P D`, `P L
  U`, `Q R`), with the whole push atomic through
  `CalculatrixMachine.executeAtomic` (issue #39, AC5): a mid-push failure
  leaves the stack exactly as it was, never partially applied. `exp` and
  `ln` (arithmetic category) round out the transcendental pair alongside
  `power`; `ln` is named for the natural logarithm because `log` is left
  free for a future base-10 word (D46). Every new word's preconditions,
  examples and `seeAlso` follow spec section 7 exactly like the words
  registered in earlier PRs; none of them introduce a new
  `CalculatrixErrorId`.
- "Did you mean" for RPN words (spec section 7, "Did you mean"; issue #41):
  `CalculatrixCommandRegistry.suggest(word)` ranks the registry's entries
  by restricted edit distance (Damerau-OSA) to their name and aliases,
  with an exact match on a search term ranked first (`hcat` suggests
  `append-cols` even though `hcat` is never a word). A dependency-free
  reimplementation, not a call into `modular_cli_sdk`'s own
  `CommandCatalog.suggest`: the app needs the very same suggestions
  without depending on a CLI package. `UnknownWordError` now carries these
  candidates in a new `suggestions` field (`CalculatrixError.suggestions`,
  empty by default), and appends them to its own message when not empty.

- Actionable agent-facing errors (issue #51): `RpnStackUnderflowError.message`
  now names the word that underflowed and how far short the stack fell
  (`"power needs 1 value on the stack, found 0."`), built lazily from a new
  `needed`/`found` pair every `RpnEngine` throw site now records, once the
  evaluator's dispatch loop has enriched the error with its word
  (`CalculatrixError.enrichToken`); an error built with no token, or no
  `needed`/`found`, keeps its original message exactly as before. A name
  written into an infix expression (`sqrt(7)`, `e`, `ln(10)`) now raises
  `ExpressionSyntaxError` (still `syntax-error`, same `details.position`)
  explaining that infix only accepts numbers, matrix literals, the four
  arithmetic operators, `^` and parentheses; when the name is a registered
  RPN word or alias, the message also shows its RPN form (`cx eval rpn "7
  sqrt"`), via `CalculatrixError.name`, newly set on the error. A
  non-literal RPN word whose text looks like an infix expression (contains
  `(`/`)`, or an operator sandwiched between operand-shaped characters,
  such as `3.7^2.5`) now appends a hint to its `unknown-word` message
  pointing at `cx eval infix`, both from `cx eval rpn` and from the root
  `<program>` shortcut; the id, exit code and suggestions are unchanged.
  `CalculatrixCommandRegistry.suggest()` now scales its distance threshold
  to the needle's own length (`(needle.length - 1).clamp(0, maxDistance)`)
  instead of a flat threshold, so a short token such as `e` no longer
  pulls in unrelated one-character aliases (`+`, `-`, `*`, `/`) as "did you
  mean" suggestions, while longer typos (`pow`, `dupp`, `transpos`) keep
  suggesting the word they were obviously reaching for.
- Review fixes on the compiled `cx` binary (issue #51): `power` (and every
  other registry word with a declared arity) now reports the arity of the
  word actually typed, not whatever an inner primitive its definition
  expands to happens to pop. `CalculatrixCommandEntry` gained a new
  `arity` field, set on every word whose stack need is fixed and known
  ahead of time (`null` for the handful, such as `vector`, `pick` and
  `roll`, whose need is only known at run time and which already report
  their own accurate `needed`/`found`); `Calculatrix` now checks the real
  stack depth against that arity before expanding a word's definition,
  instead of letting the first primitive inside it raise its own, possibly
  different, underflow. A new test iterates every registry word with an
  arity, both on an empty stack and one value short, asserting the message
  always states the real arity and the actual depth. `suggest()` also
  tightens its candidates to the single closest edit-distance tier (and,
  within a tie in that tier, to a prefix match when one exists), so `pow`
  suggests only `power`, not also `rows` or `rotate` merely because they
  happen to sit at the same raw distance, and `dupp` suggests only
  `duplicate`, not also `drop`. `restrictedEditDistance` (the distance
  function `suggest()` itself uses) is now public, exported for
  `calculatrix_cli` to reuse rather than reimplement when it does the
  equivalent tightening for its own route suggestions.
- A second round of review fixes on the compiled `cx` binary (issue #51):
  a truncated infix call such as `sqrt(` no longer throws an unhandled
  `RangeError`; an unclosed parenthesis is now detected and reported as
  the normal syntax error instead. The declared `arity` that lets
  `Calculatrix` pre-check a word's real stack depth (see the entry above)
  is now `null` again for `zeros`, `ones`, `delete-row`, `delete-col`,
  `duplicate-row`, `duplicate-col`, `move-row` and `move-col`: each of
  these pops and validates one argument before it ever pops the next, so
  with only one value on the stack a fixed arity would have masked that
  argument's own type-mismatch (`"zeros requires a non-negative integer
  count, found -1.0."`) behind a misleading stack-underflow. `vector` now
  checks its own real need (the count against the values actually below
  it) before popping any of them, rather than letting its last pop fail
  with the generic "needs 1 value, found 0": `1 2 3 vector` now reports
  `"vector needs 3 values on the stack, found 2."`, the count and the true
  shortfall, not the inner pop's. A registry word written with a hyphen
  (`frobenius-norm(7)`) is now recognized by its whole name in an infix
  name error, not just the run of letters before the hyphen. The RPN form
  an infix name error suggests is now shown only when the call's argument
  is a plain number literal; a non-literal argument (`sqrt(1+2)`) or a
  space before the call (`sqrt (7)`) instead gets a generic, non-runnable
  description of where the argument goes, since neither `cx eval rpn "1+2
  sqrt"` nor `cx eval rpn "sqrt"` is actually valid RPN. The infix-shaped
  heuristic behind the unknown-word hint now also matches a signed
  (`3^-2`) or leading-decimal (`1+.5`) right-hand operand.
  `CalculatrixError.name`, set on an infix name error, now rides along in
  the CLI's JSON error envelope as `details.name`. The root `--help`/`-h`
  text now gives every listed command its own example, including
  `commands list`, `doctor`, `upgrade`, `uninstall` and `version`, which
  previously had none.
- Exact numbers (runbook-trust.md, step T2). `Rational` is an exact
  rational over `BigInt`, always reduced, and a `Matrix` is either exact or
  approximate as a whole (`isExact`, `exactRows`, `exactAt`; D49).
  Literals in RPN, infix and matrix literals are exact (D50); `~` before a
  literal makes it approximate (D56). `+ - * /`, `negate`, `percent`,
  integer powers of scalars and non-negative integer powers of square
  matrices are exact on exact operands (`ExactArithmetic`); one approximate
  operand makes the result approximate (D51). Stack and structure words keep
  exactness, and `zeros`, `ones`, `identity` and `rows` build exact values;
  every other word converts its operands to approximate (D53). New words
  `approx` (alias `num`) and `exact` (D52). `Rational.toDisplayString` gives
  the text of D54. The new error id `limit-exceeded`
  (`LimitExceededError`, with `limit` and `estimated`) is raised before an
  exact result would exceed `maxDigits` digits (default
  `ExactArithmetic.defaultMaxDigits`, 10000), a new parameter of
  `evaluateRpn`, `evaluateRpnStack` and `evaluateInfix` (D55).
  `evaluateInfix(approximate: true)` keeps the old approximate result for
  callers that only take doubles, as the app does until step T5. A literal
  out of the double range (`1e400`) is exact now, no longer `non-finite`;
  `~1e400` still is. Differential tests against Giac
  (`test/exact/giac_differential_test.dart`, tag `giac`) check every exact
  word of this step, and run in CI (D57).
- Exact linear algebra (runbook-trust.md, step T3). `ExactLinearAlgebra`
  extends `ExactArithmetic` with `inverse`, `determinant`, `rref`, `rank`,
  `trace`, `cofactors`, `adjugate`, `lu`, `dot` and `cross` on exact
  matrices, and the matching RPN words use them on exact operands (D53);
  a negative integer power of an exact square matrix is the exact power of
  its inverse. Elimination is fraction-free (Bareiss) on the integer matrix
  over one common denominator. Before computing, the Hadamard bound
  estimates the size of the result and raises `limit-exceeded` over
  `maxDigits` (D55). Shapes and error messages are those of the
  approximate methods, and `lu` picks the pivot of largest magnitude, as
  `luDecomposition` does. The Giac differential tests cover every new word,
  with more than 1100 cases.
- Exact roots and eigenvalues (runbook-trust.md, step T4). The extension
  `ExactRoots` adds `fractionalPower`, `frobeniusNorm`, `exp` and `ln`, and
  `ExactLinearAlgebra.eigenvalues` joins it. `power` with a non-integer
  exact exponent, `sqrt` (`0.5 power`, and `RpnEngine.applyUnary` too),
  `frobenius-norm`, `eigenvalues`, `exp` and `ln` are exact on exact
  operands when the result is rational (D53), and otherwise return the
  approximate result, errors included. Scalars, complex numbers in their
  2x2 form and diagonal matrices use closed forms (`-4 sqrt` is `2i`);
  any other matrix gets its principal root approximately, converted to the
  simplest nearby rationals and checked exactly. `eigenvalues` computes
  the characteristic polynomial (Berkowitz) and its rational roots by
  Hensel lifting modulo a small prime, largest first with multiplicity,
  after a norm bound check against `maxDigits` (D55). `exp` and `ln` are
  exact only for a zero matrix and the identity. Complex eigenvalues are
  deferred (D53 amended). New: `Rational.root`, `Rational.floorRoot`,
  `Rational.simplestWithin`. The Giac tests cover every word and check
  that irrational results stay approximate.
- Fraction literals and exact sessions (runbook-trust.md, step T5). An
  integer fraction `p/q` is one exact numeric literal in RPN and inside a
  matrix literal (D59), each part of an exact fraction held to `maxDigits`
  (`~p/q` is exempt, like any marked literal); infix is unchanged.
  `MatrixDisplayFormatter` prints exact values in full and marks
  approximate ones with `~` in `compact`, `expanded` and `complex`, and the
  new `text`, `mark` and `entry` give the `cx` stack-line form (D54).
  `CalculatrixSession` no longer evaluates literals as approximate: memory
  arithmetic, sign toggle, square root, inverse and the expression seeded
  from a result keep exact values, and an approximate seed carries its
  mark. `PushZerosCommand`, `PushOnesCommand` and `PushIdentityCommand`
  push exact matrices, as `zeros`, `ones` and `identity` do.

### Fixed

- `Matrix.sqrt()` no longer rejects singular matrices that do have a real
  principal square root. It first normalizes the target by its own
  infinity norm `s` (`sqrt(A) = sqrt(s) * sqrt(A/s)`, rescaling the result
  back afterward), so every tolerance-based decision that follows acts on
  a target of norm 1, where a fixed absolute tolerance like `1e-12` is
  meaningful; without this, a uniformly tiny or uniformly huge but
  otherwise well-conditioned matrix could be misclassified as singular (or
  vice versa) purely because of its own absolute scale. It then runs the
  original Newton (Denman-Beavers) iteration first for any normalized
  target that is not structurally singular, so every previously working
  case, including complex eigenvalue pairs and non-semisimple nonzero
  eigenvalues, is unchanged. A matrix is structurally singular when its
  rank falls below its dimension under a strict, machine-epsilon-scaled
  relative tolerance, deliberately tighter than the caller's own
  `relativeTolerance`/`absoluteTolerance` so a merely tiny but nonzero
  eigenvalue relative to the target's own norm is never misclassified as
  singular. A structurally singular target is instead split into
  complementary A-invariant subspaces, its range and null space (`V =
  [basis of range(A) | basis of ker(A)]`, `V⁻¹AV = blockdiag(B, 0)` with
  `B` nonsingular), with `sqrt(B)` computed by the same unmodified Newton
  iteration and `sqrt(A) = V · blockdiag(sqrt(B), 0) · V⁻¹`. This requires
  only that the zero eigenvalue be semisimple (`rank(A) == rank(A²)`); it
  continues to raise `MatrixDomainError` otherwise, for example for a
  nilpotent Jordan block, and now raises that same error instead of an
  unrelated shape error on the (structurally unreachable, but guarded)
  case of an empty range basis. An eigenvalue that is numerically zero
  relative to the target's own norm is returned as exactly 0, which is
  backward stable (`X*X` reconstructs `A`) even where it is not
  forward-accurate. Verified against Giac to a relative Frobenius error of
  1e-12 or better (issue #19), including four regressions found in review
  of the first fix: a non-semisimple nonzero eigenvalue on an otherwise
  singular matrix, a complex eigenvalue pair with a real principal root, a
  genuinely nonsingular matrix with a tiny nonzero eigenvalue that a
  looser rank tolerance would have misrouted, and a uniformly tiny (or
  huge) but well-conditioned matrix that fixed absolute tolerances are not
  invariant to.
- `power` at exponent `-1` (a matrix base) calls the matrix inverse
  directly, and at `0.5` (a scalar or matrix base) calls `sqrt()`, instead
  of the general `exp(y * log B)` route (runbook D44, issue #35), so
  `-4 0.5 power` is exactly `[[0 -2] [2 0]]` and `[[0 0] [0 4]] 0.5 power`
  is `[[0 0] [0 2]]` instead of `log-undefined`. The rounding noise of
  `[[1 2] [3 4]] -1 power` comes from the inverse itself and is left to
  the display formatter (runbook D45). `sqrt()` of a complex matrix
  `[[a -b] [b a]]` (runbook D25) is its complex principal square root, as
  for a negative scalar: `[[-1 0] [0 -1]] sqrt` and `0.5 power` give
  exactly `i`, `[[0 -1] [1 0]]`, and `[[3 -4] [4 3]]` gives `[[2 -1] [1 2]]`. Every internal
  failure of `Matrix.sqrt()` now also carries `errorId:
  CalculatrixErrorId.logUndefined`, so `[[-1 0] [0 2]] sqrt` and
  `[[-1 0] [0 2]] 0.5 power` raise `log-undefined` instead of the CLI's
  generic fallback error id.
- Removed development meta references (runbook, issue, decision and
  acceptance-criterion mentions) from `CalculatrixCommandEntry` user-facing
  fields in `command_registry.dart`. Those references meant nothing to a
  reader of `cx commands show|search|list` and leaked the development
  process into the product; the ones worth keeping for maintainers now live
  in a `//` comment beside the entry instead. `registry_text_test.dart`
  guards against a regression by scanning every entry's user-facing string
  fields for the same patterns (issue #43).

## [0.7.0] - 2026-05-21

### Changed

- Coordinated version alignment with the repository-wide `0.7.0` release that
  closes the Stage 7 Flutter shell milestone.
- No public `package:calculatrix` API or semantic contracts changed in this
  release; core math, machine, and session behavior remain the same as in
  `0.6.6`.

### Documentation

- Consumer-facing docs now describe the Flutter shell as a persistent `RPN`
  surface with explicit `INFIX` and `MATRIX` editors over the unchanged core
  session model.

## [0.6.6] - 2026-05-19

### Added

- **Formal mathematical specification** (`docs/spec/calculatrix_mathematics.md`)
  covering the normative model of the engine:
  - scalar-as-`1x1` embedding
  - complex-as-`2x2` embedding
  - matrix-first operator semantics and scalar promotion law
  - numerical policy and determinism criteria
  - formal contracts/limits for `sqrt`, `exp`, `log`, `svd`, eigen and
    decomposition workflows
  - proof-oriented worked examples (Euler identity, conjugation, spectral
    invariant behind SVD)

### Documentation

- Establishes a concrete and complete mathematical baseline for pre-publication
  validation in subsequent release gates.

## [0.6.5] - 2026-05-19

### Added

- **`Matrix.log()` method**: principal matrix logarithm with matrix-first
  semantics. Supports:
  - positive scalars: `log(x) = ln(x)`
  - negative scalars: complex principal value as `ln(|x|) + π·i`
  - complex-form matrices `[[a,-b],[b,a]]`: principal branch
    `log(a+bi) = ln(r) + θ·i`
  - diagonalizable real-domain square matrices with positive spectrum
- **`Matrix.svd()` method** returning `SvdDecomposition(u, s, vT)` with
  reconstruction contract `A ≈ U·S·Vᵀ` and non-negative descending singular
  values in `S`.
- **New v0.6.5 test suite** (`matrix_log_svd_test.dart`): 10 tests covering
  logarithm domain/branch behavior, `exp(log(A))` round-trip on positive
  diagonal matrices, SVD reconstruction for square/rectangular matrices,
  singular value ordering, and zero-matrix behavior.

## [0.6.4] - 2026-05-19

### Added

- **`Matrix.exp()` method**: computes the matrix exponential via truncated
  Taylor series (I + A + A²/2! + A³/3! + ..., truncated at 50 terms).
  For pure imaginary matrices θ·J, yields rotation matrices:
  expm(θ·J) = [[cos(θ), -sin(θ)], [sin(θ), cos(θ)]].
  Enables Euler's formula verification: `exp(π·i) + I = 0`.
- **Comprehensive exponential test suite** (`matrix_exponential_test.dart`):
  13 tests covering exp(0) = I, Euler's formula (e^(πi) = -I),
  full rotations (e^(2πi) = I), angle addition law for complex exponentials,
  and mixed real-complex: exp(3 + 2i) = e³·exp(2i).

## [0.6.3] - 2026-05-19

### Added

- **Scalar promotion** in `Matrix.+` and `Matrix.-`: when one operand is a
  1×1 scalar and the other is n×n square (n > 1), the scalar `k` is
  automatically promoted to `k·Iₙ` before the element-wise operation. This
  enables natural complex arithmetic: `Matrix.scalar(3) + Matrix.i` yields
  `Matrix.complex(3, 1)` = `3 + i`.
- `CONJ` button (Infix and RPN): applies transpose, yielding the complex
  conjugate for complex-form matrices (e.g., `CONJ(3+2i)` = `3 - 2i`).
- `i` button in Infix MAIN and RPN MAIN decks: inserts the imaginary unit
  `J = [[0,-1],[1,0]]` as a matrix literal, enabling expressions like
  `3 + 2 × i =` to evaluate to `3 + 2i`.

### Changed

- Infix MAIN deck: replaced `ID` with `i` and `M-` with `CONJ`. The identity
  preset remains accessible via the I button in the matrix editor EDIT deck.
- RPN MAIN deck: replaced `OVER` and `ROT` with `CONJ` and `i`. Both stack
  operations remain in the STACK deck.

## [0.6.2] - 2026-05-19

### Added

- `Matrix.complex(double re, double im)` factory: creates `re·I₂ + im·J` as
  `[[re, -im], [im, re]]`, the canonical 2×2 matrix representation of a
  complex number in the subalgebra isomorphic to ℂ.
- `Matrix.isComplexForm` getter: returns true for 2×2 matrices matching the
  pattern `[[a, -b], [b, a]]` (i.e., members of the complex subalgebra).
- `Matrix.realPart` / `Matrix.imagPart` getters: extract the real and
  imaginary components from a complex-form matrix; throw `MatrixDomainError`
  otherwise.
- `MatrixDisplayFormatter.complex(Matrix)`: formats a complex-form matrix as
  `a + bi` or `a - bi` with canonical edge-case handling (pure real, pure
  imaginary, coefficient ±1 shown as `±i` without digit prefix).

### Changed

- `Matrix.squareRoot()` for negative scalars now returns `√|k|·J` (a
  complex-form matrix) instead of throwing `MatrixDomainError`. For example,
  `sqrt(-4)` returns `[[0, -2], [2, 0]]` (i.e., `2i`).

## [0.6.1] - 2026-05-27

### Added

- INV (matrix inverse) is now an immediate unary operation in Infix mode,
  consistent with how √ is handled.
- I and J preset buttons in the matrix editor EDIT deck; pressing I fills the
  editor with the 2×2 identity matrix, J with `Matrix.i` (the imaginary unit).

## [0.5.6] - 2026-05-19

### Fixed

- Sqrt of negative number in Infix mode now shows Error instead of silently
  failing (uncaught `MatrixDomainError` in `_rewriteInfixDraftUnary`).

### Changed

- RPN keypad: moved √ and % to MAIN deck for immediate access; MC and M−
  moved to STACK deck.

## [0.5.5] - 2026-05-19

### Changed

- Fixed all off-grid spacing values (10dp → 8dp) for strict 4dp grid
  compliance: matrix cell padding, RPN register card spacing, mode button
  vertical padding.
- Added hover and focus state overlays to calculator buttons (hoverColor 8%,
  focusColor 10% of foreground color) for desktop interaction feedback.
- Replaced `GestureDetector` with `Material` + `InkWell` on mode switch pills
  and deck selector tabs to support hover/focus/splash states on desktop.
- All interactive elements now provide visible feedback on mouse hover and
  keyboard focus (H7 Flexibility & Efficiency, Fitts's Law feedback).

## [0.5.4] - 2026-05-19

### Changed

- Unified all border radii to M3 shape scale: 12 (medium), 16 (large),
  24 (extraLarge). Removed ad-hoc values (10, 14, 18).
- Calculator buttons now use elevation 0 (flat tonal M3 style) instead of
  elevation 2 with drop shadows.
- Drag feedback widgets use Material elevation instead of hardcoded BoxShadow.
- Deck selector tabs: radius 14 → 12 (medium).
- Mode switch container: radius 18 → 16 (large).
- Mode button pill: radius 14 → 12 (medium).
- Matrix cell inputs: radius 10 → 12 (medium).

## [0.5.3] - 2026-05-19

### Changed

- Migrated all hardcoded `TextStyle` constructors in the calculator UI to
  `Theme.of(context).textTheme` role references with `.copyWith()` overrides.
- Memory/stack indicators now use `labelLarge`.
- Expression text uses `titleMedium` (monospace override).
- Display value uses `displaySmall` (monospace override, dynamic sizing).
- RPN register labels use `labelLarge` (monospace override).
- Deck selector labels use `labelMedium`.
- Button labels use `titleMedium`/`titleLarge` (size-adaptive).
- Mode switch labels use `labelLarge`.
- Matrix cell labels use `labelSmall`.
- Matrix preview/error text uses `bodyMedium`.
- Zero raw `TextStyle(...)` constructors remain in view code.

## [0.5.2] - 2026-05-18

### Changed

- Migrated all hardcoded hex colors in the calculator UI to Material 3
  ColorScheme role lookups (`surfaceContainer`, `primaryContainer`,
  `tertiaryContainer`, `secondaryContainer`, etc.).
- Added dark and light ThemeData with `ColorScheme.fromSeed` (seed:
  `0xFF4FC3F7`) and automatic switching via `ThemeMode.system`.
- Mode switch now uses `primary`/`onPrimary` roles; deck selector uses
  `secondaryContainer`/`onSecondaryContainer` for visual hierarchy
  differentiation (H4 Consistency).
- Regularized deck margin from 6 dp to 8 dp (4 dp grid-aligned).
- Removed artificial 32 dp minimum key size floor; keys derive their size
  naturally from layout constraints (>48 dp on all supported viewports).

## [0.5.1] - 2026-05-18

### Fixed

- Keypad buttons no longer double-announce (added `excludeSemantics` to
  `Semantics` wrapper, preventing both tooltip and text from being read).
- Mode buttons no longer redundantly announce label twice ("Infix mode Infix"
  → "Infix mode").
- Deck selector tabs now provide descriptive labels (e.g., "Main operations"
  instead of just "MAIN").
- All function buttons (RREF, DIAG, COF, ADJ, TR, RANK, NORM, SNORM, DOT,
  CROSS) have explicit semantic labels for screen readers.
- Matrix editor row/column drag handles now have descriptive tooltips.
- Add-row and add-column buttons now have tooltips.
- Matrix cell labels expanded from abbreviated "r1c1" to "Row 1, Column 1".
- RPN X0 register wrapped in descriptive Semantics container.

### Added

- Live region semantics on expression, display value, and RPN entry register
  so screen readers automatically announce value changes.
- Dedicated accessibility widget test suite (`accessibility_semantics_test.dart`)
  with 8 assertions covering display, expression, buttons, mode switch, deck
  selectors, function labels, matrix cells, and editor handle tooltips.

## [0.5.0] - 2026-05-18

### Added

- `example/example.dart` demonstrating matrix creation, operations,
  decompositions, RPN evaluation, and interactive session usage.
- Topics `linear-algebra` and `math` added to pubspec for discoverability.
- Library-level dartdoc documentation.

### Changed

- README fully rewritten: accurate version, complete feature list, quick-start
  code examples, and correct API surface reference.
- Dartdoc now generates with zero warnings.
- `dart analyze` and `dart pub publish --dry-run` both pass cleanly.

### Milestone

Developer-preview release: package passes all pub.dev validation requirements
and is ready for publication.

## [0.4.8] - 2026-05-18

### Added

- Factory `Matrix.hilbert(n)` for the Hilbert ill-conditioned test matrix.
- Factory `Matrix.pascal(n)` for the Pascal symmetric positive-definite matrix.
- Factory `Matrix.frank(n)` for the Frank upper-Hessenberg matrix.
- 58-test numerical robustness suite validating inverse, LU, QR, eigenvalue,
  and RREF residuals on standard matrices from the literature (dimensions 3–8).

## [0.4.70] - 2026-05-18

### Added

- Public `Matrix.rref()` for Reduced Row Echelon Form via Gaussian elimination
  with partial pivoting.
- Public `Matrix.spectralNorm()` returning the induced 2-norm (largest singular
  value) as a scalar matrix.
- `RrefCommand` and `SpectralNormCommand` on the public typed command surface.
- RREF button in app FACT deck, SNORM button in PROP deck.
- Reorganized FACT/PROP decks for clarity: FACT=transforms, PROP=scalar queries.

## [0.4.60] - 2026-05-18

### Added

- Public `Matrix.dot()` and `Matrix.cross()` for column-vector operations.
- `DotProductCommand` and `CrossProductCommand` on the public typed command surface.
- VEC deck in app RPN mode with DOT and CROSS buttons.

## [0.4.50] - 2026-05-18

### Added

- Public `Matrix.minor()`, `Matrix.cofactor()`, `Matrix.cofactorMatrix()`,
  and `Matrix.adjugate()` following textbook definitions.
- `CofactorMatrixCommand` and `AdjugateCommand` on the public typed command surface.

## [0.4.40] - 2026-05-18

### Added

- Public `Matrix.trace()`, `Matrix.frobeniusNorm()`, and `Matrix.rank()`.
- `TraceCommand`, `NormCommand`, `RankCommand` on the public typed command surface.

## [0.4.30] - 2026-05-18

### Added

- Public `Matrix.diagonalization()` returning eigenvector matrix P and
  diagonal eigenvalue matrix D.
- `DiagonalizationCommand` on the public typed command surface.
- Null-space eigenvector extraction via Gaussian elimination.

### Changed

- `FACT` deck in the app now shows `DIAG` instead of `ZEROS`.

## [0.4.20] - 2026-05-18

### Added

- Generalized `Matrix.eigenvalues()` to arbitrary NxN square matrices using
  Hessenberg reduction and implicit QR iteration with Wilkinson shift.
- Complex-spectrum detection for NxN matrices (throws `MatrixDomainError`).

### Changed

- Removed `UnsupportedCalculatrixOperationError` size restriction on eigenvalues.
- Preserved 1x1 identity and 2x2 characteristic polynomial as fast paths.

## [0.4.10] - 2026-05-18

### Added

- Public `Matrix.eigenvalues()` support for `1x1` matrices and `2x2` matrices
  with a real spectrum.
- `EigenvaluesCommand` on the public typed command surface.

### Changed

- Extended the post-Stage-4 linear-algebra command vocabulary with a
  deterministic column-matrix eigenvalue workflow.

### Fixed

- Kept invalid eigenvalue requests on typed shape/domain/unsupported errors
  instead of introducing consumer-local fallbacks.

## [0.4.0] - 2026-05-18

### Added

- Stable Stage 4 public support for determinant, LU decomposition, and QR
  decomposition on the canonical matrix stack kernel.

### Changed

- Closed Stage 4 with release-grade validation across core, CLI, and app while
  keeping the public matrix-first stack contract intact.

## [0.3.31] - 2026-05-18

### Changed

- No public core API changes; the package version is aligned with the Stage 4
  end-to-end workflow coverage release built on top of the same canonical
  kernel.

## [0.3.30] - 2026-05-18

### Changed

- No public core API changes; the package version is aligned with the Stage 4
  Matrix-workstation factorization workflow release built on top of the same
  canonical kernel.

## [0.3.21] - 2026-05-18

### Added

- Focused LU coverage for partial pivoting and singular square matrices.
- Focused QR coverage for tall full-rank matrices and dependent columns.

### Changed

- Strengthened typed machine coverage for stack-expanding LU and QR commands in
  canonical-kernel edge cases.

## [0.3.20] - 2026-05-18

### Added

- Public `Matrix.luDecomposition()` with explicit permutation, lower, and
  upper factors.
- Public `Matrix.qrDecomposition()` with thin `Q` and `R` outputs.
- `LuDecompositionCommand` and `QrDecompositionCommand` on the public typed
  command surface.
- Focused LU and QR contract coverage for core, CLI, app widgets, and Windows
  integration workflows.

### Changed

- Extended the Stage 4 command vocabulary to support stack-expanding
  multi-result decompositions without changing the existing `RPN` model.

### Fixed

- Kept decomposition behavior in the public core and stack machine instead of
  introducing consumer-local factorization logic.

## [0.3.10] - 2026-05-18

### Added

- Public `Matrix.determinant()` support for square matrices with scalar-matrix
  output.
- `DeterminantCommand` on the public typed command surface.
- Focused determinant contract coverage for `Matrix`, `CalculatrixMachine`,
  CLI command routing, app widgets, and Windows integration workflows.

### Changed

- Expanded the first Stage 4 release slice without changing existing parser,
  session, or `RPN` contracts.

### Fixed

- Kept determinant available to app and CLI consumers through the same public
  command barrel instead of consumer-local implementations.

## [0.3.1] - 2026-05-17

### Changed

- `CalculatrixSession` now treats calculator-style `Infix` square root as an
  immediate action over the committed value, a bare operand draft, or the
  trailing operand of a pending binary expression.
- `CalculatrixSession` now supports Casio-style `Infix` percent semantics,
  including `x%y = x*y/100`, bare-operand percent on evaluation, and pending
  additive/multiplicative contexts, while keeping public parser and `RPN`
  semantics unchanged.

### Fixed

- Corrected the interactive `Infix` calculator contract so `√` and `%` no
  longer collapse every percent use case to `x/100`.
- Kept public direct-evaluation behavior stable while moving consumer-specific
  interaction translation into the session layer.

## [0.3.0] - 2026-05-17

### Added

- `CalculatrixMachine` as the canonical public stack-machine runtime.
- Typed public commands, typed public macros, and typed public programs.
- Public structural command coverage for delete, duplicate, and move row/column.
- Public macro coverage for zeros-like, ones-like, append-zero-row,
  append-zero-column, and identity creation.

### Changed

- `Calculatrix.compileInfix` now defines the infix-over-stack contract for the
  public API surface.
- `CalculatrixSession` remains above the same canonical kernel instead of
  introducing a second semantic center.

### Fixed

- Aligned app and CLI consumers on the same public command and macro surface.
- Closed the remaining late-v0.2 documentation drift around the public API.

## [0.2.110] - 2026-05-16

### Added

- Square-matrix root on the public `Matrix` API.
- `CalculatrixSession` as a public core API for notation drafts, committed
  value `X`, matrix memory, and stack/state mutations.
- Core TDD coverage for scalar-only division, matrix square root, and
  session-based shared-value workflows.

### Changed

- `RpnEngine` square root now delegates to `Matrix` semantics, and division
  remains restricted to scalar `1x1` denominators.
- Shared calculator memory semantics are now matrix-first in the core.

### Fixed

- Removed scalar-only behavior for square root when valid matrix semantics
  exist.
- Moved interactive calculator behavior out of the Flutter controller and into
  the core package contract.

## [0.2.90] - 2026-05-16

First SemVer-aligned package release recorded under the accepted repository
versioning policy.

### Added

- Matrix-first arithmetic model covering scalars, vectors, square matrices, and
  non-square matrices.
- Shared infix evaluation and `RPN` execution over the same matrix semantics.
- Advanced `RPN` stack utilities including `pick`, `roll`, and `rot`.
- Numeric comparison helpers and deterministic tolerance policy.

### Changed

- Hardened public error taxonomy for matrix shape, domain, stack underflow, and
  stack range failures.
- Established `calculatrix` as the authoritative release version for
  coordinated repository releases.

### Fixed

- Contract coverage for vectors, non-square matrices, parser failures, and
  cross-notation equivalence.

## [0.0.1]

Initial core package release.

### Added

- Immutable `Matrix` type with shape validation.
- Matrix operations: addition, subtraction, multiplication, scale, transpose.
- Typed error model for matrix, RPN stack, and expression syntax/domain errors.
- `RpnEngine` with stack primitives and operators:
  `+`, `-`, `*`, `/`, `sqrt`, `%`, `dup`, `drop`, `swap`, `over`.
- `Calculatrix` facade with `evaluateInfix` and `evaluateRpn`.
- Test suite for matrix operations, RPN behavior, and cross-notation evaluation.

