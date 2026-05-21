# Stage 7 Honest RPN Shell Specification

Status: Implemented in v0.7.0
Owner: Calculatrix maintainers
Primary target path: `code/app`
Secondary target path: `code/core` only if shell contracts require explicit
state support not already exposed by `CalculatrixSession`

## 1. Purpose

This document breaks Stage 7 into implementation-oriented stories for the
Flutter shell.

The goal is to replace the visible three-mode shell with one persistent `RPN`
shell, two invoked editors (`Infix` and `Matrix`), one truthful committed stack
surface, and one fixed module taxonomy.

This is a shell specification. It does not move matrix semantics, stack
semantics, or memory algebra out of `package:calculatrix`.

## 2. Scope

### 2.1 In scope

1. Remove the visible `Infix / RPN / Matrix` mode switch from the app shell
2. Keep `RPN` as the only persistent shell surface
3. Separate the pre-stack draft from committed `X0`, `X1`, `X2`, ...
4. Route `Infix` and `Matrix` through explicit editor entry points
5. Replace dynamic deck families with one fixed module taxonomy
6. Adopt the fixed keypad layout agreed for Stage 7
7. Implement contextual `DELETE` / `DROP`
8. Implement shell-level `MRC` toggle behavior
9. Refresh shell documentation and app tests

### 2.2 Out of scope

1. New mathematical algorithms in the core
2. Full population of the future `MATH` module beyond agreed seed actions
3. Reordering or polishing every module beyond the initial Stage 7 contract
4. Editing committed stack cards directly by touch
5. CLI UX redesign

## 3. Normative Shell Contract

### 3.1 Persistent Shell

1. `RPN` is the only persistent shell surface
2. Committed runtime truth is always the committed stack
3. `X0`, `X1`, `X2`, ... refer only to committed stack registers

### 3.2 Draft Boundary

1. The app may hold a shell draft while the user types in `RPN`
2. The app may also hold an editor-owned pre-stack draft
3. No draft may be labeled as committed `X0`
4. While a draft exists, committed stack numbering stays unchanged

### 3.3 Editor Entry and Exit

1. `INFIX` opens the infix editor explicitly
2. `MATRIX` is opened explicitly from the `EDIT` module
3. In the `Infix` editor, `=` remains infix-only
4. In the `Infix` editor, `ENTER` resolves the draft to matrices, pushes the
   result, and returns to `RPN`
5. In the `Matrix` editor, `ENTER` validates and pushes the matrix draft, then
   returns to `RPN`
6. In both editors, `CANCEL` discards the draft and returns to `RPN`

### 3.4 Fixed Keypad Contract

The fixed keypad is:

```text
 7   8   9   ÷   INFIX
 4   5   6   ×   DELETE
 1   2   3   -   =
 0   .   ±   +   ENTER
```

Rules:

1. `DELETE` edits the active draft when a draft exists
2. When no draft exists, `DELETE` may act as `DROP` on committed `X0`
3. Outside the infix editor, `=` has no independent shell meaning
4. In `RPN`, `ENTER` remains the stack-facing commit/evaluation key

### 3.5 Fixed Module Taxonomy

The fixed module bar contains:

1. `BASIC`
2. `STACK`
3. `MATH`
4. `MATRIX`
5. `VECTOR`
6. `FACT`
7. `PROP`
8. `EDIT`
9. `BUILD`
10. `MEM`

Rules:

1. Each module page exposes up to 10 command slots
2. Empty slots are allowed
3. Commands must not be duplicated only to fill space
4. Overflow paging uses `>` on the first overflowing page and `<` / `>` on
   intermediate pages only when extra pages exist

### 3.6 BASIC Seed Contract

The initial `BASIC` command map is:

```text
 MRC  M-   M+   AC   C
 ___  %   SQRT INV   i
```

`MATH` is reserved for later expansion with functions such as `log`, `ln`, and
`exp` once the Stage 7 shell is stable.

## 4. Technical Stories

### Story 1. Truthful committed stack presentation

Objective:

Separate committed stack rendering from draft rendering so the shell never
mislabels a draft as `X0`.

Acceptance criteria:

1. The primary committed stack card always shows committed `X0`
2. A pending draft is rendered in a distinct `Draft` or `Error` surface
   without `X` labeling
3. Entering digits in `RPN` no longer visually shifts committed `X0` to `X1`
   before a real commit occurs
4. Existing committed stack depth indicators stay truthful while a draft exists

Focused tests:

1. Widget test: typing a shell draft leaves committed `X0` label/value intact
2. Widget test: draft surface appears with `Draft` semantics and without `X`
   register semantics
3. Controller test: committed stack literals remain unchanged until commit

Likely touch points:

1. `code/app/lib/modules/calc/view.dart`
2. `code/app/lib/modules/calc/controller.dart`
3. `code/app/test/modules/calc/calculator_view_test.dart`
4. `code/app/test/modules/calc/calculator_controller_test.dart`

### Story 2. Fixed keypad frame

Objective:

Adopt the Stage 7 keypad layout without reintroducing mode-dependent key
positions.

Acceptance criteria:

1. The four fixed keypad rows match the Stage 7 layout exactly
2. `INFIX`, `DELETE`, `=`, and `ENTER` remain in stable positions
3. Key geometry remains square across supported viewports

Focused tests:

1. Widget test: each fixed key exists in the expected layout
2. Widget test: keys remain square
3. Integration test: keypad actions still work on the canonical target

Likely touch points:

1. `code/app/lib/modules/calc/view.dart`
2. `code/app/test/modules/calc/calculator_view_test.dart`
3. `code/app/integration_test/calculator_test.dart`

### Story 3. Fixed module bar and overflow paging

Objective:

Replace the dynamic mode/deck selector with a stable module taxonomy and explicit
overflow navigation.

Acceptance criteria:

1. The module bar always exposes the same top-level module names
2. Modules do not disappear because of shell mode changes
3. Empty command slots render inertly when needed
4. Overflow paging appears only for modules that really need it

Focused tests:

1. Widget test: all fixed module labels are present
2. Widget test: a short module keeps empty slots instead of duplicated commands
3. Widget test: overflow arrows appear only on overflowing modules

Likely touch points:

1. `code/app/lib/modules/calc/view.dart`
2. `code/app/test/modules/calc/calculator_view_test.dart`
3. `code/app/test/modules/calc/accessibility_semantics_test.dart`

### Story 4. EDIT module and editor lifecycle

Objective:

Make `Infix` and `Matrix` explicit editor entry points instead of peer shell
modes.

Acceptance criteria:

1. `EDIT` exposes `INFIX` and `MATRIX`
2. Entering an editor does not mutate the committed stack
3. In the infix editor, `=` stays local to infix editing
4. In both editors, `ENTER` pushes to the stack and returns to `RPN`
5. In both editors, `CANCEL` discards the draft and returns to `RPN`

Focused tests:

1. Widget test: `EDIT` opens `INFIX` and `MATRIX` explicitly
2. Integration test: editor `ENTER` returns to `RPN` with a pushed result
3. Integration test: editor `CANCEL` returns to `RPN` without stack mutation

Likely touch points:

1. `code/app/lib/modules/calc/view.dart`
2. `code/app/lib/modules/calc/controller.dart`
3. `code/app/test/modules/calc/calculator_view_test.dart`
4. `code/app/integration_test/calculator_test.dart`

### Story 5. Contextual DELETE / DROP behavior

Objective:

Make the fixed delete key honest about whether the user is editing a draft or
mutating the committed stack.

Acceptance criteria:

1. With an active draft, `DELETE` edits only that draft
2. Without a draft, the same key acts as `DROP` on committed `X0`
3. Draft deletion and stack drop are visually distinguishable in semantics and
   tests

Focused tests:

1. Controller test: `DELETE` shortens the draft when draft exists
2. Controller test: `DELETE` drops committed `X0` when no draft exists
3. Widget test: semantics/tooltip reflect the contextual behavior

Likely touch points:

1. `code/app/lib/modules/calc/view.dart`
2. `code/app/lib/modules/calc/controller.dart`
3. `code/app/test/modules/calc/calculator_controller_test.dart`
4. `code/app/test/modules/calc/accessibility_semantics_test.dart`

### Story 6. Pocket-calculator-style MRC

Objective:

Compress recall/clear memory UX into one shell-facing key without changing the
matrix-first core memory model.

Acceptance criteria:

1. First consecutive `MRC` press recalls memory
2. Second consecutive `MRC` press clears memory
3. Any intervening non-`MRC` action resets the consecutive-press cycle
4. Memory arithmetic stays core-driven and matrix-first

Focused tests:

1. Controller test: first `MRC` press recalls
2. Controller test: second consecutive `MRC` press clears
3. Controller test: non-`MRC` action resets the sequence
4. Integration test: recall/clear flow works from the shell

Likely touch points:

1. `code/app/lib/modules/calc/controller.dart`
2. `code/app/lib/modules/calc/view.dart`
3. `code/app/test/modules/calc/calculator_controller_test.dart`
4. `code/app/integration_test/calculator_test.dart`

### Story 7. BASIC module seed and documentation cleanup

Objective:

Lock the initial BASIC command map and align docs/tests with the new shell
taxonomy.

Acceptance criteria:

1. `BASIC` matches the agreed 10-slot seed map
2. `SQRT` is available in `BASIC` for Stage 7 even though `MATH` exists
3. Documentation no longer describes a visible three-mode shell

Focused tests:

1. Widget test: BASIC exposes the agreed command set
2. Accessibility test: BASIC command labels remain descriptive
3. Doc validation: architecture, roadmap, and ADR all align on the shell model

Likely touch points:

1. `code/app/lib/modules/calc/view.dart`
2. `code/app/test/modules/calc/calculator_view_test.dart`
3. `code/app/test/modules/calc/accessibility_semantics_test.dart`
4. `docs/architecture.md`
5. `docs/roadmap.md`
6. `docs/adr/0003-honest-rpn-shell-and-invoked-editors.md`

## 5. Recommended Execution Order

1. Story 1. Truthful committed stack presentation
2. Story 4. EDIT module and editor lifecycle
3. Story 2. Fixed keypad frame
4. Story 3. Fixed module bar and overflow paging
5. Story 5. Contextual DELETE / DROP behavior
6. Story 6. Pocket-calculator-style MRC
7. Story 7. BASIC module seed and documentation cleanup

## 6. Validation Matrix

Before closing Stage 7, rerun at minimum:

1. `code/core` focused tests for unchanged stack semantics if any core-facing
   adapter changes were needed
2. `code/app` focused controller and widget tests for draft/stack separation
3. `code/app/integration_test` canonical editor-entry and stack workflows
4. Accessibility widget coverage for fixed modules and contextual key labels
5. `code/cli` smoke validation confirming shell changes did not imply CLI
   contract changes