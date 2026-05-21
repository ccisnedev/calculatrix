# Changelog
All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

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
