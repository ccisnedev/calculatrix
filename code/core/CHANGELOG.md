# Changelog
All notable changes to package calculatrix will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the package adheres to [Semantic Versioning](https://semver.org/).

## [3.2.0] - 2026-05-18

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

## [3.1.0] - 2026-05-18

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

## [3.0.1] - 2026-05-17

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

## [3.0.0] - 2026-05-17

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
- Closed the remaining late-v2 documentation drift around the public API.

## [2.11.0] - 2026-05-16

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

