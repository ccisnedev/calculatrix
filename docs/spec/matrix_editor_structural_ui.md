# Matrix Structural Editor UI Specification

Status: Draft
Owner: Calculatrix maintainers
Target release: v0.2.130
Target surface: calculatrix_app matrix editor
Target path in monorepo: code/app
Companion baseline: docs/spec/matrix_editor_ui.md
Companion roadmap entry: docs/roadmap.md v0.2.130
Supported visible shapes: bounded NxM up to 4x4

## 1. Purpose

This document defines the UI, interaction, and accessibility contract for the
next matrix editor evolution after the v0.2.120 square-order workflow.

The new editor must let users think in ordered row lists and column lists,
while still preserving the matrix-as-one-object mental model.

The editor must be:

1. Clear for users who think in rows and columns as movable units
2. Fast for square presets such as 2x2, 3x3, and 4x4
3. Safe for structural edits such as add, delete, duplicate, and reorder
4. Consistent with the canonical matrix literal already shared by app, core,
   and CLI
5. Usable on both desktop and mobile without splitting the product into a
   separate structural editor mode

## 2. Scope

### 2.1 In scope

1. Row handles and column handles that expose structural editing directly in the
   editor
2. Add row and add column controls bounded by a maximum visible shape of 4x4
3. Delete any visible row or column while keeping at least one row and one
   column
4. Duplicate any visible row or column while capacity remains below 4 in the
   target axis
5. Reorder rows and columns by drag and drop on supported platforms
6. Non-drag fallback behavior for reordering on keyboard-first or imprecise
   pointer workflows
7. Preview, validation, and confirmation parity after structural edits
8. Continued square-preset workflow for 2x2, 3x3, and 4x4

### 2.2 Out of scope

1. Unlimited NxM editing beyond 4x4
2. Advanced linear algebra operations inside the editor itself
3. Named rows or named columns
4. Multi-select row or column batch operations
5. Undo and redo history inside the editor
6. Matrix pasting from spreadsheets or TSV sources

## 3. Baseline Product Contract

This specification extends the v0.2.120 editor contract instead of replacing it.

1. Confirming the editor still serializes to the canonical bracket literal,
   for example [[1,2],[3,4]].
2. In Infix mode, confirmation inserts the serialized literal into the current
   expression draft.
3. In RPN mode, confirmation pushes the serialized literal onto the stack.
4. Numeric cells remain text-based exact-entry fields, not spinbuttons.
5. The current bounded backing store of 4x4 remains acceptable for app-local
   editing as long as structural edits preserve the visible contract.

## 4. Verified Reference Base

All references in this section were checked on 2026-05-17.

### 4.1 Normative interaction references

| Source | Decision supported |
|--------|--------------------|
| W3C WAI-ARIA APG Grid Pattern | Grid navigation, one tab stop inside the matrix body, edit-mode versus navigation-mode split |
| W3C WAI-ARIA APG Rearrangeable Listbox Example | Reorderable structural lists need explicit action fallback, keyboard shortcuts, and live confirmation of movement |
| Material 3 Tabs overview | Tabs are appropriate for organizing peer categories and can scale horizontally when the count is bounded but visible |

### 4.2 Continued references from v0.2.120

The following v0.2.120 references remain applicable and are inherited by this
specification:

1. GOV.UK text-input guidance
2. GOV.UK number-input research
3. MDN input type=number guidance
4. Material data table guidance for numeric alignment

### 4.3 Design conclusion from references

The structural editor should behave like a spreadsheet with structural rails:

1. The matrix body remains a grid
2. Row and column rails act as drag handles for ordered structural units
3. Drag is an enhancement, not the only path
4. Duplicate and delete actions must remain explicit and discoverable

## 5. Design Principles

1. Matrix first: the matrix must still read as one mathematical object
2. Structure visible: row and column operations must be expressed in the UI,
   not hidden behind menus disconnected from the matrix
3. Square fast path: 2x2, 3x3, and 4x4 presets remain the fastest route for
   the common educational workflow
4. Bounded complexity: structural editing is capped at 4 rows and 4 columns
5. Drag plus fallback: pointer drag may reorder, but non-drag alternatives must
   exist
6. Lossless parity: preview and final literal must always match the visible row
   and column order

## 6. UX Contract

### 6.1 Shape model

The editor supports any visible shape from 1x1 through 4x4.

Rules:

1. The default visible shape on first open remains 2x2.
2. The existing square preset chips 2x2, 3x3, and 4x4 remain available at the
   top of the editor.
3. Choosing a square preset sets both row count and column count to that order.
4. Structural edits may intentionally diverge from square shapes, for example
   2x4 or 4x1.
5. The current visible shape must always be shown somewhere in the editor,
   for example as a compact shape badge such as 3x4.

### 6.2 Structural rails

The editor adds two structural rails around the matrix body:

1. Column handles above the grid
2. Row handles to the left of the grid

Each handle represents one ordered structural unit.

Rules:

1. Column handles are shown as unlabeled drag grips above the corresponding columns.
2. Row handles are shown as unlabeled drag grips beside the corresponding rows.
3. Position is conveyed by spatial alignment with the grid, not by visible r/c text.
4. After any reorder, the handles remain aligned to the new visible order.

### 6.3 Tap behavior for row and column handles

Tap is for structural actions, not direct cell editing.

Rules:

1. Tapping a row handle reveals a small contextual action tray for that row.
2. Tapping a column handle reveals a small contextual action tray for that column.
3. The contextual tray exposes exactly these primary actions:
   1. Duplicate
   2. Delete
4. The tray remains lightweight and anchored to the touched handle.
5. Opening one tray closes any previously open row or column tray.

### 6.4 Drag behavior for row and column handles

Drag is the primary desktop reorder mechanism.

Rules:

1. Pressing and moving a row handle beyond a drag threshold reorders that row.
2. Pressing and moving a column handle beyond a drag threshold reorders that
   column.
3. A simple tap-release without meaningful movement must open the action tray
   instead of starting reorder.
4. On touch-first devices, reorder may require a short long-press threshold
   before drag starts in order to reduce accidental movement.
5. Reorder preview must show the full dragged row or full dragged column while
   dragging, not only the handle label.
6. The source cells of the dragged structural unit should temporarily render as
   lightweight skeleton placeholders so the user keeps the matrix shape in view.
7. On drop, the row or column values move with the structural unit.

### 6.5 Add row and add column controls

The editor exposes explicit append controls integrated into the matrix
boundary.

Rules:

1. A right-edge add-column placeholder marked with + appends one column to the
   far right.
2. A bottom-edge add-row placeholder marked with + appends one row to the
   bottom.
3. Add-column is disabled when column count is already 4.
4. Add-row is disabled when row count is already 4.
5. Newly added rows and columns start empty.
6. Newly added rows and columns become part of validation immediately.
7. The add placeholder should preview the insertion affordance with a skeleton
   cell strip rather than a standalone button detached from the grid.

### 6.6 Duplicate and delete behavior

Duplicate and delete are structural operations on the currently selected
handle.

Duplicate rules:

1. Duplicate row inserts a copy immediately after the source row.
2. Duplicate column inserts a copy immediately after the source column.
3. Duplicate copies the raw visible cell strings exactly, including incomplete
   or invalid text.
4. Duplicate is disabled when the target axis is already at size 4.

Delete rules:

1. Delete row removes the selected row.
2. Delete column removes the selected column.
3. Delete is disabled when only one row remains.
4. Delete is disabled when only one column remains.
5. Delete is immediate inside the current open session.
6. Cancel still restores the full pre-open state for the entire session.

### 6.7 Reorder fallback behavior

Drag cannot be the only reorder path.

Fallback rules:

1. When a row handle has focus, Alt+Up and Alt+Down reorder the row.
2. When a column handle has focus, Alt+Left and Alt+Right reorder the column.
3. If the implementation chooses not to use those exact shortcuts, it must
   still provide a keyboard path that is documented and discoverable.
4. Reorder fallback must keep focus on the moved structural unit after the move.
5. A live status message should announce the completed move, for example
   Row 3 moved to row 2.

### 6.8 Grid and rail synchronization

Structural rails and the cell grid are one stateful object.

Rules:

1. Reordering a row moves every cell in that row.
2. Reordering a column moves every cell in that column.
3. Duplicating a row or column updates the grid immediately.
4. Deleting a row or column updates the grid immediately.
5. If the focused cell belongs to a moved row or column, focus follows the moved
   data rather than staying on the old numeric index.
6. Preview text is recalculated after every structural change.
7. Confirmation serializes the visible rows and columns in their final order.

### 6.9 Quick actions and square-only helpers

The existing quick actions remain, but they become shape-aware.

Rules:

1. Zeros applies to every visible cell regardless of shape.
2. Clear empties every visible cell regardless of shape.
3. Identity is enabled only when row count equals column count.
4. When the shape is non-square, Identity should either be disabled or show an
   explanatory message instead of mutating the matrix incorrectly.
5. Switching back to a square shape re-enables Identity.

### 6.10 Validation and preview behavior

Validation rules from v0.2.120 still apply, but structural edits change which
cells are visible and therefore validated.

Rules:

1. Every visible cell must be non-empty and parse as a number before confirm.
2. Hidden cells outside the current visible shape are ignored.
3. If a delete operation removes the only invalid visible row or column,
   preview may immediately become valid.
4. Structural edits must never produce a preview that disagrees with the grid.
5. Error copy must continue naming the exact row and column after any reorder.

### 6.11 Confirmation behavior

The action row remains structurally unchanged:

1. Cancel
2. Insert or Push

Rules:

1. Confirm serializes the current visible NxM matrix in final row and column
   order.
2. Infix confirmation inserts that exact literal.
3. RPN confirmation pushes that exact literal.
4. Cancel abandons all structural edits from the current open session.

## 7. Layout Guidance

### 7.1 Desktop

Desktop is the primary pointer-drag target.

Rules:

1. Column handles should sit directly above the matrix body, aligned with columns.
2. Row handles should sit directly to the left of the matrix body, aligned with
   rows.
3. Add-column placeholder should appear on the right boundary of the matrix
   region.
4. Add-row placeholder should appear on the bottom boundary of the matrix
   region.
5. Contextual action trays should not cover the entire matrix or hide the
   current preview.

### 7.2 Mobile

Mobile prioritizes reliable touch targets over drag density.

Rules:

1. Tap-revealed action trays must have touch targets of at least 48dp.
2. If drag is supported on mobile, use long-press drag rather than immediate
   drag.
3. Add-row and add-column controls must remain reachable with the software
   keyboard open.
4. The matrix body must still avoid horizontal scrolling on common phone widths
   at 4 columns.

## 8. Wireframes

### 8.1 Desktop wireframe

```text
+-----------------------------------------------------------------------+
| Insert Matrix                                                         |
| Presets: [2x2] [3x3] [4x4]    Shape: 3x4                              |
|                                                                       |
|            [::]    [::]    [::]    [::]        [+][----]             |
|          /-----------------------------------------------\            |
| [::]     | [ 1 ]   [ 2 ]   [ 3 ]   [ 4 ]                 |            |
|  dup del |                                               |            |
| [::]     | [ 5 ]   [ 6 ]   [ 7 ]   [ 8 ]                 |            |
| [::]     | [ 9 ]   [10 ]   [11 ]   [12 ]                 |            |
|          \-----------------------------------------------/            |
|                          [+] [----] [----] [----] [----]              |
|                                                                       |
| Actions: [Zeros] [Identity disabled] [Clear]                          |
| Preview: [[1,2,3,4],[5,6,7,8],[9,10,11,12]]                           |
|                                                 [Cancel] [Insert]     |
+-----------------------------------------------------------------------+
```

Legend:

1. Tap a row or column handle to reveal duplicate/delete micro-actions
2. Drag a row or column handle to reorder that structural unit
3. While dragging, the whole row or column is previewed and the source slot
   stays visible as skeleton placeholders

### 8.2 Mobile wireframe

```text
+----------------------------------------------+
| Matrix                                       |
| [2x2] [3x3] [4x4]   2x3                      |
|                                              |
|        [::]   [::]   [::]   [+][--]         |
|     /-----------------------------\          |
| [::] | [ 1 ] [ 2 ] [ 3 ]           |         |
| [::] | [ 4 ] [ 5 ] [ 6 ]           |         |
|     \-----------------------------/          |
|            [+] [--] [--] [--]                |
|         dup / del                             |
|                                              |
| [Zeros] [Identity off] [Clear]               |
| Preview: [[1,2,3],[4,5,6]]                   |
+----------------------------------------------+
| [Cancel]                           [Insert]  |
+----------------------------------------------+
```

## 9. Acceptance Checklist

### 9.1 Implementation checklist

- [ ] The editor exposes visible row handles and column handles as structural lists.
- [ ] Each visible row handle supports Duplicate and Delete from a tap-revealed tray.
- [ ] Each visible column handle supports Duplicate and Delete from a tap-revealed tray.
- [ ] Row handles can reorder rows by drag on supported desktop pointer devices.
- [ ] Column handles can reorder columns by drag on supported desktop pointer devices.
- [ ] A right-edge integrated + placeholder appends a column until width reaches 4.
- [ ] A bottom-edge integrated + placeholder appends a row until height reaches 4.
- [ ] Delete cannot reduce the matrix below 1 row or 1 column.
- [ ] Duplicate cannot exceed 4 rows or 4 columns in the target axis.
- [ ] Square preset chips remain available for the fast 2x2, 3x3, and 4x4 workflow.
- [ ] Identity is disabled or guarded for non-square shapes.
- [ ] Preview and final literal always reflect the final visible row and column order.

### 9.2 QA checklist

- [ ] Add row from 2x2 yields a valid 3x2 visible shape with new empty cells.
- [ ] Add column from 2x2 yields a valid 2x3 visible shape with new empty cells.
- [ ] Duplicating a row copies the exact row text and inserts it after the source.
- [ ] Duplicating a column copies the exact column text and inserts it after the source.
- [ ] Deleting a row removes its cells from preview and final literal.
- [ ] Deleting a column removes its cells from preview and final literal.
- [ ] Dragging a row changes row order without corrupting cell values.
- [ ] Dragging a column changes column order without corrupting cell values.
- [ ] Dragging a row shows full-row feedback and leaves row skeleton placeholders behind.
- [ ] Dragging a column shows full-column feedback and leaves column skeleton placeholders behind.
- [ ] Keyboard fallback reorders rows and columns without drag.
- [ ] Infix confirmation after a structural edit inserts the expected NxM literal.
- [ ] RPN confirmation after a structural edit pushes the expected NxM literal.
- [ ] Cancel restores the exact pre-open matrix draft and shape.

## 10. Deferred Decisions

The following decisions are intentionally deferred:

1. Whether row and column handles may be renamed in a future release
2. Whether duplicate and delete should be icon-only or icon-plus-text on mobile
3. Whether insert-before and insert-after should be separate actions later
4. Whether explicit Move Left/Right and Move Up/Down buttons should be added to
   the tap tray in addition to drag and keyboard fallback

## 11. Verified References

1. W3C WAI-ARIA Authoring Practices Guide. Grid Pattern. Verified 2026-05-17.
   https://www.w3.org/WAI/ARIA/apg/patterns/grid/
2. W3C WAI-ARIA Authoring Practices Guide. Example Listboxes with Rearrangeable
   Options. Verified 2026-05-17.
   https://www.w3.org/WAI/ARIA/apg/patterns/listbox/examples/listbox-rearrangeable/
3. Material Design 3. Tabs Overview. Verified 2026-05-17.
   https://m3.material.io/components/tabs/overview
4. GOV.UK Design System. Text input. Verified 2026-05-17.
   https://design-system.service.gov.uk/components/text-input/
5. GOV.UK Technology Blog. Why the GOV.UK Design System team changed the input
   type for numbers. Verified 2026-05-17.
   https://technology.blog.gov.uk/2020/02/24/why-the-gov-uk-design-system-team-changed-the-input-type-for-numbers/
6. MDN Web Docs. input type="number". Verified 2026-05-17.
   https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/number