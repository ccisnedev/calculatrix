# v3.0.0 Matrix Stack Machine TDD Plan

Status: Draft
Owner: Calculatrix maintainers
Target release: v3.0.0
Primary package: calculatrix
Primary surfaces: code/core, code/app, code/cli
Companion release specification: docs/spec/v3_0_0_matrix_stack_machine.md
Companion API specification: docs/spec/v3_0_0_matrix_stack_machine_api.md
Companion stage specification: docs/spec/stage_3_matrix_stack_machine.md

## 1. Purpose

This document translates the v3.0.0 release specification into an executable
TDD plan.

The goal is to land the matrix stack machine architecture without drifting into
UI-first implementation or app-local semantics.

## 2. Current Implementation Anchors

The current code already contains useful seams, but they represent the late-v2
model and must be treated as starting points rather than final architecture.

### 2.1 Core anchors

1. Matrix domain: code/core/lib/src/matrix/matrix.dart
2. Low-level stack engine: code/core/lib/src/rpn/rpn_engine.dart
3. Infix and RPN facade: code/core/lib/src/evaluation/calculatrix.dart
4. Interactive session facade: code/core/lib/src/session/calculatrix_session.dart
5. Existing core tests: code/core/test/**

Important baseline facts:

1. The runtime domain is already matrix-first.
2. Infix already lowers into RPN-like execution rather than using a fully
   separate math engine.
3. The public API does not yet expose typed commands or public macros.
4. Structural matrix editing commands do not yet exist in the core.

### 2.2 App anchors

1. Presentation adapter: code/app/lib/modules/calc/controller.dart
2. Main shell and keypad wiring: code/app/lib/modules/calc/view.dart
3. Local matrix draft state: code/app/lib/modules/calc/matrix_editor_draft.dart
4. Existing app unit and widget tests: code/app/test/modules/calc/**
5. Existing Android integration tests: code/app/integration_test/calculator_test.dart

Important baseline facts:

1. The app still models only Infix and RPN at the controller level.
2. Matrix editing still enters through a modal dialog.
3. Local matrix drafting already supports incomplete text and bounded structural
   edits, which is still useful for Matrix mode.

### 2.3 CLI anchors

1. CLI entrypoint: code/cli/bin/calculatrix_cli.dart
2. CLI tests: code/cli/test/calculatrix_cli_test.dart

Important baseline facts:

1. The CLI currently routes only infix and tokenized RPN evaluation.
2. The CLI does not yet expose public commands or macros from the future v3
   core API.

## 3. TDD Policy for This Release

Execution must remain kernel-first.

Rules:

1. Do not start with the app Matrix shell UI.
2. Lock the typed command layer before broad UI refactors.
3. Prove parity for existing RPN behavior through the new public command path
   before adding new command families.
4. Add macros only after primitive commands are locked.
5. Rebase infix onto typed programs before redesigning the app shell around the
   new model.
6. Only after core parity is green should app and CLI migrate to the new API.

## 4. Recommended Validation Order

1. code/core unit and contract tests
2. code/core analyze
3. code/cli tests
4. code/app controller and widget tests
5. code/app integration tests

## 5. Behavioral Slices

### 5.1 Slice A: typed machine facade

Goal:

Introduce the public machine/program facade without changing observable stack
math yet.

Primary owner:

code/core

Tests to add first:

1. Executing a PushScalarCommand then AddCommand yields the same top value as
   the current engine path.
2. executeAll applies commands sequentially and leaves the expected stack
   snapshot.
3. top returns null on empty machine.
4. stackSnapshot is immutable from the consumer point of view.

Expected implementation impact:

1. New machine/program public types in code/core/lib/src/
2. New machine-focused tests in code/core/test/

### 5.2 Slice B: existing stack op parity through commands

Goal:

Preserve all current stack behavior through the new typed command path.

Primary owner:

code/core

Tests to add first:

1. DupCommand matches current dup behavior.
2. DropCommand matches current drop behavior.
3. SwapCommand matches current swap behavior.
4. OverCommand matches current over behavior.
5. PickCommand and RollCommand preserve current indexed stack behavior.
6. RotCommand matches current top-3 rotation behavior.
7. Existing binary and unary math via commands matches the old engine results.

Expected implementation impact:

1. New primitive command classes
2. Adapter path from commands into the current engine internals or their
   replacement
3. Compatibility preservation for existing core tests

### 5.3 Slice C: public construction commands

Goal:

Expose matrix construction through the command layer.

Primary owner:

code/core

Tests to add first:

1. PushZerosCommand creates the expected zero matrix for an explicit shape.
2. PushOnesCommand creates the expected one matrix for an explicit shape.
3. PushIdentityCommand creates the expected identity matrix.
4. Invalid size or shape is rejected with typed errors.

Expected implementation impact:

1. Matrix helpers or equivalent machine-side construction path
2. New command classes and tests

### 5.4 Slice D: unary matrix command expansion

Goal:

Expose required unary matrix commands through the canonical command layer.

Primary owner:

code/core

Tests to add first:

1. NegateCommand negates scalar and non-scalar matrices consistently.
2. PercentCommand scales matrices by 0.01 through the command path.
3. SqrtCommand matches existing square-root semantics.
4. TransposeCommand transposes square and non-square matrices.
5. InverseCommand inverts supported matrices and rejects singular or invalid
   ones with typed errors.

Expected implementation impact:

1. Public inverse exposure in matrix domain or equivalent command implementation
2. New unary command classes
3. New tests in code/core/test/matrix and machine-facing tests

### 5.5 Slice E: binary structural append commands

Goal:

Support stack-native structural growth through real binary commands.

Primary owner:

code/core

Tests to add first:

1. AppendRowCommand consumes a matrix and a compatible row operand and appends
   that row.
2. AppendColumnCommand consumes a matrix and a compatible column operand and
   appends that column.
3. Shape mismatches are rejected with typed errors.
4. The command result preserves existing values and the new structural unit.

Expected implementation impact:

1. Matrix helpers for append row and append column or equivalent command logic
2. New binary command classes and tests

### 5.6 Slice F: parameterized structural commands

Goal:

Expose row/column structural mutation without hidden GUI selection state.

Primary owner:

code/core

Tests to add first:

1. DeleteRowCommand removes the indexed row.
2. DeleteColumnCommand removes the indexed column.
3. DuplicateRowCommand inserts a copy after the indexed row.
4. DuplicateColumnCommand inserts a copy after the indexed column.
5. MoveRowCommand reorders rows without value corruption.
6. MoveColumnCommand reorders columns without value corruption.
7. Invalid indices throw MatrixIndexError.
8. Invalid structural end states throw typed shape or domain errors.

Expected implementation impact:

1. New structural matrix helpers or equivalent command implementations
2. New MatrixIndexError or equivalent typed error
3. New command classes and tests

### 5.7 Slice G: public macros

Goal:

Add the public macro layer over the primitive command vocabulary.

Primary owner:

code/core

Tests to add first:

1. FillZerosLikeTopMacro expands or executes to replace the top matrix with
   same-shape zeros.
2. FillOnesLikeTopMacro replaces the top matrix with same-shape ones.
3. AppendZeroRowMacro appends a compatible zero row.
4. AppendZeroColumnMacro appends a compatible zero column.
5. CreateIdentityMacro pushes the requested identity matrix.
6. Macro behavior is available without app or CLI dependencies.

Expected implementation impact:

1. New macro types and tests
2. Macro expansion helpers or execution helpers in core

### 5.8 Slice H: infix compilation rebased onto typed programs

Goal:

Make infix formally a frontend to the new typed command layer.

Primary owner:

code/core

Tests to add first:

1. compileInfix returns a deterministic command program for a valid expression.
2. evaluateInfix matches the result of executing the compiled program.
3. Matrix literals survive compilation unchanged as operands.
4. Existing infix precedence and parenthesis behavior remains intact.
5. Existing evaluateRpn compatibility continues to work.

Expected implementation impact:

1. InfixCompiler or equivalent public API
2. Rebased Calculatrix facade implementation
3. New compile-focused tests plus existing evaluation parity tests

### 5.9 Slice I: session facade redesign

Goal:

Make the session a convenience adapter over the canonical machine rather than a
second semantic center.

Primary owner:

code/core

Tests to add first:

1. Session command routing leaves results identical to direct machine
   execution.
2. Session infix draft commits through compiled command execution.
3. Session RPN draft commits through machine execution.
4. Shared-current-value and memory behavior remain coherent after command-based
   mutations.
5. If CalculatrixEntryMode is introduced, the session exposes infix and rpn as
   entry frontends only.

Expected implementation impact:

1. calculatrix_session.dart
2. session tests
3. Potential mode enum rename or migration

### 5.10 Slice J: CLI command and macro parity

Goal:

Move the CLI from loose evaluation dispatch to public core command parity.

Primary owner:

code/cli

Tests to add first:

1. CLI still supports infix evaluation through the v3 core facade.
2. CLI still supports RPN token evaluation through compatibility paths.
3. CLI can invoke at least one public primitive command workflow.
4. CLI can invoke at least one public macro workflow.
5. CLI help reflects the new command vocabulary or routing model.

Expected implementation impact:

1. code/cli/bin/calculatrix_cli.dart
2. code/cli/test/calculatrix_cli_test.dart

### 5.11 Slice K: app shell mode expansion

Goal:

Upgrade the app shell from two modes to three complementary modes.

Primary owner:

code/app

Tests to add first:

1. The mode switch exposes Infix, RPN, and Matrix.
2. Switching to Matrix does not open a dialog.
3. Switching modes preserves the shared committed-value contract.
4. Existing Infix and RPN mode switching remains stable.

Expected implementation impact:

1. code/app/lib/modules/calc/controller.dart
2. code/app/lib/modules/calc/view.dart
3. app controller and widget tests

### 5.12 Slice L: matrix workstation shell migration

Goal:

Replace the modal editor with an integrated Matrix shell surface.

Primary owner:

code/app

Tests to add first:

1. MAT no longer launches the old modal workflow.
2. Matrix mode renders the workstation inside the shell body.
3. Existing draft initialization from a matrix value works in the new shell.
4. Invalid local drafts stay local and do not mutate the core until commit.

Expected implementation impact:

1. view.dart major refactor
2. Reuse or extract matrix draft code from matrix_editor_draft.dart
3. Widget contracts for the new shell surface

### 5.13 Slice M: matrix keyboard and command wiring

Goal:

Wire Matrix mode actions to public commands and macros.

Primary owner:

code/app

Tests to add first:

1. Matrix keyboard exposes inverse, transpose, zeros, ones, add row, add
   column, clear, and numeric entry support.
2. Add row delegates through the public core path and updates the work matrix.
3. Add column delegates through the public core path and updates the work
   matrix.
4. Zeros and ones delegate through public macros.
5. Transpose and inverse delegate through public commands.

Expected implementation impact:

1. view.dart keypad definitions and routing
2. controller adapter methods if needed
3. widget and controller tests

### 5.14 Slice N: direct RPN access to the new vocabulary

Goal:

Ensure advanced users can stay in RPN mode and still reach the same matrix
workflows.

Primary owner:

code/app plus code/core

Tests to add first:

1. RPN mode exposes direct access to the new command vocabulary or equivalent
   routing.
2. A workflow available in Matrix mode is reproducible in RPN mode.
3. Stack summaries remain coherent after new matrix commands.

Expected implementation impact:

1. app keypad/page definitions
2. command routing in controller or view adapter
3. widget and integration tests

### 5.15 Slice O: end-to-end regression and QA closure

Goal:

Prove the v3 architecture works across core, app, and CLI.

Primary owner:

all three consumers

Tests to add first:

1. One infix workflow using the new core path.
2. One RPN direct-command workflow using new matrix commands.
3. One Matrix mode workstation workflow using friendly actions backed by
   public macros or commands.
4. One CLI workflow invoking a public macro or command path.

Expected implementation impact:

1. integration tests in app
2. CLI smoke tests
3. final release QA script updates if needed

## 6. Definition of Done for v3.0.0 TDD

v3.0.0 is not done until all of the following are green.

1. Core command and macro contracts.
2. Infix compilation parity.
3. Session-facade parity.
4. CLI parity for commands or macros.
5. App shell mode contracts.
6. Matrix workstation command wiring.
7. End-to-end app integration coverage.

## 7. Recommended First Slice

Start with Slice A.

Reason:

1. It creates the public command seam that every later slice depends on.
2. It allows existing behavior to be re-proven incrementally rather than
   rewritten wholesale.
3. It keeps the first edits inside code/core where semantics belong.

## 8. Current Readiness Assessment

Assessment: ready to begin TDD.

Why:

1. The v3 release contract is explicit.
2. The public API target is explicit.
3. The slice order is explicit.
4. The Stage 4 boundary is explicit.