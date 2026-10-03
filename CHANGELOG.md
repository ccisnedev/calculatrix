# Changelog
All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### CLI

- Rebuilt the `calculatrix`/`cx` CLI on `modular_cli_sdk` (runbook stage S2):
	a banner on a bare `cx`, `cx eval rpn`, `cx eval infix`, and the `cx
	<program>` RPN shortcut, following the grammar in
	`docs/spec/calculatrix_cli.md` section 4. Replaces the previous
	`infix`/`rpn`/`command`/`macro` mode CLI.
- Added `scripts/dev-install.ps1` to build the CLI from source and install it
	locally, with a `cx.cmd` alias shim.
- The executable is named `cx` (`bin/cx.dart`, compiled to `cx.exe`). There is
	no `calculatrix` executable and no alias of any kind. A `.cmd`/`.bat` shim
	runs through cmd.exe, which consumes `^` as its own escape character while
	parsing the command line, before the shim body ever runs, so
	`cx eval infix '2^0.5'` silently lost the caret through the earlier
	`cx.cmd` shim. `scripts/dev-install.ps1` now installs `cx.exe` only and
	removes a legacy `cx.cmd` or `calculatrix.exe` from a previous install.
	Added `scripts/check-caret.ps1` as a regression check (issue #22).
- Wired `cx version`, `cx doctor`, `cx upgrade` and `cx uninstall` from
	`modular_cli_sdk`'s standard plugins (runbook stage S3, D26, D31, D33,
	D40): `VersionPlugin`, `DoctorPlugin`, and `InstallationPlugin` configured
	with the `cli-v` tag prefix, per-platform asset names, and no alias.
	Contributed a small `path` doctor check of our own, since
	`InstallationPlugin` no longer provides one as of `modular_cli_sdk` 0.8.0.
- Added `.github/workflows/cli-release.yml` (check-version, create-release,
	build matrix, publish-release), modeled on `ccisnedev/inquiry`'s release
	workflow: on a push to `main` that changes `code/cli/pubspec.yaml`, it
	tags and releases `cli-vX.Y.Z`, building `cx.exe`/`cx` for Windows and
	Linux. Guarded `android-release.yml` and `windows-release.yml` so a
	`cli-v*` release no longer also triggers an Android or Windows app build.
- Added `scripts/build.ps1`/`build.sh` (compile and package a release
	archive) and `scripts/install.ps1`/`install.sh` (download and install the
	newest `cli-v*` release, with no alias, without ever calling
	`releases/latest`), served from `https://calculatrix.ccisne.dev` via
	`pages-release.yml`.
- Amended ADR 0002 section 8 for the `cli-v` tag prefix, since this
	repository's app releases already use `vX.Y.Z`.
- Branded the bare `cx` banner (issue #26): a glow-colored dot (`#2EF2C3`)
	inside square box-drawing brackets that span the whole matrix (9 columns by 4 rows), the tagline, a `Commands:`
	block, and a `Quickstart:` line. Color is used only on a real terminal
	that supports ANSI escapes, and is off when `NO_COLOR` is set. The dot
	uses 24-bit color when `COLORTERM` is `truecolor` or `24bit`, and bright
	cyan (ANSI 96) otherwise. The command list is read
	from the CLI's own route catalog at call time, so it lists only routes
	that are actually registered and needs no change once issue #25 adds
	`doctor`, `upgrade`, `uninstall` and `version`.

### RPN

- `ENTER` with an empty draft now duplicates the top of the stack, as `ENTER`
	does on the HP 50g with an empty command line. It does nothing on an empty
	stack.
- `⌫` with no draft and an empty stack no longer shows `Error`. The `DROP`
	command itself still fails on an empty stack.
- Matrix literals accept rows with no whitespace between them,
	`[[0 -1][1 0]]`, the logo's form and the HP 50g's own notation, in RPN
	and infix. It means the same as `[[0 -1] [1 0]]` (issue #29). Shipped in
	`cx` 0.8.1.
- `cx doctor`, `cx upgrade` and `cx uninstall` exit as soon as they print
	their result, instead of about 15 s later: `modular_cli_sdk` 0.8.3 closes
	the HTTP client its release lookup opens (modular_cli_sdk issue #44).
	Shipped in `cx` 0.8.2.
- Moved to `modular_cli_sdk` 0.9.0. Every `Usage:` line now names the
	program (`Usage: cx <command> [options]`, `Usage: cx eval rpn [options]
	[<program>]`; before, the name was empty). `cx --help` and `cx -h` print
	the same catalog as `cx help`, with the same `--json`, and `cx --version`
	answers like `cx version` (before, it was an unknown option, exit 7).
	Nothing else changes: the rows, their examples and the banner on a bare
	`cx` are the same. Shipped in `cx` 0.8.3.
- `eval rpn` and the `cx <program>` shortcut print the whole stack the
	program leaves, highest level first and level 1 at the bottom (`2: 5`,
	`1: 7`); before, a program that left more than one value failed with
	`syntax-error`. A program that leaves the stack empty (`1 drop`) prints an
	empty line and exits 0 (runbook D47).
- Breaking: the JSON of `eval rpn` and `eval infix` names each level,
	`{"stack": [{"level": 1, "value": 3}]}`, in the order the text prints;
	before, it was `{"stack": [3]}` (runbook D47).
- Text output shows each number through the display formatter of core, the
	one the app uses: at most 12 significant digits, trailing zeros removed.
	`[[1 2] [3 4]] -1 ^` prints `[[-2 1] [1.5 -0.5]]` instead of
	`-1.9999999999999996`. `--json` keeps the full double (runbook D45).
- A word whose result overflows (`1e300 1e300 *`) is the error
	`non-finite`, exit 65, on that word's token and position, as spec section
	6 requires; before, `cx` printed `1: Infinity` (or `NaN`) and exited 0,
	and `--json` crashed. The app shows the same error for an overflowing
	infix expression. Shipped in `cx` 0.9.0.
- Exact numbers (runbook-trust.md, step T2). A literal is the exact
	rational it spells, so `0.1 0.2 +` prints `0.3`, `1 3 /` prints `1/3`
	and `3 40 ^` prints all 20 digits (D50). `+ - * /`, `negate`, `percent`,
	integer powers and the stack and structure words keep exactness; any
	other word converts to approximate (D53). An exact value prints in full:
	an integer, a decimal with at most 20 places, or a fraction (D54).
- An approximate value carries the mark `~` once, in front (`~0.333333333333`,
	`~[[-2 1] [1.5 -0.5]]`), and `~` before a literal makes it approximate,
	so every text output can be typed back (D56). Approximation is
	contagious: one approximate operand makes the result approximate (D51).
	`approx` (alias `num`) and `exact` convert between the two (D52).
- Breaking: each JSON stack level gains `"exact"`, and exact numbers are
	strings (`{"level": 1, "exact": true, "value": "1/3"}`), because a JSON
	number cannot hold them; approximate numbers stay JSON numbers with the
	full double (D54). The `result` of each example in `cx commands show
	--json` takes the same shape.
- A result with more digits than the limit is the new error
	`limit-exceeded`, exit 65, raised before computing, with `limit` and
	`estimated` in `details` and the program to run for an approximate
	result: `cx '3 1000000 approx ^'`. `--max-digits <n>` on `eval rpn`,
	`eval infix` and the shortcut sets the limit; the default is 10000 (D55).
	Shipped in `cx` 0.10.0.
- Exact linear algebra (runbook-trust.md, step T3). `inverse`,
	`determinant`, `rref`, `rank`, `trace`, `adjugate`, `cofactors`, `lu`,
	`dot`, `cross` and negative matrix powers are exact on exact values:
	`[[1 2] [3 4]] inverse` prints `[[-2 1] [1.5 -0.5]]` without the mark,
	and the inverse of a Hilbert matrix is its exact integer matrix (D53).
	Before computing, the elimination words estimate the size of the result
	with the Hadamard bound and raise `limit-exceeded` over the limit, with
	the program to run for an approximate result (D55). `lu` picks the same
	pivots as the approximate decomposition, so P is the same. Shipped in
	`cx` 0.11.0.
- Exact roots and eigenvalues (runbook-trust.md, step T4). `sqrt`,
	fractional powers, `frobenius-norm`, `eigenvalues`, `exp` and `ln` are
	exact on exact values when the result is rational: `9 4 / sqrt` prints
	`1.5`, `-4 sqrt` prints `[[0 -2] [2 0]]`, `[[5 4] [4 5]] sqrt` prints
	`[[2 1] [1 2]]` and `[[2 1] [1 2]] eigenvalues` prints `[[3] [1]]`, all
	without the mark; `2 sqrt` stays approximate, with the mark (D53).
	`eigenvalues` estimates the size of its characteristic polynomial first
	and raises `limit-exceeded` over the limit (D55). Complex eigenvalues are
	deferred: `[[0 -1] [1 0]] eigenvalues` is still an error. Shipped in
	`cx` 0.12.0.
- Fraction literals (runbook-trust.md, step T5, D59). In RPN and inside a
	matrix literal, `p/q` with integer parts is one exact literal: `1/3`,
	`-5/3`, `[[1/3 2]]`. Every exact output can now be typed back, `1/3`
	included. `~1/3` is approximate, `1/0` is `non-finite`, and `1.5/2`,
	`1/2/3` or `1/-2` are not literals (`unknown-word` in RPN,
	`syntax-error` inside a matrix literal). Infix keeps `/` as division.
	Shipped in `cx` 0.13.0.
- Release fix, `cx` 0.13.1. The Windows build of 0.10.0 to 0.13.0 stopped
	at the Giac differential test, so those releases were never published:
	on the Windows runner `wsl` starts with no Ubuntu distribution and exits
	at once, and the test failed writing to it instead of skipping. It now
	skips, as it does when Giac is missing. No change to `cx` itself since
	0.13.0.
- Complex results (runbook-trust.md, step T6, D60). A real matrix with a
	complex pair of eigenvalues makes `eigenvalues` and `diagonalize` raise
	the new error id `complex-result`, exit 65, instead of the generic
	`calculatrix-error`: `[[0 -1] [1 0]] eigenvalues` has no column of
	complex values to print yet (issue #64). Shipped in `cx` 0.14.0.
- Discoverability, after the round r2 of the benchmark (issue #66), `cx`
	0.15.0. `cx commands show` prints each example with the exactness its
	program gives (`2 3 + -> 5`, not `~5`). `exact` and `approx` explain
	that values are exact unless marked `~` and the literal forms, and
	`cx commands search literal`, `fraction` or `decimal` finds them. `cx
	--help` has a paragraph on values and on `--`. A value that starts with
	`-` and looks like an expression, such as `cx eval infix '-sqrt(-1)'`,
	is still `invalid-short-option`, exit 7, but the message now gives the
	command with `--` in place. In infix a unary minus negates any operand:
	`-(2+3)` is -5 (it was a syntax error), and `-2^2` is -4, as in Giac
	(it was 4).
- Agent usability (issue #80, runbook `docs/runbook-agent-usability.md`),
	`cx` 0.16.0. The `cx <program>` shortcut accepts `--json` and
	`--quiet`/`-q` before or after the program, as `cx eval rpn` does, and
	rejects `--file` and `--stdin` naming the full spelling (#68, spec G4).
	The banner and the install scripts show one overview text: RPN, infix,
	matrices, exact and approximate values, and where to look for more
	(#72). A call of an RPN word in infix, `inverse([[1 2] [3 4]])`, names
	the program to type, and a `--` inside a program names the form that
	puts it before the quoted program; `commands show power` says when
	`power` is exact (#73). New names `pi` (also `π`), `e` and `i`:
	`pi` and `e` are approximate, `i` is the exact matrix `[[0 -1] [1 0]]`,
	in RPN and in infix (`e^(i*pi)`, `3+4*i`), listed by `cx commands list`
	in the new category `constants` (#70).

### Benchmark

- The agent benchmark of `docs/mission.md` moves into `benchmark/`: the
	basic and trap task sets, their answer keys verified with Giac,
	`run-trial.ps1` and `summarize.ps1`. `benchmark/trap-set.json` writes
	each trap as a `cx` program with its expected output, and
	`code/cli/test/trap_set_test.dart` runs it in RPN and infix with the CLI
	tests, which the CLI release workflow runs before every release: the
	trap set passes 8 of 8 through `cx` (acceptance 2 of #54).

### App

- Exact values in the app (runbook-trust.md, step T5). The display, the
	RPN stack and the memory status go through the core formatter, the one
	`cx` uses: `1 ÷ 3` shows `1/3`, `× 3` gives back `1`, `0.1 + 0.2` shows
	`0.3`, and `2 √` shows `~1.41421356237` (D54). Screen readers read the
	mark as "approximately". Infix, RPN, memory, ± and the matrix editor keep
	exact values instead of turning every literal approximate; the editor
	accepts `1/3` and `~0.1` in a cell, and its zeros, identity and `i`
	fills are exact.

## [0.7.1] - 2026-05-30

First publication-preparation release after Stage 7, focused on hardening public
distribution surfaces for the web and Windows delivery paths.

### App

- Finalized the public Windows desktop identity as `Calculatrix` with publisher
	metadata aligned to `ccisne.dev`.
- Added automated Windows release packaging based on the Flutter Windows bundle
	plus an Inno Setup installer path for release assets.

### Web

- Established GitHub Pages as the first public publication target for the app.
- Removed redundant local `/info/` and `/info/privacy/` pages after moving
	canonical legal content to the publisher legal site.

### Docs

- Added a publication checklist grounded in verified deployment evidence.
- Recorded the installer-format decision for the Windows Package Manager path.
- Added a root MIT license surface for release-facing distribution metadata.

## [0.7.0] - 2026-05-21

Closes Stage 7, Honest RPN Shell, as a coordinated repository release.

### Core

- Synchronized `calculatrix` to `0.7.0` for the coordinated release.
- No new public core API or semantic changes beyond the already-shipped `0.6.x`
	matrix, stack, and session contracts.

### App

- The Flutter shell now ships as one persistent `RPN` surface without the old
	visible `Infix / RPN / Matrix` mode switch.
- `INFIX` and `MATRIX` are explicit editors over a pre-stack `Draft` surface,
	while committed `X0`, `X1`, ... remain visually truthful.
- The keypad now follows the fixed Stage 7 layout and the shell exposes the
	fixed module taxonomy `BASIC`, `STACK`, `MATH`, `MATRIX`, `VECTOR`, `FACT`,
	`PROP`, `EDIT`, `BUILD`, `MEM`.
- `DELETE` is contextual (`draft edit` vs `DROP`) and `MRC` now follows the
	pocket-calculator recall/clear interaction.

### CLI

- Synchronized `calculatrix_cli` to `0.7.0` for the coordinated release.
- CLI command surfaces remain semantically aligned with the unchanged shared
	core contracts.

### Docs

- Refreshed Stage 7 roadmap, architecture notes, spec wording, and public
	README surfaces to describe the implemented shell model.

### QA

- Full coordinated validation green before release closure:
	- core: `dart test` -> 429 passing tests
	- CLI: `dart test` -> 12 passing tests
	- app: `flutter analyze` clean
	- app widget/unit: 157 passing tests, 3 skipped
	- app Windows integration: 19 passing tests

## [0.4.50] - 2026-05-18

Adds formal definitional operations: minor, cofactor matrix, and adjugate
(classical adjoint). These follow textbook definitions and enable step-by-step
reasoning such as: inverse = adjugate / determinant.

### Core

- Added `Matrix.minor(row, column)` returning the (n-1)×(n-1) submatrix.
- Added `Matrix.cofactor(row, column)` returning (-1)^(i+j) * det(minor).
- Added `Matrix.cofactorMatrix()` returning the full NxN cofactor matrix.
- Added `Matrix.adjugate()` returning the transpose of the cofactor matrix.
- Added `CofactorMatrixCommand` and `AdjugateCommand` to the typed command surface.

### App

- Added `COF` and `ADJ` to the `RPN` `FACT` deck.
- Added new `PROP` deck grouping property queries (DET, RANK, TR, NORM, etc.).

### CLI

- Added `cof` / `cofactor-matrix` and `adj` / `adjugate` to `command` mode.

### QA

- TDD coverage for minor, cofactor, cofactorMatrix, adjugate on 2x2/3x3.
- Verified definitional identity: A·adj(A) = det(A)·I.
- Full regression green: core 174, CLI 12, widget 130, integration 38.

## [0.4.40] - 2026-05-18

Adds trace, Frobenius norm, and numerical rank as lightweight matrix
properties on the public API.

### Core

- Added `Matrix.trace()` returning the sum of diagonal entries (scalar matrix).
- Added `Matrix.frobeniusNorm()` returning the Frobenius norm (scalar matrix).
- Added `Matrix.rank()` returning the numerical rank via row reduction (scalar matrix).
- Added `TraceCommand`, `NormCommand`, and `RankCommand` to the public typed command surface.

### App

- Reorganized `FACT` deck: `LU`, `QR`, `EIG`, `DIAG`, `TR`, `NORM`, `RANK`, `MAT`.

### CLI

- Added `tr` / `trace`, `norm`, `rank` to `command` mode.

### QA

- TDD coverage for trace, norm, rank on square, non-square, rank-deficient matrices.
- Full regression green: core 166, CLI 12, widget 130, integration 38.

## [0.4.30] - 2026-05-18

Adds eigenvector computation and matrix diagonalization as public APIs,
completing the eigendecomposition workflow.

### Core

- Added `Matrix.diagonalization()` returning `Diagonalization(p, d)` where
  P holds eigenvector columns and D is the diagonal eigenvalue matrix.
- Eigenvectors computed via null-space extraction (Gaussian elimination with
  partial pivoting on A - λI).
- Added `DiagonalizationCommand` to the public typed command surface.

### App

- Added `DIAG` to the `RPN` `FACT` deck (replaced `ZEROS`).

### CLI

- Added `diag` / `diagonalization` to `command` mode.

### QA

- Added TDD coverage for 2x2 diagonal, 2x2 non-diagonal, 3x3 diagonal,
  3x3 symmetric eigenvectors; complex-spectrum and non-square rejection.
- Full regression green: core 158, CLI 12, widget 130, integration 38.

### Docs

- Added v0.4.30 roadmap slice with TDD execution order.

## [0.4.20] - 2026-05-18

Generalizes eigenvalue computation from 2x2-only to arbitrary NxN square
matrices via Hessenberg reduction and implicit QR iteration with Wilkinson
shift.

### Core

- Generalized `Matrix.eigenvalues()` to support arbitrary square matrices.
- Added Hessenberg reduction (Householder reflections) as preprocessing step.
- Added implicit QR iteration with Wilkinson shift and Givens rotations.
- Preserved 1x1 identity and 2x2 characteristic polynomial fast paths.
- Added complex-spectrum detection for NxN matrices via `MatrixDomainError`.
- Removed `UnsupportedCalculatrixOperationError` size restriction.

### QA

- Added TDD coverage for 3x3 diagonal, 3x3 symmetric, 3x3 non-symmetric,
  4x4 diagonal, 4x4 symmetric, repeated eigenvalues, and NxN complex spectrum.
- Full regression green across core (151), CLI (12), app widget (130), and
  Windows integration (38) suites.

### Docs

- Added v0.4.20 roadmap slice with TDD execution order.

## [0.4.10] - 2026-05-18

First post-Stage-4 slice extending the canonical matrix stack kernel with
small-matrix real eigenvalue workflows.

### Core

- Added public `Matrix.eigenvalues()` support for `1x1` matrices and `2x2`
	real-spectrum matrices.
- Added `EigenvaluesCommand` to the public typed command surface.
- Added typed failure coverage for non-square, complex-spectrum, and out-of-slice
	eigenvalue requests.

### App

- Added `EIG` to the `RPN` `FACT` deck so committed top-of-stack matrices can
	route through the shared eigenvalue command path.

### CLI

- Added `eig` / `eigenvalues` to `command` mode over the same public core
	vocabulary.

### QA

- Added focused matrix, machine, CLI, widget, and Windows integration coverage
	for the new eigenvalue workflow.

### Docs

- Added the first `0.4.x` roadmap slice and refreshed release-facing version
	references to `0.4.10`.

## [0.4.0] - 2026-05-18

Stable release closing Stage 4 around advanced linear algebra on the canonical
matrix stack kernel.

### Core

- Stage 4 now ships determinant plus public LU and QR decompositions on the
	shared matrix-first kernel.
- Locked edge-case coverage for pivots, singular LU inputs, tall QR inputs,
	and dependent QR columns before the stable stage cut.

### App

- The Flutter shell now exposes determinant, LU, and QR through `RPN`, and the
	Matrix workstation can dispatch factorization workflows directly back onto the
	canonical stack.
- Stage 4 workflows are covered by widget and Windows integration tests,
	including a full Matrix -> macro -> QR -> Infix round trip.

### CLI

- `command` mode exposes determinant, LU, and QR over the same public core
	vocabulary and prints multi-result stack outputs as `X0`, `X1`, ... when
	required.

### Docs

- Closed the Stage 4 roadmap and refreshed release-facing documentation for the
	stable release.

## [0.3.31] - 2026-05-18

Patch release closing the remaining Stage 4 end-to-end workflow coverage gap.

### QA

- Added a focused Windows integration workflow that combines Matrix creation,
	`RPN` macro expansion, QR factorization, and a return to `Infix`.
- Locked the visible `Infix` empty-expression chrome after returning from the
	advanced `RPN` workflow so the shared current value contract stays explicit.

### Docs

- Marked the remaining Stage 4 end-to-end workflow checklist item as complete.
- Updated coordinated version references to the `0.3.31` patch line.

## [0.3.30] - 2026-05-18

Stage 4 shell-polish slice extending advanced factorization workflows inside the
Matrix workstation.

### App

- Added a Matrix-mode `FACT` deck for `RPN`-backed workstation sessions so LU
	and QR are available without leaving the editor manually.
- Allowed valid Matrix drafts to submit directly into the canonical stack,
	execute LU or QR, and return to the `RPN` shell with the resulting factors
	visible on the stack.

### Docs

- Marked the Stage 4 advanced-workflow polish slice as complete in the roadmap.
- Updated release-facing version references to the coordinated `0.3.30` line.

### QA

- Added focused widget coverage for Matrix-mode LU and QR dispatch into the
	stack.
- Added focused Windows integration coverage for the Matrix-to-LU workflow.

## [0.3.21] - 2026-05-18

Patch release hardening LU and QR coverage on top of the `0.3.20`
factorization slice.

### Core

- Added focused LU coverage for zero-leading pivots and singular square
	matrices.
- Added focused QR coverage for tall full-rank matrices and dependent columns.

### QA

- Extended typed machine tests so stack-expanding LU and QR commands keep their
	reconstruction and stack-order contracts in edge cases.
- Revalidated the focused linear-algebra core suite after hardening coverage.

## [0.3.20] - 2026-05-18

Second Stage 4 slice adding LU and QR decomposition workflows on top of the
canonical matrix stack kernel.

### Core

- Added public LU decomposition with partial pivoting, returning explicit
	permutation, lower, and upper factors.
- Added public QR decomposition with thin `Q` and `R` factors for matrices
	whose row count is at least their column count.
- Added typed LU and QR commands that expand decomposition results onto the
	canonical stack instead of hiding them behind app-local behavior.

### App

- Added an `RPN` factorization deck exposing `LU` and `QR` alongside advanced
	matrix commands while preserving the fixed keypad layout.
- Kept decomposition workflows stack-native so users can inspect factors via
	the existing `RPN` stack display.

### CLI

- Added `lu` and `qr` to `command` mode.
- Updated `command` output to print `X0`, `X1`, ... when a workflow leaves
	multiple matrix results on the stack.

### Docs

- Added the `v0.3.20` roadmap slice for LU and QR as the next Stage 4 delivery.
- Updated repository and package version references for the coordinated `0.3.20`
	release.

### QA

- Added focused LU and QR coverage in core matrix and machine tests, CLI
	command tests, app widget tests, and the Windows integration suite.

## [0.3.10] - 2026-05-18

First Stage 4 slice adding determinant workflows on top of the canonical
matrix stack kernel.

### Core

- Added public `Matrix.determinant()` support using square-matrix elimination
	with scalar-matrix output so determinant stays inside the matrix-first domain.
- Added `DeterminantCommand` to the typed command surface used by the stack
	machine and shared session consumers.

### App

- Added `DET` to the shared matrix command decks so determinant is available in
	`RPN` workflows and directly inside the Matrix editor without breaking the
	fixed 6x4 keypad layout.

### CLI

- Added determinant routing to `command` mode through `det` / `determinant`.

### Docs

- Added the `v0.3.10` roadmap slice for determinant as the first Stage 4
	delivery.
- Updated repository and package version references for the coordinated `0.3.10`
	release.

### QA

- Added focused determinant coverage in core matrix and machine tests, CLI
	command tests, app widget tests, and the Windows integration suite.

## [0.3.1] - 2026-05-17

Patch release correcting calculator-style `Infix` interaction semantics on top
of the `v0.3.0` foundation.

### Core

- Added immediate `Infix` session handling for square root against the current
	committed value, a bare operand draft, or the trailing operand of a pending
	binary expression.
- Added Casio-style percent handling in `Infix`, including `x%y = x*y/100`,
	bare-operand percent evaluation on `=`, and pending additive/multiplicative
	percent translation.
- Preserved public parser, direct evaluation, and `RPN` semantics while moving
	the calculator-specific interaction behavior into `CalculatrixSession`.

### App

- Updated the `Infix` button workflow so `√` applies immediately and `%`
	supports delayed Casio-style evaluation instead of collapsing every case to
	`x/100` at keypress time.
- Replaced the paged keypad with one shared calculator keyboard whose bottom
	four rows remain fixed and whose top two rows switch through mode-specific
	deck selectors.
- Kept the shared shell wired through the same core session API.

### Docs

- Added the `v0.3.1` roadmap checklist for the `Infix` calculator interaction
	patch line and extended it to cover the unified keypad redesign.
- Updated release-facing version references for the coordinated `0.3.1` cut.

### QA

- Added focused core session and app widget coverage for immediate `Infix`
	unary behavior and Casio-style percent flows.
- Updated the app integration suite to use deck selectors and `ENTER` against
	the unified keypad contract.
- Revalidated public core evaluation coverage to confirm no regression in
	parser or `RPN` contracts.

## [0.3.0] - 2026-05-17

Canonical matrix stack machine foundation release.

### Core

- Promoted `package:calculatrix` to the public semantic center of the product.
- Added a public matrix stack machine with typed commands, typed macros, and
	typed programs.
- Kept infix as a frontend over the same kernel via public compilation and
	evaluation APIs.
- Exposed structural matrix commands and public workflow macros for zeros,
	ones, identity, append-row, and append-column workflows.

### App

- Finalized the three-mode shell: `Infix`, `RPN`, and `Matrix`.
- Replaced the old modal editing mental model with an embedded Matrix
	workstation surface.
- Added bounded structural row/column editing, compact structural affordances,
	mode-accurate shell copy, and direct RPN matrix workflow parity.

### CLI

- Added public `command` and `macro` workflows on top of the same core API.
- Added parameterized structural command routing for delete, duplicate, and
	move row/column operations.

### Docs

- Refreshed roadmap, architecture, and package README content around the
	canonical stack-machine model.
- Updated public usage docs for core, app, and CLI consumers.

## [0.2.120] - 2026-05-17

App-only matrix editor UX refinement release for late v0.2.

### App

- Replaced free row/column matrix sizing with direct `2x2`, `3x3`, and `4x4`
	selection for the educational editor workflow.
- Preserved overlapping matrix values while changing order within a draft and
	added `Zeros`, `Identity`, and `Clear` quick actions.
- Added literal preview, clearer bracketed grid presentation, and explicit
	row/column validation errors for incomplete visible cells.

### Docs

- Added a matrix editor UX specification with verified references, wireframes,
	and implementation checklist.
- Added the matrix editor TDD plan and updated the roadmap with v0.2.120
	execution progress.

### QA

- Completed green `dart analyze` and `dart test` runs for `code/core` and
	`code/cli`.
- Completed green `flutter analyze`, `flutter test`, and full Android
	integration coverage for `code/app`, using `flutter drive` for the complete
	emulator suite.

## [0.2.110] - 2026-05-16

Core-only matrix semantics release for late v0.2.

### Core

- Added square-matrix root and shared session/state semantics to the shared
	computation package.
- Added `CalculatrixSession` so interactive calculator state, matrix memory,
	and committed-value transitions live in `package:calculatrix`.
- Removed scalar-only restrictions from shared square root semantics when valid
	matrix behavior exists, while keeping public division restricted to scalar
	`1x1` denominators until the determinant/inverse stage.

### App

- Migrated `CalculatorController` to a presentation adapter over the new core
	session API.
- Enabled matrix memory workflows in the shared calculator shell.

### CLI

- Kept the CLI on public core APIs only and revalidated its contract over the
	updated package surface.

### Docs

- Added and completed the v0.2.110 roadmap checklist and TDD execution record.
- Refreshed repository and package README content to reflect the current
	shared-core architecture.

### QA

- Completed green regression runs for `code/core`, `code/app`, and `code/cli`
	automated test suites.

## [0.2.90] - 2026-05-16

First coordinated late-v0.2 release recorded under the accepted repository
versioning policy.

### Core

- Established `calculatrix` as the authoritative semantic version for the
	product release.
- Delivered the shared matrix-first computation engine with infix evaluation,
	`RPN` execution, advanced stack utilities, numeric tolerance policy, and
	hardened error taxonomy.

### App

- Added the multi-page calculator shell with explicit `Infix` and `RPN` modes.
- Added generic `NxM` matrix entry and matrix-aware display rendering.
- Added stack visualization, `ENTER` semantics, and draft-aware `RPN`
	interactions.
- Removed the legacy app-local tokenizer/parser/evaluator pipeline so the app
	now depends exclusively on the shared core for evaluation semantics.

### CLI

- Added matrix literal parity with the shared core in both infix and `RPN`
	workflows.
- Aligned CLI output with the shared compact matrix formatting contract.
- Added explicit non-zero exit codes for usage and evaluation failures.

### Docs

- Added ADR 0002 defining the repository versioning and changelog policy.
- Added a release checklist to standardize version sync, changelog updates,
	QA gates, and automation targets.
- Updated the roadmap and architecture documents to reflect the late-v0.2 freeze
	and Stage 3 readiness.

### QA

- Completed full regression validation across core, app, and CLI test suites.
- Added app integration coverage for matrix and `RPN` flows, with execution on
	supported target devices remaining environment-dependent.
