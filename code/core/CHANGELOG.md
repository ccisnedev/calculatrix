# Changelog
All notable changes to package calculatrix will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the package adheres to [Semantic Versioning](https://semver.org/).

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

