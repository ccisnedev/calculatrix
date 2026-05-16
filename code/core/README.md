[![pub package](https://img.shields.io/pub/v/calculatrix.svg)](https://pub.dev/packages/calculatrix)

# Calculatrix

Calculatrix is a pure Dart computation engine designed for calculator products.
It is matrix-first and RPN-first by design: scalar values are represented as `1x1`
matrices, so algebraic and stack-based workflows share the same math core.

## Status

- Current published version: `0.0.1`
- Focus: stable Stage 2 core baseline
- Runtime dependencies: none (pure Dart)

## Features available now

- Immutable `Matrix` type with dimension validation
- Matrix operations: `+`, `-`, `*`, scale, transpose
- Multiplication treats `1x1` operands as scalar scaling, so both `A * [[s]]` and `[[s]] * A` are valid
- `RpnEngine` stack with binary operators (`add`, `subtract`, `multiply`, `divide`)
- `RpnEngine` stack utilities: `dup`, `drop`, `swap`, `over`
- Unary operators: square root (`sqrt`) and percent (`%`)
- `Calculatrix` facade: `evaluateInfix` and `evaluateRpn`
- Unit tests for matrix, RPN, and cross-notation evaluation

## Numeric policy

- Exact `==` on `Matrix` remains strict and value-based.
- Approximate floating-point comparison is available through `Matrix.almostEquals`.
- Default tolerances:
	- relative: `1e-10`
	- absolute: `1e-12`

## API stability

- The current Stage 2.x API is intended to remain stable as the base for Stage 3 UX work.
- RPN stack failures are exposed through the `RpnStackError` hierarchy:
	- `RpnStackUnderflowError`
	- `RpnStackRangeError`
- App and CLI consumers should depend on the public barrel `package:calculatrix/calculatrix.dart`.

## Quick start

```dart
import 'package:calculatrix/calculatrix.dart';

void main() {
	final Matrix a = Matrix(<List<double>>[
		<double>[1, 2],
		<double>[3, 4],
	]);

	final Matrix result = a * Matrix.scalar(2);
	print(result); // Matrix([[2.0, 4.0], [6.0, 8.0]])
}
```

## Roadmap

See the roadmap in [ROADMAP.md](ROADMAP.md).

## License

This project is licensed under the MIT License.

