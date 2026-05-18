# Changelog
All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

## [3.1.0] - 2026-05-18

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

- Added the `v3.1.0` roadmap slice for determinant as the first Stage 4
	delivery.
- Updated repository and package version references for the coordinated `3.1.0`
	release.

### QA

- Added focused determinant coverage in core matrix and machine tests, CLI
	command tests, app widget tests, and the Windows integration suite.

## [3.0.1] - 2026-05-17

Patch release correcting calculator-style `Infix` interaction semantics on top
of the `v3.0.0` foundation.

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

- Added the `v3.0.1` roadmap checklist for the `Infix` calculator interaction
	patch line and extended it to cover the unified keypad redesign.
- Updated release-facing version references for the coordinated `3.0.1` cut.

### QA

- Added focused core session and app widget coverage for immediate `Infix`
	unary behavior and Casio-style percent flows.
- Updated the app integration suite to use deck selectors and `ENTER` against
	the unified keypad contract.
- Revalidated public core evaluation coverage to confirm no regression in
	parser or `RPN` contracts.

## [3.0.0] - 2026-05-17

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

## [2.12.0] - 2026-05-17

App-only matrix editor UX refinement release for late v2.

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
- Added the matrix editor TDD plan and updated the roadmap with v2.12.0
	execution progress.

### QA

- Completed green `dart analyze` and `dart test` runs for `code/core` and
	`code/cli`.
- Completed green `flutter analyze`, `flutter test`, and full Android
	integration coverage for `code/app`, using `flutter drive` for the complete
	emulator suite.

## [2.11.0] - 2026-05-16

Core-only matrix semantics release for late v2.

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

- Added and completed the v2.11.0 roadmap checklist and TDD execution record.
- Refreshed repository and package README content to reflect the current
	shared-core architecture.

### QA

- Completed green regression runs for `code/core`, `code/app`, and `code/cli`
	automated test suites.

## [2.9.0] - 2026-05-16

First coordinated late-v2 release recorded under the accepted repository
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
- Updated the roadmap and architecture documents to reflect the late-v2 freeze
	and Stage 3 readiness.

### QA

- Completed full regression validation across core, app, and CLI test suites.
- Added app integration coverage for matrix and `RPN` flows, with execution on
	supported target devices remaining environment-dependent.
