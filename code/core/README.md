[![pub package](https://img.shields.io/pub/v/calculatrix.svg)](https://pub.dev/packages/calculatrix)

# Calculatrix

Calculatrix is a pure Dart computation engine designed for calculator products.
It is matrix-first and RPN-first by design: scalar values are represented as
`1x1` matrices, so algebraic and stack-based workflows share the same math core.

## Status

- Current package version: `2.11.0`
- Focus: Stage 2.11.0 core-only matrix semantics
- Runtime dependencies: none (pure Dart)

## Features available now

- Immutable `Matrix` type with dimension validation
- Matrix operations: `+`, `-`, `*`, `/`, `sqrt`, `scale`, `transpose`
- Multiplication treats `1x1` operands as scalar scaling, so both `A * [[s]]`
	and `[[s]] * A` are valid
- Division currently supports scalar `1x1` denominators only; general matrix
	right-division is deferred to the determinant/inverse stage
- Square root supports square matrices in the real domain and throws typed
	domain errors when no real root is available
- `RpnEngine` stack with binary operators (`add`, `subtract`, `multiply`, `divide`)
- `RpnEngine` stack utilities: `dup`, `drop`, `swap`, `over`, `pick`, `roll`, `rot`
- Unary operators: square root (`sqrt`) and percent (`%`)
- `CalculatrixSession` for shared calculator state, notation drafts,
	committed value `X`, matrix memory, and stack mutations
- `Calculatrix` facade: `evaluateInfix` and `evaluateRpn`
- Unit tests for matrix, RPN, session, and cross-notation evaluation

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
	final CalculatrixSession session = CalculatrixSession();
	session.insertMatrixLiteral('[[5,4],[4,5]]');
	session.evaluate();
	session.memoryAdd();

	final Matrix sqrt = session.currentValue!.sqrt();
	print(sqrt); // Matrix([[2.0, 1.0], [1.0, 2.0]])
}
```

## Roadmap

See the roadmap in [../../docs/roadmap.md](../../docs/roadmap.md).

## License

This project is licensed under the MIT License.

