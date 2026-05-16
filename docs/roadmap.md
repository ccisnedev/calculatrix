# Roadmap

> **Versioning philosophy**: each stage ends with a stable major release.
> Versions `X.y.z` after each `.0` are improvements and fixes on top of that base.

- **Package**: `dev.ccisne.calculatrix`
- **Framework**: Flutter (web-first for QA, then multi-platform)
- **Architecture**: MVVM (Controller extends ChangeNotifier + notifyListeners)
- **QA**: TDD + Widget tests + Integration tests (Semantics-driven)

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
reusable from Flutter, CLI, and other consumers.

### v1.x.x → v2.0.0

- [ ] Create and stabilize `package:calculatrix` (pure Dart, no Flutter dependency)
- [ ] Define a matrix model as the domain baseline (scalars as 1×1 matrices)
- [ ] Implement the RPN core (`RpnEngine`) with stack and binary operations
- [ ] Implement the matrix API (`Matrix`) with addition, subtraction, multiplication, and transpose
- [ ] Add algebraic parser/evaluator on top of the same matrix domain
- [ ] Define an error taxonomy (invalid dimensions, insufficient stack depth, unsupported operations)
- [ ] Publish a complete unit test suite for the package
- [ ] Document package integration for Flutter app and CLI

### v2.0.0 — Stable Release

- [ ] `package:calculatrix` published as the official computation engine
- [ ] Flutter app migrated to consume the package instead of embedded logic
- [ ] Updated architecture documentation (shared core: Flutter + CLI)

### v2.x.x — Improvements and fixes on top of v2

- Bug fixes in the math core
- Extended RPN operations and stack utilities
- Performance and numeric precision improvements

---

## Stage 3 — "Matrices" (2.x.x → 3.0.0)

Matrix operations: input, visualization, and basic linear algebra.

### v2.x.x → v3.0.0

- [ ] Data model: Matrix (m×n)
- [ ] Matrix editor (cell-based input)
- [ ] Matrix addition and subtraction
- [ ] Matrix multiplication
- [ ] Scalar multiplication
- [ ] Transpose
- [ ] Determinant
- [ ] Matrix inverse
- [ ] Matrix display in a grid
- [ ] Integration with algebraic and RPN modes
- [ ] Linear algebra tests

### v3.0.0 — Stable Release

- [ ] Calculator with full matrix support
- [ ] Matrix operations documentation

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
