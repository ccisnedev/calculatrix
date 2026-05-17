# Matrix Editor UI TDD Plan

Status: Draft
Owner: Calculatrix maintainers
Companion specification: `docs/spec/matrix_editor_ui.md`
Target app path: `code/app`

## 1. Purpose

This document translates the matrix editor UI specification into a concrete TDD
execution order for the current Flutter app surfaces.

The goal is to improve the matrix editor for `2x2`, `3x3`, and `4x4` editing
without introducing ambiguity about:

1. Which abstraction owns each behavior
2. Which test layer should lock it down first
3. Which files should change when implementation begins

## 2. Current implementation anchors

The current code already exposes the relevant local seams:

1. Draft matrix state: `code/app/lib/modules/calc/matrix_editor_draft.dart`
2. App interaction adapter: `code/app/lib/modules/calc/controller.dart`
3. UI surface: `code/app/lib/modules/calc/view.dart`
4. Controller tests: `code/app/test/modules/calc/calculator_controller_test.dart`
5. Widget tests: `code/app/test/modules/calc/calculator_view_test.dart`
6. Integration tests: `code/app/integration_test/calculator_test.dart`

## 3. TDD policy for this slice

Execution order must remain narrow:

1. Lock deterministic draft behavior first
2. Then lock controller-visible behavior
3. Then lock widget interaction contracts
4. Then lock integration flows only for the user journeys that widget tests
   cannot prove

The implementation should not begin by editing `view.dart` broadly. The first
test additions should identify the minimal missing contract in the draft model
or controller-visible state.

## 4. Behavioral slices

### 4.1 Slice A: order switching preserves overlap

Goal:

Switching between `2x2`, `3x3`, and `4x4` preserves the overlapping top-left
cells inside the same draft session.

Primary owner:

`matrix_editor_draft.dart`

Tests to add first:

1. Resize `2x2 -> 4x4` keeps existing `2x2` values in the top-left corner
2. Resize `4x4 -> 2x2` keeps the visible `2x2` values
3. Resize back `2x2 -> 4x4` restores previously hidden values if the session
   model is extended to retain them

Expected implementation impact:

1. `matrix_editor_draft.dart`
2. Possibly editor-local state in `view.dart` if hidden-cell retention is kept
   outside the draft object

### 4.2 Slice B: quick actions apply to the active order

Goal:

`Zeros`, `Identity`, and `Clear` mutate only the currently active visible order.

Primary owner:

Draft state plus editor wiring

Tests to add first:

1. `Zeros` fills all visible cells with `0`
2. `Identity` fills diagonal `1`s and off-diagonal `0`s for `2x2`, `3x3`, and
   `4x4`
3. `Clear` empties all visible cells in the active order

Expected implementation impact:

1. `matrix_editor_draft.dart`
2. `view.dart`

### 4.3 Slice C: invalid cell text remains recoverable

Goal:

Invalid user input is not silently discarded and remains editable until fixed.

Primary owner:

Widget state in `view.dart`

Tests to add first:

1. Invalid text entered into a cell remains visible after validation failure
2. Confirm action is disabled or rejected while any visible cell is invalid
3. Error message identifies the failing row and column

Expected implementation impact:

1. `view.dart`
2. Possibly helper methods around draft validation

### 4.4 Slice D: keyboard navigation versus edit mode

Goal:

The grid distinguishes navigation mode from edit mode.

Primary owner:

`view.dart`

Tests to add first:

1. Arrow keys move focus between visible cells in navigation mode
2. `Enter` enters edit mode for the focused cell
3. `Esc` restores the last committed cell value and exits edit mode
4. `Tab` commits the current cell and moves to the next visible cell

Expected implementation impact:

1. `view.dart`
2. Editor-local focus and controller lifecycle only

### 4.5 Slice E: mobile action bar remains usable

Goal:

`Cancel` and confirm remain accessible with the software keyboard open.

Primary owner:

`view.dart`

Tests to add first:

1. The matrix editor action bar remains in the widget tree while the text input
   is active
2. Confirm still succeeds after editing the last cell

Expected implementation impact:

1. `view.dart`

### 4.6 Slice F: literal preview and confirmation parity

Goal:

Visible grid values, preview text, and confirmed literal always match.

Primary owner:

Draft serialization plus UI presentation

Tests to add first:

1. A valid `2x2` grid renders the expected preview literal
2. A valid `4x4` grid renders the expected preview literal
3. Confirm in `Infix` inserts the exact preview literal into the expression
4. Confirm in `RPN` pushes the exact preview literal onto the stack

Expected implementation impact:

1. `matrix_editor_draft.dart`
2. `controller.dart`
3. `view.dart`

## 5. Test layer mapping

### 5.1 Pure-state tests

These should be added before widget work when the behavior is independent of
Flutter focus or layout.

Preferred target:

1. New test file: `code/app/test/modules/calc/matrix_editor_draft_test.dart`

Must cover:

1. Resize behavior
2. Quick actions if implemented in draft state
3. Literal build parity for visible cells

### 5.2 Controller tests

Preferred target:

1. `code/app/test/modules/calc/calculator_controller_test.dart`

Must cover:

1. `Infix` confirmation inserts the exact literal
2. `RPN` confirmation pushes the exact literal
3. No controller regression for existing matrix insertion flows

### 5.3 Widget tests

Preferred target:

1. `code/app/test/modules/calc/calculator_view_test.dart`

Must cover:

1. Order toggle visibility and state retention
2. Quick action buttons
3. Validation messages
4. Keyboard navigation contract where test harness supports it
5. Action bar visibility and enablement

### 5.4 Integration tests

Preferred target:

1. `code/app/integration_test/calculator_test.dart`

Must cover only high-value flows:

1. Create `4x4` identity matrix and insert it in `Infix`
2. Create `3x3` matrix and push it in `RPN`
3. Recover from one invalid cell and then confirm successfully

The integration suite should not duplicate every widget-level detail.

## 6. Recommended execution order

### Step 1

Add pure-state tests for resize preservation and literal construction.

Validation target:

1. Run the new draft-focused unit tests only

### Step 2

Implement or refine draft helpers for order switching and quick actions.

Validation target:

1. Re-run the same draft-focused tests

### Step 3

Add controller tests for `Infix` insert parity and `RPN` push parity using the
final literal output.

Validation target:

1. Run `calculator_controller_test.dart`

### Step 4

Add widget tests for order controls, validation messages, and quick actions.

Validation target:

1. Run `calculator_view_test.dart`

### Step 5

Implement the keyboard and layout changes in `view.dart`.

Validation target:

1. Re-run `calculator_view_test.dart`

### Step 6

Add narrow integration tests for the three canonical user journeys.

Validation target:

1. Run `calculator_test.dart` on the emulator only after the narrower tests are
   green

## 7. Definition of done

The slice is complete when all of the following are true:

1. The active order is directly selectable as `2x2`, `3x3`, or `4x4`
2. Visible-cell values preserve overlap across order changes
3. Quick actions behave deterministically for every supported order
4. Invalid text is recoverable and never silently discarded
5. Keyboard navigation and edit mode are distinct and test-covered
6. `Infix` insert and `RPN` push both preserve the exact preview literal
7. Desktop and mobile action rows remain usable during editing

## 8. Commands to prefer during implementation

When implementation starts, prefer this validation sequence:

1. Focused draft test file only
2. `code/app/test/modules/calc/calculator_controller_test.dart`
3. `code/app/test/modules/calc/calculator_view_test.dart`
4. `code/app/integration_test/calculator_test.dart`

Do not start with the full app integration suite.