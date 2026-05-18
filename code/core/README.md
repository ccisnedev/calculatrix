[![pub package](https://img.shields.io/pub/v/calculatrix.svg)](https://pub.dev/packages/calculatrix)

# Calculatrix

Calculatrix is a pure Dart computation engine designed for calculator products.
It is matrix-first by design: scalars are represented as `1x1` matrices, so
algebraic input, direct stack workflows, and calculator session state all share
the same canonical kernel.

## Status

- Current package version: `3.1.0`
- Focus: Stage 4 determinant slice over the canonical matrix stack kernel
- Runtime dependencies: none (pure Dart)

## Features available now

- Immutable `Matrix` type with dimension validation
- `CalculatrixMachine` as the canonical mutable stack machine
- Typed public commands, typed public macros, and typed public programs
- `Calculatrix.compileInfix`, `evaluateInfix`, and `evaluateRpn`
- `CalculatrixSession` for interactive shared calculator state and memory
- Matrix operations: `+`, `-`, `*`, `/`, `sqrt`, `scale`, `transpose`, `inverse`, `determinant`
- Multiplication treats `1x1` operands as scalar scaling, so both `A * [[s]]`
	and `[[s]] * A` are valid
- Division currently supports scalar `1x1` denominators only; general matrix
	right-division remains deferred to a later linear-system workflow
- Square root supports square matrices in the real domain and throws typed
	domain errors when no real root is available
- Primitive command families for stack operations, push/construction, unary,
	binary, and parameterized structural edits
- Public macros including zeros-like, ones-like, append-zero-row,
	append-zero-column, and identity creation
- Unit tests for matrix, RPN, session, and cross-notation evaluation

## Public API surface

The main public barrel is `package:calculatrix/calculatrix.dart` and exports:

- `Matrix` and `MatrixDisplayFormatter`
- `CalculatrixMachine`
- `CalculatrixCommand`, `CalculatrixMacro`, `CalculatrixProgram`
- typed commands from `commands.dart`
- public macros from `macros.dart`
- `CalculatrixSession`
- numeric policy and typed error taxonomy

## Numeric policy

- Exact `==` on `Matrix` remains strict and value-based.
- Approximate floating-point comparison is available through `Matrix.almostEquals`.
- Default tolerances:
	- relative: `1e-10`
	- absolute: `1e-12`

## API stability

- `v3.0.0` establishes the public matrix stack machine surface.
- `v3.1.0` starts Stage 4 with determinant as a non-breaking command-surface expansion.
- RPN stack failures are exposed through the `RpnStackError` hierarchy:
	- `RpnStackUnderflowError`
	- `RpnStackRangeError`
- App and CLI consumers should depend on the public barrel `package:calculatrix/calculatrix.dart`.

## Quick start

```dart
import 'package:calculatrix/calculatrix.dart';

void main() {
	final CalculatrixProgram program = Calculatrix.compileInfix(
	  '[[1,2],[3,4]] * [[2]]',
	);

	final CalculatrixMachine machine = CalculatrixMachine();
	machine.executeProgram(program);
	machine.executeMacro(const AppendZeroRowMacro());

	print(MatrixDisplayFormatter.compact(machine.top!));
	// [[2,4],[6,8],[0,0]]
}
```

## Roadmap

See the roadmap in [../../docs/roadmap.md](../../docs/roadmap.md).

## License

This project is licensed under the MIT License.

