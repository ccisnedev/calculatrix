# Calculatrix Mathematical Specification (v0.6.6)

## 1. Scope

This document defines the formal mathematical model implemented by Calculatrix.
All runtime values are real matrices, and each value is either exact or
approximate, as a whole (runbook-trust.md D49):

- Exact domain: Q^(m x n). Entries are rationals, a pair of arbitrary-size
  integers, always reduced, with a positive denominator; an integer is a
  rational with denominator 1.
- Approximate domain: F^(m x n), where F is the set of finite IEEE 754
  doubles, a subset of R. Operations follow section 4.
- Scalar embedding: k is represented as [[k]] (1x1)
- Complex embedding: a + bi is represented as [[a, -b], [b, a]]
- Core principle: matrix-first semantics in all operations and state transitions

A value never mixes exact and approximate entries. Literals are exact
(`0.1` is 1/10, `1/3` is one third; D50, D59), `~` before a literal makes it
approximate (D56), and the exactness of a result follows section 4.

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

Phi is defined over Q as well: a complex number with rational parts is an
exact 2x2 matrix, so `-4 sqrt` gives the exact [[0, -2], [2, 0]] (2i).

The word `i` pushes J as an exact value, [[0 -1] [1 0]] (issue #70,
runbook-agent-usability.md D66). With it a complex number is typed as a
matrix expression: `3 4 i * +` is Phi(3 + 4i) = [[3 -4] [4 3]], exact, and
`i dup *` is -I2. It prints as the matrix; showing it as `i` is issue #78.

The other system constants are real and approximate, marked `~`: `pi`
(also `π`) is the double nearest to pi, 3.141592653589793, and `e` is the
double nearest to e, 2.718281828459045. They agree with Giac's `evalf` of
the same constants rounded to a double. Because `e` and `pi` are
approximate, `e^(i*pi)` is [[-1 0] [0 -1]] to within 1e-14 (the residue of
`J*pi exp` in doubles is under 7e-15), not exactly.

The constants are names of the core name table, not numbers: `1e3` is the
number 1000, `2e` and `e3` are not constants, and `-pi` and `~pi` are not
valid in RPN (write `pi negate` and `pi approx`).

### 2.3 Complex Results of Real Words

The embedding covers a single complex number. A result that would be a
column of complex numbers, such as the eigenvalues of a real matrix with a
complex pair, has no representation yet. `eigenvalues` and `diagonalize`
raise `complex-result` (MatrixDomainError, CLI exit 65) when the
discriminant (a - d)^2 + 4bc of a real 2x2 block [[a, b], [c, d]] is
negative beyond its rounding error, for exact and approximate input alike
(runbook-trust.md D60):

- eigenvalues([[0, -1], [1, 0]]) => complex-result (the spectrum is {i, -i})

Words that use the spectrum only internally keep their own contract:
ln(A) of a rotation is real, so `ln`, `spectral-norm` and `svd` never raise
`complex-result`.
Complex vectors as blocks of Phi (n complex numbers as a 2n x 2 matrix)
are tracked in issue #64.

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

### 4.1 Exactness

Exactness depends only on the values, never on a mode (runbook-trust.md
D51, D53):

- Exact with exact gives exact when the result is rational and can be
  checked exactly: `+ - * /`, `negate`, `percent`, integer powers,
  `inverse`, `determinant`, `rref`, `rank`, `trace`, `adjugate`,
  `cofactors`, `lu`, `dot`, `cross`; `sqrt`, fractional powers,
  `frobenius-norm` and `eigenvalues` when the result is rational; `exp` and
  `ln` in trivial cases. Stack and structure words keep exactness.
- An irrational result, or any other word, gives an approximate value.
- One approximate operand makes the result approximate (contagion).
- `approx` (alias `num`) and `exact` convert explicitly; `exact` takes the
  simplest rational that rounds to the same double (D52).

Exact computation uses no tolerance: equality and zero tests are exact,
and elimination is fraction-free (Bareiss). Before computing, the size of
an exact result is estimated (`a^n`, the Hadamard bound, a norm bound on
the characteristic polynomial); over the limit, 10000 digits per numerator
or denominator by default, the error is `limit-exceeded`, never an
approximate result instead (D55).

An approximate value is always shown with the mark `~` (D54), so a value
that is not exact never looks exact.

### 4.2 Tolerances of the Approximate Path

Calculatrix uses explicit floating-point tolerances on approximate values.

- defaultAbsoluteTolerance = 1e-12
- defaultRelativeTolerance = 1e-10

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

- eigenvalues(A): square only; real-domain only; a complex pair is
  `complex-result` (section 2.3)
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
