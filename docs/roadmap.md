# Roadmap

> **Versioning philosophy**: before the first public `1.0.0`, each stage ends
> with a stable `0.N.0` release.
> Versions `0.N.z` after each `.0` are improvements and fixes on top of that
> base.

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

## Stage 1 — "Casio Skin, Google Brain" (0.0.x → 0.1.0)

Basic calculator with a Casio HL-820LV-inspired layout and an evaluation engine
with Google Calculator-style operator precedence.

### v0.0.10 — Foundation ✅

- [x] Flutter project scaffolded (`dev.ccisne.calculatrix`)
- [x] MVVM structure: `lib/{models,controllers,views,widgets}`
- [x] Domain model: `Token` (number, operator, paren), `TokenType` enum
- [x] `Tokenizer`: string → List\<Token\>
- [x] Tokenizer unit tests (TDD)
- [x] Basic widget test: app starts without crash

### v0.0.20 — Parser & Evaluator ✅

- [x] `Parser`: List\<Token\> → expression tree (AST)
- [x] Recursive descent with PEMDAS precedence
- [x] `Evaluator`: AST → double
- [x] Operations: `+`, `-`, `×`, `÷`
- [x] Parentheses and unary negation
- [x] Exhaustive unit tests (TDD): normal cases + edge cases
- [x] `CalculatorController` (ChangeNotifier) connects input → evaluation

### v0.0.30 — Casio UI Layout ✅

- [x] 4-column button grid (HL-820LV layout)
- [x] All widgets with `Semantics` labels
- [x] Display: expression on top + result below (live preview)
- [x] Visual differentiation by functional key group
- [x] Widget tests: every button has semantics, display updates
- [x] Integration test: complete flow `3 + 4 = 7`

### v0.0.40 — Casio Features ✅

- [x] Square root (`√`)
- [x] Percentage (`%`)
- [x] Memory (MC, MR, M-, M+)
- [x] Sign toggle (`+/-`)
- [x] Status indicators: M, Error
- [x] Unit tests for each feature
- [x] Integration test: memory workflow

### v0.0.50 — Polish & Hardening ✅

- [x] Error handling (÷0, overflow, negative √)
- [x] Numeric precision with smart rounding (12 significant digits)
- [x] Repeat constant (`=` pressed repeatedly)
- [x] Haptic/visual feedback on buttons
- [x] Integration test: all error flows

### v0.1.0 — Stable Release ✅

- [x] Feature-complete basic calculator with operator precedence
- [x] User documentation
- [x] CI/CD pipeline (GitHub Actions: test + build web)
- [x] Full regression test suite passing

### v0.1.x — Improvements and fixes on top of v0.1

- Bug fixes
- UX/performance improvements
- Visual refinement

---

## Stage 2 — "Core Engine Package" (0.1.x → 0.2.0)

Implementation of `package:calculatrix` as a pure Dart computation core,
reusable from Flutter, CLI, and other consumers. This stage establishes the
core package as the single source of truth for all calculator semantics.

### v0.1.x → v0.2.0

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

### v0.2.0 — Stable Release

- [x] `package:calculatrix` published as the official computation engine
- [x] Flutter app and CLI both running against shared core semantics
- [x] Updated architecture documentation (shared core: app + CLI + backend)

### v0.2.x — Improvements and fixes on top of v0.2

Late v0.2.x focuses on consumer UX expansion over the already-stable core
semantics. The default experience remains the current scalar/`1x1`
calculator shell, while app and CLI progressively expose arbitrary matrices,
explicit notation modes, and richer display contracts.

#### v0.2.10 — Advanced RPN Stack Utilities

- [x] Define and document stack semantics for `pick(n)`, `roll(n)`, and `rot`
- [x] Implement `pick(n)` with 1-based indexing from the top of the stack
- [x] Implement `roll(n)` moving the nth stack value to the top
- [x] Implement `rot` as a top-3 stack rotation
- [x] Add typed range/underflow errors for advanced stack utilities
- [x] Add TDD coverage for invariants and edge cases of all advanced stack ops

#### v0.2.20 — Numeric Policy and Determinism

- [x] Define formal tolerance policy for floating-point comparison
- [x] Implement approximate matrix comparison helpers in core
- [x] Add tests for floating-point determinism and tolerance boundaries
- [x] Document numeric comparison policy in README and tests

#### v0.2.30 — Parser and Evaluation Performance Baseline

- [x] Optimize tokenization/evaluation hot paths without changing semantics
- [x] Add TDD coverage for scientific notation and signed numeric edge cases
- [x] Capture baseline benchmark/smoke measurements for supported workloads
- [x] Verify no regressions in core, app, and CLI behaviors

#### v0.2.40 — Hardening and API Freeze Before Stage 3

- [x] Expand contract tests for vectors, non-square matrices, and parser failures
- [x] Harden public error taxonomy for stack range/domain failures
- [x] Review API stability and update docs for app/CLI consumers
- [x] Confirm Stage 3 can build on the current core without breaking changes

#### v0.2.50 — Multi-Page Shell and Layout Geometry

- [x] Add an explicit notation mode switch (`Infix` / `RPN`) in the shared calculator shell
- [x] Preserve the current scalar / `1x1` workflow as the default keypad page
- [x] Introduce horizontally paged keypad layouts (swipe left/right + visible page indicators)
- [x] Make calculator keys square across supported screen sizes
- [x] Target a display/keypad vertical proportion near the golden ratio when screen constraints allow
- [x] Add controller/layout unit coverage plus widget and integration tests for keypad paging, mode visibility, and key geometry invariants

#### v0.2.60 — Generic Matrix Entry

- [x] Add a dedicated `NxM` matrix editor surface with row/column selection
- [x] Validate cell editing and serialize matrices using the core literal contract
- [x] Insert matrices into infix expressions without changing the shared shell model
- [x] Push matrices directly onto the stack in `RPN` mode
- [x] Define copy/paste and confirmation flows for matrix literals across app and CLI
- [x] Add TDD coverage for matrix editor state, cancellation, validation, insertion/push flows, and CLI literal parity

#### v0.2.70 — RPN Mode UX

- [x] Make notation mode persistent and visible in app state
- [x] Add an `RPN`-focused keypad page for stack actions and operand entry
- [x] Add stack visualization (top levels + depth navigation) in the app
- [x] Relabel the primary action key from `=` to `ENTER` in `RPN` mode
- [x] Define `ENTER` as commit of the current draft operand; duplication remains an explicit `dup` action
- [x] Auto-commit any active draft before unary or binary stack operators execute through the core
- [x] Define `C`, `⌫`, `MC`, `MR`, `M+`, and `M-` semantics for draft-aware `RPN` workflows
- [x] Support switching between `Infix` and `RPN` without ambiguous display state
- [x] Add controller, widget, integration, and CLI smoke tests for stack workflows, notation switching, and error presentation

#### v0.2.80 — Matrix Display and Formatting

 [x] Display non-scalar matrix results in the app without collapsing them to `scalarValue`
 [x] Define compact and expanded matrix render policies for small and large screens
 [x] Add overflow, scrolling, and readability rules for matrix output
 [x] Align matrix formatting expectations between Flutter app and CLI
 [x] Add accessibility semantics for matrix structures and stack previews
 [x] Add regression coverage for matrix render, formatting, and cross-consumer parity

#### v0.2.90 — Consumer Cleanup and Freeze Before Stage 3

- [x] Remove legacy app-side parser/tokenizer/evaluator artifacts no longer used at runtime
- [x] Generalize controller/view-model state from scalar-only display to scalar-or-matrix display
- [x] Revisit whether memory remains scalar-only or generalizes to matrices before Stage 3
- [x] Add Android project support so `integration_test` runs on a real emulator/device target
- [x] Run full regression QA across multi-page keypad, matrix editor, and `RPN` mode
- [x] Add or complete automated CLI tests before the Stage 3 handoff
- [x] Confirm advanced linear algebra work can build on the consumer UX without breaking changes
- [x] Refresh architecture and integration docs for the late-v0.2 app/CLI experience

#### v0.2.100 — Shared Current Value Across Infix and RPN

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

#### v0.2.110 — Core-Only Matrix Semantics

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

#### v0.2.120 — Matrix Editor UX Refinement

- [x] Restrict the matrix editor order selector to direct `2x2`, `3x3`, and `4x4` choices for the supported educational workflow
- [x] Preserve overlapping top-left cell values when switching order within the same draft session
- [x] Add lightweight quick actions for `Zeros`, `Identity`, and `Clear`
- [x] Split navigation mode from edit mode in the matrix grid, including arrow-key movement and `Enter`/`Esc` semantics
- [x] Replace spinbutton-like numeric entry assumptions with text-based numeric cells optimized for exact signed decimal input
- [x] Add explicit row-and-column error copy for invalid or empty visible cells
- [x] Keep the mobile action row usable while the software keyboard is open for `4x4` entry
- [x] Add focused TDD coverage for draft state, controller parity, widget contracts, and canonical end-to-end flows

##### TDD Execution Order

- [x] Step 1: lock draft-state contracts for order changes, visible-cell preservation, and literal generation
- [x] Step 2: add draft-level helpers or editor-local state for `Zeros`, `Identity`, and `Clear`
- [x] Step 3: prove controller parity for `Infix` insert and `RPN` push using the exact serialized literal
- [x] Step 4: lock widget contracts for order controls, validation, quick actions, and keyboard edit/navigation behavior
- [x] Step 5: add narrow emulator coverage for one `Infix` insert flow, one `RPN` push flow, and one invalid-cell recovery flow

#### v0.2.130 — Matrix Row/Column List Editor UX

- [x] Add row-list and column-list editing affordances on top of the existing grid so structural edits remain visible as matrix operations, not hidden form state
- [x] Support bounded `NxM` editing up to `4x4`, including add/remove row and add/remove column operations without breaking canonical literal serialization
- [x] Keep the current square quick workflow (`2x2`, `3x3`, `4x4`) as the fast path, while allowing structural list edits to diverge into non-square shapes when the user intentionally changes rows or columns
- [x] Support desktop-first row reordering with pointer drag handles and provide an explicit fallback affordance when drag is unavailable or imprecise
- [x] Keep row/column list order, visible grid cells, preview text, and final `Infix`/`RPN` confirmation output in strict sync after every structural edit
- [x] Restrict square-only helpers like `Identity` to square shapes while keeping shape-agnostic helpers like `Zeros` and `Clear`
- [x] Add focused TDD coverage for draft insert/delete/reorder semantics, widget drag-and-drop contracts, and canonical end-to-end confirmation flows

##### TDD Execution Order

- [x] Step 1: lock draft-state contracts for row/column insertion, deletion, reordering, and value preservation within the bounded `4x4` backing store
- [x] Step 2: prove controller parity for non-square and reordered literals so `Infix` insert and `RPN` push keep using the exact serialized matrix
- [x] Step 3: lock widget contracts for row/column list affordances, add/remove controls, drag handles, and square-only helper availability
- [x] Step 4: add desktop-focused interaction coverage for pointer-driven row reorder plus non-drag fallbacks
- [x] Step 5: add integration coverage for one add-row flow, one reorder-row flow, and one mixed row/column structural edit followed by successful confirmation

---

## Stage 3 — "Canonical Matrix Stack Machine" (0.2.x → 0.3.0)

Stage 3 is an architectural reset, not only an advanced-linear-algebra pass.
The product is redefined around one canonical matrix stack machine in
package:calculatrix, with infix treated as a convenience frontend and Matrix as
an app shell mode instead of a modal editor.

Current status: most kernel-level Stage 3 work is already merged on the `v0.2.x`
line and the release gate is now closed: `v0.3.0` has aligned public docs,
versioning, changelog entries, and green validation across core, app, and CLI.

Companion specification: docs/spec/stage_3_matrix_stack_machine.md

### v0.2.x → v0.3.0

- [x] Reframe package:calculatrix around a public matrix stack machine kernel
- [x] Expose typed public APIs for primitive commands and public macros
- [x] Keep all committed runtime values matrix-first and execute all committed operations through stack semantics
- [x] Treat infix as translation or convenience evaluation over the same stack kernel instead of as a separate semantic engine
- [x] Expose public matrix creation, structural editing, transpose, inverse, zeros, ones, and stack-native workflow commands in the core package
- [x] Replace the app-side modal matrix editor with a dedicated Matrix shell mode and matrix-focused keyboard pages
- [x] Keep advanced users able to access the same command vocabulary directly from RPN mode
- [x] Add CLI parity for public commands, public macros, and infix convenience execution
- [x] Refresh architecture, docs, and QA around the new canonical core model

#### v0.2.140 — Stage 3 Closure and Release Hardening

- [x] Fix the failing Matrix structural add-row interaction so compact affordances remain usable on the canonical integration target
- [x] Complete end-to-end coverage for add-row, reorder-row, and one mixed row+column structural confirmation flow
- [x] Resolve remaining Matrix shell release-polish regressions, including mode-accurate copy and shell-state feedback
- [x] Keep direct RPN workflows aligned with the same public command vocabulary already exposed by core and CLI
- [x] Refresh top-level docs and user guides around the matrix stack machine, public commands/macros, and the infix-over-stack contract
- [x] Define and run the release-grade validation matrix for core, app, and CLI before the stage-closing stable cut
- [x] Prepare `v0.3.0` release inputs only after executable validation is green: version bumps, changelog, and stable release notes

##### Execution Order

- [x] Step 1: reproduce and lock the failing add-row structural interaction with a narrow regression check on the canonical integration path
- [x] Step 2: repair Matrix structural hit-target/state issues and prove add-row plus reorder flows on the release target
- [x] Step 3: add the missing mixed row+column structural confirmation flow and close remaining unstable app checks where practical
- [x] Step 4: finish shell parity for RPN/Matrix command access and mode-accurate UI copy
- [x] Step 5: refresh README/public docs, run release validation across core/app/cli, and then cut the `v0.3.0` release artifacts

### v0.3.0 — Stable Release

Release gate note: closed. The project now ships with aligned `v0.3.0`
versioning, updated public docs, current changelog entries, and green
validation across `code/core`, `code/cli`, and `code/app` including the
Windows integration suite.

Entry criterion: satisfied.

- [x] One canonical matrix stack machine core with public command and macro APIs
- [x] Three complementary app shell modes: Infix, RPN, Matrix
- [x] Matrix workstation replaces the modal editor and delegates real operations to public core commands or macros
- [x] Public documentation for commands, macros, and the infix-over-stack contract

### v0.3.x — Improvements and fixes on top of v0.3

- Additional command packs and workflow macros
- Matrix workstation ergonomics and shell polish
- CLI scripting and programmable-workflow improvements over the same public core command layer

#### v0.3.1 — Calculator Interaction Corrections and Unified Keypad

- [x] Make `√` act immediately in `Infix` when there is a committed value or a parseable active operand
- [x] Add Casio-style `%` behavior in `Infix`, including `x%y = x*y/100`, bare-operand percent on evaluation, and pending binary percent translation while preserving public core `%` semantics in `RPN` and direct evaluation APIs
- [x] Replace the horizontally paged calculator keypad with one shared `6x4` keyboard whose bottom four rows stay fixed as `7 8 9 ÷`, `4 5 6 ×`, `1 2 3 -`, and `0 . ENTER +`
- [x] Expose mode-specific actions through top-deck selectors so `Infix`, `RPN`, and `Matrix` only swap the top two rows instead of the whole keypad surface
- [x] Keep `package:calculatrix` public parser and `RPN` contracts stable for CLI and API consumers
- [x] Add TDD coverage in `code/core` session tests plus `code/app` widget and integration tests for the revised `Infix` interaction contract and unified keypad workflow
- [x] Run focused validation across core and app before closing the patch release slice

##### TDD Execution Order

- [x] Step 1: lock the new `Infix` interaction contract in `CalculatrixSession` tests for immediate `√` and Casio-style `%`
- [x] Step 2: prove the app button wiring through focused widget tests for immediate unary interaction
- [x] Step 3: implement the `Infix` session-layer translation without changing public `RPN` execution semantics
- [x] Step 4: replace keypad paging with deck selectors while preserving the fixed bottom-row calculator layout
- [x] Step 5: rerun focused core/app validation, including the Windows integration suite, and only then mark the patch checklist progress

---

## Stage 4 — "Advanced Linear Algebra on Canonical Stack Kernel" (0.3.x → 0.4.0)

Stage 4 builds advanced linear algebra on top of the already-stable matrix
stack machine and the Stage 3 shell/workstation architecture.

Readiness gate: ready. Stage 3 is now declared stable at `v0.3.0`, so Stage 4
can start on top of the canonical kernel and the validated three-mode shell.

### v0.3.x → v0.4.0

- [x] Determinant
- [x] LU decomposition
- [x] QR decomposition
- [x] Extend display and interaction polish for complex advanced matrix workflows
- [x] Extended linear algebra tests over the canonical stack kernel
- [x] End-to-end workflows combining matrix creation, notation switching, commands, macros, and advanced operations

#### v0.3.10 — Determinant on the Canonical Stack Kernel

- [x] Add public determinant support on `Matrix` while preserving the matrix-first scalar contract through `Matrix.scalar(...)` results
- [x] Expose determinant through the typed command vocabulary so `CalculatrixMachine` and `CalculatrixSession` consumers can invoke it without private hooks
- [x] Route determinant through CLI command workflows and the Flutter app `RPN` / Matrix decks using the unified keypad model
- [x] Add focused TDD coverage in core, CLI, widget, and Windows integration suites for determinant workflows
- [x] Bump coordinated versions and refresh release-facing docs for the first Stage 4 slice

##### TDD Execution Order

- [x] Step 1: lock determinant behavior in `Matrix` and typed machine command tests
- [x] Step 2: implement the determinant API and command with square-matrix validation and scalar-matrix output
- [x] Step 3: prove CLI and app consumer routing through focused widget and command tests
- [x] Step 4: rerun the Windows integration suite with direct `DET` workflows before closing the slice

#### v0.3.20 — LU and QR Decompositions on the Canonical Stack Kernel

- [x] Add public LU decomposition with partial pivoting and explicit `P`, `L`, `U` factors for square matrices
- [x] Add public QR decomposition with thin `Q` and `R` factors for matrices with `rowCount >= columnCount`
- [x] Expose LU and QR through typed stack commands so decomposition results expand onto the canonical `RPN` stack instead of requiring consumer-local types
- [x] Extend CLI command workflows to print `X0`, `X1`, ... when a command sequence leaves multiple matrix results on the stack
- [x] Add an `RPN` factorization deck in the Flutter app so LU and QR are accessible without breaking the fixed keypad geometry
- [x] Add focused TDD coverage in core, CLI, widget, and Windows integration suites for LU and QR workflows

##### TDD Execution Order

- [x] Step 1: lock LU and QR factorization contracts in `Matrix` and typed machine command tests
- [x] Step 2: implement LU with partial pivoting and QR with thin orthogonal/upper outputs in the public core API
- [x] Step 3: route multi-result factorization commands through CLI `command` mode and the app `RPN` factorization deck
- [x] Step 4: rerun focused widget and Windows integration validation for stack-expanding LU and QR workflows

#### v0.3.21 — LU and QR Edge-Case Hardening

- [x] Lock LU reconstruction for zero-leading pivots so partial pivoting remains covered by tests
- [x] Lock LU reconstruction for singular square matrices without changing stack result ordering
- [x] Lock QR behavior for tall full-rank matrices and dependent columns under the public matrix-first contract
- [x] Extend typed machine command tests for stack-expanding LU and QR edge cases
- [x] Rerun focused core validation after the new linear-algebra hardening coverage

##### TDD Execution Order

- [x] Step 1: add failing LU and QR tests for pivots, singular matrices, tall matrices, and dependent columns
- [x] Step 2: rerun focused core validation to confirm whether implementation changes are required
- [x] Step 3: close the slice as a patch release once the canonical kernel remains green

#### v0.3.30 — Matrix Workstation Factorization Workflow Polish

- [x] Expose a Matrix-mode factorization deck when the workstation is entered from `RPN`
- [x] Allow valid Matrix drafts to dispatch LU and QR directly onto the canonical stack and return to the `RPN` shell
- [x] Keep Matrix deck availability mode-aware so stack-expanding workflows only appear when the underlying entry mode can represent them
- [x] Add focused widget and Windows integration coverage for Matrix-to-factorization workflows
- [x] Bump coordinated versions and refresh release-facing docs for the Stage 4 shell-polish slice

##### TDD Execution Order

- [x] Step 1: lock Matrix-mode `RPN` workflows in app widget and integration tests before wiring the new factorization path
- [x] Step 2: route LU and QR from the embedded Matrix workstation back into the canonical stack shell without changing core semantics
- [x] Step 3: rerun focused widget and Windows integration validation before closing the slice

#### v0.3.31 — Stage 4 End-to-End Workflow Coverage

- [x] Lock a full Stage 4 shell workflow that combines Matrix creation, an `RPN` macro, QR factorization, and notation switching
- [x] Prove that the canonical current value remains coherent when returning from advanced `RPN` workflows to `Infix`
- [x] Close the remaining Stage 4 end-to-end workflow checklist item with focused Windows integration coverage
- [x] Bump coordinated versions and refresh release-facing docs for the patch slice

##### TDD Execution Order

- [x] Step 1: add a failing Windows integration test for a combined Matrix -> macro -> QR -> Infix workflow
- [x] Step 2: align the assertion with the existing empty-expression chrome once the behavior is confirmed end-to-end
- [x] Step 3: rerun the focused integration path and only then close the Stage 4 checklist item

### v0.4.0 — Stable Release

- [x] Calculator UX with canonical matrix shell modes and advanced linear algebra over the shared core
- [x] Advanced matrix operations documentation

Release gate note: closed. Stage 4 now ships with determinant, LU, QR,
Matrix-workstation factorization workflows, and end-to-end validation across
core, CLI, and app.

### v0.4.x — Improvements and fixes on top of v0.4

#### v0.4.10 — Small-Matrix Real Eigenvalues

- [x] Add public `Matrix.eigenvalues()` support for `1x1` matrices and `2x2` matrices with a real spectrum
- [x] Return eigenvalues as a deterministic column matrix sorted in descending order
- [x] Surface `MatrixShapeError`, `MatrixDomainError`, and `UnsupportedCalculatrixOperationError` for non-square, non-real, and out-of-slice requests
- [x] Expose `EIG` / `eig` through the shared typed command path in app `RPN` and CLI `command` mode
- [x] Add focused core, CLI, widget, and Windows integration coverage for the new workflow

##### TDD Execution Order

- [x] Step 1: lock real eigenvalue behavior and failure modes in core matrix and machine tests
- [x] Step 2: route `EigenvaluesCommand` through CLI `command` mode with a stable `eig` alias
- [x] Step 3: expose `EIG` in the app `RPN` factorization deck and rerun focused widget plus Windows integration validation

#### v0.4.20 — General Real Eigenvalues via QR Iteration

- [x] Generalize `Matrix.eigenvalues()` from 2x2-only to arbitrary square matrices using the iterative QR algorithm
- [x] Preserve the existing 1x1 identity and 2x2 characteristic polynomial fast paths
- [x] Implement Hessenberg reduction as a preprocessing step to accelerate convergence
- [x] Implement implicit QR iteration with Wilkinson shift on the Hessenberg form
- [x] Detect and report complex eigenvalues (2x2 blocks on the quasi-upper-triangular result) via `MatrixDomainError`
- [x] Return eigenvalues as a deterministic column matrix sorted in descending order (same contract as v0.4.10)
- [x] Add focused core TDD coverage for 3x3, 4x4, diagonal, symmetric, and defective matrices
- [x] Rerun CLI command mode, widget, and Windows integration validation for the generalized path

##### TDD Execution Order

- [x] Step 1: add failing core tests for 3x3 and 4x4 diagonal, symmetric, and general matrices with known eigenvalues
- [x] Step 2: implement Hessenberg reduction and QR iteration with shift in `Matrix.eigenvalues()`
- [x] Step 3: add core tests for complex-spectrum detection on 3x3+ matrices
- [x] Step 4: rerun CLI, widget, and Windows integration suites to confirm the generalized path is transparent to consumers

#### v0.4.30 — Eigenvectors and Diagonalization

- [x] Add public `Matrix.diagonalization()` returning a `Diagonalization` type whose `p` holds eigenvector columns and `d` is the diagonal eigenvalue matrix
- [x] Compute eigenvectors by solving `(A - λI)x = 0` via Gaussian elimination with partial pivoting for each real eigenvalue
- [x] Add public `Diagonalization` type with `p` (eigenvector columns) and `d` (diagonal eigenvalue matrix) such that `A ≈ P * D * P⁻¹`
- [x] Add `DiagonalizationCommand` to the typed public command surface
- [x] Route `DIAG` / `diag` through CLI `command` mode and the app `RPN` factorization deck
- [x] Throw `MatrixDomainError` when the eigenvalue spectrum is complex (delegates to `eigenvalues()` detection)
- [x] Throw `MatrixShapeError` for non-square inputs
- [x] Add focused core TDD coverage for 2x2, 3x3, and 4x4 eigenvector and diagonalization workflows
- [x] Rerun CLI, widget, and Windows integration validation for the new commands

##### TDD Execution Order

- [x] Step 1: add failing core tests for eigenvectors and diagonalization on 2x2, 3x3 diagonal, and 3x3 symmetric matrices
- [x] Step 2: implement `Matrix.diagonalization()` and `Diagonalization` in core
- [x] Step 3: add `DiagonalizationCommand`, wire through CLI and app
- [x] Step 4: rerun CLI, widget, and Windows integration suites for the new command paths

#### v0.4.40 — Trace, Frobenius Norm, and Rank

- [x] Add public `Matrix.trace()` returning the sum of diagonal entries as a scalar matrix; throw `MatrixShapeError` for non-square inputs
- [x] Add public `Matrix.frobeniusNorm()` returning the Frobenius norm as a scalar matrix (valid for any shape)
- [x] Add public `Matrix.rank()` returning the numerical rank as a scalar matrix (count of non-negligible pivots from row reduction)
- [x] Add `TraceCommand`, `NormCommand`, and `RankCommand` to the typed public command surface
- [x] Route `TR` / `trace`, `NORM` / `norm`, and `RANK` / `rank` through CLI `command` mode and the app `RPN` factorization deck
- [x] Add focused core TDD coverage for trace, norm, and rank on scalar, square, non-square, and zero matrices
- [x] Rerun CLI, widget, and Windows integration validation for the new commands

##### TDD Execution Order

- [x] Step 1: add failing core tests for trace, Frobenius norm, and rank on representative matrices
- [x] Step 2: implement `trace()`, `frobeniusNorm()`, and `rank()` in `Matrix`
- [x] Step 3: add commands, wire through CLI and app
- [x] Step 4: rerun CLI, widget, and Windows integration suites

#### v0.4.50 — Formal Definitional Operations (Minor, Cofactor, Adjugate)

These operations follow textbook definitions rather than efficient numerical
algorithms. They enable step-by-step reasoning: inverse = adjugate / determinant,
where adjugate = transpose of cofactor matrix, and each cofactor = signed minor
determinant. Expensive for large matrices, but mathematically important.

- [x] Add public `Matrix.minor(int row, int column)` returning the (n-1)×(n-1) submatrix with the specified row and column removed
- [x] Add public `Matrix.cofactor(int row, int column)` returning `(-1)^(i+j) * det(minor(i,j))` as a scalar matrix
- [x] Add public `Matrix.cofactorMatrix()` returning the full NxN matrix of cofactors
- [x] Add public `Matrix.adjugate()` returning the transpose of the cofactor matrix (classical adjoint)
- [x] Add `CofactorMatrixCommand` and `AdjugateCommand` to the typed public command surface
- [x] Route `COF` / `cof` and `ADJ` / `adj` through CLI `command` mode and the app `RPN` factorization deck
- [x] Throw `MatrixShapeError` for non-square inputs on cofactor/adjugate operations
- [x] Add focused core TDD coverage for minor, cofactor, cofactor matrix, and adjugate on 2x2, 3x3, and 4x4 matrices
- [x] Verify the definitional identity: `adjugate(A) = det(A) * inverse(A)` in tests
- [x] Rerun CLI, widget, and Windows integration validation for the new commands

##### TDD Execution Order

- [x] Step 1: add failing core tests for minor, cofactor, cofactorMatrix, and adjugate with known results
- [x] Step 2: implement `minor()`, `cofactor()`, `cofactorMatrix()`, and `adjugate()` in `Matrix`
- [x] Step 3: add commands, wire through CLI and app
- [x] Step 4: rerun CLI, widget, and Windows integration suites

#### v0.4.60 — Vector Operations (Dot Product, Cross Product)

A vector is defined as a column matrix (n×1). Two multiplication operations
are defined for vectors using matrix algebra:
- Dot product: `dot(A, B) = Aᵀ · B` (result is 1×1 scalar matrix, any dimension)
- Cross product: `cross(A, B) = skew(A) · B` (only R³)

Where `skew([[x],[y],[z]]) = [[0, -z, y], [z, 0, -x], [-y, x, 0]]`

- [x] Add public `Matrix.dot(Matrix other)` returning Aᵀ·B as a 1×1 scalar matrix
- [x] Add public `Matrix.cross(Matrix other)` returning skew(A)·B as a 3×1 column matrix
- [x] Add private `Matrix._skewSymmetric()` building the 3×3 skew-symmetric matrix from a 3×1 vector
- [x] Throw `MatrixShapeError` if operands are not column vectors (n×1) of matching dimension
- [x] Throw `MatrixShapeError` if cross product operands are not exactly 3×1
- [x] Add `DotProductCommand` and `CrossProductCommand` to the typed public command surface
- [x] Route `DOT` / `dot` and `CROSS` / `cross` through CLI command mode and the app RPN deck
- [x] Add focused core TDD coverage for dot and cross on 2D/3D vectors with known results
- [x] Verify dot product identity: `dot(A,B) = dot(B,A)` (commutativity)
- [x] Verify cross product identity: `cross(A,B) = -cross(B,A)` (anti-commutativity)
- [x] Rerun CLI, widget, and Windows integration validation for the new commands

##### TDD Execution Order

- [x] Step 1: add failing core tests for dot and cross with known results and error cases
- [x] Step 2: implement `dot()`, `cross()`, and `_skewSymmetric()` in `Matrix`
- [x] Step 3: add commands, wire through CLI and app
- [x] Step 4: rerun CLI, widget, and Windows integration suites

#### v0.4.70 — RREF and Spectral Norm

Two operations that complete the core linear algebra toolkit:
- RREF (Reduced Row Echelon Form): Gaussian elimination with partial pivoting,
  essential for students studying systems of equations and rank visually.
- Spectral norm (‖A‖₂): the largest singular value, computed as
  sqrt(λ_max(AᵀA)). Complements Frobenius norm for operator-norm reasoning.

- [x] Add public `Matrix.rref()` returning the reduced row echelon form
- [x] Implement Gaussian elimination with partial pivoting and back-substitution
- [x] Handle non-square matrices (m×n) correctly in RREF
- [x] Add public `Matrix.spectralNorm()` returning ‖A‖₂ as a 1×1 scalar matrix
- [x] Compute spectral norm as sqrt of largest eigenvalue of AᵀA
- [x] Add `RrefCommand` and `SpectralNormCommand` to the typed public command surface
- [x] Route `RREF` / `rref` and `SNORM` / `snorm` through CLI command mode and the app
- [x] Add focused core TDD coverage for RREF on augmented systems and rank-deficient matrices
- [x] Verify RREF identity: rref(I) = I, rref of rank-r matrix has exactly r pivot rows
- [x] Verify spectral norm properties: ‖I‖₂ = 1, submultiplicativity
- [x] Rerun CLI, widget, and Windows integration validation

##### TDD Execution Order

- [x] Step 1: add failing core tests for rref and spectralNorm with known results
- [x] Step 2: implement `rref()` and `spectralNorm()` in `Matrix`
- [x] Step 3: add commands, wire through CLI and app
- [x] Step 4: rerun CLI, widget, and Windows integration suites

#### v0.4.8 — Numerical Robustness: Standard Test Matrices and Residual Assertions

Reference: Higham, *Accuracy and Stability of Numerical Algorithms* (2002);
MATLAB `gallery()` function; LAPACK test suite methodology.

Standard test matrices from the numerical computing literature are the canonical
way to validate linear algebra implementations. Each matrix family stresses a
specific algorithmic weakness: Hilbert matrices have exponentially growing
condition numbers, Pascal matrices expose pivot precision, Frank matrices test
eigenvalue algorithms on non-symmetric Hessenberg structure.

Residual-norm assertions (‖A·A⁻¹ − I‖, ‖QR − A‖/‖A‖) test backward stability
independent of forward error — the gold standard for numerical validation.

- [x] Add `Matrix.hilbert(int n)` factory: `H[i,j] = 1/(i+j+1)` for dimensions 3–6
- [x] Add `Matrix.pascal(int n)` factory: `P[i,j] = C(i+j, i)` for dimensions 3–5
- [x] Add `Matrix.frank(int n)` factory: `F[i,j] = min(i,j)+1` for upper-Hessenberg structure
- [x] Add residual-norm test helpers: `relativeResidual(A, B, expected)` → ‖A·B − expected‖/‖expected‖
- [x] Test inverse residual: ‖A·A⁻¹ − I‖_F / n < tolerance for Hilbert(3), Pascal(4)
- [x] Test LU residual: ‖P·A − L·U‖_F / ‖A‖_F < tolerance for all standard matrices
- [x] Test QR residual: ‖Q·R − A‖_F / ‖A‖_F < tolerance for all standard matrices
- [x] Test eigenvalue residual: ‖A·v − λ·v‖ / (‖A‖·‖v‖) for diagonalizable standard matrices
- [x] Test RREF correctness on Hilbert (rank-deficient at tolerance boundary)
- [x] Add dimension stress tests: eigenvalues, LU, QR, determinant, RREF on 5×5, 6×6, 8×8
- [x] Document numerical limitations discovered during validation (condition number thresholds)
- [x] Rerun full core test suite confirming no regressions

##### TDD Execution Order

- [x] Step 1: add `Matrix.hilbert(n)`, `Matrix.pascal(n)`, `Matrix.frank(n)` factories with construction tests
- [x] Step 2: add residual-norm helper and inverse/LU/QR residual assertions on standard matrices
- [x] Step 3: add eigenvalue residual assertions and RREF tests on standard matrices
- [x] Step 4: add dimension stress tests (5×5 through 8×8) for all major operations
- [x] Step 5: document discovered limitations and rerun full validation

#### v0.4.9 — Package Publication Readiness

Reference: pub.dev scoring criteria (https://pub.dev/help/scoring);
dart.dev package layout conventions; effective Dart documentation guide.

Before publishing `calculatrix` as a developer preview on pub.dev, the package
must pass `dart pub publish --dry-run` cleanly, include a working example,
have complete dartdoc coverage on public members, and present an accurate README.

- [x] Create `code/core/example/example.dart` demonstrating matrix creation, operations, RPN evaluation, and session usage
- [x] Update `code/core/README.md`: fix version references, add complete feature list, add usage examples matching example.dart
- [x] Add missing `topics` to pubspec.yaml: include `linear-algebra` and `math`
- [x] Run `dart doc` and fix all undocumented public member warnings
- [x] Run `dart pub publish --dry-run` and fix all reported issues
- [x] Add `funding` and/or `screenshots` metadata if applicable
- [x] Verify `dart analyze` reports zero issues on the public API surface
- [x] Bump version to `0.5.0` as developer-preview milestone

##### TDD Execution Order

- [x] Step 1: create `example/example.dart` with representative usage patterns
- [x] Step 2: update README with accurate version, features, and code examples
- [x] Step 3: add topics and fix pubspec metadata
- [x] Step 4: run `dart doc`, fix documentation gaps on public members
- [x] Step 5: run `dart pub publish --dry-run` and resolve all blocking issues, then cut `0.5.0`

#### v0.5.1 — Accessibility Audit and Semantic Corrections

Reference: WCAG 2.1 AA; Flutter Semantics API; Android TalkBack / iOS VoiceOver
accessibility testing guidelines; Material Design accessibility checklist.

A granular audit of all app views using Flutter's `Semantics` widget tree
to ensure screen readers can fully convey calculator state and interaction
affordances. Each mode (Infix, RPN, Matrix) and the matrix editor are
inspected independently for label clarity, role correctness, and navigation order.

- [x] Audit Infix mode: display area semantics, button labels, deck selector, mode indicator
- [x] Audit RPN mode: stack display semantics, entry area, operation buttons, deck selector
- [x] Audit Matrix mode: matrix grid semantics, structural edit buttons, deck selector
- [x] Audit Matrix editor: cell semantics, order selector, quick actions, navigation mode
- [x] Fix redundant or missing `Semantics` labels on keypad buttons (e.g., "RR" → "Reduced Row Echelon Form")
- [x] Add `Semantics` labels to display areas describing current value and state
- [x] Add `Semantics` labels to deck selector tabs with descriptive names
- [x] Fix button roles: ensure all interactive elements have `button` role, not generic
- [x] Verify focus order matches visual layout (top-to-bottom, left-to-right)
- [x] Add live region semantics to result display so screen readers announce changes
- [x] Rerun widget tests confirming Semantics nodes exist for all interactive elements
- [x] Rerun Windows integration suite confirming no regressions

##### TDD Execution Order

- [x] Step 1: audit all views via browser accessibility tree and source code; document findings
- [x] Step 2: add widget tests asserting expected Semantics labels for all buttons and display areas
- [x] Step 3: implement Semantics corrections in view code to pass the new tests
- [x] Step 4: rerun widget and Windows integration suites confirming accessibility + no regressions
- [x] Step 5: bump version and update changelog

#### v0.5.x — UI/UX Refinement Series (0.5.2, 0.5.3, 0.5.4, …)

A series of incremental improvements focused on visual design, usability, and
modern interaction patterns. Each version addresses one cohesive aspect of the
user interface. Specific scope for each version will be defined as work
progresses. Methodology: HDCD (Heuristic-Driven Component Design) per
docs/research/ui-ux-design-methodology.md.

#### v0.5.2 — Material 3 Color System and Theme Foundation

HDCD Intent: Replace all hardcoded hex colors with Material 3 ColorScheme roles
so the UI derives its palette from the M3 token system instead of ad-hoc
decisions. This enables dark/light theme switching, guarantees accessible
contrast by construction, and establishes the token layer for all subsequent
UI iterations.

HDCD Acceptance Criteria:
- All colors from ColorScheme (no raw hex in view code)
- Dark and light theme automatic via ThemeData
- Minimum touch target 48dp enforced (fix current 32dp floor)
- Spacing regularized to 4dp grid (fix 6dp margin)
- Visual hierarchy: mode switch ≠ deck selector appearance (H4 Consistency)

Scope:
- [x] Define app-level ThemeData with Material 3 ColorScheme (dark seed + light seed)
- [x] Replace all hardcoded button colors with ColorScheme role lookups
- [x] Replace display area colors with surface/onSurface token roles
- [x] Replace mode switch colors with primary/onPrimary (stronger visual weight)
- [x] Replace deck selector colors with secondaryContainer/onSecondaryContainer for active
- [x] Replace typography with Theme.textTheme scale references (done in v0.5.3)
- [x] Remove artificial 32dp key size floor; natural layout is >48dp on supported viewports
- [x] Regularize deck margin from 6dp to 8dp (grid-aligned)
- [x] Visually differentiate mode switch (pill toggle) from deck selector (tab bar)
- [x] Verify automatic dark/light switching via ThemeMode.system
- [x] Run widget tests and integration tests confirming no regressions
- [x] Produce HDCD evaluation scorecard confirming all gates pass

- Additional factorizations beyond LU/QR
- Sparse matrices

#### v0.5.3 — Typography Scale Migration

HDCD Intent: Replace all hardcoded fontSize/fontWeight values with Material 3
TextTheme role references so typography responds to system accessibility
settings, stays consistent across the app, and enables future theme
customization.

HDCD Acceptance Criteria:
- All text styles derive from Theme.textTheme roles (with copyWith for monospace)
- No raw fontSize literals in view code (except dynamic calculator display)
- Font weight semantics come from textTheme role definitions where possible
- Text scales properly with system accessibility large-text settings
- Visual appearance unchanged (matching roles selected to preserve current sizes)

Scope:
- [x] Replace memory/stack indicators with textTheme.labelLarge
- [x] Replace expression text with textTheme.titleMedium + monospace
- [x] Replace display value with textTheme.displaySmall/headlineMedium + monospace
- [x] Replace RPN register labels with textTheme.labelLarge + monospace
- [x] Replace deck selector labels with textTheme.labelMedium
- [x] Replace button labels with textTheme.titleLarge/titleMedium (size-adaptive)
- [x] Replace mode switch labels with textTheme.labelLarge
- [x] Replace matrix cell labelStyle with textTheme.labelSmall
- [x] Run widget tests and integration tests confirming no regressions

#### v0.5.4 — Shape System and Elevation Cleanup

HDCD Intent: Unify border radii to a consistent M3 shape scale and remove
drop-shadow elevation from tonal buttons (M3 FilledTonalButton pattern uses
elevation 0 with colored containers). This reduces visual noise, improves
consistency (H4), and modernizes the aesthetic (Aesthetic-Usability Effect).

HDCD Acceptance Criteria:
- All radii map to M3 shape tokens: 8 (small), 12 (medium), 16 (large), 28 (extraLarge)
- No ad-hoc radius values (10, 14, 18) remain
- Buttons use elevation 0 (flat tonal) instead of elevation 2 (drop shadow)
- Drag feedback uses Material elevation instead of hardcoded BoxShadow
- Visual hierarchy maintained through color contrast, not shadows

Scope:
- [x] Unify button radius from 16 to 16 (large — no change needed)
- [x] Unify deck selector radius from 14 to 12 (medium)
- [x] Unify mode switch container radius from 18 to 16 (large)
- [x] Unify mode button inner radius from 14 to 12 (medium)
- [x] Unify matrix input radius from 10 to 12 (medium)
- [x] Remove button elevation (2 → 0) for M3 flat tonal style
- [x] Replace drag feedback BoxShadow with Material elevation widget
- [x] Run widget tests and integration tests confirming no regressions

#### v0.5.5 — Spacing Grid Compliance and Desktop Interaction States

HDCD Intent: Complete M3 spatial compliance by fixing all off-grid spacing
values (10dp → 8dp) and add visible hover/focus state overlays on interactive
elements for desktop users. This improves keyboard accessibility (H7 Flexibility),
consistency (H4), and desktop usability (Fitts's Law feedback).

HDCD Acceptance Criteria:
- All spacing values on strict 4dp grid (no 10dp values remain)
- Interactive buttons show visible hover state on desktop (mouse over)
- Mode switch pills show hover feedback
- Deck selector tabs show hover feedback
- Keyboard focus visible on all interactive elements

Scope:
- [x] Fix contentPadding 10 → 8 in matrix cell inputs
- [x] Fix SizedBox(width: 10) → 8 in RPN secondary card
- [x] Fix mode button vertical padding 10 → 8
- [x] Add hoverColor overlay to calculator buttons (M3: 8% on-color)
- [x] Add focusColor overlay to calculator buttons
- [x] Add hover/focus feedback to mode switch pills
- [x] Add hover/focus feedback to deck selector tabs
- [x] Run widget tests and integration tests confirming no regressions

#### v0.5.6 — Infix sqrt error handling and RPN keypad fix

- [x] Fix uncaught `MatrixDomainError` in `_rewriteInfixDraftUnary` when applying
  √ to a negative bare operand in Infix mode (now shows "Error")
- [x] Move √ and % to RPN MAIN deck for immediate access (were in STACK deck)
- [x] Add core test: `sqrt of negative bare operand sets error instead of throwing`
- [x] Update widget test to cover direct sqrt(-1) without ENTER

---

## Stage 6 — "Lateral Numbers" (0.6.x)

Complex number support via Gauss's matrix representation. The imaginary unit $i$
is encoded as the 2×2 real matrix $J = [[0, -1], [1, 0]]$ satisfying $J^2 = -I$.
A complex number $a + bi$ is the matrix $aI + bJ = [[a, -b], [b, a]]$. All existing matrix operations
(multiplication, inverse, determinant, transpose) naturally yield correct complex
arithmetic without a separate Complex type.

### v0.6.0 — Imaginary unit constant and algebraic verification

- [x] Add `Matrix.i` static constant: `[[0, -1], [1, 0]]`
- [x] Test suite verifying all imaginary unit axioms:
  - $i^2 = -I$, $i^3 = -i$, $i^4 = I$ (periodicity)
  - $\det(i) = 1$ (unit norm)
  - $i^{-1} = -i$, $i^T = -i$
  - Complex multiplication: $(aI + bi)(cI + di) = (ac-bd)I + (ad+bc)i$
  - Commutativity, distributivity
  - Conjugate via transpose: $(aI + bJ)^T = aI - bJ$
  - Modulus: $z \cdot z^* = |z|^2 I$
  - Matrix form: $aI + bJ = [[a, -b], [b, a]]$

### v0.6.1 — 5-column keypad layout

Restructure the fixed button grid from 4 to 5 columns, integrating essential
operations (√, INV, ⌫, ENTER) into the permanent grid instead of requiring
deck navigation.

New layout:
```
 7   8   9   ÷   INV
 4   5   6   ×    √
 1   2   3   -    ⌫
 0   .   ±   +  ENTER
```

- [x] Change `_columnCount` from 4 to 5
- [x] Update `_fixedBottomButtons` to include 5th column (INV, √, ⌫, ENTER)
- [x] Move ± into fixed grid (row 4, col 3); remove from deck
- [x] Move ENTER to 5th column (row 4, col 5)
- [x] Adjust `_shellMaxWidth` for wider grid
- [x] Update deck definitions (remove buttons now in fixed grid)
- [x] Add INV as immediate unary operation in Infix mode
- [x] Label button as `=` in Infix and `ENTER` in RPN
- [x] Update widget tests for new button positions

### v0.6.2 — sqrt(-1) returns Matrix.i

- [x] Change `Matrix.squareRoot()` to return `Matrix.i` for scalar -1
- [x] Generalize: sqrt of negative scalar $-k$ returns $\sqrt{k} \cdot i$
- [x] Add I and J preset buttons in matrix editor EDIT deck
- [x] Add `Matrix.isComplexForm` getter (detects $[[a,-b],[b,a]]$ pattern)
- [x] Add `Matrix.realPart` / `Matrix.imagPart` extraction
- [x] Add `Matrix.complex(double re, double im)` factory
- [x] Update display formatting: show `a + bi` when matrix matches complex form

### v0.6.3 — Complex arithmetic in calculator

- [x] Add `i` button to keypad (Infix and RPN)
- [x] Scalar promotion: when adding/subtracting/multiplying 1×1 with n×n square, promote scalar to $k \cdot I_n$
- [x] Input `3+2i` parsed as `3I + 2J` internally (via scalar promotion + `i` button)
- [x] Display complex results in `a + bi` notation (done in v0.6.2)
- [x] Complex conjugate button (CONJ = transpose for complex-form matrices)

### v0.6.4 — Complex functions (planned)

- [ ] Complex exponential via matrix exponential: $e^{θi}$
- [ ] Euler's formula verification: $e^{πi} + I = 0$
- [ ] Complex logarithm
- [ ] Polar form display: $r∠θ$

---

## General Backlog

- Performance profiling
- Observability (metrics, tracing)
- Visual themes / dark mode
- History export
- PWA / offline mode
