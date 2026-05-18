# v0.3.0 Matrix Stack Machine Release Specification

Status: Draft
Owner: Calculatrix maintainers
Target release: v0.3.0
Primary package: calculatrix
Primary surfaces: code/core, code/app, code/cli
Companion stage specification: docs/spec/stage_3_matrix_stack_machine.md
Companion roadmap entry: docs/roadmap.md Stage 3
Companion architecture note: docs/architecture.md
Companion API specification: docs/spec/v0_3_0_matrix_stack_machine_api.md
Companion TDD plan: docs/spec/v0_3_0_matrix_stack_machine_tdd.md

## 1. Purpose

This document defines the release-grade specification for v0.3.0.

v0.3.0 establishes Calculatrix around one canonical semantic center:

1. The core package is a matrix-first stack machine.
2. All committed runtime values are matrices.
3. Public primitive commands and public macros live in package:calculatrix.
4. Infix is a convenience frontend over that same kernel.
5. The app shell exposes three complementary product modes: Infix, RPN, Matrix.

This release is not a minor UX refinement of the late-v0.2 matrix editor.
It is the major reset that makes the shared core, the app shell, and the CLI
all describe the same product model.

## 2. Release Goals

v0.3.0 must achieve all of the following.

1. Remove the semantic split between interactive matrix editing and committed
   matrix commands.
2. Make advanced-user RPN workflows first-class instead of app-only hidden
   plumbing.
3. Keep infix workflows available without letting infix become a separate math
   engine.
4. Replace the modal matrix editor with a matrix workstation integrated into the
   calculator shell.
5. Ship a public core API that non-GUI consumers can use directly.

## 3. Non-Goals

The following are explicitly outside v0.3.0.

1. Determinant.
2. LU decomposition.
3. QR decomposition.
4. Symbolic algebra or variable handling.
5. Sparse matrices.
6. Unlimited spreadsheet-scale visual editing.

## 4. Core Product Statement

The canonical product model for v0.3.0 is:

1. One matrix stack machine kernel in package:calculatrix.
2. One public vocabulary of primitive commands.
3. One public vocabulary of shipping macros.
4. One infix convenience surface that compiles or translates to that kernel.
5. Multiple consumer views over the same semantics.

Corollaries:

1. The app is not allowed to invent committed matrix operations that the core
   does not expose publicly.
2. The CLI is not allowed to implement alternate semantics for commands that
   already exist in the core.
3. The modal matrix dialog is no longer the primary model for matrix creation.

## 5. Canonical Core Contract

### 5.1 Runtime truth

Committed runtime truth is always expressed as:

1. A stack of Matrix values.
2. Primitive command execution against that stack.
3. Macro expansion or macro execution through the same command layer.

No committed computation path may bypass this model.

### 5.2 Matrix domain

Matrix remains the only committed value type.

Rules:

1. Scalars are represented as 1x1 matrices.
2. Vectors are matrices.
3. Non-square matrices are first-class values.
4. Shape errors are part of domain semantics, not UI validation hacks.
5. Public command semantics must remain matrix-first even when a consumer shows
   scalar-friendly text.

### 5.3 Primitive command contract

Primitive commands are the smallest public semantic units that mutate or query
the matrix stack machine.

Rules:

1. Primitive commands must be typed public APIs.
2. Primitive commands must be testable directly in code/core.
3. Primitive commands must not depend on hidden app state.
4. Parameterized commands must carry their own explicit indices, sizes, or
   shape arguments.

#### 5.3.1 Required stack commands

v0.3.0 must keep or expose direct public equivalents for:

1. dup
2. drop
3. swap
4. over
5. pick
6. roll
7. rot

#### 5.3.2 Required construction commands

v0.3.0 must expose direct public equivalents for:

1. push scalar literal
2. push matrix literal
3. push zeros matrix by explicit shape
4. push ones matrix by explicit shape
5. push identity matrix by explicit square size

#### 5.3.3 Required unary matrix commands

v0.3.0 must expose direct public equivalents for:

1. negate
2. percent
3. square root
4. transpose
5. inverse

#### 5.3.4 Required binary matrix commands

v0.3.0 must expose direct public equivalents for:

1. add
2. subtract
3. multiply
4. divide with the documented matrix-domain restriction
5. append row from a compatible right operand
6. append column from a compatible right operand

#### 5.3.5 Required parameterized structural commands

v0.3.0 must expose direct public equivalents for:

1. delete row by index
2. delete column by index
3. duplicate row by index
4. duplicate column by index
5. move row from index A to index B
6. move column from index A to index B

### 5.4 Public macro contract

Macros are public release features.

Rules:

1. A macro may expand into primitive commands.
2. A macro may inspect explicit machine state required by its own documented
   contract.
3. A macro must remain accessible to app, CLI, tests, and future consumers.
4. A macro must never be a GUI-only shortcut with hidden semantics.

#### 5.4.1 Required shipping macros

v0.3.0 must ship public equivalents for at least these workflows:

1. Replace current work matrix with same-shape zeros.
2. Replace current work matrix with same-shape ones.
3. Append a zero row to the bottom of the current work matrix.
4. Append a zero column to the right of the current work matrix.
5. Create a fresh identity matrix for a chosen square size.

### 5.5 Infix contract

Infix remains part of the public product, but it is no longer treated as a
second semantic engine.

Rules:

1. Infix input denotes a program over the matrix stack kernel.
2. The core may implement infix by compiling to typed commands or to an
   intermediate RPN-like program.
3. The public evaluateInfix entrypoint may remain as a convenience API.
4. Infix and direct-command execution must be semantically equivalent for the
   same supported operation set.
5. Infix parsing errors are syntax-level concerns only; the underlying matrix
   domain semantics remain shared.

### 5.6 Session-facade contract

If a session facade remains public in v0.3.0, it must be an adapter over the
canonical kernel, not a second center of truth.

Rules:

1. Drafts may exist for consumer convenience.
2. Drafts are transient, not committed values.
3. A session helper may route commands and macros, but it must not redefine
   them.
4. GUI-only concepts such as selected cell, open action tray, or drag hover are
   forbidden inside the core session model.

## 6. Public API Expectations

v0.3.0 does not freeze exact class names in this specification, but it does
freeze the capability level required from the public API.

### 6.1 Required API roles

The package must expose typed public equivalents of these roles:

1. Matrix value API.
2. Matrix stack machine API.
3. Primitive command API.
4. Public macro API.
5. Infix convenience execution or infix compilation API.
6. Optional interactive session facade API.

### 6.2 Required API qualities

1. Public primitive commands must be typed, not stringly-typed only.
2. Public macros must be invokable from code without a GUI dependency.
3. Public convenience parsers may exist, but they do not replace the typed
   command layer.
4. SemVer-facing surface changes must be intentional and documented.

### 6.3 Illustrative API shape

The following examples are illustrative only, but the public API must provide
equivalent capabilities.

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

## 7. App Shell Contract

### 7.1 Product shell

The app remains one calculator shell.

Rules:

1. The app exposes three complementary modes: Infix, RPN, Matrix.
2. These are shell modes, not independent calculators.
3. The current committed value model remains shared across shell surfaces.
4. Switching shell modes must not silently rewrite committed semantics.

### 7.2 Infix mode

Infix mode is the algebra-style entry surface.

Rules:

1. The user edits algebra-style text.
2. Confirming evaluation delegates to the canonical core infix entry.
3. Infix mode behaves like an algebraic calculator workspace, not a symbolic
   CAS.

### 7.3 RPN mode

RPN mode is the direct-command surface.

Rules:

1. RPN mode exposes direct stack operations.
2. RPN mode must expose access to the same command vocabulary needed by
   advanced users.
3. Any shipping matrix workflow in Matrix mode must remain reachable from RPN
   mode through commands or macros.

### 7.4 Matrix mode

Matrix mode is the friendly matrix workstation.

Rules:

1. Matrix mode replaces the modal matrix editor.
2. Matrix mode is part of the main shell, not an external dialog workflow.
3. Matrix mode may keep local drafts for incomplete cell editing.
4. Committed matrix operations in Matrix mode must delegate to public core
   commands or public core macros.

## 8. Matrix Workstation Contract

### 8.1 Work target

The workstation edits one active matrix work target at a time.

Rules:

1. The work target may be seeded from the committed current matrix value.
2. If no suitable committed matrix exists, the workstation may create a default
   bounded draft such as 2x2.
3. The local draft may be temporarily invalid while the user is typing.

### 8.2 Commit-before-execute rule

Before any real command or macro executes from Matrix mode:

1. The local draft must be validated.
2. If valid, the draft is committed into the core representation.
3. If invalid, the action is blocked and the error remains local to the
   workstation.

### 8.3 Matrix keyboard contract

Matrix mode uses dedicated keyboard pages while preserving the same calculator
shell metaphor.

The matrix keyboard must expose access to at least:

1. inverse
2. transpose
3. zeros
4. ones
5. add row
6. add column
7. clear or equivalent draft reset action
8. numeric entry for cell editing

### 8.4 Friendly-action contract

Friendly actions in Matrix mode are wrappers over public core semantics.

Examples:

1. Add column creates a compatible zero column and executes append-column
   behavior through the public core layer.
2. Add row creates a compatible zero row and executes append-row behavior
   through the public core layer.
3. Zeros replaces the current work matrix with a same-shape zero matrix through
   a public macro or equivalent public command sequence.
4. Ones replaces the current work matrix with a same-shape one matrix through a
   public macro or equivalent public command sequence.
5. Inverse and transpose are real commands, not GUI-only mutations.

### 8.5 Bounded GUI scope

The app workstation may remain optimized for the bounded educational editing
surface established in late v0.2.x.

Rules:

1. The core stays matrix-general.
2. The GUI may continue to optimize around small visible matrices such as up to
   4x4.
3. A bounded visible editor does not justify app-local command semantics.

## 9. CLI Contract

v0.3.0 CLI must remain a thin adapter over the same public core APIs.

Rules:

1. The CLI must be able to invoke public commands.
2. The CLI must be able to invoke public macros.
3. The CLI may expose infix convenience entry through the core infix contract.
4. The CLI must not contain private math semantics absent from the core.

## 10. Migration Contract from Late v0.2.x

### 10.1 Preserved truths

1. Matrix remains the universal committed value model.
2. Infix remains available to end users.
3. RPN remains available to end users.
4. App and CLI remain thin consumers of the shared core.

### 10.2 Explicitly replaced behaviors

1. The modal matrix dialog is replaced by Matrix shell mode.
2. Matrix creation and structural editing stop being primarily literal-serialization workflows.
3. The core is no longer described as merely Infix plus RPN semantics; it is
   now a matrix stack machine with convenience frontends.

## 11. Acceptance Criteria for v0.3.0

v0.3.0 is complete only when all of the following are true.

1. package:calculatrix exposes a public matrix stack machine kernel.
2. package:calculatrix exposes typed primitive commands.
3. package:calculatrix exposes shipping macros as public API.
4. Infix is documented and tested as a frontend to the same kernel.
5. The app exposes Infix, RPN, and Matrix shell modes.
6. The modal matrix editor is removed from the primary workflow.
7. Matrix-mode friendly actions delegate to public core commands or macros.
8. Advanced users can perform the same workflows directly from RPN mode.
9. CLI parity exists for commands, macros, and infix convenience execution.
10. Architecture and docs reflect the canonical kernel model.

## 12. TDD Readiness Gate

The project is considered ready to start TDD for v0.3.0 when all of the
following are true.

1. The semantic center is agreed: matrix stack machine core.
2. The shell contract is agreed: Infix, RPN, Matrix.
3. The public-command principle is agreed: no GUI-only committed semantics.
4. The public-macro principle is agreed: shipping macros belong to the core.
5. The Stage 4 boundary is agreed: determinant, LU, QR stay deferred.
6. The first executable slice can be named without ambiguity.

### 12.1 Current readiness assessment

Assessment: ready to start TDD.

Reasoning:

1. The semantic model is now explicit in docs/spec/stage_3_matrix_stack_machine.md.
2. The release contract is now explicit in this v0.3.0 specification.
3. The roadmap and architecture documents are aligned with the same model.

### 12.2 Recommended first TDD slice

Start with the core package, not the app.

Recommended first slice:

1. Introduce the typed public command layer and machine façade in code/core.
2. Prove parity for existing stack commands through the new command path.
3. Add the first public matrix-specific commands that unblock the rest of the
   release: transpose, inverse, push-zeros, push-ones, append-row,
   append-column.

Do not start with the Matrix shell UI.

## 13. Deferred to Post-v3 Work

The following remain outside this release.

1. Determinant.
2. LU decomposition.
3. QR decomposition.
4. Eigenvalues and eigenvectors.
5. Sparse-matrix-oriented workflows.