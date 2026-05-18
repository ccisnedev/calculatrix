[![pub package](https://img.shields.io/pub/v/calculatrix.svg)](https://pub.dev/packages/calculatrix)

# Calculatrix

Calculatrix is a pure Dart computation engine designed for calculator products.
It is matrix-first by design: scalars are represented as `1x1` matrices, so
algebraic input, direct stack workflows, and calculator session state all share
the same canonical kernel.

## Status

- Current package version: `0.5.0`
- Stage: advanced linear algebra over the canonical matrix stack kernel
- Runtime dependencies: **none** (pure Dart)
- Test coverage: 340+ unit tests including numerical robustness validation

## Features

### Matrix operations
- Immutable `Matrix` type with dimension validation
- Arithmetic: `+`, `-`, `*`, `/`, `scale`, `sqrt`
- Structural: `transpose`, `inverse`, `rref` (Reduced Row Echelon Form)
- Properties: `determinant`, `trace`, `rank`, `frobeniusNorm`, `spectralNorm`
- Formal: `minor`, `cofactor`, `cofactorMatrix`, `adjugate`
- Vector: `dot` (inner product), `cross` (R³ cross product)

### Decompositions
- LU with partial pivoting (`P`, `L`, `U` factors)
- Thin QR (`Q`, `R` factors)
- Eigenvalues (real spectrum, arbitrary NxN via QR iteration)
- Diagonalization (`P`, `D` such that A ≈ P·D·P⁻¹)

### Standard test matrices
- `Matrix.hilbert(n)` — ill-conditioned, κ grows exponentially
- `Matrix.pascal(n)` — symmetric positive definite, det = 1
- `Matrix.frank(n)` — upper-Hessenberg with known eigenvalue structure

### Evaluation engines
- `Calculatrix.evaluateInfix('2 + 3 * 4')` — algebraic with PEMDAS
- `Calculatrix.evaluateRpn(['3', '4', '+'])` — RPN token evaluation
- `CalculatrixMachine` — mutable stack machine with typed commands
- `CalculatrixSession` — interactive calculator with infix/RPN modes and memory

### Design principles
- Matrix-first: scalars are `1x1` matrices; no special scalar type
- All operations flow through the stack machine kernel
- Typed command vocabulary (`CalculatrixCommand` subclasses)
- Composable macros (`CalculatrixMacro`) for multi-step workflows
- Strict error taxonomy: `MatrixShapeError`, `MatrixDomainError`, `RpnStackUnderflowError`

## Quick start

```dart
import 'package:calculatrix/calculatrix.dart';

void main() {
  // Infix evaluation
  final result = Calculatrix.evaluateInfix('2 + 3 * 4');
  print(result.scalarValue); // 14.0

  // Matrix algebra
  final a = Matrix([[1, 2], [3, 4]]);
  print(a.determinant().scalarValue); // -2.0
  print(a.eigenvalues().rows); // [[5.37...], [-0.37...]]

  // Stack machine
  final machine = CalculatrixMachine();
  machine.execute(PushMatrixCommand(a));
  machine.execute(DeterminantCommand());
  print(machine.top!.scalarValue); // -2.0

  // Decompositions
  final lu = a.luDecomposition();
  final qr = a.qrDecomposition();
  print(a.rref().rows); // [[1, 0], [0, 1]]
}
```

See [`example/example.dart`](example/example.dart) for comprehensive usage.

## Public API surface

The barrel export `package:calculatrix/calculatrix.dart` provides:

- `Matrix`, `LuDecomposition`, `QrDecomposition`, `Diagonalization`
- `MatrixDisplayFormatter`
- `CalculatrixMachine`
- `CalculatrixCommand`, `CalculatrixMacro`, `CalculatrixProgram`
- Typed commands: `PushMatrixCommand`, `DeterminantCommand`, `EigenvaluesCommand`, `LuDecompositionCommand`, `QrDecompositionCommand`, `RrefCommand`, `SpectralNormCommand`, `DotProductCommand`, `CrossProductCommand`, etc.
- `Calculatrix` (static infix/RPN evaluation)
- `CalculatrixSession` (interactive state)
- `CalculatrixNumericPolicy` and typed error taxonomy

## Numeric policy

- Exact `==` on `Matrix` is strict and value-based.
- Approximate comparison via `Matrix.almostEquals` with configurable tolerances.
- Default tolerances: relative `1e-10`, absolute `1e-12`.

## Roadmap

See [docs/roadmap.md](https://github.com/ccisnedev/calculatrix/blob/main/docs/roadmap.md).

## License

This project is licensed under the MIT License.
