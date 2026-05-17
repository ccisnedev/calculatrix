# Roadmap

> **Versioning philosophy**: each stage ends with a stable major release.
> Versions `X.y.z` after each `.0` are improvements and fixes on top of that base.

- **Core package**: `calculatrix`
- **Flutter consumer**: `calculatrix_app`
- **CLI consumer**: `calculatrix_cli`
- **Framework**: Flutter (multi-platform, with Android as the canonical `integration_test` target)
- **Architecture**: MVVM (Controller extends ChangeNotifier + notifyListeners)
- **QA**: TDD + Widget tests + Android integration tests

> **Architecture rule**: calculator logic (algebraic evaluation, matrix operations,
> and RPN stack semantics) lives in `package:calculatrix`. Flutter app and CLI
> are UI/interaction layers over the same core API.

> **Testing policy**:
> 1. `code/core` must keep TDD and full unit/contract coverage for public semantics and new logic.
> 2. `code/app` controller/view-model/editor state should target full unit coverage; widget tests protect only critical UI invariants.
> 3. `code/app/integration_test` covers user-visible end-to-end flows for released features and runs on Android emulator/device as the canonical automated integration environment.
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

- [x] Remove legacy app-side parser/tokenizer/evaluator artifacts no longer used at runtime
- [x] Generalize controller/view-model state from scalar-only display to scalar-or-matrix display
- [x] Revisit whether memory remains scalar-only or generalizes to matrices before Stage 3
- [x] Add Android project support so `integration_test` runs on a real emulator/device target
- [x] Run full regression QA across multi-page keypad, matrix editor, and `RPN` mode
- [x] Add or complete automated CLI tests before the Stage 3 handoff
- [x] Confirm advanced linear algebra work can build on the consumer UX without breaking changes
- [x] Refresh architecture and integration docs for the late-v2 app/CLI experience

#### v2.10.0 — Shared Current Value Across Infix and RPN

- [x] Define the shell as one calculator with two notation modes operating over the same committed current value (`X`)
- [x] Preserve the committed current value across `Infix` ↔ `RPN` mode switches
- [x] Keep draft state private to each notation mode until an explicit commit action occurs
- [x] Define `=` in `Infix` as evaluation of the current expression and replacement of `X`
- [x] Define the `RPN` top-of-stack as the same shared current value `X`
- [x] Invalidate stale `Infix` repeat-`=` state whenever `X` is mutated through `RPN` actions or other external state changes
- [x] Define no-draft display semantics for both notation modes against the shared `X` contract
- [x] Add TDD coverage for mode switching, preserved current value, repeat-`=` invalidation, and mixed-notation workflows

##### Proposed Product Contract

**What is always preserved**

- The committed current value `X` is shared by `Infix` and `RPN`.
- Switching notation mode never clears `X`.
- In `RPN`, `X` is the top of the committed stack.
- In `Infix`, `=` evaluates the current expression and replaces `X` with that result.
- Matrix/scalar formatting rules stay consumer-level; the shared state remains matrix-first.

**What is always invalidated**

- A draft remains a draft until an explicit commit action happens (`=`, `ENTER`, or an `RPN` operator that auto-commits the active draft).
- Mode switching never auto-evaluates, auto-pushes, or silently translates a draft from one notation to the other.
- `Infix` repeat-`=` memory (`last operator` / `last operand`) is invalidated when `X` changes through `RPN` stack operators, stack reordering (`SWAP`, `ROT`, `ROLL`, `PICK`, `DROP`, `OVER`, `DUP`), `ENTER`, `MR`, matrix insertion, or any other non-`Infix` mutation path.
- Transient error state is not treated as a committed current value.

**What each mode shows when there is no draft**

- `Infix`: show the shared committed current value `X`; if no committed value exists yet, show `0`.
- `RPN`: show the top-of-stack summary, which is the same shared committed current value `X`; if the committed stack is empty, show `0`.
- If `RPN` changes the top of stack, then returning to `Infix` with no draft must show that new `X`.
- If `Infix` evaluates a new expression, then returning to `RPN` with no draft must show that new `X` at the top of stack.

**Implementation notes for TDD**

- Prefer a single source of truth for committed current value instead of parallel `Infix result` versus `RPN top` state.
- Treat notation-specific drafts as separate transient state from committed value.
- Reject any design where mode switching makes the app feel like two independent calculators.
- Add regression tests for examples such as `3+3= -> 6`, repeated `= -> 9`, then `RPN` top mutation invalidating a stale `+3` repetition before returning to `Infix`.

#### v2.11.0 — Core-Only Matrix Semantics

- [x] Define `package:calculatrix` as the only owner of calculator semantics for memory, unary operators, binary operators, stack mutations, and committed-value transitions
- [x] Introduce a core session/state API for interactive consumers while keeping CLI behavior on public core APIs only
- [x] Generalize memory from scalar-only storage to matrix-first storage in the core
- [x] Keep matrix division in the core restricted to scalar `1x1` denominators and defer general matrix right-division until the determinant/inverse stage
- [x] Implement square-matrix root in the core with explicit real-domain errors when no real root is supported
- [x] Ensure `%`, `+/-`, `MC`, `MR`, `M+`, and `M-` all operate on matrices through shared core rules
- [x] Remove remaining app-side math/state rules other than input translation, presentation, and interaction wiring
- [x] Add TDD contract coverage in `code/core` first, then consumer regression coverage proving app and CLI are thin adapters

##### TDD Execution Order

- [x] Step 1: lock matrix-level contracts in `code/core/test/matrix` for scalar division, square root, and matrix memory primitives while explicitly deferring general matrix division and inverse
- [x] Step 2: update `RpnEngine` and facade tests so unary/binary operators delegate to matrix semantics instead of scalar-only branches
- [x] Step 3: add a core calculator session/state model covering committed value `X`, drafts, memory, and notation-independent mutations
- [x] Step 4: migrate Flutter app to that core session/state API and keep CLI on public core APIs only
- [x] Step 5: refresh roadmap/docs/changelog/versioning only after executable validation is green

---

## Stage 3 — "Advanced Linear Algebra on Mature Matrix UX" (2.x.x → 3.0.0)

Advanced linear algebra and release-grade matrix workflows on top of the
stabilized multi-page shell, matrix editor, and RPN UX delivered in late v2.x.

### v2.x.x → v3.0.0

- [ ] Determinant
- [ ] Matrix inverse
- [ ] LU decomposition
- [ ] QR decomposition
- [ ] Promote late-v2 matrix workflows to major-release quality across app and CLI
- [ ] Extend display and interaction polish for complex matrix workflows
- [ ] Extended linear algebra tests (advanced ops)
- [ ] End-to-end workflows combining matrix input, notation switching, and advanced operations

### v3.0.0 — Stable Release

- [ ] Calculator UX with matrix editing, notation switching, and determinant/inverse/LU/QR over shared core
- [ ] Advanced matrix operations documentation

### v3.x.x — Improvements and fixes on top of v3

- Eigenvalues / eigenvectors (backlog)
- Additional factorizations beyond LU/QR
- Sparse matrices

---

## General Backlog

- Performance profiling
- Observability (metrics, tracing)
- Visual themes / dark mode
- History export
- PWA / offline mode
