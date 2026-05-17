# Changelog
All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

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
