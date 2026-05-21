# Architecture

## Overview

Calculatrix is a shared-core calculator system.

- `package:calculatrix` is the semantic source of truth.
- `calculatrix_app` is the Flutter consumer shell.
- `calculatrix_cli` is the command-line consumer.

The current default app experience is an infix calculator oriented to scalar
and `1x1` workflows, but the runtime semantics are already matrix-first. The
current roadmap direction after the `v0.6.x` line is an honest `RPN` shell:
the persistent app surface is `RPN`, while `Infix` and `Matrix` are invoked
editors over a pre-stack draft. The core continues to expose the public
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
| `calculatrix_app` | Persistent `RPN` shell, pre-stack draft lifecycle, invoked `Infix` / `Matrix` editors, fixed module bar, stack visualization, memory UX, formatting, accessibility |
| `calculatrix_cli` | Argument parsing, infix/RPN/command/macro routing, core invocation, output formatting, exit behavior |

## Consumer Shell Model (v0.7.0)

The current application model is a single shell with specialized surfaces, not
multiple independent calculators.

- One shared calculator shell
- One persistent shell mode: `RPN`
- Two invoked editors over the same pre-stack draft: `Infix` and `Matrix`
- One labeled `Draft` surface distinct from committed `X0`, `X1`, `X2`, ...
- Fixed module taxonomy instead of mode-specific dynamic deck families
- Fixed keypad layout with contextual command modules above it
- Stack visualization in the persistent `RPN` shell
- Square keys across supported screen sizes
- Display/keypad height guided by a golden-ratio-like split when constraints allow

### Draft and Editor Contract

- The app-side matrix editor serializes values to the same bracket literal accepted by the core package, for example `[[1,2],[3,4]]`.
- The app maintains one pre-stack draft that is not part of the committed `RPN` stack until a real commit occurs.
- The shell renders that pre-stack surface as `Draft` (or `Error` when appropriate), never as an `X` register.
- Entering the `Infix` editor opens that draft as an infix expression draft.
- Entering the `Matrix` editor opens that draft as a matrix-construction draft.
- In the `Infix` editor, `=` remains an infix-only action, while `ENTER` resolves the draft to matrices, pushes the resulting value onto the stack, and returns to the `RPN` shell.
- In the `Matrix` editor, `ENTER` validates and pushes the matrix draft onto the stack, then returns to the `RPN` shell.
- `CANCEL` discards the pending editor draft and returns to `RPN`.
- CLI workflows use the same literal format directly on the command line, so copy/paste between app and CLI remains lossless.

### Draft and Stack Boundary Contract

- The committed stack remains the only truthful source of `X0`, `X1`, `X2`, ... register numbering.
- A pending draft must never be mislabeled as `X0` or as any other committed register.
- Touch interaction on committed stack cards is read-only; editor entry happens only through explicit `EDIT` commands.
- Matrix-building actions remain draft-local until confirmation, while committed stack operations continue to route through public core commands or macros.

## Testing Policy

- **TDD is mandatory** for all new behavior.
- `code/core` should maintain full unit and contract coverage for public semantics and new logic.
- `code/app` stateful logic should target full unit coverage for controllers, view-models, and editor state.
- Widget tests should guard only critical UI contracts: semantics, fixed module bar, truthful committed stack numbering, square key geometry, matrix rendering, and stack summaries.
- `code/app/integration_test` should cover canonical end-to-end user journeys for released features.
- `code/cli` should add automated unit and smoke/integration coverage for argument parsing, output formatting, and representative commands.
- Stage completion should include focused validation of core tests/analyze, Flutter tests, app integration flows, and CLI automation/smokes.

## RPN Interaction Contract (v0.7.0)

### Shared Current Value

- The shell maintains one committed current value, `X`, which is always the top of the committed `RPN` stack.
- The `Infix` editor works over a draft and may resolve that draft to a matrix result, but the committed `RPN` stack remains the runtime source of truth.
- Opening or closing an editor must not silently mutate committed `X`.
- If the committed `RPN` stack mutates `X`, any stale `Infix` repeat-`=` state must be invalidated.

### Draft and Editor State

- `RPN` is the only persistent user-visible shell state.
- The shell may still maintain a direct `RPN` input draft while the user is typing in the shell.
- The shell also maintains one editor-owned pre-stack draft for the invoked `Infix` and `Matrix` editors.
- Entering an editor must be explicit through the `EDIT` module; the shell must not silently reinterpret one draft as another.

### Primary Action Key

- In the persistent `RPN` shell, the bottom-right key is `ENTER` and continues to commit the current shell draft onto the stack.
- In the `Infix` editor, `=` is an infix-only action, while `ENTER` resolves the editor draft to matrices, pushes the result to the stack, and returns to `RPN`.
- In the `Matrix` editor, `ENTER` confirms the matrix draft, pushes it onto the stack, and returns to `RPN`.
- `v0.7.0` still does **not** overload `ENTER` as implicit duplicate; duplication stays explicit via `dup`.

### Operator Semantics

- If a draft operand is active, unary and binary operators commit that draft before delegating to the core stack engine.
- Unary operators (`√`, `%`) apply to the top of the committed stack.
- Binary operators (`+`, `-`, `*`, `/`) apply to the top two committed stack values.
- Error behavior follows the core error taxonomy exposed by `package:calculatrix`.

### Fixed Shell Keys

- The fixed keypad layout is:

```text
 7   8   9   ÷   INFIX
 4   5   6   ×   DELETE
 1   2   3   -   =
 0   .   ±   +   ENTER
```

- `INFIX` invokes the `Infix` editor from the `RPN` shell.
- `DELETE` edits the active draft when a draft exists.
- When no draft exists, the same physical `DELETE` key may act as `DROP` over committed `X0`.
- Outside the `Infix` editor, `=` has no independent shell meaning; `ENTER` is the stack-facing evaluation and commit action.

### Clear and Editing Semantics

- `DELETE` edits only the active draft operand when a draft exists.
- `DELETE` does not mutate already committed stack values unless it is explicitly acting as contextual `DROP` on `X0` with no draft active.
- `C` clears the active draft when a draft exists.
- `C` clears the stack and transient error state when no draft is active.
- `CANCEL` inside an invoked editor discards the pending editor draft and returns to `RPN`.

### Memory Semantics

- Memory is matrix-first in the core session model.
- `MRC` behaves like a pocket-calculator memory recall/clear key: the first press recalls the committed matrix value, and the second consecutive press clears memory.
- `M+` and `M-` operate through the same shared core matrix rules instead of scalar-only consumer special cases.
- Explicit memory semantics still live in the core package even when the shell presents them through compact calculator-style controls.

### Display Semantics

- In the `RPN` shell, the display may show the active shell draft in a `Draft` card when editing, otherwise the top-of-stack summary for committed `X`.
- In an invoked editor, the display shows the active editor draft and editor-local feedback.
- A dedicated stack surface shows recent stack levels and current depth.
- The committed stack surface never relabels a draft as `X0`.
- Matrix rendering policy belongs to the consumer shell, while matrix computation remains in the core package.

## Stage 3 Status and Stage 4 Gate

Stage 3 is complete in the current `v0.3.0` line.

The stabilized foundation now includes:

- `package:calculatrix` exports a public matrix stack machine, typed commands, typed macros, and typed programs.
- Infix compiles to typed programs executed by the same machine layer.
- The app shell is moving from visible `Infix` / `RPN` / `Matrix` modes toward one persistent `RPN` shell with invoked editors.
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
Only shell concerns remain in the app: editor entry, matrix entry, display,
stack presentation, fixed-module navigation, memory UX, and accessibility.
