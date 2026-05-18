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

#### v2.12.0 — Matrix Editor UX Refinement

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

#### v2.13.0 — Matrix Row/Column List Editor UX

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

## Stage 3 — "Canonical Matrix Stack Machine" (2.x.x → 3.0.0)

Stage 3 is an architectural reset, not only an advanced-linear-algebra pass.
The product is redefined around one canonical matrix stack machine in
package:calculatrix, with infix treated as a convenience frontend and Matrix as
an app shell mode instead of a modal editor.

Current status: most kernel-level Stage 3 work is already merged on the `v2.x`
line and the release gate is now closed: `v3.0.0` has aligned public docs,
versioning, changelog entries, and green validation across core, app, and CLI.

Companion specification: docs/spec/stage_3_matrix_stack_machine.md

### v2.x.x → v3.0.0

- [x] Reframe package:calculatrix around a public matrix stack machine kernel
- [x] Expose typed public APIs for primitive commands and public macros
- [x] Keep all committed runtime values matrix-first and execute all committed operations through stack semantics
- [x] Treat infix as translation or convenience evaluation over the same stack kernel instead of as a separate semantic engine
- [x] Expose public matrix creation, structural editing, transpose, inverse, zeros, ones, and stack-native workflow commands in the core package
- [x] Replace the app-side modal matrix editor with a dedicated Matrix shell mode and matrix-focused keyboard pages
- [x] Keep advanced users able to access the same command vocabulary directly from RPN mode
- [x] Add CLI parity for public commands, public macros, and infix convenience execution
- [x] Refresh architecture, docs, and QA around the new canonical core model

#### v2.14.0 — Stage 3 Closure and Release Hardening

- [x] Fix the failing Matrix structural add-row interaction so compact affordances remain usable on the canonical integration target
- [x] Complete end-to-end coverage for add-row, reorder-row, and one mixed row+column structural confirmation flow
- [x] Resolve remaining Matrix shell release-polish regressions, including mode-accurate copy and shell-state feedback
- [x] Keep direct RPN workflows aligned with the same public command vocabulary already exposed by core and CLI
- [x] Refresh top-level docs and user guides around the matrix stack machine, public commands/macros, and the infix-over-stack contract
- [x] Define and run the release-grade validation matrix for core, app, and CLI before the major-version cut
- [x] Prepare `v3.0.0` release inputs only after executable validation is green: version bumps, changelog, and stable release notes

##### Execution Order

- [x] Step 1: reproduce and lock the failing add-row structural interaction with a narrow regression check on the canonical integration path
- [x] Step 2: repair Matrix structural hit-target/state issues and prove add-row plus reorder flows on the release target
- [x] Step 3: add the missing mixed row+column structural confirmation flow and close remaining unstable app checks where practical
- [x] Step 4: finish shell parity for RPN/Matrix command access and mode-accurate UI copy
- [x] Step 5: refresh README/public docs, run release validation across core/app/cli, and then cut the `v3.0.0` release artifacts

### v3.0.0 — Stable Release

Release gate note: closed. The project now ships with aligned `v3.0.0`
versioning, updated public docs, current changelog entries, and green
validation across `code/core`, `code/cli`, and `code/app` including the
Windows integration suite.

Entry criterion: satisfied.

- [x] One canonical matrix stack machine core with public command and macro APIs
- [x] Three complementary app shell modes: Infix, RPN, Matrix
- [x] Matrix workstation replaces the modal editor and delegates real operations to public core commands or macros
- [x] Public documentation for commands, macros, and the infix-over-stack contract

### v3.x.x — Improvements and fixes on top of v3

- Additional command packs and workflow macros
- Matrix workstation ergonomics and shell polish
- CLI scripting and programmable-workflow improvements over the same public core command layer

#### v3.0.1 — Calculator Interaction Corrections and Unified Keypad

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

## Stage 4 — "Advanced Linear Algebra on Canonical Stack Kernel" (3.x.x → 4.0.0)

Stage 4 builds advanced linear algebra on top of the already-stable matrix
stack machine and the Stage 3 shell/workstation architecture.

Readiness gate: ready. Stage 3 is now declared stable at `v3.0.0`, so Stage 4
can start on top of the canonical kernel and the validated three-mode shell.

### v3.x.x → v4.0.0

- [x] Determinant
- [x] LU decomposition
- [x] QR decomposition
- [ ] Extend display and interaction polish for complex advanced matrix workflows
- [ ] Extended linear algebra tests over the canonical stack kernel
- [ ] End-to-end workflows combining matrix creation, notation switching, commands, macros, and advanced operations

#### v3.1.0 — Determinant on the Canonical Stack Kernel

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

#### v3.2.0 — LU and QR Decompositions on the Canonical Stack Kernel

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

### v4.0.0 — Stable Release

- [ ] Calculator UX with canonical matrix shell modes and advanced linear algebra over the shared core
- [ ] Advanced matrix operations documentation

### v4.x.x — Improvements and fixes on top of v4

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
