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
  cross-notation equivalence.# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

## 0.0.1

Initial core package release.

### Added

- Immutable `Matrix` type with shape validation.
- Matrix operations: addition, subtraction, multiplication, scale, transpose.
- Typed error model for matrix, RPN stack, and expression syntax/domain errors.
- `RpnEngine` with stack primitives and operators:
	`+`, `-`, `*`, `/`, `sqrt`, `%`, `dup`, `drop`, `swap`, `over`.
- `Calculatrix` facade with `evaluateInfix` and `evaluateRpn`.
- Test suite for matrix operations, RPN behavior, and cross-notation evaluation.

