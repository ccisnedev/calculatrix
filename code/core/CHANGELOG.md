# Changelog

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

