# Roadmap

> **Versioning philosophy**: each stage ends with a stable major release.
> Versions `X.y.z` after each `.0` are improvements and fixes on top of that base.

- **Core package**: `calculatrix`
- **Flutter consumer**: `calculatrix_app`
- **CLI consumer**: `calculatrix_cli`
- **Framework**: Flutter (web-first for QA, then multi-platform)
- **Architecture**: MVVM (Controller extends ChangeNotifier + notifyListeners)
- **QA**: TDD + Widget tests + Integration tests (Semantics-driven)

> **Architecture rule**: calculator logic (algebraic evaluation, matrix operations,
> and RPN stack semantics) lives in `package:calculatrix`. Flutter app and CLI
> are UI/interaction layers over the same core API.

---

## Stage 1 — "Casio Skin, Google Brain" (0.x.x → 1.0.0)

Basic calculator with a Casio HL-820LV-inspired layout and an evaluation engine
with Google Calculator-style operator precedence.

### v0.1.0 — Foundation ✅

- [x] Flutter project scaffolded (`dev.ccisne.calculatrix`)
- [x] MVVM structure: `lib/{models,controllers,views,widgets}`
- [x] Domain model: `Token` (number, operator, paren), `TokenType` enum
- [x] `Tokenizer`: string → List\<Token\>
- [x] Tokenizer unit tests (TDD)
- [x] Basic widget test: app starts without crash

### v0.2.0 — Parser & Evaluator ✅

- [x] `Parser`: List\<Token\> → expression tree (AST)
- [x] Recursive descent with PEMDAS precedence
- [x] `Evaluator`: AST → double
- [x] Operations: `+`, `-`, `×`, `÷`
- [x] Parentheses and unary negation
- [x] Exhaustive unit tests (TDD): normal cases + edge cases
- [x] `CalculatorController` (ChangeNotifier) connects input → evaluation

### v0.3.0 — Casio UI Layout ✅

- [x] 4-column button grid (HL-820LV layout)
- [x] All widgets with `Semantics` labels
- [x] Display: expression on top + result below (live preview)
- [x] Visual differentiation by functional key group
- [x] Widget tests: every button has semantics, display updates
- [x] Integration test: complete flow `3 + 4 = 7`

### v0.4.0 — Casio Features ✅

- [x] Square root (`√`)
- [x] Percentage (`%`)
- [x] Memory (MC, MR, M-, M+)
- [x] Sign toggle (`+/-`)
- [x] Status indicators: M, Error
- [x] Unit tests for each feature
- [x] Integration test: memory workflow

### v0.5.0 — Polish & Hardening ✅

- [x] Error handling (÷0, overflow, negative √)
- [x] Numeric precision with smart rounding (12 significant digits)
- [x] Repeat constant (`=` pressed repeatedly)
- [x] Haptic/visual feedback on buttons
- [x] Integration test: all error flows

### v1.0.0 — Stable Release ✅

- [x] Feature-complete basic calculator with operator precedence
- [x] User documentation
- [x] CI/CD pipeline (GitHub Actions: test + build web)
- [x] Full regression test suite passing

### v1.x.x — Improvements and fixes on top of v1

- Bug fixes
- UX/performance improvements
- Visual refinement

---

## Stage 2 — "Core Engine Package" (1.x.x → 2.0.0)

Implementation of `package:calculatrix` as a pure Dart computation core,
reusable from Flutter, CLI, and other consumers. This stage establishes the
core package as the single source of truth for all calculator semantics.

### v1.x.x → v2.0.0

- [x] Create and stabilize `package:calculatrix` (pure Dart, no Flutter dependency)
- [x] Define matrix-first domain model for all arithmetic (`1x1`, vectors, square, non-square)
- [x] Implement matrix API (`Matrix`) with uniform semantics for all valid shapes
- [x] Implement RPN core (`RpnEngine`) with stack operations over the same matrix domain
- [x] Implement algebraic parser/evaluator (`evaluateInfix`) mapped to the same core rules
- [x] Implement RPN evaluator facade (`evaluateRpn`) equivalent in semantics to algebraic mode
- [x] Define an error taxonomy (invalid dimensions, insufficient stack depth, unsupported operations)
- [x] Publish complete unit/property test suite for matrix, RPN, and cross-notation equivalence
- [x] Migrate Flutter app to consume core math APIs (no duplicated math engine in app)
- [x] Scaffold CLI commands consuming the same core APIs (no duplicated algorithms in CLI)
- [x] Document package integration contracts for Flutter app and CLI

### v2.0.0 — Stable Release

- [x] `package:calculatrix` published as the official computation engine
- [x] Flutter app and CLI both running against shared core semantics
- [x] Updated architecture documentation (shared core: app + CLI + backend)

### v2.x.x — Improvements and fixes on top of v2

- Bug fixes in the math core
- Extended RPN operations and stack utilities
- Performance and numeric precision improvements

---

## Stage 3 — "Advanced Matrix UX and Linear Algebra" (2.x.x → 3.0.0)

User-facing matrix workflows and advanced linear algebra on top of the Stage 2 core.

### v2.x.x → v3.0.0

- [ ] Matrix editor (cell-based input)
- [ ] Matrix stack visualization for RPN mode (top levels + depth navigation)
- [ ] Matrix input/output UX for app and CLI
- [ ] Determinant
- [ ] Matrix inverse
- [ ] Additional decompositions (priority subset: LU or QR)
- [ ] Matrix display and formatting policies (readability + precision)
- [ ] Extended linear algebra tests (advanced ops)

### v3.0.0 — Stable Release

- [ ] Calculator UX with advanced matrix workflows over shared core
- [ ] Advanced matrix operations documentation

### v3.x.x — Improvements and fixes on top of v3

- Eigenvalues / eigenvectors (backlog)
- Factorizations (LU, QR)
- Sparse matrices

---

## General Backlog

- Performance profiling
- Observability (metrics, tracing)
- Visual themes / dark mode
- History export
- PWA / offline mode
