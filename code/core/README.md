[![pub package](https://img.shields.io/pub/v/calculatrix.svg)](https://pub.dev/packages/calculatrix)

# Calculatrix

Calculatrix is a pure Dart computation engine designed for calculator products.
It is matrix-first by design: scalars are represented as `1x1` matrices, so
algebraic input, direct stack workflows, and calculator session state all share
the same canonical kernel.

## Status

- Current package version: `0.4.10`
- Focus: first post-Stage-4 linear-algebra slice over the canonical matrix stack kernel
- Runtime dependencies: none (pure Dart)

## Features available now

- Immutable `Matrix` type with dimension validation
- `CalculatrixMachine` as the canonical mutable stack machine
- Typed public commands, typed public macros, and typed public programs
- `Calculatrix.compileInfix`, `evaluateInfix`, and `evaluateRpn`
- `CalculatrixSession` for interactive shared calculator state and memory
- Matrix operations: `+`, `-`, `*`, `/`, `sqrt`, `scale`, `transpose`, `inverse`, `determinant`, `eigenvalues` for `1x1` and real `2x2` matrices
- Public decomposition APIs: LU with `P/L/U` factors and thin QR with `Q/R`
  factors
- Multiplication treats `1x1` operands as scalar scaling, so both `A * [[s]]`
	and `[[s]] * A` are valid
- Division currently supports scalar `1x1` denominators only; general matrix
	right-division remains deferred to a later linear-system workflow
- Square root supports square matrices in the real domain and throws typed
	domain errors when no real root is available
- Primitive command families for stack operations, push/construction, unary,
	binary, and parameterized structural edits
- Stack-expanding decomposition commands for determinant, LU, and QR workflows
- Public macros including zeros-like, ones-like, append-zero-row,
	append-zero-column, and identity creation
- Unit tests for matrix, RPN, session, and cross-notation evaluation

## Public API surface

The main public barrel is `package:calculatrix/calculatrix.dart` and exports:

- `Matrix` and `MatrixDisplayFormatter`
- `LuDecomposition` and `QrDecomposition`
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

- `v0.3.0` establishes the public matrix stack machine surface.
- `v0.3.10` starts Stage 4 with determinant as a non-breaking command-surface expansion.
- `v0.3.20` extends Stage 4 with LU and QR while keeping the same stack-machine contract.
- `v0.3.21` hardens LU and QR edge-case coverage without changing the public API.
- `v0.3.30` keeps the public core API stable while the app shell extends Matrix-mode factorization workflows on top of it.
- `v0.3.31` keeps the public core API stable while Stage 4 closes its end-to-end shell coverage over the same kernel.
- `v0.4.0` closes Stage 4 as the stable advanced-linear-algebra release over the same public matrix stack machine.
- `v0.4.10` adds real eigenvalue workflows for `1x1` and `2x2` matrices through the same typed command barrel.
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

