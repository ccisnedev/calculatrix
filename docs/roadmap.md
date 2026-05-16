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

> **Testing policy**:
> 1. `code/core` must keep TDD and full unit/contract coverage for public semantics and new logic.
> 2. `code/app` controller/view-model/editor state should target full unit coverage; widget tests protect only critical UI invariants.
> 3. `code/app/integration_test` covers user-visible end-to-end flows for released features.
> 4. `code/cli` must have automated unit + smoke/integration coverage for argument parsing, output, and representative commands.

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

Late v2.x focuses on consumer UX expansion over the already-stable core
semantics. The default experience remains the current scalar/`1x1`
calculator shell, while app and CLI progressively expose arbitrary matrices,
explicit notation modes, and richer display contracts.

#### v2.1.0 — Advanced RPN Stack Utilities

- [x] Define and document stack semantics for `pick(n)`, `roll(n)`, and `rot`
- [x] Implement `pick(n)` with 1-based indexing from the top of the stack
- [x] Implement `roll(n)` moving the nth stack value to the top
- [x] Implement `rot` as a top-3 stack rotation
- [x] Add typed range/underflow errors for advanced stack utilities
- [x] Add TDD coverage for invariants and edge cases of all advanced stack ops

#### v2.2.0 — Numeric Policy and Determinism

- [x] Define formal tolerance policy for floating-point comparison
- [x] Implement approximate matrix comparison helpers in core
- [x] Add tests for floating-point determinism and tolerance boundaries
- [x] Document numeric comparison policy in README and tests

#### v2.3.0 — Parser and Evaluation Performance Baseline

- [x] Optimize tokenization/evaluation hot paths without changing semantics
- [x] Add TDD coverage for scientific notation and signed numeric edge cases
- [x] Capture baseline benchmark/smoke measurements for supported workloads
- [x] Verify no regressions in core, app, and CLI behaviors

#### v2.4.0 — Hardening and API Freeze Before Stage 3

- [x] Expand contract tests for vectors, non-square matrices, and parser failures
- [x] Harden public error taxonomy for stack range/domain failures
- [x] Review API stability and update docs for app/CLI consumers
- [x] Confirm Stage 3 can build on the current core without breaking changes

#### v2.5.0 — Multi-Page Shell and Layout Geometry

- [x] Add an explicit notation mode switch (`Infix` / `RPN`) in the shared calculator shell
- [x] Preserve the current scalar / `1x1` workflow as the default keypad page
- [x] Introduce horizontally paged keypad layouts (swipe left/right + visible page indicators)
- [x] Make calculator keys square across supported screen sizes
- [x] Target a display/keypad vertical proportion near the golden ratio when screen constraints allow
- [x] Add controller/layout unit coverage plus widget and integration tests for keypad paging, mode visibility, and key geometry invariants

#### v2.6.0 — Generic Matrix Entry

- [x] Add a dedicated `NxM` matrix editor surface with row/column selection
- [x] Validate cell editing and serialize matrices using the core literal contract
- [x] Insert matrices into infix expressions without changing the shared shell model
- [x] Push matrices directly onto the stack in `RPN` mode
- [x] Define copy/paste and confirmation flows for matrix literals across app and CLI
- [x] Add TDD coverage for matrix editor state, cancellation, validation, insertion/push flows, and CLI literal parity

#### v2.7.0 — RPN Mode UX

- [x] Make notation mode persistent and visible in app state
- [x] Add an `RPN`-focused keypad page for stack actions and operand entry
- [x] Add stack visualization (top levels + depth navigation) in the app
- [x] Relabel the primary action key from `=` to `ENTER` in `RPN` mode
- [x] Define `ENTER` as commit of the current draft operand; duplication remains an explicit `dup` action
- [x] Auto-commit any active draft before unary or binary stack operators execute through the core
- [x] Define `C`, `⌫`, `MC`, `MR`, `M+`, and `M-` semantics for draft-aware `RPN` workflows
- [x] Support switching between `Infix` and `RPN` without ambiguous display state
- [x] Add controller, widget, integration, and CLI smoke tests for stack workflows, notation switching, and error presentation

#### v2.8.0 — Matrix Display and Formatting

 [x] Display non-scalar matrix results in the app without collapsing them to `scalarValue`
 [x] Define compact and expanded matrix render policies for small and large screens
 [x] Add overflow, scrolling, and readability rules for matrix output
 [x] Align matrix formatting expectations between Flutter app and CLI
 [x] Add accessibility semantics for matrix structures and stack previews
 [x] Add regression coverage for matrix render, formatting, and cross-consumer parity

#### v2.9.0 — Consumer Cleanup and Freeze Before Stage 3

- [ ] Remove legacy app-side parser/tokenizer/evaluator artifacts no longer used at runtime
- [ ] Generalize controller/view-model state from scalar-only display to scalar-or-matrix display
- [ ] Revisit whether memory remains scalar-only or generalizes to matrices before Stage 3
- [ ] Run full regression QA across multi-page keypad, matrix editor, and `RPN` mode
- [ ] Add or complete automated CLI tests before the Stage 3 handoff
- [ ] Confirm advanced linear algebra work can build on the consumer UX without breaking changes
- [ ] Refresh architecture and integration docs for the late-v2 app/CLI experience

---

## Stage 3 — "Advanced Linear Algebra on Mature Matrix UX" (2.x.x → 3.0.0)

Advanced linear algebra and release-grade matrix workflows on top of the
stabilized multi-page shell, matrix editor, and RPN UX delivered in late v2.x.

### v2.x.x → v3.0.0

- [ ] Determinant
- [ ] Matrix inverse
- [ ] Additional decompositions (priority subset: LU or QR)
- [ ] Promote late-v2 matrix workflows to major-release quality across app and CLI
- [ ] Extend display and interaction polish for complex matrix workflows
- [ ] Extended linear algebra tests (advanced ops)
- [ ] End-to-end workflows combining matrix input, notation switching, and advanced operations

### v3.0.0 — Stable Release

- [ ] Calculator UX with matrix editing, notation switching, and advanced linear algebra over shared core
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
