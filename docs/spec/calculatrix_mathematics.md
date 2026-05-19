# Calculatrix Mathematical Specification (v0.6.6)

## 1. Scope

This document defines the formal mathematical model implemented by Calculatrix.
All runtime values are matrices over the real numbers.

- Domain: R^(m x n)
- Scalar embedding: k in R is represented as [[k]] (1x1)
- Complex embedding: a + bi is represented as [[a, -b], [b, a]]
- Core principle: matrix-first semantics in all operations and state transitions

This is a normative specification for core, app, and CLI behavior.

## 2. Canonical Embeddings

### 2.1 Scalars as 1x1 Matrices

For every scalar k in R:

k := Matrix.scalar(k) = [[k]]

Consequences:

- Scalar operations are matrix operations restricted to 1x1 shape.
- No separate scalar execution engine exists.
- Operator contracts are shape-based, not type-based.

### 2.2 Complex Numbers as 2x2 Real Matrices

Define J (imaginary unit) as:

J = [[0, -1], [1, 0]], with J^2 = -I2

Map complex number z = a + bi to:

Phi(z) = a*I2 + b*J = [[a, -b], [b, a]]

Properties used by the engine:

- Phi(z1 + z2) = Phi(z1) + Phi(z2)
- Phi(z1 * z2) = Phi(z1) * Phi(z2)
- Phi(conj(z)) = Phi(z)^T
- det(Phi(a+bi)) = a^2 + b^2

## 3. Operator Semantics

## 3.1 Shape Laws

For A in R^(m x n), B in R^(p x q):

- A + B defined iff m=p and n=q
- A - B defined iff m=p and n=q
- A * B defined iff n=p
- A / B defined iff B is 1x1 (scalar denominator)

### 3.2 Scalar Promotion Rule

For element-wise + and - with one 1x1 scalar and one n x n matrix (n > 1):

[[k]] is promoted to k*In

This preserves natural expressions in complex form, for example:

3 + (2*J) => 3*I2 + 2*J = [[3, -2], [2, 3]]

### 3.3 Unary Operators

- transpose(A) = A^T
- inverse(A) defined for square non-singular A
- determinant(A) defined for square A
- trace(A) defined for square A
- rref(A) defined for any A
- rank(A) defined by rref pivot count

## 4. Numerical Policy

Calculatrix uses explicit floating-point tolerances.

- defaultAbsoluteTolerance = 1e-14
- defaultRelativeTolerance = 1e-13

For numbers x, y:

nearlyEqual(x, y) uses absolute and relative criteria.

Policy goals:

- deterministic behavior for tests and CI
- stable comparisons after iterative algorithms
- explicit rejection of exact-equality assumptions in floating-point paths

## 5. Function Contracts and Limits

## 5.1 sqrt

Contract:

- square matrices only
- scalar k >= 0 => [[sqrt(k)]]
- scalar k < 0 => sqrt(|k|)*J
- matrix case: iterative method with convergence bounds

Failure modes:

- non-square => MatrixShapeError
- no real-domain convergence => MatrixDomainError

## 5.2 exp

Contract:

- square matrices only
- computed by Taylor series sum(A^n/n!, n=0..N), N <= 50
- stop condition uses infinity norm and absolute tolerance

Special behaviors:

- scalar: exp([[k]]) = [[e^k]]
- pure imaginary theta*J gives rotation matrix

## 5.3 log (principal)

Contract:

- square matrices only
- scalar x > 0 => [[ln(x)]]
- scalar x < 0 => complex principal value ln(|x|) + pi*i as 2x2 form
- scalar x = 0 => domain error
- complex-form [[a,-b],[b,a]] => ln(r) + theta*i where
  r = sqrt(a^2+b^2), theta = atan2(b,a)
- diagonalizable real-domain square matrices with positive spectrum:
  log(A) = P*log(D)*P^-1

Failure modes:

- non-square => MatrixShapeError
- invalid domain (zero or non-positive real spectrum for real branch)
  => MatrixDomainError

## 5.4 svd

Contract:

For A in R^(m x n), svd(A) returns (U, S, V^T) such that:

A ~= U*S*V^T

with:

- U in R^(m x n)
- S in R^(n x n), diagonal, sigma_i >= 0, sorted descending
- V^T in R^(n x n)

Current construction:

- based on diagonalization of A^T*A
- singular values: sigma_i = sqrt(lambda_i(A^T*A)) for lambda_i >= 0

Failure modes:

- if A^T*A cannot be diagonalized in real domain => MatrixDomainError

## 5.5 Eigen and Decompositions

- eigenvalues(A): square only; real-domain only
- diagonalization(A): requires real spectrum and independent eigenvectors
- luDecomposition(A): square only
- qrDecomposition(A): rows >= columns

Error classes are explicit and stable:

- MatrixShapeError
- MatrixDomainError
- MatrixIndexError

## 6. Proof-Oriented Worked Examples

## 6.1 Euler Identity in Matrix Form

Let J = [[0,-1],[1,0]].

exp(pi*J) = [[cos(pi), -sin(pi)], [sin(pi), cos(pi)]] = -I2

Therefore:

exp(pi*J) + I2 = 0

## 6.2 Conjugation by Transpose

For Z = [[a,-b],[b,a]]:

Z^T = [[a,b],[-b,a]] = [[a,-(-b)],[(-b),a]] = Phi(a-bi)

So transpose is complex conjugation on the embedded complex subalgebra.

## 6.3 Spectral Invariant Used by SVD

A^T*A is symmetric positive semidefinite.

Its eigenvalues are non-negative and define singular values by:

sigma_i = sqrt(lambda_i(A^T*A))

Hence S is diagonal with sigma_i >= 0.

## 7. Cross-Consumer Consistency Requirements

The following are mandatory:

- app and CLI must call core semantics, not re-implement algebra
- display formatting may differ by consumer
- computed matrix values and error classes must be identical across consumers

## 8. Verification Baseline

Current baseline for this spec:

- core tests: 429 passing
- app tests: 141 passing
- cli tests: 12 passing

All mathematical contracts in this document are backed by executable tests.
