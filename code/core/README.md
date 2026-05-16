[![pub package](https://img.shields.io/pub/v/calculatrix.svg)](https://pub.dev/packages/calculatrix)

# Calculatrix

Calculatrix is a pure Dart computation engine designed for calculator products.
It is matrix-first and RPN-first by design: scalar values are represented as `1x1`
matrices, so algebraic and stack-based workflows share the same math core.

## Status

- Current line: `2.0.0-dev`
- Focus: Stage 2 foundation (matrix core + RPN core)
- Runtime dependencies: none (pure Dart)

## Features available now

- Immutable `Matrix` type with dimension validation
- Matrix operations: `+`, `-`, `*`, transpose, scalar helpers
- `RpnEngine` stack with binary operators (`add`, `subtract`, `multiply`)
- Unit tests for matrix and RPN fundamentals

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

