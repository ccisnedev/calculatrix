# Matrix Editor UI Specification

Status: Draft
Owner: Calculatrix maintainers
Target surface: `calculatrix_app` matrix editor
Target path in monorepo: `code/app`
Supported orders: `2x2`, `3x3`, `4x4`

## 1. Purpose

This document defines the UX, accessibility, and interaction contract for the
Calculatrix matrix editor used to create square matrices of order 2 through 4.

The editor must be:

1. Clear for novice users who think in visible rows and columns
2. Fast for repeat entry with keyboard navigation
3. Consistent with the shared matrix literal contract already used by app,
   core, and CLI
4. Usable on both desktop and mobile without introducing a separate matrix-only
   shell

## 2. Scope

### 2.1 In scope

1. Order selection for `2x2`, `3x3`, and `4x4`
2. Cell-based numeric entry
3. Validation and error presentation
4. Keyboard and focus behavior
5. Mobile and desktop layout behavior
6. Quick actions for common matrix presets
7. Literal preview and confirmation behavior

### 2.2 Out of scope

1. Free-size `NxM` editing beyond order 4
2. Determinant, inverse, decomposition, or matrix-operation buttons inside the
   editor itself
3. Symbolic entries
4. Multi-matrix side-by-side editing in one surface
5. Locale-specific decimal parsing beyond the canonical dot-decimal format

## 3. Existing Product Contract

This specification extends the current architectural contract rather than
replacing it.

1. The app-side matrix editor serializes values to the core literal format,
   for example `[[1,2],[3,4]]`.
2. In `Infix` mode, confirming the editor inserts that literal into the current
   expression buffer.
3. In `RPN` mode, confirming the editor pushes the parsed matrix onto the
   stack.
4. Copy/paste compatibility with CLI is preserved by keeping the literal format
   lossless.

## 4. Verified Reference Base

All references in this section were checked on `2026-05-17`.

### 4.1 Normative interaction and accessibility references

| Source | Decision supported |
|--------|--------------------|
| W3C WAI-ARIA APG Grid Pattern | Single tab stop, arrow-key navigation, edit-mode separation, focus movement inside an interactive grid |
| MDN `grid` role reference | Expected keyboard behavior, focusable cell model, row and column semantics |
| Material Design data tables | Right-aligned numeric columns, density, focus visibility, minimum touch target guidance |
| GOV.UK text input guidance | No placeholder-as-label, explicit error copy, text input guidance for decimals |
| GOV.UK number-input research | Do not use native incrementable number controls when values are not truly spinbutton-like |
| MDN `input type="number"` reference | Native number fields imply `spinbutton`, can round or step, and are not ideal when incrementing is not the task |

### 4.2 Product and interaction precedents

| Source | Decision supported |
|--------|--------------------|
| Desmos Matrix Calculator | Direct per-cell editing, size controls near the matrix, clear warning states for invalid operations |
| GeoGebra matrices manual | Retain a canonical literal/text representation as an advanced or interoperable path |
| AG Grid keyboard interaction | `Enter`/`F2` edit-mode convention, `Esc` to exit, spreadsheet-like focus restoration |
| Calculator.net Matrix Calculator | Preset buttons and matrix-size-first workflow familiar to calculator users |
| utils.com Matrix Calculator | Separate quick actions like `Identity`, `Random`, and `Clear` add value when kept lightweight |

### 4.3 Design conclusion from references

The editor should behave like a small, math-specific spreadsheet, not like:

1. A generic multiline text form
2. An admin data table
3. A set of spinbuttons

The primary object is the matrix itself. All supporting UI should help users
enter, inspect, and confirm that matrix with minimal indirection.

## 5. Design Principles

1. Matrix first: the grid must visually read as one mathematical object
2. Order first: users choose `2x2`, `3x3`, or `4x4` directly, not independent
   row and column counts
3. One interaction model: novice pointer input and expert keyboard input must
   operate on the same visible cells
4. Explicit validation: never silently discard characters or auto-correct into
   a different number
5. Mobile viability: `4x4` must remain usable with the software keyboard open
6. Core parity: confirmed output must remain the canonical matrix literal

## 6. UX Contract

### 6.1 Order selection

The editor must expose three direct order controls at the top of the surface:

1. `2x2`
2. `3x3`
3. `4x4`

Rules:

1. If there is no previous draft, the default order is `2x2`.
2. If a draft already exists in the same editing session, reopening the editor
   should restore the previous order and values.
3. Changing order preserves the overlapping top-left submatrix.
4. Hidden cells are excluded from validation, preview, and serialization.
5. Changing order must not immediately destroy hidden values during the same
   editor session.

### 6.2 Grid presentation

The matrix must be rendered as a dedicated grid wrapped by visible left and
right brackets.

Presentation rules:

1. Cell dimensions remain uniform within the active order.
2. Numeric values are right-aligned for scanability.
3. Digits should use tabular figures when the typography system allows it.
4. Row and column labels may be visually subtle, but accessible names must be
   explicit.
5. The focus indicator must be visible without fighting the bracket outline.
6. The grid must not horizontally scroll on common phone widths when showing a
   `4x4` matrix.

### 6.3 Cell input model

Each visible cell is a text-based numeric entry field, not a native spinbutton.

Input policy:

1. Accept signed decimal input in canonical dot-decimal form.
2. Trim surrounding whitespace on commit.
3. Do not use placeholder text inside cells.
4. Request a signed+decimal software keyboard where the platform supports it.
5. Do not expose increment/decrement steppers.
6. Do not silently drop invalid characters.

Rationale:

Matrix cell entry is about exact numeric transcription, not incrementing a
counter. Native number controls optimize for stepwise changes and can introduce
accessibility and data-integrity problems in this workflow.

### 6.4 Navigation and edit modes

The grid behaves as one keyboard stop with spreadsheet-like navigation.

Navigation mode:

1. `Tab` enters the grid on the last focused cell, or the top-left visible cell
   if none exists.
2. Arrow keys move focus one cell at a time.
3. `Home` moves to the first cell in the current row.
4. `End` moves to the last cell in the current row.
5. `Ctrl+Home` moves to the first visible cell.
6. `Ctrl+End` moves to the last visible cell.

Edit mode:

1. `Enter` or `F2` enters edit mode for the focused cell.
2. Typing a digit, `-`, or `.` while in navigation mode should also enter edit
   mode for the focused cell.
3. `Enter` commits the edited value and returns to navigation mode on the same
   cell.
4. `Tab` and `Shift+Tab` commit the value and move to the next or previous
   visible cell in row-major order.
5. `Esc` restores the previous committed cell value and exits edit mode.

Mobile adaptation:

1. If the platform exposes IME actions, `Next` moves to the next visible cell.
2. `Done` commits the current cell and closes the keyboard.

### 6.5 Quick actions

The editor should provide lightweight quick actions below the grid:

1. `Zeros`: fill every visible cell with `0`
2. `Identity`: fill the visible square matrix with `1` on the diagonal and `0`
   elsewhere
3. `Clear`: empty every visible cell in the active order

Rules:

1. Quick actions apply only to the active order.
2. `Identity` is always valid because only square orders are supported.
3. `Random` is optional future work, not part of this contract.

### 6.6 Validation and error behavior

Validation occurs at two levels: cell-level and form-level.

Cell-level rules:

1. A visible cell may be temporarily incomplete while actively being edited.
2. On commit or blur, the cell must either become a valid number or show an
   explicit error state.
3. Invalid cells keep the raw user text so the user can correct it.

Form-level rules:

1. Confirmation is blocked while any visible cell is empty or invalid.
2. Error copy identifies the exact row and column.
3. Literal preview is only shown as a valid output when all visible cells are
   valid.
4. If the matrix is incomplete, preview area should say that preview is
   unavailable until all visible cells are valid.

Recommended error copy:

1. `Enter a value for r2 c3`
2. `r2 c3 must be a number, like -2 or 3.5`

### 6.7 Confirmation behavior

The bottom action row must expose:

1. `Cancel`
2. `Insert` or `Push`, depending on the surrounding mode label strategy

Rules:

1. `Cancel` discards draft changes made in the current open session.
2. Confirm serializes the visible matrix into the canonical bracket literal.
3. The preview, the confirmed value, and the serialized literal must always
   match.
4. The action row remains visible on mobile while the keyboard is open.

## 7. Layout Guidance

### 7.1 Desktop

Preferred container: modal dialog or embedded panel with enough width for `4x4`
without horizontal scrolling.

Desktop rules:

1. Keep order selector, grid, quick actions, preview, and action row visible at
   once when space allows.
2. Use the widest space for the grid, not for decorative chrome.
3. Keep action buttons bottom-right aligned.

### 7.2 Mobile

Preferred container: full-height bottom sheet or full-screen editor.

Mobile rules:

1. Do not use a small centered dialog for `4x4` entry.
2. Keep a sticky bottom action bar for `Cancel` and `Insert`.
3. Keep visible tap targets at or above `48dp`.
4. If vertical space is constrained by the software keyboard, allow vertical
   scrolling of the content area but avoid horizontal scrolling of the matrix.
5. The active cell should remain visible when the keyboard opens.

## 8. Wireframes

### 8.1 Desktop wireframe

```text
+------------------------------------------------------------------+
| Insert Matrix                                                    |
| Order: [2x2] [3x3] [4x4]     Hint: Arrows move. Enter edits.     |
|                                                                  |
|          c1        c2        c3        c4                        |
|       /-----------------------------------------------\          |
| r1    | [ 1.0 ]   [ 0 ]     [ 0 ]     [ 0 ]          |          |
| r2    | [ 0 ]     [ 1.0 ]   [ 0 ]     [ 0 ]          |          |
| r3    | [ 0 ]     [ 0 ]     [ 1.0 ]   [ 0 ]          |          |
| r4    | [ 0 ]     [ 0 ]     [ 0 ]     [ 1.0 ]        |          |
|       \-----------------------------------------------/          |
|                                                                  |
| Actions: [Zeros] [Identity] [Clear]                              |
| Preview: [[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]              |
| Error: r2 c3 must be a number, like -2 or 3.5                   |
|                                              [Cancel] [Insert]   |
+------------------------------------------------------------------+
```

### 8.2 Mobile wireframe

```text
+--------------------------------------+
| Matrix                               |
| [2x2] [3x3] [4x4]                    |
| Next moves cell. Done commits.       |
|                                      |
|    /----------------------------\    |
| r1 | [ 1 ] [ 0 ] [ 0 ] [ 0 ]    |    |
| r2 | [ 0 ] [ 1 ] [ 0 ] [ 0 ]    |    |
| r3 | [ 0 ] [ 0 ] [ 1 ] [ 0 ]    |    |
| r4 | [ 0 ] [ 0 ] [ 0 ] [ 1 ]    |    |
|    \----------------------------/    |
|                                      |
| [Zeros] [Identity] [Clear]           |
| Preview unavailable until valid      |
+--------------------------------------+
| [Cancel]                 [Insert]    |
+--------------------------------------+
```

## 9. Acceptance Checklist

### 9.1 Implementation checklist

- [ ] The editor exposes direct `2x2`, `3x3`, and `4x4` order controls.
- [ ] The active order defaults to `2x2` when there is no prior draft.
- [ ] Changing order preserves the overlapping top-left values within the same draft session.
- [ ] Hidden cells are excluded from serialization and validation.
- [ ] Confirmed output is the canonical bracket literal accepted by core and CLI.
- [ ] Cells use text-based numeric entry, not spinbutton-style controls.
- [ ] Signed decimal input is supported in canonical dot-decimal form.
- [ ] Numbers are right-aligned and visually scannable.
- [ ] The grid behaves as one tab stop with arrow-key navigation.
- [ ] `Enter` or `F2` enters edit mode and `Esc` cancels the in-progress cell edit.
- [ ] `Tab` and `Shift+Tab` move between visible cells in row-major order.
- [ ] The editor exposes `Zeros`, `Identity`, and `Clear` quick actions.
- [ ] The action row stays visible on mobile with the software keyboard open.
- [ ] The `4x4` layout avoids horizontal scrolling on target phones.
- [ ] Error copy names the failing row and column explicitly.

### 9.2 QA checklist

- [ ] `2x2`, `3x3`, and `4x4` all serialize to the expected literal format.
- [ ] `Identity` fills the correct diagonal for every supported order.
- [ ] `Clear` empties only the visible active-order cells.
- [ ] In `Infix` mode, confirmation inserts the literal into the expression draft.
- [ ] In `RPN` mode, confirmation pushes the matrix result onto the stack.
- [ ] Keyboard-only entry works from first focus through confirmation.
- [ ] Screen-reader output identifies cell position and current value.
- [ ] Invalid cell content is recoverable without losing the user text.
- [ ] Preview never disagrees with the final serialized matrix.
- [ ] Cancel restores the pre-open state.
- [ ] The active cell remains visible after the mobile keyboard opens.

## 10. Deferred Decisions

The following items are intentionally deferred and should not block the base
editor redesign:

1. Advanced paste mode for full matrix literals
2. Locale-aware decimal comma support
3. Random-fill action
4. Multi-matrix compare/edit workflows

## 11. Verified References

1. W3C WAI-ARIA Authoring Practices Guide. Grid Pattern. Verified `2026-05-17`.
   https://www.w3.org/WAI/ARIA/apg/patterns/grid/
2. MDN Web Docs. ARIA: grid role. Verified `2026-05-17`.
   https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/grid_role
3. Material Design. Data tables. Verified `2026-05-17`.
   https://m2.material.io/components/data-tables
4. AG Grid. JavaScript Data Grid Keyboard Interaction. Verified `2026-05-17`.
   https://www.ag-grid.com/javascript-data-grid/keyboard-navigation/
5. Desmos Help Center. Matrix Calculator. Verified `2026-05-17`.
   https://help.desmos.com/hc/en-us/articles/4404851938445-Matrix-Calculator
6. GeoGebra Manual. Matrices. Verified `2026-05-17`.
   https://geogebra.github.io/docs/manual/en/Matrices/
7. GOV.UK Design System. Text input. Verified `2026-05-17`.
   https://design-system.service.gov.uk/components/text-input/
8. GOV.UK Technology Blog. Why the GOV.UK Design System team changed the input type for numbers. Verified `2026-05-17`.
   https://technology.blog.gov.uk/2020/02/24/why-the-gov-uk-design-system-team-changed-the-input-type-for-numbers/
9. MDN Web Docs. `<input type="number">`. Verified `2026-05-17`.
   https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/number
10. Calculator.net. Matrix Calculator. Verified `2026-05-17`.
    https://www.calculator.net/matrix-calculator.html
11. utils.com. Matrix Calculator. Verified `2026-05-17`.
    https://matrix.utils.com/