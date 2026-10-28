# Calculatrix Mathematical Specification

Describes core 0.8.0.

This document defines the mathematical model of `calculatrix_core`: what a
value is, when a result is exact, and what each mathematical word computes.
The literal syntax, the command registry and the list of error ids are in
`calculatrix_core.md`; how values and errors are printed, and the exit codes,
are in `calculatrix_cli.md`, section "Output and errors". Examples are RPN
programs as `cx` runs them.

## 1. Values

Every value is a real matrix, and it is either exact or approximate as a
whole. A value never mixes exact and approximate entries.

- Exact: Q^(m x n). Each entry is a rational, a pair of integers of any size,
  always reduced, with a positive denominator; an integer is a rational with
  denominator 1.
- Approximate: F^(m x n), where F is the set of finite IEEE 754 doubles.

Numeric literals are exact: `0.1` is 1/10, `1/3` is one third, `1e400` is
10^400. A `~` before a literal makes it approximate (`~0.1`). The exact
syntax is in `calculatrix_core.md`, section "Literals".

### 1.1 Scalars and vectors

A scalar k is the 1x1 matrix [[k]]. There is no separate scalar engine:
scalar operations are matrix operations on 1x1 shapes, and every contract is
stated by shape. A vector of n entries is the n x 1 column matrix.

### 1.2 Complex numbers

The imaginary unit is J = [[0, -1], [1, 0]], with J^2 = -I. A complex number
a + bi is the 2x2 matrix

    Phi(a + bi) = a*I + b*J = [[a, -b], [b, a]]

and a 2x2 matrix is "complex" (in complex form) exactly when its entries
satisfy M[0][0] = M[1][1] and M[0][1] = -M[1][0]. Phi keeps sums and
products, Phi(conj z) = Phi(z)^T (transpose is conjugation) and
det Phi(a + bi) = a^2 + b^2. Phi is defined over Q too: a complex number with
rational parts is an exact 2x2 matrix, so `-4 sqrt` is the exact
[[0 -2] [2 0]] (2i).

### 1.3 Constants

- `i` is J, exact. `3 4 i * +` is [[3 -4] [4 3]] (3 + 4i, by the scalar
  promotion of section 3), and `i dup *` is -I.
- `pi` (also `π`) is the double nearest to pi, 3.141592653589793, and `e` the
  double nearest to e, 2.718281828459045. Both are approximate.

Because `e` and `pi` are approximate, `e pi i * ^` (e^(i pi)) is
~[[-1 -6.33e-15] [6.33e-15 -1]]: -I to within the rounding of doubles, not
exactly. The constants are names, not numbers; their syntax is in
`calculatrix_core.md`, section "Name table".

## 2. Exactness

Exactness depends only on the values, never on a mode.

- A word given exact operands gives an exact result when that result is
  rational and can be computed and checked exactly:
  - always: `+ - * /`, `negate`, `percent`, integer powers, `inverse`,
    `determinant`, `rref`, `rank`, `trace`, `adjugate`, `cofactors`, `lu`,
    `dot`, `cross`;
  - when the result is rational: `sqrt` and fractional powers (section 6),
    `frobenius-norm` (when the sum of squares is a rational square) and
    `eigenvalues` (when every root of the characteristic polynomial is
    rational);
  - in the trivial cases only: `exp` of a zero matrix (the identity) and `ln`
    of the identity (the zero matrix).
- Every other result is approximate: an irrational result (`2 sqrt`), and
  every result of `exp`, `ln`, `diagonalize`, `qr` and `spectral-norm`
  outside the cases above.
- Approximation is contagious: one approximate operand makes the result
  approximate (`1 3 / ~1 *` is ~0.333333333333). The reverse never happens.
- Stack, construction and structure words move or build entries without
  computing, so they keep exactness; a word that joins values (`vector`,
  `append-rows`, `append-cols`) is exact only when all of them are.
- `approx` (alias `num`) makes a value approximate: each entry becomes the
  nearest double; an entry too large for a double is `non-finite`, one too
  small becomes 0. `exact` makes a value exact: each entry becomes the
  simplest rational (smallest denominator) that rounds to the same double, so
  `0.1 approx exact` is 1/10 again. Each is the identity on a value already
  of its kind.

Exact computation uses no tolerance: equality and zero tests are exact, and a
matrix is singular or not. Elimination is fraction-free (Bareiss) on the
matrix brought to integers over one common denominator. Exact eigenvalues
come from the characteristic polynomial (Berkowitz's algorithm, division
free); its integer roots are found modulo a prime and lifted p-adically, then
checked exactly. A non-integer power of a matrix that is not scalar, complex
or diagonal is guessed from the approximate result and kept exact only when
the guess Y satisfies Y^q = B^p exactly.

The size of an exact result is estimated before it is computed (n log10|b|
for a power, the Hadamard bound for elimination, a norm bound for the
characteristic polynomial). Over the limit, 10000 digits per numerator or
denominator by default, the error is `limit-exceeded`, never an approximate
result instead: `2 40000 ^` fails, `2 40000 approx ^` is approximate. The
limit and its option are in `calculatrix_cli.md`, section "Output and
errors".

Rejected designs: a `rationalize` with a tolerance (it would guess a value the
input does not determine); exactness per entry (a value is exact or
approximate as a whole). Exact irrational values such as 3 + sqrt 3 are
symbolic computation, a later phase of `docs/roadmap.md`.

## 3. Operators

For A of size m x n and B of size p x q:

- A + B and A - B are defined when the shapes match. A scalar meets an n x n
  matrix (n > 1) as k*I: `3 i 2 * +` is [[3 -2] [2 3]] (3 + 2i), and
  `[[1 2] [3 4]] 2 +` is [[3 2] [3 6]]. A scalar and a non-square matrix are
  `dimension-mismatch`.
- A * B is the matrix product when n = p, and scaling when either is a
  scalar.
- A / B is defined only for a scalar B (`type-mismatch` otherwise); division
  by zero is `non-finite`.
- `transpose`, `rref` and `rank` take any shape; `inverse`, `determinant`,
  `trace`, `exp`, `ln`, `sqrt`, `eigenvalues`, `diagonalize` and `lu` take a
  square matrix; `qr` needs rows >= columns.

## 4. The approximate path

An approximate value holds finite doubles only. After each word, an
approximate result with an infinite or NaN entry is `non-finite`
(`~1e308 ~1e308 +`).

The approximate algorithms decide with explicit tolerances:

- absolute tolerance 1e-12: pivots in elimination (`inverse`, `rank`,
  `rref`, `lu`), deflation and near-zero eigenvalues, and results within it
  of zero are set to 0;
- relative tolerance 1e-10: convergence of the matrix square root.

Two doubles x, y are nearly equal when |x - y| <= 1e-12 or
|x - y| <= 1e-10 * max(|x|, |y|).

## 5. Functions

### 5.1 sqrt

`sqrt` is `0.5 power` (section 6). On an exact base it follows the exact
rules of section 6. On an approximate base:

- scalar k >= 0: [[sqrt k]]; scalar k < 0: sqrt(|k|) * J;
- complex form: the principal square root x + yi, with x >= 0 (and y >= 0
  when x = 0), computed without cancellation;
- any other square matrix: the Denman-Beavers (Newton) iteration on the
  matrix scaled to unit norm. A singular matrix whose zero eigenvalue is
  semisimple is split into its range and null space and the iteration runs on
  the range. A matrix with a negative real eigenvalue, other than the complex
  form, has a complex principal square root and is `complex-result`
  (`[[-1 0] [0 2]] sqrt`); a matrix with no square root at all is
  `log-undefined` (`[[0 1] [0 0]] sqrt`).

### 5.2 exp

- scalar: [[e^k]];
- otherwise the indices are split into the groups that nonzero off-diagonal
  entries couple, each group is a block computed alone, and each block B is
  shifted by mu = trace(B)/n. If B - mu*I is exactly nilpotent,
  exp(B) is e^mu times the finite series. Otherwise exp(B) is computed by
  scaling and squaring: B / 2^s with infinity norm at most 0.5, its Taylor
  series to the tolerance, then squared s times.
- A pure imaginary theta*J gives the rotation
  [[cos theta, -sin theta], [sin theta, cos theta]].
- An overflowing result is `non-finite`.

### 5.3 ln (principal logarithm)

- scalar x > 0: [[ln x]]; x < 0: ln|x| + pi*i, in complex form; x = 0:
  `log-undefined`;
- complex form a + bi: ln r + theta*i, with r = sqrt(a^2 + b^2) and
  theta = atan2(b, a);
- other 2x2 matrices: the closed form c1*A + c0*I from the two eigenvalues
  (Sylvester), so a defective matrix such as [[1 1] [0 1]] has a logarithm,
  and a complex-conjugate pair gives a real result. The eigenvalues come
  from the discriminant (a - d)^2 + 4bc, and ln l1 - ln l2 is computed as
  ln(1 + (l1 - l2)/l2), so close eigenvalues lose no digits;
- larger matrices: P * ln(D) * P^-1 from `diagonalize`, so a repeated
  eigenvalue works (`[[2 0 0] [0 2 0] [0 0 3]] ln` is
  diag(ln 2, ln 2, ln 3)) and a defective matrix is `not-diagonalizable`;
- a real eigenvalue <= 0, or a singular matrix, is `log-undefined`.

### 5.4 Eigenvalues and spectral words

- `eigenvalues` gives a column, largest first. A 2x2 matrix uses the closed
  form with the discriminant (a - d)^2 + 4bc of [[a, b], [c, d]], which does
  not cancel as trace^2 - 4 det does; a larger one is reduced to Hessenberg
  form (Householder) and iterated with shifted QR (Wilkinson shift, Givens
  rotations).
- `diagonalize` leaves P and D with A = P D P^-1; the columns of P are unit
  eigenvectors. Eigenvalues within 1e-10 of each other, relative to the
  largest, are one eigenvalue of multiplicity m, and its columns are a basis
  of the null space of A - lambda*I (rank taken on A - lambda*I scaled by
  the largest eigenvalue): `[[2 0] [0 2]] diagonalize` gives P = I and
  D = 2I. When that null space has fewer than m dimensions, or P is
  singular, the matrix is defective and the word raises
  `not-diagonalizable` (`[[1 1] [0 1]] diagonalize`); it never returns a
  singular P.
- `spectral-norm` is the square root of the largest eigenvalue of A^T A.
- `frobenius-norm` is the square root of the sum of the squared entries.

### 5.5 Decompositions

- `lu` leaves P, L, U with P A = L U, L unit lower triangular (partial
  pivoting on the approximate path).
- `qr` leaves Q, R with A = Q R, Q with orthonormal columns and R upper
  triangular (Gram-Schmidt).

### 5.6 Complex results of real words

Phi covers one complex number, not a column of them. When a real 2x2 block
[[a, b], [c, d]] met by `eigenvalues` or `diagonalize` has a discriminant
(a - d)^2 + 4bc that is negative beyond its rounding error, the eigenvalues
are a complex pair with no representation yet, and the word raises
`complex-result`, for exact and approximate input alike:
`[[0 -1] [1 0]] eigenvalues` (the spectrum is {i, -i}).

The principal square root and a non-integer power of a matrix (not in
complex form) with a negative real eigenvalue are complex too, and raise
`complex-result`: `[[-1 0] [0 2]] sqrt`, `[[-1 0] [0 2]] 1.5 ^`.

Words that use the spectrum only inside keep their own result: the logarithm
of a rotation is real, so `ln` and `spectral-norm` never raise
`complex-result`.

## 6. power

`power` (aliases `pwr`, `^`) is defined on matrices: B^Y = exp(Y * log B),
with the principal logarithm and the matrix exponential of section 5. In the
table, "scalar" is a 1x1 matrix and "complex" a 2x2 matrix in complex form
(section 1.2). Complex matrices commute, so for them the order of the
product Y * log B does not matter. `X exp` and `e X ^` agree to rounding.

Exact operands take exact routes first:

- exact B and an exact integer Y: repeated squaring, exact; a negative Y
  raises the exact inverse of a matrix B (`[[1 2] [3 4]] -2 ^` is
  [[5.5 -2.5] [-3.75 1.75]]);
- exact B and an exact non-integer scalar Y = p/q: exact when the result is
  rational. A scalar, a complex B (for q = 2) and a diagonal B use closed
  forms; any other B uses the verified guess of section 2 (`8 1/3 ^` is 2,
  `-4 1/4 ^` is [[1 -1] [1 1]], `[[1 1] [0 1]] 1/3 ^` is [[1 1/3] [0 1]]).
  Otherwise the result is the approximate one, errors included
  (`2 0.5 ^` is ~1.41421356237).

On the approximate path, Y = 1/2 is the square root of section 5.1 and Y = -1
on a matrix is its inverse, the same algorithms `sqrt` and `inverse` use.

| # | Base B | Exponent Y | Result | Example |
|---|---|---|---|---|
| 1 | scalar | scalar | real power. B < 0 with a non-integer Y gives the complex principal value, as the square root of a negative number does | `-4 0.5 ^` is [[0 -2] [2 0]] |
| 2 | scalar > 0 | square matrix | exp(ln B * Y), approximate | `e pi i * ^` is ~[[-1 -6.33e-15] [6.33e-15 -1]] |
| 3 | complex, or scalar < 0 | complex | exp(Y * log B), approximate | `i i ^` is ~[[0.2079 0] [0 0.2079]], e^(-pi/2) |
| 4 | square | integer scalar | repeated multiplication; a negative integer uses the inverse; a singular B with a negative integer is `singular-matrix`; Y = 0 gives I | `[[1 1] [0 1]] 3 ^` is [[1 3] [0 1]]; `[[1 2] [2 4]] -1 ^` is `singular-matrix` |
| 5 | square | non-integer scalar | exp(y * log B). A base that is neither scalar nor complex, with a negative real eigenvalue, is `complex-result`; with a zero eigenvalue, `log-undefined` (see below). For y = 1/2 it is the principal square root, so a singular base with no negative eigenvalue has a result; a base with no square root at all is `log-undefined` | `[[2 0] [0 3]] 0.5 ^` is ~[[1.4142 0] [0 1.7321]]; `[[1 1] [0 1]] 0.5 ^` is [[1 0.5] [0 1]] (not diagonalizable); `[[0 0] [0 4]] 0.5 ^` is [[0 0] [0 2]] |
| 6 | any other pair with Y not a scalar (order of checks, below) | square, not scalar | `ambiguous-power`: exp(Y log B) and exp(log B Y) differ when Y and log B do not commute. Row 3 is the exception | `[[1 1] [0 1]] [[0 1] [1 0]] ^`: log B is [[0 1] [0 0]], and the two orders give [[1 0] [0 2.7183]] and [[2.7183 0] [0 1]] |
| 7 | 0 | scalar | Y > 0 gives 0; `0 0 ^` gives 1; Y < 0 is `non-finite` | `0 -1 ^` is `non-finite`; `0 0.5 ^` is 0 |
| 8 | 0, or a singular matrix, where the case needs log B (never for y = 1/2, row 5) | | `log-undefined` | `0 pi i * ^`; `[[1 2] [2 4]] 1.5 ^` |
| 9 | not square | any | `dimension-mismatch` | `[[1 2]] 2 ^` |
| 10 | any | not square | `dimension-mismatch` | `2 [[1 2]] ^`, `[[1 0] [0 1]] [[1 2]] ^` |
| 11 | n x n | m x m, n != m, neither scalar | `dimension-mismatch` | `[[1 0] [0 1]] [[1 0 0] [0 1 0] [0 0 1]] ^` |
| 12 | scalar < 0 | square, not complex, not scalar | `ambiguous-power`: log B is complex (2x2) and does not match Y | `-2 [[1 0] [0 2]] ^`: log -2 is [[0.6931 -3.1416] [3.1416 0.6931]], which does not commute with Y |
| 13 | any approximate | any, result overflows | `non-finite`. An exact result never overflows: it is exact, or `limit-exceeded` over the digit limit | `~10 400 ^` is `non-finite`; `10 400 ^` is the exact 10^400 |

Approximate entries above are rounded to 4 decimals; `cx` prints 12
significant digits.

**Order of the checks.** The first rule that applies decides. The kinds of B
and Y decide, never a numerical test of whether they commute:

1. Dimensions: B is square (row 9), Y is square (row 10), and when neither is
   a scalar both have the same size (row 11). Otherwise `dimension-mismatch`.
2. Y is a scalar: rows 1, 4, 5, 7, 8 and 13. For a scalar base, row 7 comes
   before row 4: `0 -1 ^` and `0 inverse` are `non-finite`.
3. Y is not a scalar: B = 0 is `log-undefined` (row 8); B scalar > 0 is
   row 2; B complex or scalar < 0, with Y complex, is row 3. Every other
   pair is `ambiguous-power` (rows 6 and 12): `i [[1 0] [0 2]] ^` is
   `ambiguous-power`.

**A matrix with no real logarithm.** `[[-1 0] [0 2]] 0.5 ^` has no real
result: the base has a negative eigenvalue and is not in complex form, so its
principal value is complex. It is `complex-result`, as is
`[[-1 0] [0 2]] 1.5 ^`; a negative scalar keeps its complex form
(`-4 0.5 ^`, row 1). A complex number is only a*I + b*J; a matrix whose entries
would be complex has no representation yet. Turning this error into a value
later breaks no one.

`inverse` is defined as `-1 power` and `sqrt` as `0.5 power`, and each gives
bitwise the same result as its definition.

## 7. Worked identities

- Euler: exp(pi*J) = [[cos pi, -sin pi], [sin pi, cos pi]] = -I, so
  exp(pi*J) + I = 0. With the approximate `pi`, `pi i * exp` is -I within
  7e-15 (section 1.3).
- Conjugation: for Z = Phi(a + bi), Z^T = [[a, b], [-b, a]] = Phi(a - bi).

## 8. Consistency and verification

- The app and the CLI call core; they never reimplement the mathematics.
  Display may differ by consumer; values, exactness and error ids may not.
- Every rule here has a core test. The power table is tested row by row in
  `code/core/test/matrix/power_test.dart` and, for `inverse` and `sqrt`, in
  `code/core/test/registry/defined_words_test.dart`. Every exact word is
  tested against Giac in `code/core/test/exact/giac_differential_test.dart`.
