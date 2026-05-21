# ADR 0003: Honest RPN Shell and Invoked Editors

**Status:** Accepted

## Context

The shared core is already matrix-first and stack-first, but the Flutter shell
still presents three visible runtime modes: `Infix`, `RPN`, and `Matrix`.

That presentation causes several architectural problems:

- it suggests three peer runtime semantics even though the core runtime truth is
  the matrix stack machine,
- it blurs the boundary between committed stack state and temporary editing
  state,
- it allows the primary `RPN` card to look like committed `X0` even when it is
  only showing a draft,
- it couples the top command bar to mode-specific deck families instead of to a
  stable command taxonomy,
- it treats `Matrix` as a visible shell mode even though it is fundamentally an
  editor over a draft.

We need a shell model that is honest about stack semantics, preserves matrix
purity, and keeps committed stack registers visually truthful at all times.

## Decision

### 1. `RPN` is the only persistent shell

The Flutter app will expose one persistent shell surface: `RPN`.

- The visible `Infix / RPN / Matrix` mode switch is removed.
- Committed runtime truth in the app is always the committed `RPN` stack.
- `X0`, `X1`, `X2`, ... always refer only to committed stack registers.

### 2. `Infix` and `Matrix` become invoked editors

`Infix` and `Matrix` are not peer shell modes.

- `Infix` is an invoked editor over a pre-stack draft.
- `Matrix` is an invoked editor over the same pre-stack draft.
- Entering either editor happens explicitly through the `EDIT` module.
- Touch interaction on committed stack cards remains read-only.

### 3. The pre-stack draft is distinct from the committed stack

The app maintains one pending draft surface that is not part of the committed
stack until a real commit occurs.

- A draft must never be labeled as `X0` or as any other committed register.
- While a draft exists, committed stack numbering remains unchanged.
- If committed `X0` is visible, it stays visible as committed `X0` until the
  draft is actually pushed or otherwise committed through stack semantics.

### 4. Commit semantics differ between shell `RPN` and invoked editors

The shell keeps normal `RPN` draft behavior.

- In persistent `RPN`, `ENTER` may commit the active shell draft onto the stack.
- In persistent `RPN`, unary and binary operators may still auto-commit the
  active shell draft before delegating to the core stack engine.

The invoked editors have stricter exit semantics.

- In the `Infix` editor, `=` remains an infix-only action.
- In the `Infix` editor, `ENTER` resolves the draft to matrices, pushes the
  result onto the stack, and returns to `RPN`.
- In the `Matrix` editor, `ENTER` validates and pushes the matrix draft onto the
  stack, then returns to `RPN`.
- In both editors, `CANCEL` discards the pending editor draft and returns to
  `RPN`.

### 5. The keypad layout becomes fixed

The fixed shell keypad is:

```text
 7   8   9   ÷   INFIX
 4   5   6   ×   DELETE
 1   2   3   -   =
 0   .   ±   +   ENTER
```

- `INFIX` is the explicit entry point to the infix editor.
- `DELETE` edits the active draft when a draft exists.
- When no draft exists, the same physical `DELETE` key may act as `DROP` over
  committed `X0`.
- Outside the infix editor, `=` has no independent shell meaning.

### 6. The command taxonomy becomes fixed

The dynamic mode-specific command decks are replaced by one fixed module bar:

- `BASIC`
- `STACK`
- `MATH`
- `MATRIX`
- `VECTOR`
- `FACT`
- `PROP`
- `EDIT`
- `BUILD`
- `MEM`

Each module exposes up to 10 command slots without filler duplication.

- Empty slots are acceptable.
- Overflow uses explicit paging controls only when extra pages really exist.

### 7. Memory adopts pocket-calculator-style `MRC`

The shell may compress memory controls into a calculator-style `MRC` key.

- First consecutive press: memory recall.
- Second consecutive press: memory clear.

This is a shell interaction decision only. Core memory semantics remain
matrix-first and continue to live in `package:calculatrix`.

## Consequences

- The app becomes honest about its runtime semantics: the visible runtime is the
  matrix stack machine, not three peer modes.
- The committed stack becomes visually truthful because drafts are no longer
  mislabeled as `X0`.
- `Matrix` is reclassified from a visible shell mode to an editor over a draft.
- `Infix` remains available, but explicitly as an editor and not as a second
  persistent calculator.
- The fixed keypad and fixed module taxonomy make command discoverability more
  stable, but require reorganization of current shell decks.
- Widget and integration tests that assert a visible mode switch, matrix mode,
  or draft-as-`X0` presentation must be replaced.
- The app shell gains a cleaner long-term home for future functions such as
  `log`, `ln`, and `exp` via the reserved `MATH` module.

## Follow-up Guidance

- Align `docs/architecture.md` with this ADR.
- Keep `docs/roadmap.md` synchronized with the Stage 7 execution order.
- Implement the shell transition through TDD, beginning with tests that lock
  truthful committed stack numbering and explicit editor entry/exit behavior.
- Treat this ADR as a shell decision only; do not move matrix or stack semantics
  out of `package:calculatrix`.