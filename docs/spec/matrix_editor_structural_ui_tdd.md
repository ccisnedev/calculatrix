# Matrix Structural Editor TDD Plan

Status: Draft
Owner: Calculatrix maintainers
Companion specification: docs/spec/matrix_editor_structural_ui.md
Target release: v0.2.130
Target app path: code/app

## 1. Purpose

This document translates the v0.2.130 structural matrix editor specification
into a narrow implementation plan.

The goal is to add bounded structural editing for rows and columns without
breaking:

1. Existing matrix literal parity
2. Existing Infix and RPN confirmation semantics
3. Existing square preset workflow
4. The current bounded 4x4 local editing model

## 2. Current Implementation Anchors

The current code already exposes the seams needed for this work:

1. Draft matrix state: code/app/lib/modules/calc/matrix_editor_draft.dart
2. App interaction adapter: code/app/lib/modules/calc/controller.dart
3. UI surface: code/app/lib/modules/calc/view.dart
4. Existing draft tests: code/app/test/modules/calc/matrix_editor_draft_test.dart
5. Existing controller tests: code/app/test/modules/calc/calculator_controller_test.dart
6. Existing widget tests: code/app/test/modules/calc/calculator_view_test.dart
7. Existing integration tests: code/app/integration_test/calculator_test.dart
8. Existing stable integration driver: code/app/test_driver/integration_test.dart

Important baseline facts:

1. The draft already supports independent rowCount and columnCount bounded by 4.
2. The current UI only exposes square presets and a plain grid.
3. The controller already accepts any canonical matrix literal and does not need
   to know how the editor UI produced it.

## 3. TDD Policy for This Slice

Execution order must remain narrow and data-first:

1. Lock structural draft semantics before editing the dialog UI broadly.
2. Prove controller parity using the final serialized literal, not UI guesses.
3. Then lock widget contracts for tabs, trays, add controls, and drag behavior.
4. Only after widget contracts are green, add narrow Android integration flows.

Do not start by building drag and drop directly in view.dart.

## 4. Behavioral Slices

### 4.1 Slice A: bounded structural insert and delete

Goal:

Rows and columns can be inserted and deleted while preserving the remaining
visible matrix and staying within 1..4 per axis.

Primary owner:

matrix_editor_draft.dart

Tests to add first:

1. Append row from 2x2 yields 3x2 with old rows preserved
2. Append column from 2x2 yields 2x3 with old columns preserved
3. Delete middle row from 3x2 shifts lower rows upward
4. Delete middle column from 2x3 shifts right columns leftward
5. Delete row is rejected or disabled when only one row remains
6. Delete column is rejected or disabled when only one column remains

Expected implementation impact:

1. matrix_editor_draft.dart

### 4.2 Slice B: duplicate row and duplicate column

Goal:

Duplicate copies raw visible text exactly and inserts the duplicate after the
source structural unit.

Primary owner:

matrix_editor_draft.dart

Tests to add first:

1. Duplicate row inserts an exact row copy after the source row
2. Duplicate column inserts an exact column copy after the source column
3. Duplicate is blocked when the target axis is already at size 4
4. Duplicate preserves invalid raw text exactly rather than reparsing it

Expected implementation impact:

1. matrix_editor_draft.dart

### 4.3 Slice C: reorder semantics

Goal:

Moving a row or column changes only structure and order, not values.

Primary owner:

matrix_editor_draft.dart

Tests to add first:

1. Move row 0 to row 2 preserves all row contents in their new order
2. Move column 0 to column 2 preserves all column contents in their new order
3. Reorder followed by literal build serializes in the new order
4. Reorder is a no-op when source equals destination

Expected implementation impact:

1. matrix_editor_draft.dart

### 4.4 Slice D: square preset interop and helper gating

Goal:

Structural editing and square presets coexist without breaking helper behavior.

Primary owner:

matrix_editor_draft.dart plus view.dart

Tests to add first:

1. Structural 2x3 shape switched to 3x3 preserves top-left overlap
2. Identity is available only when rowCount equals columnCount
3. Zeros and Clear remain available for non-square shapes
4. Preview and literal use the currently visible shape after preset changes

Expected implementation impact:

1. matrix_editor_draft.dart
2. view.dart

### 4.5 Slice E: row and column tab action trays

Goal:

Tap on a structural tab reveals Duplicate and Delete actions for that unit.

Primary owner:

view.dart

Tests to add first:

1. Tapping a row tab reveals row Duplicate and row Delete actions
2. Tapping a column tab reveals column Duplicate and column Delete actions
3. Opening a second tray closes the first tray
4. Delete is visibly disabled for the last remaining row or column
5. Duplicate is visibly disabled at the 4-row or 4-column limit

Expected implementation impact:

1. view.dart

### 4.6 Slice F: add row and add column controls

Goal:

Boundary controls append rows and columns in a discoverable way.

Primary owner:

view.dart plus draft helpers

Tests to add first:

1. Right-edge add control increases column count by one
2. Bottom-edge add control increases row count by one
3. Add controls disable at 4 in the target axis
4. Added structural units start empty and therefore affect validation

Expected implementation impact:

1. matrix_editor_draft.dart
2. view.dart

### 4.7 Slice G: drag and drop contracts

Goal:

Desktop pointer drag reorders rows and columns without opening the tap tray.

Primary owner:

view.dart

Tests to add first:

1. Mouse drag on a row tab changes row order
2. Mouse drag on a column tab changes column order
3. A simple tap on a tab does not reorder
4. After drag, preview text reflects the new order immediately

Expected implementation impact:

1. view.dart

### 4.8 Slice H: controller and end-to-end parity

Goal:

All structural edits still end in the exact canonical literal accepted by the
controller.

Primary owner:

controller tests plus integration flows

Tests to add first:

1. Infix confirm after add-row serializes the expected NxM literal
2. RPN confirm after reordered columns serializes the expected NxM literal
3. Mixed flow add column -> duplicate row -> delete column still confirms the
   expected literal

Expected implementation impact:

1. calculator_controller_test.dart
2. calculator_test.dart

## 5. Test Layer Mapping

### 5.1 Pure-state tests

Preferred target:

1. New file: code/app/test/modules/calc/matrix_editor_structure_draft_test.dart

Must cover:

1. Insert row and insert column
2. Delete row and delete column
3. Duplicate row and duplicate column
4. Move row and move column
5. Literal build parity after structural edits

### 5.2 Controller tests

Preferred target:

1. code/app/test/modules/calc/calculator_controller_test.dart

Must cover:

1. Infix insert parity for non-square literals produced by the editor
2. RPN push parity for reordered literals produced by the editor
3. No regression in existing square insert and push flows

### 5.3 Widget tests

Preferred targets:

1. code/app/test/modules/calc/calculator_view_test.dart
2. Optional new file if needed: code/app/test/modules/calc/matrix_editor_structure_view_test.dart

Must cover:

1. Row and column tab visibility
2. Tap-revealed Duplicate and Delete trays
3. Add-row and add-column controls
4. Identity helper gating for non-square shapes
5. Mouse drag reorder contracts
6. Keyboard fallback reorder contracts when harness support is sufficient

### 5.4 Integration tests

Preferred target:

1. code/app/integration_test/calculator_test.dart

Must cover only high-value flows:

1. Add a row, fill values, and insert in Infix
2. Reorder rows and push in RPN
3. Delete a column from a previously valid matrix and then confirm successfully

The integration suite should not duplicate all widget-level drag details.

## 6. Recommended Execution Order

### Step 1

Add pure-state tests for insert, delete, duplicate, and reorder in the draft
model.

Validation target:

1. Run the new structural draft-focused unit tests only

### Step 2

Implement the structural draft API and keep literal generation green.

Validation target:

1. Re-run the same draft-focused tests

### Step 3

Add controller tests proving non-square and reordered literal parity.

Validation target:

1. Run calculator_controller_test.dart

### Step 4

Add widget tests for row tabs, column tabs, add controls, and helper gating.

Validation target:

1. Run the affected widget test file only

### Step 5

Implement the tab rails and contextual action trays in view.dart.

Validation target:

1. Re-run the same widget tests

### Step 6

Add mouse drag widget tests for row and column reorder.

Validation target:

1. Re-run the same widget tests again before touching integration

### Step 7

Add narrow Android integration tests for the three canonical structural flows.

Validation target:

1. Run flutter drive --driver=test_driver/integration_test.dart --target=integration_test/calculator_test.dart -d emulator-5554

## 7. Definition of Done

The slice is complete when all of the following are true:

1. Users can add or delete any row and any column within the bounded 4x4 limit
2. Users can duplicate any row and any column within the bounded 4x4 limit
3. Users can reorder rows and columns by drag on desktop-supported pointers
4. A non-drag fallback exists for structural reorder
5. Square preset chips and non-square structural edits coexist correctly
6. Identity is unavailable for non-square shapes
7. Preview and final literal always match the final visible NxM shape and order
8. Infix and RPN both preserve the exact serialized structural result

## 8. Commands to Prefer During Implementation

When implementation starts, prefer this validation sequence:

1. Focused structural draft test file only
2. code/app/test/modules/calc/calculator_controller_test.dart
3. Focused structural widget test file only
4. code/app/integration_test/calculator_test.dart via flutter drive

Do not start with the full app integration suite through flutter test on Android.
Prefer the existing stable driver path for complete emulator validation.