# Calculatrix mathematics

Language version: **0.1** (draft), the same as `language.md`.

This document defines what each mathematical word of the language
computes: what a value is, when a result is exact, what result each
word gives and which error it raises. Together with `language.md`, which
defines programs, the vocabulary and the error ids, and with
`engine-api-contract.md`, it is enough to build an engine in any host
language. No implementation is normative: the rules say which value a
word gives, never how to compute it.

Examples are RPN programs with the names of `language.md`, section 5.
`~` marks an approximate value; approximate entries in examples are
rounded to 4 decimals.

## Changes

| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-11-03 | First version independent of any implementation. |

## 1. Values

Every value is a real matrix, exact or approximate as a whole. A value
never mixes exact and approximate entries.

- **Exact:** every entry is a rational, a pair of integers of any size
  in lowest terms with a positive denominator. An integer is a rational
  with denominator 1.
- **Approximate:** every entry is a finite IEEE 754 binary64 double.

Numeric literals are exact: `0.1` is 1/10, `1e400` is 10^400. A `~`
before a literal makes it approximate (`~0.1`).

### 1.1 Scalars and vectors

A scalar k is the 1×1 matrix [[k]]. There are no separate scalar
operations: every rule is stated by shape, and a scalar is the 1×1
case. A vector of n entries is the n×1 column matrix.

### 1.2 Complex numbers

The imaginary unit is J = [[0 -1] [1 0]], with J² = −I. The complex
number a + bi is the 2×2 matrix

    Φ(a + bi) = a·I + b·J = [[a -b] [b a]]

A 2×2 matrix is **in complex form** exactly when M₁₁ = M₂₂ and
M₁₂ = −M₂₁. Φ keeps sums and products, Φ(conjugate of z) = Φ(z)ᵀ, and
det Φ(a + bi) = a² + b². A complex number with rational parts is an
exact matrix: `-4 square_root` is the exact [[0 -2] [2 0]], that is 2i.

λI of size 2 is in complex form (b = 0).

### 1.3 Constants

- `i` is J, exact. `3 4 i multiply add` is [[3 -4] [4 3]] (3 + 4i, by
  the scalar rule of section 4), and `i i multiply` is −I.
- `pi` is the double nearest to π, 3.141592653589793, and `e` the double
  nearest to e, 2.718281828459045. Both are approximate.

So `e pi i multiply power`, e^(iπ), is −I only to within rounding:
~[[-1 -0.0000] [0.0000 -1]].

## 2. Exactness

Exactness depends only on the values, never on a mode.

### 2.1 Which results are exact

A word given exact operands gives an exact result in these cases:

- **Always:** `add`, `subtract`, `multiply`, `divide`, `negate`,
  `percent`, `absolute_value`, `power` with an integer exponent,
  `inverse`, `determinant`, `trace`, `rank`,
  `reduced_row_echelon_form`, `cofactors`, `adjugate`, `lu`, `dot`,
  `cross`.
- **When the result is rational:**
  - `square_root` and `power` with a non-integer exponent, by the rules
    of section 6.2;
  - `frobenius_norm`, when the sum of the squared entries is the square
    of a rational;
  - `eigenvalues`, when every root of the characteristic polynomial is
    rational;
  - `diagonalize`, when every eigenvalue is rational (section 5.4).
- **In the trivial cases only:** `exponential` of a zero matrix (the
  identity) and `natural_logarithm` of the identity (the zero matrix).

Every other result is approximate: an irrational result (`2
square_root`), and every result of `exponential`, `natural_logarithm`,
`qr` and `spectral_norm` outside the cases above.

Exact computation uses no tolerance: an exact entry is zero or not, and
an exact matrix is singular or not.

### 2.2 Contagion

One approximate operand makes the result approximate: `1 3 divide ~1
multiply` is ~0.3333. The reverse never happens on its own.

Words that move or build entries without computing keep exactness
(stack, construction and structure words).

A result that counts or permutes is exact whatever its operand: `size`,
`rank` and the P of `lu`. It is an integer by definition, never a
measure, so `~[[1 2] [3 4]] rank` is `2` and `~[[1 2]] size` is `1 2`.
On an approximate operand, `rank` and the pivots of `lu` are decisions
of section 3.2; L and U stay approximate. A word that joins several
values (`vector`, `append_rows`, `append_columns`) gives an exact result
only when all of them are exact.

### 2.3 Converting

- `approximate` makes a value approximate: each entry becomes the
  double nearest to it, ties to the one with an even last bit. An entry
  beyond the largest finite double is `non_finite`; an entry too small
  becomes the nearest double, which may be 0. On an approximate value
  it changes nothing.
- `exact` makes a value exact: each entry becomes the simplest rational
  that rounds to the same double under `approximate`. The simplest is
  the one with the smallest denominator and, among those, the smallest
  absolute numerator. So `0.1 approximate exact` is 1/10. On an exact
  value it changes nothing.

No word turns an approximate value exact with a tolerance: it would
guess a value the input does not determine.

### 2.4 Digits

An exact value has no fixed size. A value with a numerator or a
denominator of more than `maxDigits` digits is `limit_digits`: a
literal or a binding before the program runs, the result of a word when
the word leaves it (the limit and its default
are in `engine-api-contract.md`). What a word computes on the way does
not count, only the value it leaves. An engine may stop a word early only
when it knows that the result will exceed the limit, never because an
upper bound says it might.

The error is never replaced by an approximate result:
`10001/10000 3000 power` is `limit_digits` (its numerator and
denominator have 12 001 digits), while
`10001/10000 approximate 3000 power` is ~1.3498385611954407.

## 3. Approximate results

An approximate value holds finite doubles only. After each word, an
approximate result with an infinite or NaN entry is `non_finite`
(`~1e308 ~1e308 add`). An exact result is never `non_finite`: it is
exact, or `limit_digits`.

### 3.1 What an engine must give

For each word, this document defines the true value Y: the exact
mathematical result of the word applied to the operands as given, each
approximate entry taken as the rational number its double is. An engine
may compute it by any algorithm. Its approximate result X conforms when

    ‖X − Y‖ ≤ 1e-10 · ‖Y‖ + 1e-12

where ‖·‖ is the infinity norm, the largest sum of absolute values in a
row. Two conforming engines may give different doubles; they never give
different exact values.

### 3.2 Decisions with a tolerance

Some approximate words decide with a threshold instead of an exact test:

| Decision | Threshold |
|---|---|
| a column has no pivot (section 5.2) | its candidates are all at most 1e-12 in absolute value |
| `qr` meets a dependent column | the part of the column orthogonal to the previous ones has a norm at most 1e-12 |
| two eigenvalues are one (section 5.4) | they differ by at most 1e-10 · max(1, largest absolute eigenvalue) |
| a pair of eigenvalues is real or complex | the true eigenvalues decide; see the band below |
| an approximate value compares as less, greater or equal | the true values decide; see the band below |

The threshold decides when the true value is clearly on one side of it.
When the true value is within the tolerance of section 3.1 of the
threshold (a pivot near 1e-12, two eigenvalues near the point of
merging, a complex pair with an imaginary part near 0, two compared
values near each other) either answer conforms, and the conformance
suite tests no case in that band.

## 4. Arithmetic

For A of size m×n and B of size p×q:

- `add`, `subtract`: defined when the shapes match. A scalar k meets an
  n×n matrix (n > 1) as k·I: `3 i 2 multiply add` is [[3 -2] [2 3]]
  (3 + 2i), and `[[1 2] [3 4]] 2 add` is [[3 2] [3 6]]. A scalar and a
  matrix that is not square is `dimension_mismatch`.
- `multiply`: the matrix product when n = p; scaling of every entry
  when either operand is a scalar. Otherwise `dimension_mismatch`.
- `divide`: A divided by a scalar k, entry by entry. A divisor that is
  not a scalar is `type_mismatch`; division by zero is `non_finite`.
- `negate`: −A.
- `percent`: A·k/100, with k a scalar: `200 15 percent` is 30. A k that
  is not a scalar is `type_mismatch`.
- `absolute_value`: |λ| as a 1×1 matrix for a real scalar λI of any
  size; any other matrix is `not_ordered` (`language.md`, section 5.3).

## 5. Linear algebra

### 5.1 Shapes

- `transpose`, `reduced_row_echelon_form`, `rank`, `frobenius_norm` and
  `spectral_norm` take any shape.
- `inverse`, `determinant`, `trace`, `cofactors`, `adjugate`, `lu`,
  `eigenvalues`, `diagonalize`, `exponential`, `natural_logarithm` and
  `square_root` take a square matrix.
- `qr` needs at least as many rows as columns.
- `dot` takes two column vectors of the same length; `cross` takes two
  3×1 vectors.

Any other shape is `dimension_mismatch`.

### 5.2 Elimination words

- `reduced_row_echelon_form`: the reduced row echelon form, which is
  unique. On an approximate value, a column with no pivot by the
  threshold of section 3.2 is treated as a column of zeros.
- `rank`: the number of nonzero rows of the reduced row echelon form.
- `determinant`, `trace`, `cofactors`, `adjugate`: their usual
  definitions. `adjugate` is the transpose of the cofactor matrix.
- `inverse`: A⁻¹. A singular matrix is `singular_matrix`; an
  approximate matrix is singular when `lu` finds a column with no
  pivot. `inverse` is `-1 power` (section 6) and gives the same value
  and the same errors.
- `lu` leaves P, L and U, with P A = L U, P a permutation, L unit lower
  triangular and U upper triangular. Column by column, the pivot is the
  entry of largest absolute value on or below the diagonal, the
  uppermost when several tie; its row is swapped into place, and the
  swap is applied to the rows of L already computed. A column with no
  nonzero candidate (section 3.2 on an approximate value) is left as it
  is, so a singular matrix has a decomposition with a zero on the
  diagonal of U. The rule is the same for exact and approximate values,
  so both give the same P outside the band of section 3.2.

### 5.3 Products and norms

- `dot`: the sum of the products of the entries, a scalar.
- `cross`: the cross product of two 3×1 vectors.
- `frobenius_norm`: the square root of the sum of the squared entries.
- `spectral_norm`: the largest singular value, the square root of the
  largest eigenvalue of AᵀA.
- `qr` leaves Q and R with A = Q R, Q of size m×n with orthonormal
  columns, and R of size n×n upper triangular with a positive diagonal.
  These are unique when A has full column rank. A matrix without full
  column rank is `rank_deficient`, decided on an approximate value by
  section 3.2.

### 5.4 Eigenvalues

- `eigenvalues` leaves the eigenvalues as a column, each repeated by
  its algebraic multiplicity, in descending order. When an eigenvalue
  is not real, the word is `complex_result` (section 5.5).
- `diagonalize` leaves P and D, with A = P D P⁻¹:
  - D is diagonal, with the eigenvalues in the order of `eigenvalues`.
  - For each distinct eigenvalue λ of multiplicity m, the next m
    columns of P are the basis of the null space of A − λI read from
    its reduced row echelon form: for each column j with no pivot, in
    increasing order of j, the vector with 1 at position j, minus the
    entry of column j in the row of each pivot at that pivot's position,
    and 0 elsewhere. The vectors are not scaled.
  - If that null space has fewer than m dimensions, the matrix is
    defective and the word is `not_diagonalizable`
    (`[[1 1] [0 1]] diagonalize`). It never leaves a singular P.
  - On an approximate value, eigenvalues closer than the threshold of
    section 3.2 are one eigenvalue.

  `[[2 1] [1 2]] diagonalize` leaves P = [[1 -1] [1 1]] and
  D = [[3 0] [0 1]], both exact. `[[2 0] [0 2]] diagonalize` leaves
  P = I and D = 2I.

### 5.5 Complex results of real words

Φ represents one complex number, not a column of them. When A has an
eigenvalue that is not real, `eigenvalues` and `diagonalize` are
`complex_result`, for exact and approximate values alike:
`[[0 -1] [1 0]] eigenvalues` (the spectrum is {i, −i}).

The principal square root and a non-integer power of a matrix that is
not in complex form, with a negative real eigenvalue, are complex too
and are `complex_result` (sections 5.6 and 6).

Words that use the spectrum only inside keep their own result: the
logarithm of a rotation is real, so `natural_logarithm` and
`spectral_norm` are never `complex_result`.

### 5.6 Functions of a matrix

- `square_root` is `1/2 power` (section 6) and gives the same value
  and the same errors. Its value is the **principal square root**: the
  unique square root whose eigenvalues all have a positive real part or
  are 0.
  - A scalar k ≥ 0 gives √k; a scalar k < 0 gives √|k|·J.
  - A matrix in complex form a + bi gives the principal square root
    x + yi, with x ≥ 0, and y ≥ 0 when x = 0.
  - Any other square matrix has a principal square root when it has no
    negative real eigenvalue and its eigenvalue 0, if any, has as many
    independent eigenvectors as its multiplicity
    (`[[0 0] [0 4]] square_root` is [[0 0] [0 2]]). With a negative real
    eigenvalue it is `complex_result` (`[[-1 0] [0 2]] square_root`);
    with a 0 eigenvalue short of eigenvectors it is `log_undefined`
    (`[[0 1] [0 0]] square_root`).
- `exponential` is e^A, the sum of the series I + A + A²/2! + ….
  For θ·J it is the rotation [[cos θ, −sin θ], [sin θ, cos θ]]. An
  approximate result that overflows is `non_finite`.
- `natural_logarithm` is the **principal logarithm**:
  - a scalar x > 0 gives ln x; x < 0 gives ln|x| + π·J, in complex
    form; x = 0 is `log_undefined`;
  - a matrix in complex form a + bi gives ln r + θ·J, with
    r = √(a² + b²) and θ = atan2(b, a), so θ is in (−π, π];
  - any other 2×2 matrix with no real eigenvalue ≤ 0 gives its principal
    logarithm, defective or not ([[1 1] [0 1]] has one), and a
    complex-conjugate pair of eigenvalues gives a real result;
  - a larger matrix gives P·ln(D)·P⁻¹ from `diagonalize`: a repeated
    eigenvalue works (`[[2 0 0] [0 2 0] [0 0 3]] natural_logarithm` is
    diag(ln 2, ln 2, ln 3)) and a defective matrix is
    `not_diagonalizable`;
  - a matrix that is not a scalar or in complex form, with a real
    eigenvalue ≤ 0, is `log_undefined`.

## 6. power

`power` is defined on matrices: B^Y = exp(Y · log B), with the
principal logarithm and the exponential of section 5.6. In the table,
"scalar" is a 1×1 matrix and "complex" a 2×2 matrix in complex form.
An exponent is an integer by its value, exact or approximate: `~2` is
the integer 2, so `-2 ~2 power` is ~4 by row 4. The test needs no
tolerance, since a double either is an integer or is not.
Complex matrices commute, so for them the order of the product
Y · log B does not matter.

### 6.1 The table

| # | Base B | Exponent Y | Result | Example |
|---|---|---|---|---|
| 1 | scalar | scalar | the real power. B < 0 with a non-integer Y gives the complex principal value, in complex form | `-4 1/2 power` is [[0 -2] [2 0]] |
| 2 | scalar > 0 | square matrix | exp(ln B · Y), approximate | `e pi i multiply power` is ~[[-1 -0.0000] [0.0000 -1]] |
| 3 | complex, or scalar < 0 | complex | exp(Y · log B), approximate | `i i power` is ~[[0.2079 0] [0 0.2079]], e^(−π/2) |
| 4 | square | integer scalar | repeated multiplication; a negative integer uses the inverse, and a singular B is then `singular_matrix`; Y = 0 gives I | `[[1 1] [0 1]] 3 power` is [[1 3] [0 1]]; `[[1 2] [2 4]] -1 power` is `singular_matrix` |
| 5 | square | non-integer scalar | exp(y · log B). A base that is neither scalar nor complex is `complex_result` with a negative real eigenvalue and `log_undefined` with a 0 eigenvalue, except for y = 1/2, which is the principal square root of section 5.6 | `[[2 0] [0 3]] 1/2 power` is ~[[1.4142 0] [0 1.7321]]; `[[1 1] [0 1]] 1/2 power` is [[1 1/2] [0 1]]; `[[0 0] [0 4]] 1/2 power` is [[0 0] [0 2]] |
| 6 | any other pair with Y not a scalar | square, not scalar | `ambiguous_power`: exp(Y log B) and exp(log B Y) differ when Y and log B do not commute. Row 3 is the exception | `[[1 1] [0 1]] [[0 1] [1 0]] power` |
| 7 | 0 | scalar | Y > 0 gives 0; Y = 0 gives 1; Y < 0 is `non_finite` | `0 -1 power` is `non_finite`; `0 1/2 power` is 0 |
| 8 | 0, or a singular matrix, where the case needs log B (never for y = 1/2, row 5) | | `log_undefined` | `0 pi i multiply power`; `[[1 2] [2 4]] 3/2 power` |
| 9 | not square | any | `dimension_mismatch` | `[[1 2]] 2 power` |
| 10 | any | not square | `dimension_mismatch` | `2 [[1 2]] power` |
| 11 | n×n | m×m, n ≠ m, neither scalar | `dimension_mismatch` | `[[1 0] [0 1]] [[1 0 0] [0 1 0] [0 0 1]] power` |
| 12 | scalar < 0 | square, neither complex nor scalar | `ambiguous_power`: log B is complex and does not commute with Y | `-2 [[1 0] [0 2]] power` |
| 13 | approximate | any, result overflows | `non_finite`. An exact result never overflows: it is exact, or `limit_digits` | `~10 400 power` is `non_finite`; `10 400 power` is the exact 10^400 |
| 14 | diagonal, not scalar, every entry ≥ 0 | non-integer scalar y > 0 | entry by entry, with 0^y = 0; no logarithm is needed | `[[0 0] [0 4]] 3/2 power` is [[0 0] [0 8]] |

**Order of the checks.** The first rule that applies decides. The
kinds of B and Y decide, never a numerical test of whether they
commute:

1. Dimensions: B is square (row 9), Y is square (row 10), and when
   neither is a scalar both have the same size (row 11).
2. Y is a scalar: rows 1, 4, 14, 5, 7, 8 and 13. For a scalar base, row 7
   comes before row 4: `0 -1 power` and `0 inverse` are `non_finite`.
   Row 14 comes before rows 5 and 8. Whether B is diagonal is read from
   its entries (every entry off the diagonal is 0), with no tolerance.
3. Y is not a scalar: B = 0 is `log_undefined` (row 8); B scalar > 0
   is row 2; B complex or scalar < 0, with Y complex, is row 3. Every
   other pair is `ambiguous_power` (rows 6 and 12): `i [[1 0] [0 2]]
   power` is `ambiguous_power`.

**A matrix with no real power.** `[[-1 0] [0 2]] 1/2 power` has a
negative eigenvalue and is not in complex form, so its principal value
is complex: `complex_result`, as is `[[-1 0] [0 2]] 3/2 power`. A
negative scalar keeps its complex form (`-4 1/2 power`, row 1). Turning
this error into a value in a later version breaks no program.

### 6.2 Exact operands

With an exact B, the table gives the value; this section says when it
is exact.

- **Integer exponent:** always exact (row 4). A negative Y uses the
  exact inverse: `[[1 2] [3 4]] -2 power` is [[11/2 -5/2] [-15/4 7/4]].
- **Non-integer exponent p/q, in lowest terms:** the result is exact
  when one of these rules applies to B and gives a rational value:
  - B is a scalar k > 0, and k^(p/q) is rational: `8 1/3 power` is 2.
  - B is a scalar k < 0, and the complex principal value of k^(p/q) has
    rational parts: `-4 1/4 power` is [[1 -1] [1 1]], that is 1 + i.
  - B is in complex form, q = 2, and the principal value has rational
    parts.
  - B is diagonal with entries d ≥ 0 (row 14 when p/q > 0), and every
    d^(p/q) is rational.
  - B is λI + N with N nilpotent and λ > 0, and λ^(p/q) is rational:
    the value is the finite sum Σ C(p/q, k) · λ^(p/q − k) · N^k over
    k from 0 to n − 1, with C the binomial coefficient:
    `[[1 1] [0 1]] 1/3 power` is [[1 1/3] [0 1]].

  All the rules compute the principal value, so two rules that apply to
  the same B give the same result. When no rule gives a rational value,
  the result is the approximate one, errors included: `2 1/2 power` is
  ~1.4142. This holds even when B has a rational root that no rule
  finds; a later version may add rules, since an approximate result
  becoming exact breaks no program.
- An exponent with a decimal literal is a rational: `0.5` is 1/2.

## 7. Worked identities

- Euler: exp(π·J) = [[cos π, −sin π], [sin π, cos π]] = −I, so
  exp(π·J) + I = 0. With the approximate `pi`, `pi i multiply
  exponential` is −I to within rounding.
- Conjugation: for Z = Φ(a + bi), Zᵀ = [[a b] [-b a]] = Φ(a − bi).
