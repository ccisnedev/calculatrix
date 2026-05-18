# calculatrix_cli

Command-line interface package for Calculatrix.

It is a thin adapter over the same public core APIs exposed by
`package:calculatrix`.

## Modes

- `infix`: evaluate an infix expression through the canonical kernel
- `rpn`: evaluate an RPN token sequence through the same kernel
- `command`: execute typed public commands against a stack machine
- `macro`: execute public macro workflows

## Run

```bash
dart run bin/calculatrix_cli.dart
```

## Examples

```bash
dart run bin/calculatrix_cli.dart infix "[[1,2],[3,4]] * [[2]]"
dart run bin/calculatrix_cli.dart rpn 3 4 + 5 *
dart run bin/calculatrix_cli.dart command "[[1,2],[3,4]]" transpose
dart run bin/calculatrix_cli.dart command "[[1,2],[3,4]]" duplicate-row:0
dart run bin/calculatrix_cli.dart macro append-zero-row "[[1,2],[3,4]]"
```

## Parameterized command syntax

- `identity:3`
- `zeros:2x3`
- `ones:2x3`
- `delete-row:1`
- `delete-column:1`
- `duplicate-row:0`
- `duplicate-column:0`
- `move-row:0:2`
- `move-column:0:2`
- `pick:2`
- `roll:3`

## Exit behavior

- Evaluation and domain errors exit with code `1`.
- Usage errors exit with code `64` and print help.
