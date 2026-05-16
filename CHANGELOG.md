# Changelog
All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

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
*** Add File: c:\Users\44358590\Code\matarama-dev\calculatrix\code\core\CHANGELOG.md
# Changelog
All notable changes to package calculatrix will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the package adheres to [Semantic Versioning](https://semver.org/).

## [2.9.0] - 2026-05-16

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
