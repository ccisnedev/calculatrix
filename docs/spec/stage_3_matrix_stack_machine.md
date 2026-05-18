# Stage 3 Matrix Stack Machine Specification

Status: Draft
Owner: Calculatrix maintainers
Target release series: v0.3.0 foundation plus v0.3.x improvements
Primary package: calculatrix
Primary surfaces: code/core, code/app, code/cli
Companion roadmap entry: docs/roadmap.md Stage 3
Companion architecture note: docs/architecture.md
Companion release specification: docs/spec/v0_3_0_matrix_stack_machine.md
Companion API specification: docs/spec/v0_3_0_matrix_stack_machine_api.md
Companion TDD plan: docs/spec/v0_3_0_matrix_stack_machine_tdd.md

## 1. Purpose

This document defines the Stage 3 architectural reset for Calculatrix.

Stage 3 no longer assumes that advanced linear algebra is the next isolated
increment over a finished late-v0.2 shell. Instead, Stage 3 redefines the core
product around one canonical execution model:

1. All runtime values are matrices.
2. All computation executes through a matrix-first stack machine.
3. Public commands and public macros live in package:calculatrix.
4. Infix is a convenience entry surface over the same stack kernel.
5. The app shell may expose multiple complementary modes without implying
   multiple semantic engines.

The end state is one coherent product where:

1. Advanced users can operate directly on public RPN commands.
2. Infix users can type algebra-style input that compiles to the same kernel.
3. Matrix users can create and edit matrices through a dedicated workstation
   surface that still delegates real operations to the same public core APIs.

## 2. Scope

### 2.1 In scope for Stage 3

1. Redefine package:calculatrix as a canonical matrix stack machine.
2. Expose typed public APIs for primitive commands and public macros.
3. Keep all runtime values matrix-first, including scalars as 1x1 matrices.
4. Treat infix as compilation or convenience execution over the same stack
   semantics instead of as a separate semantic engine.
5. Expose public matrix creation helpers and structural matrix commands in the
   core package.
6. Replace the app-side modal matrix editor with a dedicated Matrix shell mode.
7. Keep advanced users able to access the same command set directly from RPN
   mode.
8. Add CLI parity for public commands, macros, and infix convenience entry.
9. Refresh architecture, docs, and QA around the new canonical core model.

### 2.2 Out of scope for Stage 3

1. Determinant, LU, QR, and other advanced linear algebra features that do not
   unblock the new shell/kernel model.
2. Symbolic algebra or a full CAS with variables, simplification, or symbolic
   transforms.
3. Sparse-matrix data structures.
4. Unlimited spreadsheet-style GUI editing beyond the bounded educational
   workstation scope.
5. Multi-document workflows or persistent matrix notebooks.

## 3. Baseline Product Contract

Stage 3 supersedes the late-v0.2 assumption that the app owns a dedicated modal
matrix editor while the core owns only infix and RPN semantics.

After Stage 3:

1. The core owns the canonical matrix stack semantics.
2. The core publishes commands and macros as part of its supported public API.
3. The app owns only presentation, drafts, focus, selection, and accessibility.
4. The CLI remains a thin adapter over the same public core APIs.
5. No user-facing matrix workflow may depend on app-local math or app-local
   structural mutation rules once a command is committed.

## 4. Design Principles

1. Canonical kernel first: one semantic engine, many entry surfaces.
2. Matrix-only runtime truth: every committed value is a Matrix.
3. Stack-first execution: primitive execution always flows through a stack
   machine model.
4. Public-command discipline: real commands and shipping macros must be public
   API, not private UI tricks.
5. Infix as translation: algebra-style input is compiled or translated into
   stack execution.
6. Consumer-local drafts: incomplete text editing remains outside the core.
7. Shell coherence: multiple visible modes do not imply multiple calculators.
8. Advanced-user parity: anything friendly in Matrix mode must also exist as a
   real core command or public macro reachable from RPN workflows.

## 5. Canonical Core Model

### 5.1 Runtime truth

The canonical runtime model is:

1. A stack of Matrix values.
2. A public vocabulary of primitive commands.
3. A public catalog of macros that expand into primitive command sequences or
   execute through the same public kernel.
4. Optional convenience frontends such as infix evaluation or textual command
   parsing.

No committed operation may bypass that model.

### 5.2 Core semantic layers

The public API must expose typed equivalents of the following conceptual roles.
Exact type names may change, but the roles themselves are part of the Stage 3
contract.

1. Matrix value API.
2. Stack machine API.
3. Primitive command API.
4. Public macro API.
5. Infix compiler or infix convenience evaluation API.
6. Optional interactive session facade built on top of the same stack kernel.

### 5.3 Primitive command families

At minimum, Stage 3 must support public primitive commands for these families.

#### 5.3.1 Stack manipulation

1. dup
2. drop
3. swap
4. over
5. pick
6. roll
7. rot

#### 5.3.2 Push and construction

1. Push scalar literal.
2. Push matrix literal.
3. Push zeros matrix by explicit shape.
4. Push ones matrix by explicit shape.
5. Push identity matrix by explicit size.

#### 5.3.3 Unary matrix commands

1. Negate.
2. Percent.
3. Square root.
4. Transpose.
5. Inverse.

#### 5.3.4 Binary matrix commands

1. Add.
2. Subtract.
3. Multiply.
4. Divide under the documented matrix-domain restrictions.
5. Append row from a compatible right-hand row operand.
6. Append column from a compatible right-hand column operand.

#### 5.3.5 Parameterized structural commands

These commands operate on the top matrix with explicit parameters and do not
depend on hidden GUI state.

1. Delete row by index.
2. Delete column by index.
3. Duplicate row by index.
4. Duplicate column by index.
5. Move row from index A to index B.
6. Move column from index A to index B.

### 5.4 Public macro families

Macros are public product features, not private UI shortcuts.

Stage 3 must expose public macros for at least these workflows:

1. Replace current work matrix with zeros of the current visible shape.
2. Replace current work matrix with ones of the current visible shape.
3. Append a zero row to the bottom of the current work matrix.
4. Append a zero column to the right of the current work matrix.
5. Create a new identity matrix for a chosen square size.

Macro contract:

1. A macro may inspect explicit context required by its documented contract,
   such as the current top matrix shape.
2. A macro must still execute through public kernel operations.
3. A macro must be available to non-GUI consumers through public APIs.
4. A macro must be testable in code/core without any app dependency.

### 5.5 Infix contract

Infix remains supported, but its role changes from semantic peer to frontend.

Rules:

1. Infix input denotes a program over the same matrix stack kernel.
2. evaluateInfix may remain as a convenience API.
3. The implementation may compile infix text to a typed program or to an
   intermediate RPN token stream before execution.
4. Infix execution must never bypass the same command semantics used by direct
   stack workflows.
5. Matrix literals remain valid infix operands.
6. For any supported expression E, infix evaluation must be semantically
   equivalent to executing the compiled stack program for E.

### 5.6 Interactive session facade

If the core keeps an interactive session facade, that facade must sit above the
canonical kernel instead of introducing a second semantic center.

Rules:

1. A session may keep transient drafts for convenience.
2. A session may expose convenience helpers for app and CLI consumers.
3. A session must not redefine command semantics outside the stack kernel.
4. A session must not require GUI-only concepts such as focused cell, selected
   row, or open tray state.
5. A session may treat infix draft entry as a convenience surface that compiles
   into stack execution.

## 6. Consumer Boundary

### 6.1 App responsibilities

The app owns:

1. Shell mode selection.
2. Keypad layout and page organization.
3. Matrix workstation layout.
4. Local drafts for incomplete cell text.
5. Selection, focus, cursor movement, and drag affordances.
6. Accessibility semantics and visual feedback.

The app does not own:

1. Primitive command semantics.
2. Macro semantics.
3. Matrix structural semantics after commit.
4. Any committed-value math rule.

### 6.2 CLI responsibilities

The CLI owns:

1. Argument parsing.
2. Command routing.
3. Human-readable output.
4. Exit behavior.

The CLI does not own alternate math semantics.

## 7. App Shell Contract for Stage 3

The app presents three complementary shell modes:

1. Infix.
2. RPN.
3. Matrix.

These are product surfaces, not distinct semantic engines.

### 7.1 Infix mode

Infix is the algebra-style entry surface.

Rules:

1. The user edits algebra-style expressions as text.
2. Confirming evaluation compiles and executes that text against the canonical
   matrix stack kernel.
3. Infix mode behaves like a calculator algebra workspace, not like a symbolic
   CAS.

### 7.2 RPN mode

RPN is the direct-command surface for advanced users.

Rules:

1. RPN mode exposes direct stack actions and direct command execution.
2. Any matrix command or macro made friendly in Matrix mode must remain
   reachable from RPN workflows.
3. Advanced users must be able to stay entirely inside RPN mode if desired.

### 7.3 Matrix mode

Matrix mode is the friendly workstation for matrix creation and editing.

Rules:

1. Matrix mode replaces the modal matrix dialog.
2. Matrix mode is a full shell surface inside the calculator body.
3. Matrix mode edits a local work draft, but committed actions delegate to
   public core commands or public core macros.
4. Matrix mode may show a matrix-focused keyboard page set while preserving the
   same shell geometry and overall product identity.

## 8. Matrix Workstation Contract

### 8.1 Work target

The workstation edits one matrix work target at a time.

Rules:

1. If the committed current value is a supported visible matrix, Matrix mode may
   seed the draft from that value.
2. If no committed matrix is available, Matrix mode may open a default bounded
   draft such as 2x2.
3. The GUI draft may temporarily contain incomplete or invalid text.

### 8.2 Commit-before-execute

Before any real command or macro executes against the work target:

1. The local draft must be validated.
2. If valid, the draft is committed into the canonical core representation.
3. If invalid, the command is blocked and the error remains local to the
   workstation.

### 8.3 Matrix-mode keyboard

Matrix mode uses dedicated keyboard pages while preserving the same calculator
shell metaphor.

At minimum, the matrix keyboard must expose access to:

1. Inverse.
2. Transpose.
3. Zeros.
4. Ones.
5. Add row.
6. Add column.
7. Clear or equivalent draft reset affordance.
8. Numeric cell entry support.

### 8.4 Macro semantics in Matrix mode

Friendly buttons in Matrix mode are defined by core macros or core commands.

Examples:

1. Add column means: create a compatible zero column and execute append-column
   semantics through the public core API.
2. Add row means: create a compatible zero row and execute append-row semantics
   through the public core API.
3. Zeros means: replace the current work matrix with a same-shape zero matrix
   through a public macro or equivalent public command sequence.
4. Ones means: replace the current work matrix with a same-shape one matrix
   through a public macro or equivalent public command sequence.
5. Transpose and inverse are real unary commands, not GUI-only mutations.

### 8.5 Bounded GUI scope

The Stage 3 app workstation may remain visually optimized for the bounded
educational matrix scope used in late v0.2.x.

Rules:

1. The core remains matrix-general.
2. The GUI may continue to optimize around small visible matrices such as up to
   4x4 in its primary editing surface.
3. Bounded GUI visibility does not justify app-local command semantics.

## 9. Public API Expectations

Stage 3 does not lock exact type names, but it does require public API
capabilities equivalent to these examples.

```dart
abstract interface class CalculatrixMachine {
  int get depth;
  Matrix? get top;
  List<Matrix> get stackSnapshot;

  void execute(CalculatrixCommand command);
  void executeAll(Iterable<CalculatrixCommand> program);
}

abstract interface class CalculatrixCommand {}

abstract interface class CalculatrixMacro {
  Iterable<CalculatrixCommand> expand(CalculatrixMachine machine);
}
```

Contract notes:

1. Primitive commands must be typed.
2. Parameterized commands must carry their explicit indices or sizes.
3. Macros must be executable through public APIs.
4. Public convenience string parsers are allowed, but typed APIs are required.

## 10. QA and TDD Contract

### 10.1 Validation order

1. Core command and macro contracts in code/core.
2. Infix-to-stack parity coverage in code/core.
3. Session-facade coverage if a session facade remains public.
4. App shell mode coverage.
5. Matrix workstation widget and integration coverage.
6. CLI command and macro parity coverage.

### 10.2 Minimum acceptance checklist

- [ ] Public core APIs expose typed primitive commands.
- [ ] Public core APIs expose shipping macros.
- [ ] Infix evaluation is documented and tested as a frontend to the canonical stack kernel.
- [ ] The app exposes Infix, RPN, and Matrix as complementary shell modes.
- [ ] The modal matrix dialog is removed from the primary product workflow.
- [ ] Matrix-mode friendly actions delegate to public core commands or macros.
- [ ] Advanced users can execute the same matrix workflows directly from RPN mode.
- [ ] CLI consumers can reach public commands or macros without app-only logic.

## 11. Release Partition Inside Stage 3

### 11.1 v0.3.0 baseline

v0.3.0 establishes the new canonical architecture.

It must include:

1. Matrix stack machine as the core semantic center.
2. Public command and macro APIs.
3. Infix as translation or convenience execution over that kernel.
4. Matrix shell mode in the app replacing the modal editor.
5. Direct RPN access to the same command vocabulary.
6. Core-backed inverse and transpose in the shipping workflow.

### 11.2 v0.3.x improvements

Post-0.3 releases may add:

1. Additional command packs and workflow macros.
2. Matrix workstation ergonomics and polish.
3. CLI scripting improvements over the same public command layer.
4. Non-breaking command-surface expansions consistent with SemVer.

## 12. Deferred to Stage 4

The following belong to the next major stage after the kernel and shell reset:

1. Determinant.
2. LU decomposition.
3. QR decomposition.
4. Eigenvalues and eigenvectors.
5. Additional advanced factorizations.
6. Sparse-matrix-oriented workflows.