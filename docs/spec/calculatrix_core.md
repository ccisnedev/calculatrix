# Calculatrix Core Package Specification

Status: Draft
Owner: Calculatrix maintainers
Package name: `calculatrix`
Target path in monorepo: `code/core`

## 1. Purpose

`calculatrix` is the computation core for the Calculatrix ecosystem.
It must provide a reusable, pure Dart API for:

1. Matrix computation
2. Reverse Polish Notation (RPN) computation (modern profile)
3. Dual entry evaluation (`evaluateInfix` and `evaluateRpn`) over the same
	 matrix domain

The package is the single source of truth for numerical behavior used by:

1. Flutter app (`calculatrix_app`)
2. Dart CLI (`calculatrix_cli`)
3. Dart backend services (HTTP APIs, workers, jobs)
4. Potential future integrations (scripts, tests, tooling)

## 1.1 Portability Objective

Any Dart consumer must be able to use `calculatrix` with the same behavior,
including:

1. Flutter UI apps
2. CLI apps
3. Backend/server apps

The core package must remain framework-agnostic and side-effect free.

## 2. Scope

### 2.1 In scope for Stage 2

1. Public API with two modules:
	 1. `matrix`
	 2. `rpn`
2. Immutable matrix value type (`Matrix`)
3. Core matrix operations: add, subtract, multiply, transpose
4. RPN stack engine with binary operations over matrix domain
5. Consistent and typed error model
6. Unit tests for both modules

### 2.2 Out of scope for initial Stage 2 milestone

1. Flutter UI implementation details
2. Full algebraic parser migration from app to core (planned next), except the
	minimal `evaluateInfix` contract defined in this spec
3. Advanced linear algebra (determinant, inverse, LU, QR, eigen)
4. Persistent history or storage
5. Symbolic algebra / CAS features (variables, symbolic simplification,
	 symbolic differentiation/integration)

## 3. Design Principles

1. Pure Dart runtime code (no Flutter dependency)
2. Deterministic behavior
3. Immutable public data structures
4. Backward-compatible API evolution under SemVer
5. Domain consistency: scalar values are represented as 1x1 matrices
6. Matrix-first semantics: all evaluators and operators must support matrices
	 of any order (`NxM`) subject to operation shape rules
7. Single-kernel rule: the same matrix algorithms must apply to 1x1, vectors,
	 non-square matrices, and higher-order matrices without shape-specific
	 branches in semantics
8. Formal-first design: implementation follows explicit algebraic rules and
	 theorem-backed contracts before micro-optimizations
9. Educational scope: preferred practical domain up to 4x4 matrices; algorithms
	 remain general even when runtime is not optimized for large dimensions

## 3.1 Mathematical Foundation

Let:

1. \(\mathbb{R}\) be real numbers.
2. \(M_{m,n}(\mathbb{R})\) be the set of real matrices of size \(m \times n\).
3. \(\mathcal{M} = \bigcup_{m,n \ge 1} M_{m,n}(\mathbb{R})\) be the matrix universe.
4. Vectors are matrices: column vectors are elements of \(M_{n,1}(\mathbb{R})\),
	row vectors are elements of \(M_{1,n}(\mathbb{R})\).

Operations are defined as partial operations on \(\mathcal{M}\):

1. Addition/subtraction are defined only on equal-shape operands:
	\(A \pm B\) exists iff \(A,B \in M_{m,n}(\mathbb{R})\).
2. Multiplication is defined when inner dimensions agree:
	\(AB\) exists iff \(A \in M_{m,k}(\mathbb{R})\) and
	\(B \in M_{k,n}(\mathbb{R})\).

Scalar embedding:

1. Define \(\iota: \mathbb{R} \to M_{1,1}(\mathbb{R})\) by
	\(\iota(s) = [s]\).
2. A scalar in public API is therefore a 1x1 matrix value.

Theorem (uniform matrix semantics):

For any \(A, B \in \mathcal{M}\), the result of each binary operator depends
only on matrix dimensions and entries under the partial-operation rules above,
independent of whether operands are 1x1, vectors, or higher-order matrices.

Corollary:

1. 1x1 operands are not a separate numeric domain; they are processed by the
	same matrix operator definitions.
2. Vector cases are not special operators; they are ordinary matrix cases in
	\(M_{n,1}(\mathbb{R})\) or \(M_{1,n}(\mathbb{R})\).
3. Non-square matrices are not exceptional cases; they are ordinary elements of
	\(M_{m,n}(\mathbb{R})\) with \(m \ne n\), governed by the same rules.

Therefore, treating 1x1 values and vectors as matrices is mathematically sound
and preserves linear-algebra consistency across all supported dimensions.

Notation equivalence principle:

For any well-typed expression \(E\) over this operator set,
`evaluateInfix(E)` and `evaluateRpn(toRpn(E))` must denote the same matrix
result, up to documented floating-point tolerance.

## 4. Public API Surface

The package root exports:

```dart
library calculatrix;

export 'src/matrix/matrix.dart';
export 'src/rpn/rpn_engine.dart';
```

### 4.1 Matrix module

Core type:

```dart
class Matrix {
	Matrix(List<List<double>> rows);
	factory Matrix.scalar(double value);

	int get rowCount;
	int get columnCount;
	bool get isScalar;
	double get scalarValue;
	List<List<double>> get rows;

	double at(int row, int column);

	Matrix operator +(Matrix other);
	Matrix operator -(Matrix other);
	Matrix operator *(Matrix other);
	Matrix scale(double scalar);
	Matrix transpose();
}
```

#### 4.1.1 Behavioral contract

1. `Matrix(rows)` requires non-empty rectangular input.
2. `rows` getter returns immutable views.
3. `+` and `-` require equal dimensions.
4. `*` behavior:
	 1. matrix product if dimensions are compatible (`A.cols == B.rows`)
5. `scalarValue` throws if the matrix is not 1x1.
6. Equality is value-based.
7. 1x1 matrices are first-class matrices, not a separate numeric type.
8. Vector operands are treated as matrices (`Nx1` or `1xN`) with no
	dedicated vector-only branch in operator semantics.
9. Non-square operands (`m != n`) are valid first-class operands wherever
	shape rules allow the operation.
10. `Matrix.scalar(value)` is convenience syntax equivalent to
	`Matrix([[value]])`; it does not introduce a separate execution path.

### 4.2 RPN module (modern profile)

Core types:

```dart
enum RpnBinaryOperator {
	add,
	subtract,
	multiply,
}

class RpnEngine {
	int get depth;
	List<Matrix> get stack;

	void clear();
	void push(Matrix value);
	void pushScalar(double value);
	Matrix peek();
	Matrix pop();

	Matrix applyBinary(RpnBinaryOperator operatorType);
}
```

#### 4.2.1 Modern RPN profile

The engine follows modern RPN constraints from research findings:

1. Dynamic stack depth (no fixed 4-level limit internally)
2. Explicit underflow errors (never silent duplication)
3. Matrix-native operations over general matrices (not limited to 1x1 values)
4. Engine-only responsibilities (UI stack windowing is consumer-level)
5. `pushScalar(value)` is convenience syntax equivalent to
	`push(Matrix.scalar(value))`; stack/evaluation semantics remain identical.

### 4.3 Evaluation facade (notation-agnostic)

Core entrypoints:

```dart
class Calculatrix {
	static Matrix evaluateInfix(String expression);
	static Matrix evaluateRpn(List<String> tokens);
}
```

#### 4.3.1 Behavioral contract for evaluateInfix / evaluateRpn

1. Both entrypoints evaluate over the same matrix domain and return `Matrix`.
2. Both entrypoints must support operands of any order (`NxM`) when operation
	shape rules are satisfied.
3. Non-square matrices must be handled by the same formal operator rules,
	without special-case semantics.
4. Supported operator semantics are the same in both notations:
	 1. `+` and `-`: equal dimensions required
	 2. `*`: standard matrix product when `A.cols == B.rows`
5. Any expression that is semantically valid in one notation must produce the
	same result in the other notation (modulo floating-point tolerance policy).
6. Any implementation optimization must preserve the same observable result as
	the formal matrix definitions above.
7. Errors are notation-independent at domain level (same shape/domain failures,
	with notation-specific syntax errors only for parsing/tokenization stages).
8. The parser/evaluator domain is numeric-only (no symbols/variables), by
	design, to remain outside CAS scope.

## 5. Error Taxonomy

Current implementation uses `ArgumentError` and `StateError`.
Stage 2 should formalize domain-specific exceptions while maintaining
backward compatibility where feasible.

Planned error families:

1. `MatrixShapeError`
	 1. non-rectangular input
	 2. incompatible dimensions for operations
2. `MatrixDomainError`
	 1. invalid scalar access on non-scalar matrices
3. `RpnStackUnderflowError`
	 1. pop/peek on empty stack
	 2. insufficient operands for binary operation
4. `UnsupportedOperationError`
	 1. operation recognized but not yet implemented

## 6. Package Structure

Required structure:

```text
code/core/
	pubspec.yaml
	README.md
	CHANGELOG.md
	LICENSE
	lib/
		calculatrix.dart
		src/
			matrix/
				matrix.dart
			rpn/
				rpn_engine.dart
	test/
		matrix/
			matrix_test.dart
		rpn/
			rpn_engine_test.dart
```

## 7. Integration Contracts

### 7.1 Flutter app contract (`calculatrix_app`)

1. App consumes `calculatrix` through path dependency during monorepo development.
2. UI/controller layers in app must not duplicate math logic already in core.
3. App maps domain errors to user-facing messages.

### 7.2 CLI contract (`calculatrix_cli`)

1. CLI is a consumer of `calculatrix`, not a place for duplicated algorithms.
2. CLI commands should map directly to matrix and RPN APIs.

### 7.3 Backend contract

1. Backend services consume `calculatrix` as a pure library dependency.
2. Backend handlers map API payloads into `Matrix` and `RpnEngine` operations.
3. Domain errors from `calculatrix` are translated into transport-safe responses
	(for example: HTTP 400 for shape/stack errors).

## 7.4 Distribution model

`calculatrix` must support both distribution modes:

1. Local path dependency in monorepo development
2. Published package dependency from pub.dev (when released)

Consumers should require no code changes beyond dependency source selection.

## 8. Quality Requirements

1. Unit test coverage target for core logic: >= 90%
2. Zero flaky tests
3. Deterministic floating-point formatting policy documented in README
4. Lint-clean package (`dart analyze`)
5. Cross-notation equivalence tests (`evaluateInfix` vs `evaluateRpn`) for
	matching matrix workloads
6. Shape-coverage tests must include `1x1`, vectors (`Nx1`, `1xN`), square,
	and non-square matrices using the same operator contracts.

## 9. Versioning and Compatibility

1. Package follows SemVer.
2. Initial line can iterate under `0.x` until API stabilization.
3. `1.0.0` requires:
	 1. stable API for matrix + RPN modules
	 2. documented error taxonomy
	 3. migration notes for consumers if breaking changes occurred in pre-1.0

## 10. Acceptance Criteria (Stage 2 core specification)

Stage 2 spec is considered satisfied when:

1. The package exposes exactly two top-level functional modules:
	 1. matrix
	 2. rpn
2. `Matrix` API supports construction, shape validation, arithmetic, transpose,
	 with uniform semantics for `1x1`, vectors, and general `NxM` matrices.
3. `RpnEngine` supports push/pop/peek/clear/depth and binary operations.
4. `evaluateInfix` and `evaluateRpn` are specified and tested as equivalent
	entrypoints over general matrices (`NxM`), including `1x1`, vector, square,
	and non-square cases.
5. Errors are explicit and covered by tests.
6. Flutter app, CLI, and backend can consume the same package API.

## 11. Future Extensions (Post Stage 2)

1. Algebraic parser/evaluator inside core
2. Additional RPN stack ops: `dup`, `drop`, `swap`, `rot`, `over`, `pick`, `roll`
3. Linear algebra: determinant, inverse, decompositions
4. Typed numeric modes (future): decimal/rational support

