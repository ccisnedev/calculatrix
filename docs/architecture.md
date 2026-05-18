# Architecture

## Overview

Calculatrix is a shared-core calculator system.

- `package:calculatrix` is the semantic source of truth.
- `calculatrix_app` is the Flutter consumer shell.
- `calculatrix_cli` is the command-line consumer.

The current default app experience is an infix calculator oriented to scalar
and `1x1` workflows, but the runtime semantics are already matrix-first. The
current codebase is the `v0.3.0` foundation: the shared shell exposes visible
`Infix`, `RPN`, and `Matrix` modes, and the core exposes the public
machine/command/macro layer that all consumers route through.

## Runtime Truth

Evaluation no longer lives in app-local tokenizer/parser/evaluator code.
App and CLI delegate computation to the core package.

```text
Infix input (String)     -> Calculatrix.compileInfix(...) -> CalculatrixProgram
						 -> CalculatrixMachine.executeProgram(...) -> Matrix
RPN input (List<String>) -> typed commands / evaluateRpn(...)
						 -> CalculatrixMachine -> Matrix
```

All values are matrices. Scalars are represented as `1x1` matrices. Consumer
layers may choose to display `1x1` results as scalar text, but that does not
change the matrix-first semantics of the core.

## Responsibility Split

| Layer | Responsibility |
|-------|----------------|
| `package:calculatrix` | `Matrix`, `CalculatrixMachine`, typed commands/macros/programs, infix compilation/evaluation, session facade, numeric policy, error taxonomy |
| `calculatrix_app` | Shell mode selection, keypad paging, Matrix shell/workstation drafts, stack visualization, memory UX, formatting, accessibility |
| `calculatrix_cli` | Argument parsing, infix/RPN/command/macro routing, core invocation, output formatting, exit behavior |

## Consumer Shell Model (v0.3.0 Foundation)

The current application model is a single shell with specialized surfaces, not
multiple independent calculators.

- One shared calculator shell
- Three visible shell modes: `Infix` / `RPN` / `Matrix`
- Horizontally paged keypads
- Dedicated Matrix shell surface with embedded bounded `NxM` workstation controls
- Stack visualization in `RPN` mode
- Square keys across supported screen sizes
- Display/keypad height guided by a golden-ratio-like split when constraints allow

### Matrix Literal Entry Contract

- The app-side matrix editor serializes values to the same bracket literal accepted by the core package, for example `[[1,2],[3,4]]`.
- In `Infix` mode, confirming the matrix editor inserts that literal into the expression buffer.
- In `RPN` mode, confirming the matrix editor pushes the parsed matrix onto the stack.
- CLI workflows use the same literal format directly on the command line, so copy/paste between app and CLI remains lossless.

### Matrix Shell Contract

- Matrix mode is now part of the visible shell, not a separate calculator product.
- Matrix-focused keypad pages expose square order shortcuts, shape-aware helpers, and stack-native structural shortcuts.
- Structural edits remain draft-local in the app until confirmation, but committed structural commands route through public core commands or macros.

## Testing Policy

- **TDD is mandatory** for all new behavior.
- `code/core` should maintain full unit and contract coverage for public semantics and new logic.
- `code/app` stateful logic should target full unit coverage for controllers, view-models, and editor state.
- Widget tests should guard only critical UI contracts: semantics, mode switch, keypad paging, square key geometry, matrix rendering, and stack summaries.
- `code/app/integration_test` should cover canonical end-to-end user journeys for released features.
- `code/cli` should add automated unit and smoke/integration coverage for argument parsing, output formatting, and representative commands.
- Stage completion should include focused validation of core tests/analyze, Flutter tests, app integration flows, and CLI automation/smokes.

## RPN Interaction Contract (v0.3.0)

### Shared Current Value

- The shell maintains one committed current value, `X`, shared by `Infix` and `RPN`.
- In `Infix`, pressing `=` evaluates the current expression and replaces `X`.
- In `RPN`, `X` is the top of the committed stack.
- Switching notation mode must not clear `X`.
- If `RPN` mutates `X`, any stale `Infix` repeat-`=` state must be invalidated.

### Mode and Draft State

- `RPN` is an explicit user-visible mode, not a hidden internal implementation detail.
- The shell maintains notation-specific drafts while the user is typing a scalar or matrix literal.
- `Infix` and `RPN` drafts are private to their notation mode until explicitly committed.
- Mode switching must not silently reinterpret an uncommitted draft.

### Primary Action Key

- In `Infix` mode, the primary action key remains `=`.
- In `RPN` mode, the same visual position is relabeled to `ENTER`.
- `ENTER` commits the current operand draft onto the stack.
- `v0.3.0` does **not** overload `ENTER` as implicit duplicate; duplication stays explicit via `dup`.

### Operator Semantics

- If a draft operand is active, unary and binary operators commit that draft before delegating to the core stack engine.
- Unary operators (`√`, `%`) apply to the top of the committed stack.
- Binary operators (`+`, `-`, `*`, `/`) apply to the top two committed stack values.
- Error behavior follows the core error taxonomy exposed by `package:calculatrix`.

### Clear and Editing Semantics

- `⌫` edits only the active draft operand.
- `⌫` does not mutate already committed stack values.
- `C` clears the active draft when a draft exists.
- `C` clears the stack and transient error state when no draft is active.

### Memory Semantics

- Memory is matrix-first in the core session model.
- `MR` recalls the committed matrix value into the active consumer flow.
- `M+` and `M-` operate through the same shared core matrix rules instead of scalar-only consumer special cases.
- `MC` clears the memory register in both notation modes.

### Display Semantics

- In `Infix` mode, the primary display shows the active draft when editing, otherwise the shared committed current value `X`.
- In `RPN` mode, the primary display shows the active draft when editing, otherwise the top-of-stack summary for `X`.
- A dedicated stack surface shows recent stack levels and current depth.
- Matrix rendering policy belongs to the consumer shell, while matrix computation remains in the core package.

## Stage 3 Status and Stage 4 Gate

Stage 3 is complete in the current `v0.3.0` line.

The stabilized foundation now includes:

- `package:calculatrix` exports a public matrix stack machine, typed commands, typed macros, and typed programs.
- Infix compiles to typed programs executed by the same machine layer.
- The app shell already exposes `Infix`, `RPN`, and `Matrix` modes with Matrix-focused keypad pages.
- The CLI already routes infix, RPN, public commands, and public macros through the shared core.
- Public docs, versioning, and changelog entries are aligned with the canonical core model.
- Core, CLI, Flutter tests, and the Windows app integration suite are green.

The project is ready for Stage 4.

Stage 4 can now focus on advanced linear algebra on top of the stable canonical
kernel instead of carrying unresolved Stage 3 release debt.

See [docs/spec/stage_3_matrix_stack_machine.md](docs/spec/stage_3_matrix_stack_machine.md) for the Stage 3 contract.

## Cleanup Status

The historical app-side tokenizer/parser/evaluator pipeline has been removed
from `calculatrix_app`. Current consumers rely exclusively on the shared core
package for evaluation semantics.
Only shell concerns remain in the app: mode switching, matrix entry, display,
stack presentation, memory UX, and accessibility.
