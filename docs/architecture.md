# Architecture

## Overview

Calculatrix is a shared-core calculator system.

- `package:calculatrix` is the semantic source of truth.
- `calculatrix_app` is the Flutter consumer shell.
- `calculatrix_cli` is the command-line consumer.

The current default app experience is an infix calculator oriented to scalar
and `1x1` workflows, but the runtime semantics are already matrix-first. Late
v2.x extends the same shell with matrix entry, paged keyboards, and explicit
`RPN` mode instead of introducing separate calculator products.

## Runtime Truth

Evaluation no longer lives in app-local tokenizer/parser/evaluator code.
App and CLI delegate computation to the core package.

```text
Infix input (String)    -> Calculatrix.evaluateInfix(...) -> Matrix
RPN input (List<String>) -> Calculatrix.evaluateRpn(...)  -> Matrix
```

All values are matrices. Scalars are represented as `1x1` matrices. Consumer
layers may choose to display `1x1` results as scalar text, but that does not
change the matrix-first semantics of the core.

## Responsibility Split

| Layer | Responsibility |
|-------|----------------|
| `package:calculatrix` | `Matrix`, algebraic parsing/evaluation, `RpnEngine`, numeric policy, error taxonomy |
| `calculatrix_app` | Mode selection, keypad paging, matrix editor, stack visualization, memory UX, formatting, accessibility |
| `calculatrix_cli` | Argument parsing, command routing, core invocation, output formatting, exit behavior |

## Consumer Shell Model (Late v2.x)

The late-v2 application model is a single shell with specialized surfaces, not
multiple independent calculators.

- One shared calculator shell
- Explicit notation mode switch: `Infix` / `RPN`
- Horizontally paged keypads
- Dedicated `NxM` matrix editor surface
- Stack visualization in `RPN` mode
- Square keys across supported screen sizes
- Display/keypad height guided by a golden-ratio-like split when constraints allow

## Testing Policy

- **TDD is mandatory** for all new behavior.
- `code/core` should maintain full unit and contract coverage for public semantics and new logic.
- `code/app` stateful logic should target full unit coverage for controllers, view-models, and editor state.
- Widget tests should guard only critical UI contracts: semantics, mode switch, keypad paging, square key geometry, matrix rendering, and stack summaries.
- `code/app/integration_test` should cover canonical end-to-end user journeys for released features.
- `code/cli` should add automated unit and smoke/integration coverage for argument parsing, output formatting, and representative commands.
- Stage completion should include focused validation of core tests/analyze, Flutter tests, app integration flows, and CLI automation/smokes.

## RPN Interaction Contract (Late v2.x)

### Mode and Draft State

- `RPN` is an explicit user-visible mode, not a hidden internal implementation detail.
- The shell maintains a current operand draft while the user is typing a scalar or matrix literal.
- Mode switching must not silently reinterpret an uncommitted draft.

### Primary Action Key

- In `Infix` mode, the primary action key remains `=`.
- In `RPN` mode, the same visual position is relabeled to `ENTER`.
- `ENTER` commits the current operand draft onto the stack.
- Late v2.x does **not** overload `ENTER` as implicit duplicate; duplication stays explicit via `dup`.

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

- Memory remains scalar-only through the initial late-v2 `RPN` rollout.
- `MR` pushes the recalled scalar as a `1x1` operand in `RPN` mode.
- `M+` and `M-` read from the active scalar draft when present; otherwise they read from the top of stack when that value is scalar.
- Non-scalar matrix values are rejected for memory accumulation until matrix memory semantics are explicitly broadened.
- `MC` clears the memory register in both notation modes.

### Display Semantics

- In `RPN` mode, the primary display shows the active draft when editing, otherwise the top-of-stack summary.
- A dedicated stack surface shows recent stack levels and current depth.
- Matrix rendering policy belongs to the consumer shell, while matrix computation remains in the core package.

## Legacy Note

Historical app-side tokenizer/parser/evaluator files may still exist as
migration artifacts, but they are not the runtime source of truth. They are
scheduled for removal during the late-v2 cleanup/freeze work.
