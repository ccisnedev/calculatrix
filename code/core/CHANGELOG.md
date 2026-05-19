# Changelog
All notable changes to package calculatrix will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the package adheres to [Semantic Versioning](https://semver.org/).

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

