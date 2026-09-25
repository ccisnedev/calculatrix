import '../errors/errors.dart';
import '../numeric/numeric_policy.dart';
import 'dart:math' as math;

final class LuDecomposition {
  const LuDecomposition({
    required this.permutation,
    required this.lower,
    required this.upper,
  });

  final Matrix permutation;
  final Matrix lower;
  final Matrix upper;
}

final class QrDecomposition {
  const QrDecomposition({required this.q, required this.r});

  final Matrix q;
  final Matrix r;
}

final class Diagonalization {
  const Diagonalization({required this.p, required this.d});

  final Matrix p;
  final Matrix d;
}

final class SvdDecomposition {
  const SvdDecomposition({required this.u, required this.s, required this.vT});

  final Matrix u;
  final Matrix s;
  final Matrix vT;
}

class Matrix {
  Matrix(List<List<double>> rows) : _rows = _normalize(rows) {
    _validateRectangular(_rows);
  }

  factory Matrix.scalar(double value) {
    return Matrix(<List<double>>[
      <double>[value],
    ]);
  }

  factory Matrix.identity(int size) {
    if (size < 1) {
      throw MatrixShapeError('Identity matrix size must be greater than zero.');
    }

    return Matrix(
      List<List<double>>.generate(
        size,
        (int row) => List<double>.generate(
          size,
          (int column) => row == column ? 1 : 0,
          growable: false,
        ),
        growable: false,
      ),
    );
  }

  factory Matrix.zeros(int rowCount, int columnCount) {
    _validateShape(rowCount, columnCount, label: 'Zero');

    return Matrix(
      List<List<double>>.generate(
        rowCount,
        (_) => List<double>.filled(columnCount, 0, growable: false),
        growable: false,
      ),
    );
  }

  factory Matrix.ones(int rowCount, int columnCount) {
    _validateShape(rowCount, columnCount, label: 'One');

    return Matrix(
      List<List<double>>.generate(
        rowCount,
        (_) => List<double>.filled(columnCount, 1, growable: false),
        growable: false,
      ),
    );
  }

  /// The imaginary unit as a 2×2 real matrix: `[[0, -1], [1, 0]]`.
  ///
  /// Satisfies `i² = -I`, providing a faithful matrix representation of
  /// complex numbers within real linear algebra (Gauss's "lateral unit").
  static final Matrix i = Matrix(<List<double>>[
    <double>[0, -1],
    <double>[1, 0],
  ]);

  /// Creates the complex number `re + im·i` as a 2×2 matrix `re·I₂ + im·J`.
  ///
  /// The result has the form `[[re, -im], [im, re]]`, which is the standard
  /// matrix representation of complex numbers in the subalgebra `{aI + bJ}`.
  factory Matrix.complex(double re, double im) {
    return Matrix(<List<double>>[
      <double>[re, -im],
      <double>[im, re],
    ]);
  }

  /// Hilbert matrix of order [n]: `H(i,j) = 1/(i+j+1)`.
  /// Canonical ill-conditioned test matrix with κ(H_n) growing exponentially.
  factory Matrix.hilbert(int n) {
    if (n < 1) {
      throw MatrixShapeError('Hilbert matrix size must be at least 1.');
    }
    return Matrix(
      List<List<double>>.generate(
        n,
        (int i) => List<double>.generate(
          n,
          (int j) => 1.0 / (i + j + 1),
          growable: false,
        ),
        growable: false,
      ),
    );
  }

  /// Pascal matrix of order [n]: `P(i,j) = C(i+j, i)`.
  /// Symmetric positive definite with det(P) = 1.
  factory Matrix.pascal(int n) {
    if (n < 1) {
      throw MatrixShapeError('Pascal matrix size must be at least 1.');
    }
    // Build using the recurrence: P[i,j] = P[i-1,j] + P[i,j-1]
    final rows = List<List<double>>.generate(n, (int i) {
      return List<double>.generate(n, (int j) {
        if (i == 0 || j == 0) return 1.0;
        return 0.0; // placeholder
      }, growable: false);
    }, growable: false);

    // Fill using Pascal's recurrence
    for (int i = 1; i < n; i++) {
      for (int j = 1; j < n; j++) {
        rows[i][j] = rows[i - 1][j] + rows[i][j - 1];
      }
    }
    return Matrix(rows);
  }

  /// Frank matrix of order [n]: upper-Hessenberg with known eigenvalue structure.
  /// `F(i,j) = n - max(i,j)` for `j >= i-1`, else 0.
  factory Matrix.frank(int n) {
    if (n < 1) {
      throw MatrixShapeError('Frank matrix size must be at least 1.');
    }
    return Matrix(
      List<List<double>>.generate(
        n,
        (int i) => List<double>.generate(
          n,
          (int j) => j >= i - 1 ? (n - math.max(i, j)).toDouble() : 0.0,
          growable: false,
        ),
        growable: false,
      ),
    );
  }

  final List<List<double>> _rows;

  int get rowCount => _rows.length;

  int get columnCount => _rows.isEmpty ? 0 : _rows.first.length;

  bool get isSquare => rowCount == columnCount;

  bool get isScalar => rowCount == 1 && columnCount == 1;

  /// Whether this matrix is in complex form: `[[a, -b], [b, a]]`.
  ///
  /// A 2×2 matrix is in complex form iff `M[0,0] == M[1,1]` and
  /// `M[0,1] == -M[1,0]`, which is necessary and sufficient for the matrix
  /// to belong to the subalgebra `{aI + bJ}` isomorphic to ℂ.
  ///
  /// Both equalities are tested scale-relative, never against a fixed
  /// absolute floor: a fixed floor (e.g. [CalculatrixNumericPolicy.
  /// defaultAbsoluteTolerance], 1e-12) is wrong by construction at any
  /// scale far below it — `diag(1e-20, 2e-20)` has diagonal entries that
  /// truly differ, but a 1e-12 floor calls them equal and misclassifies
  /// this real diagonal matrix as complex form, which then fails a
  /// downstream "is the magnitude zero" check meant for genuine zero
  /// matrices. `M[0,0] == M[1,1]` is instead tested against
  /// `4 * u * max(|M[0,0]|, |M[1,1]|)` (u = double's unit roundoff, see
  /// [CalculatrixNumericPolicy.machineEpsilon]), and `M[0,1] == -M[1,0]`
  /// against `4 * u * ‖M‖∞` (the whole matrix's own scale, since the
  /// off-diagonal pair can be exactly zero on one or both sides).
  bool get isComplexForm {
    if (rowCount != 2 || columnCount != 2) return false;
    const double u = CalculatrixNumericPolicy.machineEpsilon;
    final double diagonalTolerance =
        4 * u * math.max(_rows[0][0].abs(), _rows[1][1].abs());
    // Round 5 correction, case 4: the off-diagonal tolerance must stay
    // finite whenever the individual entries are, so it is built from the
    // largest entry's own magnitude (a plain max, never a sum) rather than
    // from [_infinityNorm], whose row-sum can genuinely overflow to
    // Infinity even though every entry is individually finite (e.g. all
    // four entries at 1e308: the row sum 2e308 exceeds double's max finite
    // value). An infinite tolerance makes `Infinity <= Infinity` compare
    // true regardless of the actual off-diagonal values, wrongly
    // classifying a non-complex-form matrix as complex form.
    final double offDiagonalTolerance = 4 * u * _maxAbsEntry();
    return (_rows[0][0] - _rows[1][1]).abs() <= diagonalTolerance &&
        (_rows[0][1] + _rows[1][0]).abs() <= offDiagonalTolerance;
  }

  /// The real part of a complex-form matrix: the `a` in `aI + bJ`.
  ///
  /// Throws [MatrixDomainError] if [isComplexForm] is false.
  double get realPart {
    if (!isComplexForm) {
      throw MatrixDomainError('Matrix is not in complex form [[a,-b],[b,a]].');
    }
    return _rows[0][0];
  }

  /// The imaginary part of a complex-form matrix: the `b` in `aI + bJ`.
  ///
  /// Throws [MatrixDomainError] if [isComplexForm] is false.
  double get imagPart {
    if (!isComplexForm) {
      throw MatrixDomainError('Matrix is not in complex form [[a,-b],[b,a]].');
    }
    return _rows[1][0];
  }

  double get scalarValue {
    if (!isScalar) {
      throw MatrixDomainError('Matrix is not scalar.');
    }
    return _rows.first.first;
  }

  List<List<double>> get rows {
    return _rows
        .map((List<double> row) => List<double>.unmodifiable(row))
        .toList(growable: false);
  }

  double at(int row, int column) {
    return _rows[row][column];
  }

  Matrix operator +(Matrix other) {
    final Matrix a = _promoteScalar(this, other);
    final Matrix b = _promoteScalar(other, this);
    a._requireSameDimensions(b, operation: 'addition');

    final List<List<double>> result = List<List<double>>.generate(
      a.rowCount,
      (int r) => List<double>.generate(
        a.columnCount,
        (int c) => a._rows[r][c] + b._rows[r][c],
        growable: false,
      ),
      growable: false,
    );

    return Matrix(result);
  }

  Matrix operator -(Matrix other) {
    final Matrix a = _promoteScalar(this, other);
    final Matrix b = _promoteScalar(other, this);
    a._requireSameDimensions(b, operation: 'subtraction');

    final List<List<double>> result = List<List<double>>.generate(
      a.rowCount,
      (int r) => List<double>.generate(
        a.columnCount,
        (int c) => a._rows[r][c] - b._rows[r][c],
        growable: false,
      ),
      growable: false,
    );

    return Matrix(result);
  }

  Matrix operator *(Matrix other) {
    if (isScalar) {
      return other.scale(scalarValue);
    }

    if (other.isScalar) {
      return scale(other.scalarValue);
    }

    if (columnCount != other.rowCount) {
      throw MatrixShapeError(
        'Cannot multiply ${rowCount}x${columnCount} by '
        '${other.rowCount}x${other.columnCount}.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    final List<List<double>> result = List<List<double>>.generate(
      rowCount,
      (int r) => List<double>.generate(other.columnCount, (int c) {
        double sum = 0;
        for (int i = 0; i < columnCount; i++) {
          sum += _rows[r][i] * other._rows[i][c];
        }
        return sum;
      }, growable: false),
      growable: false,
    );

    return Matrix(result);
  }

  Matrix scale(double scalar) {
    final List<List<double>> result = List<List<double>>.generate(
      rowCount,
      (int r) => List<double>.generate(
        columnCount,
        (int c) => _rows[r][c] * scalar,
        growable: false,
      ),
      growable: false,
    );

    return Matrix(result);
  }

  Matrix operator /(Matrix other) {
    if (other.isScalar) {
      final double divisor = other.scalarValue;
      if (divisor == 0) {
        throw MatrixDomainError(
          'Division by zero scalar is undefined.',
          errorId: CalculatrixErrorId.nonFinite,
        );
      }

      return scale(1 / divisor);
    }

    throw UnsupportedCalculatrixOperationError(
      'Matrix division is only supported by scalar (1x1) denominator.',
      errorId: CalculatrixErrorId.typeMismatch,
    );
  }

  /// Computes the inverse after exact power-of-two scale normalization
  /// (round 4 correction, rule 1): `A = c * normalized` for `c = 2^k`
  /// nearest `‖A‖`, so `inv(A) = inv(normalized) * (1/c)`. Multiplying or
  /// dividing by an exact power of two never rounds, so `normalized`
  /// carries no more error than `A` itself, and its own norm is always
  /// within a factor of 2 of 1 — which is exactly what makes the fixed
  /// `absoluteTolerance` pivot cutoff inside [_inverseRaw] (still 1e-12 by
  /// default) a *safe* floor regardless of `A`'s own scale: at norm ~1, a
  /// genuinely zero pivot and a genuinely tiny-but-real one
  /// (e.g. `diag(1e-20, 2e-20)`, whose pivots become O(1) after
  /// normalization) are no longer confused by a cutoff tuned for O(1)
  /// matrices. This replaces comparing the cutoff directly against `A`'s
  /// own (possibly tiny or huge) entries, which is wrong by construction
  /// at any scale other than the one the cutoff happened to be tuned for.
  Matrix _inverse({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    _requireSquare(operation: 'inverse');
    _checkFiniteMatrix(this);

    final ({int k, Matrix scaled}) normalization = _normalizedByPowerOfTwo();
    if (normalization.k == 0) {
      return normalization.scaled._inverseRaw(
        absoluteTolerance: absoluteTolerance,
      );
    }

    final Matrix rawInverse = normalization.scaled._inverseRaw(
      absoluteTolerance: absoluteTolerance,
    );
    return _checkFiniteMatrix(
      _scaleByPowerOfTwo(rawInverse, -normalization.k.toDouble()),
    );
  }

  Matrix _inverseRaw({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    final int size = rowCount;
    final List<List<double>> augmented = List<List<double>>.generate(
      size,
      (int row) => <double>[
        ..._rows[row],
        ...List<double>.generate(
          size,
          (int column) => row == column ? 1 : 0,
          growable: false,
        ),
      ],
      growable: false,
    );

    for (int pivotColumn = 0; pivotColumn < size; pivotColumn++) {
      int pivotRow = pivotColumn;
      double pivotMagnitude = augmented[pivotRow][pivotColumn].abs();

      for (int row = pivotColumn + 1; row < size; row++) {
        final double candidateMagnitude = augmented[row][pivotColumn].abs();
        if (candidateMagnitude > pivotMagnitude) {
          pivotMagnitude = candidateMagnitude;
          pivotRow = row;
        }
      }

      // Round 5 correction (inverse: LU with partial pivoting, Higham
      // 2002 Ch. 9): singularity is declared only on an exact zero pivot,
      // never on an absolute cutoff compared against the pivot's own
      // magnitude. `_inverse` already normalizes to a matrix of norm ~1
      // before this runs, but even at that scale a genuinely tiny-but-real
      // pivot (e.g. one column scaled far below another by the input's own
      // structure, such as `[[1,1e20],[0,1]]`) is not singular — only a
      // pivot that is bit-for-bit zero (every candidate in the column is
      // zero, meaning the column truly has no component outside the
      // already-eliminated rows) is. A merely-huge-but-finite result is
      // instead caught by `_inverse`'s own `_checkFiniteMatrix` call after
      // undoing the scale normalization.
      if (pivotMagnitude == 0) {
        throw MatrixDomainError(
          'Matrix is singular and cannot be inverted.',
          errorId: CalculatrixErrorId.singularMatrix,
        );
      }

      if (pivotRow != pivotColumn) {
        final List<double> temp = augmented[pivotColumn];
        augmented[pivotColumn] = augmented[pivotRow];
        augmented[pivotRow] = temp;
      }

      final double pivot = augmented[pivotColumn][pivotColumn];
      for (int column = 0; column < augmented[pivotColumn].length; column++) {
        augmented[pivotColumn][column] /= pivot;
      }

      for (int row = 0; row < size; row++) {
        if (row == pivotColumn) {
          continue;
        }

        final double factor = augmented[row][pivotColumn];
        if (factor == 0) {
          continue;
        }

        for (int column = 0; column < augmented[row].length; column++) {
          augmented[row][column] -= factor * augmented[pivotColumn][column];
        }
      }
    }

    return Matrix(
      List<List<double>>.generate(
        size,
        (int row) => List<double>.generate(
          size,
          (int column) => augmented[row][size + column],
          growable: false,
        ),
        growable: false,
      ),
    );
  }

  Matrix inverse({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    return _inverse(absoluteTolerance: absoluteTolerance);
  }

  Matrix determinant({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    _requireSquare(operation: 'determinant');

    if (isScalar) {
      return this;
    }

    final int size = rowCount;
    final List<List<double>> triangular = List<List<double>>.generate(
      size,
      (int row) => List<double>.from(_rows[row]),
      growable: false,
    );

    double determinantValue = 1;
    int swapCount = 0;

    for (int pivotColumn = 0; pivotColumn < size; pivotColumn++) {
      int pivotRow = pivotColumn;
      double pivotMagnitude = triangular[pivotRow][pivotColumn].abs();

      for (int row = pivotColumn + 1; row < size; row++) {
        final double candidateMagnitude = triangular[row][pivotColumn].abs();
        if (candidateMagnitude > pivotMagnitude) {
          pivotMagnitude = candidateMagnitude;
          pivotRow = row;
        }
      }

      if (pivotMagnitude <= absoluteTolerance) {
        return Matrix.scalar(0);
      }

      if (pivotRow != pivotColumn) {
        final List<double> temp = triangular[pivotColumn];
        triangular[pivotColumn] = triangular[pivotRow];
        triangular[pivotRow] = temp;
        swapCount += 1;
      }

      final double pivot = triangular[pivotColumn][pivotColumn];
      determinantValue *= pivot;

      for (int row = pivotColumn + 1; row < size; row++) {
        final double factor = triangular[row][pivotColumn] / pivot;
        if (factor == 0) {
          continue;
        }

        triangular[row][pivotColumn] = 0;
        for (int column = pivotColumn + 1; column < size; column++) {
          triangular[row][column] -= factor * triangular[pivotColumn][column];
        }
      }
    }

    return Matrix.scalar(
      swapCount.isEven ? determinantValue : -determinantValue,
    );
  }

  /// Computes eigenvalues after exact power-of-two scale normalization
  /// (round 4 correction, rule 1): `eig(A) = c * eig(normalized)` for
  /// `c = 2^k` nearest `‖A‖`. Every deflation check and eigenvalue-cleanup
  /// cutoff inside [_eigenvaluesRaw] compares against the fixed
  /// [absoluteTolerance] (1e-12 by default), which is only ever a sound
  /// floor when the matrix it is applied to has norm ~1 — exactly what
  /// `normalized` guarantees regardless of `A`'s own scale. Without this,
  /// a tiny-scale matrix (e.g. eigenvalues ~1e-14) has every genuine
  /// subdiagonal/eigenvalue entry wrongly zeroed by a cutoff many orders
  /// of magnitude above them, and a huge-scale one has its genuine
  /// subdiagonal noise never zeroed at all.
  Matrix eigenvalues({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
    @Deprecated(
      'Unused since round 5: the QR iteration bound is now the fixed, '
      'internally-computed 30*n (Higham 2008 Ch. 2 / LAPACK dhseqr), not a '
      'caller-supplied cutoff.',
    )
    int maxIterations = 200,
  }) {
    _requireSquare(operation: 'eigenvalues');
    _checkFiniteMatrix(this);

    if (isScalar) {
      return this;
    }

    // Exact-triangular fast path (round 5 correction): a triangular
    // matrix's eigenvalues ARE its diagonal entries, exactly, by
    // definition of the determinant of `A - lambda*I` for a triangular
    // `A` (the characteristic polynomial factors as
    // `prod(A[i][i] - lambda)`). This never runs Hessenberg reduction, QR
    // iteration or power-of-two normalization at all, so it cannot be
    // defeated by an overflowing normalization step (e.g.
    // `diag(1e308, 1.5e308)`, whose norm-based `k` would otherwise land
    // near 1024 and overflow a naive single-step `2^k` undo-scale).
    if (_isExactlyTriangular()) {
      final List<double> diagonal = List<double>.generate(
        rowCount,
        (int i) => _rows[i][i],
        growable: false,
      )..sort((double left, double right) => right.compareTo(left));
      return Matrix(
        diagonal.map((double value) => <double>[value]).toList(
          growable: false,
        ),
      );
    }

    final ({int k, Matrix scaled}) normalization = _normalizedByPowerOfTwo();
    final Matrix raw = normalization.scaled._eigenvaluesRaw(
      absoluteTolerance: absoluteTolerance,
    );
    if (normalization.k == 0) {
      return raw;
    }
    return _checkFiniteMatrix(
      _scaleByPowerOfTwo(raw, normalization.k.toDouble()),
    );
  }

  Matrix _eigenvaluesRaw({required double absoluteTolerance}) {
    if (rowCount == 2) {
      return _eigenvalues2x2(absoluteTolerance);
    }

    // General NxN: Hessenberg reduction then QR iteration with Wilkinson
    // shift (round 4 correction, case G: every 11th iteration without a
    // deflation instead takes an "exceptional shift" — a standard Francis
    // QR remedy for spectra a plain Wilkinson shift can stagnate on, such
    // as a permutation matrix's eigenvalues sitting equally spaced on the
    // unit circle).
    //
    // Deflation test (round 5 correction): the standard LAPACK criterion
    // (`dlahqr`/`dhseqr`), a subdiagonal entry is negligible relative to
    // its two diagonal neighbors —
    // `|h[i][i-1]| <= eps*(|h[i-1][i-1]| + |h[i][i]|)` — rather than a
    // fixed absolute floor, which (like every other fixed cutoff replaced
    // this round) is only sound for a matrix of norm ~1.
    //
    // Iteration bound (round 5 correction): a fixed `30*n` (Higham 2008
    // Ch. 2 / LAPACK's own convergence budget), not a caller-supplied
    // cutoff — this is a data-independent loop bound that throws
    // `no-convergence` if exhausted, never a silent fallback.
    final int n = rowCount;
    final int maxIterationsPerBlock = 30 * n;
    final List<List<double>> h = _toHessenberg(absoluteTolerance);
    const double eps = CalculatrixNumericPolicy.machineEpsilon;

    // QR iteration on upper Hessenberg form
    int size = n;
    final List<double> eigenvaluesList = <double>[];

    while (size > 2) {
      int iterations = 0;
      while (iterations < maxIterationsPerBlock) {
        // Check for deflation: subdiagonal element negligible relative to
        // its two diagonal neighbors.
        if (h[size - 1][size - 2].abs() <=
            eps * (h[size - 2][size - 2].abs() + h[size - 1][size - 1].abs())) {
          eigenvaluesList.add(h[size - 1][size - 1]);
          size--;
          break;
        }

        // Check for 2x2 block deflation
        if (size >= 3 &&
            h[size - 2][size - 3].abs() <=
                eps *
                    (h[size - 3][size - 3].abs() +
                        h[size - 2][size - 2].abs())) {
          // Extract 2x2 trailing block
          final double a = h[size - 2][size - 2];
          final double b = h[size - 2][size - 1];
          final double c = h[size - 1][size - 2];
          final double d = h[size - 1][size - 1];
          _solve2x2Block(a, b, c, d, eigenvaluesList, absoluteTolerance);
          size -= 2;
          break;
        }

        final double a = h[size - 2][size - 2];
        final double b = h[size - 2][size - 1];
        final double c = h[size - 1][size - 2];
        final double d = h[size - 1][size - 1];
        final double shift = _shiftForQrIteration(h, size, iterations, a, b, c, d);

        // Apply shift
        for (int i = 0; i < size; i++) {
          h[i][i] -= shift;
        }

        // QR step via Givens rotations on the Hessenberg matrix
        _qrStepGivens(h, size, absoluteTolerance);

        // Undo shift
        for (int i = 0; i < size; i++) {
          h[i][i] += shift;
        }

        iterations++;
      }

      if (iterations == maxIterationsPerBlock) {
        // Failed to converge — check if it might be complex eigenvalues
        throw MatrixDomainError(
          'Eigenvalues did not converge for this matrix.',
          errorId: CalculatrixErrorId.noConvergence,
        );
      }
    }

    // Handle remaining 1x1 or 2x2 block
    if (size == 2) {
      final double a = h[0][0];
      final double b = h[0][1];
      final double c = h[1][0];
      final double d = h[1][1];
      _solve2x2Block(a, b, c, d, eigenvaluesList, absoluteTolerance);
    } else if (size == 1) {
      eigenvaluesList.add(h[0][0]);
    }

    // Sort descending. Round 5 correction: the trailing "clean near-zero
    // eigenvalues" absolute-cutoff loop that used to run here has been
    // removed entirely — it zeroed any eigenvalue at or below
    // [absoluteTolerance] regardless of the matrix's own scale, which
    // silently discarded genuinely tiny-but-nonzero eigenvalues. The
    // matrix-wide power-of-two normalization already makes every fixed
    // tolerance *inside* this method (the deflation tests above) sound
    // relative to a matrix of norm ~1; there is no further "cleanup" step
    // that is ever correct across every scale.
    eigenvaluesList.sort((double left, double right) => right.compareTo(left));

    return Matrix(
      eigenvaluesList
          .map((double value) => <double>[value])
          .toList(growable: false),
    );
  }

  /// Picks the shift for one QR iteration step: the ordinary Wilkinson
  /// shift, except every 11th iteration without a deflation, when an
  /// "exceptional shift" is used instead (round 4 correction, case G).
  ///
  /// A plain single-shift QR iteration can stagnate indefinitely on
  /// certain spectra — most notably a permutation matrix, whose
  /// eigenvalues sit equally spaced on the unit circle, so the Wilkinson
  /// shift (the trailing 2x2 block's eigenvalue closest to `h[n-1][n-1]`)
  /// keeps picking the same non-progressing direction every iteration.
  /// The standard remedy (used by LAPACK's `dlahqr`/EISPACK's `hqr`) is to
  /// periodically substitute an unrelated, ad hoc shift derived from nearby
  /// subdiagonal magnitudes, which reliably breaks the cycle without
  /// otherwise disturbing convergence on well-behaved spectra (this never
  /// fires before the 11th iteration of a given deflation block, so it
  /// costs nothing for matrices that already converge quickly).
  static double _shiftForQrIteration(
    List<List<double>> h,
    int size,
    int iterations,
    double a,
    double b,
    double c,
    double d,
  ) {
    if (iterations > 0 && iterations % 11 == 0) {
      final double s =
          h[size - 1][size - 2].abs() +
          (size >= 3 ? h[size - 2][size - 3].abs() : 0);
      return 0.75 * s;
    }
    return _wilkinsonShift(a, b, c, d);
  }

  Matrix _eigenvalues2x2(double absoluteTolerance) {
    final double a = _rows[0][0];
    final double b = _rows[0][1];
    final double c = _rows[1][0];
    final double d = _rows[1][1];
    final double trace = a + d;
    final double determinantValue = (a * d) - (b * c);

    double discriminant = (trace * trace) - (4 * determinantValue);
    if (discriminant.abs() <= absoluteTolerance) {
      discriminant = 0;
    }

    if (discriminant < 0) {
      throw MatrixDomainError(
        'Eigenvalues are undefined in the real domain for this matrix.',
      );
    }

    final double sqrtDiscriminant = math.sqrt(discriminant);
    final List<double> values = <double>[
      (trace + sqrtDiscriminant) / 2,
      (trace - sqrtDiscriminant) / 2,
    ];

    values.sort((double left, double right) => right.compareTo(left));

    return Matrix(
      values
          .map(
            (double value) => <double>[
              value.abs() <= absoluteTolerance ? 0 : value,
            ],
          )
          .toList(growable: false),
    );
  }

  /// Collects only the strictly real eigenvalues of this matrix, using the
  /// same Hessenberg reduction plus shifted QR real-Schur pipeline as
  /// [eigenvalues]. Unlike the public API, this never throws just because
  /// the spectrum also contains a genuine complex-conjugate pair: such a
  /// pair simply contributes no entries to the returned list.
  ///
  /// This is what [log] and [power] use to test the actual domain rule for
  /// the principal logarithm, "some real eigenvalue is non-positive", which
  /// must not be tripped up by an unrelated complex-conjugate pair sitting
  /// elsewhere in the spectrum: a real matrix with no eigenvalue on the
  /// closed negative real axis has a unique real principal logarithm even
  /// when some of its other eigenvalues are complex.
  /// Normalize-then-undo wrapper around [_realEigenvaluesIgnoringComplexPairsRaw]
  /// (round 4 correction, rule 1) — see [eigenvalues]'s doc comment for why
  /// this is necessary: every cutoff inside the raw computation only makes
  /// sense relative to a matrix of norm ~1.
  List<double> _realEigenvaluesIgnoringComplexPairs({
    required double absoluteTolerance,
  }) {
    if (isScalar) {
      return <double>[scalarValue];
    }

    // Exact-triangular fast path (round 5 correction) — see [eigenvalues]'s
    // doc comment for why this must come before normalization at all.
    if (_isExactlyTriangular()) {
      return List<double>.generate(
        rowCount,
        (int i) => _rows[i][i],
        growable: false,
      );
    }

    final ({int k, Matrix scaled}) normalization = _normalizedByPowerOfTwo();
    final List<double> raw = normalization
        .scaled
        ._realEigenvaluesIgnoringComplexPairsRaw(
          absoluteTolerance: absoluteTolerance,
        );
    if (normalization.k == 0) {
      return raw;
    }
    return raw
        .map(
          (double value) =>
              _scalarScaleByPowerOfTwo(value, normalization.k.toDouble()),
        )
        .toList(growable: false);
  }

  List<double> _realEigenvaluesIgnoringComplexPairsRaw({
    required double absoluteTolerance,
  }) {
    if (rowCount == 2) {
      final double a = _rows[0][0];
      final double b = _rows[0][1];
      final double c = _rows[1][0];
      final double d = _rows[1][1];
      final List<double> realEigenvaluesList = <double>[];
      _solve2x2BlockIgnoringComplexPairs(
        a,
        b,
        c,
        d,
        realEigenvaluesList,
        absoluteTolerance,
      );
      return realEigenvaluesList;
    }

    final int n = rowCount;
    final int maxIterationsPerBlock = 30 * n;
    final List<List<double>> h = _toHessenberg(absoluteTolerance);
    const double eps = CalculatrixNumericPolicy.machineEpsilon;

    int size = n;
    final List<double> realEigenvaluesList = <double>[];

    while (size > 2) {
      int iterations = 0;
      while (iterations < maxIterationsPerBlock) {
        if (h[size - 1][size - 2].abs() <=
            eps * (h[size - 2][size - 2].abs() + h[size - 1][size - 1].abs())) {
          realEigenvaluesList.add(h[size - 1][size - 1]);
          size--;
          break;
        }

        if (size >= 3 &&
            h[size - 2][size - 3].abs() <=
                eps *
                    (h[size - 3][size - 3].abs() +
                        h[size - 2][size - 2].abs())) {
          final double a = h[size - 2][size - 2];
          final double b = h[size - 2][size - 1];
          final double c = h[size - 1][size - 2];
          final double d = h[size - 1][size - 1];
          _solve2x2BlockIgnoringComplexPairs(
            a,
            b,
            c,
            d,
            realEigenvaluesList,
            absoluteTolerance,
          );
          size -= 2;
          break;
        }

        final double a = h[size - 2][size - 2];
        final double b = h[size - 2][size - 1];
        final double c = h[size - 1][size - 2];
        final double d = h[size - 1][size - 1];
        final double shift = _shiftForQrIteration(h, size, iterations, a, b, c, d);

        for (int i = 0; i < size; i++) {
          h[i][i] -= shift;
        }

        _qrStepGivens(h, size, absoluteTolerance);

        for (int i = 0; i < size; i++) {
          h[i][i] += shift;
        }

        iterations++;
      }

      if (iterations == maxIterationsPerBlock) {
        throw MatrixDomainError(
          'Eigenvalues did not converge for this matrix.',
          errorId: CalculatrixErrorId.noConvergence,
        );
      }
    }

    if (size == 2) {
      final double a = h[0][0];
      final double b = h[0][1];
      final double c = h[1][0];
      final double d = h[1][1];
      _solve2x2BlockIgnoringComplexPairs(
        a,
        b,
        c,
        d,
        realEigenvaluesList,
        absoluteTolerance,
      );
    } else if (size == 1) {
      realEigenvaluesList.add(h[0][0]);
    }

    // Round 5 correction: no trailing absolute-cutoff cleanup loop — see
    // [_eigenvaluesRaw]'s doc comment for why every matrix-wide zeroing
    // pass was removed.
    return realEigenvaluesList;
  }

  /// Normalize-then-undo wrapper (round 4 correction, rule 1): the
  /// eigenvector Gaussian elimination below has its own pivot/free-column
  /// cutoffs against [absoluteTolerance], which are only sound for a
  /// matrix of norm ~1 — exactly the same defect [_inverseRaw] and
  /// [_eigenvaluesRaw] had. Eigenvectors are scale-invariant (the null
  /// space of `(cA - cλI) = c(A - λI)` is identical to that of `A - λI`),
  /// so the elimination is done entirely on the normalized matrix with its
  /// own (un-rescaled) eigenvalues; only `D`'s diagonal is rescaled back
  /// by `c = 2^k` at the end.
  Diagonalization diagonalization({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    _requireSquare(operation: 'diagonalization');
    _checkFiniteMatrix(this);

    final ({int k, Matrix scaled}) normalization = _normalizedByPowerOfTwo();
    final Matrix target = normalization.scaled;

    final Matrix eigenvalueColumn = target.eigenvalues(
      absoluteTolerance: absoluteTolerance,
    );

    final int n = rowCount;
    final List<double> lambdas = List<double>.generate(
      n,
      (int i) => eigenvalueColumn.at(i, 0),
      growable: false,
    );

    // Build D as a diagonal matrix, rescaled back to A's own magnitude.
    final List<List<double>> dRows = List<List<double>>.generate(
      n,
      (int r) => List<double>.generate(
        n,
        (int c) => r == c
            ? _scalarScaleByPowerOfTwo(lambdas[r], normalization.k.toDouble())
            : 0,
        growable: false,
      ),
      growable: false,
    );

    // Build P: for each eigenvalue, solve (target - λI)x = 0 via row
    // reduction on the normalized target (eigenvectors are scale-invariant).
    final List<List<double>> pColumns = <List<double>>[];

    for (int k = 0; k < n; k++) {
      final double lambda = lambdas[k];

      // Form target - λI
      final List<List<double>> augmented = List<List<double>>.generate(
        n,
        (int r) => List<double>.generate(
          n,
          (int c) => target._rows[r][c] - (r == c ? lambda : 0),
          growable: false,
        ),
        growable: false,
      );

      // Gaussian elimination with partial pivoting (forward reduction)
      final List<int> pivotColumns = <int>[];
      int pivotRow = 0;
      for (int col = 0; col < n && pivotRow < n; col++) {
        // Find pivot
        int maxRow = pivotRow;
        double maxVal = augmented[pivotRow][col].abs();
        for (int r = pivotRow + 1; r < n; r++) {
          if (augmented[r][col].abs() > maxVal) {
            maxVal = augmented[r][col].abs();
            maxRow = r;
          }
        }

        if (maxVal <= absoluteTolerance) {
          continue;
        }

        // Swap rows
        if (maxRow != pivotRow) {
          final List<double> temp = augmented[pivotRow];
          augmented[pivotRow] = augmented[maxRow];
          augmented[maxRow] = temp;
        }

        pivotColumns.add(col);

        // Scale pivot row
        final double pivotVal = augmented[pivotRow][col];
        for (int c = col; c < n; c++) {
          augmented[pivotRow][c] /= pivotVal;
        }

        // Eliminate below and above
        for (int r = 0; r < n; r++) {
          if (r == pivotRow) continue;
          final double factor = augmented[r][col];
          if (factor.abs() <= absoluteTolerance) continue;
          for (int c = col; c < n; c++) {
            augmented[r][c] -= factor * augmented[pivotRow][c];
          }
        }

        pivotRow++;
      }

      // Find a free variable column (not a pivot column)
      // Build the null space vector
      final List<double> eigenvector = List<double>.filled(n, 0);
      final Set<int> pivotSet = pivotColumns.toSet();

      // Find the first free column
      int freeCol = -1;
      for (int c = 0; c < n; c++) {
        if (!pivotSet.contains(c)) {
          freeCol = c;
          break;
        }
      }

      if (freeCol == -1) {
        // Numerically rank n: shouldn't happen for a true eigenvalue.
        // Fall back to the last column direction.
        eigenvector[n - 1] = 1;
      } else {
        eigenvector[freeCol] = 1;
        // Back-substitute: for each pivot row i with pivot column p[i],
        // x[p[i]] = -augmented[i][freeCol]
        for (int i = 0; i < pivotColumns.length; i++) {
          eigenvector[pivotColumns[i]] = -augmented[i][freeCol];
        }
      }

      // Normalize the eigenvector
      double norm = 0;
      for (int i = 0; i < n; i++) {
        norm += eigenvector[i] * eigenvector[i];
      }
      norm = math.sqrt(norm);
      if (norm > absoluteTolerance) {
        for (int i = 0; i < n; i++) {
          eigenvector[i] /= norm;
        }
      }

      // Clean near-zero entries
      for (int i = 0; i < n; i++) {
        if (eigenvector[i].abs() <= absoluteTolerance) {
          eigenvector[i] = 0;
        }
      }

      pColumns.add(eigenvector);
    }

    // Build P matrix (columns are eigenvectors)
    final List<List<double>> pRows = List<List<double>>.generate(
      n,
      (int r) => List<double>.generate(
        n,
        (int c) => pColumns[c][r],
        growable: false,
      ),
      growable: false,
    );

    return Diagonalization(p: Matrix(pRows), d: Matrix(dRows));
  }

  Matrix trace() {
    _requireSquare(operation: 'trace');

    double sum = 0;
    for (int i = 0; i < rowCount; i++) {
      sum += _rows[i][i];
    }
    return Matrix.scalar(sum);
  }

  Matrix frobeniusNorm() {
    double sum = 0;
    for (int r = 0; r < rowCount; r++) {
      for (int c = 0; c < columnCount; c++) {
        sum += _rows[r][c] * _rows[r][c];
      }
    }
    return Matrix.scalar(math.sqrt(sum));
  }

  Matrix rank({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    final int m = rowCount;
    final int n = columnCount;

    // Row reduce a copy with partial pivoting
    final List<List<double>> work = List<List<double>>.generate(
      m,
      (int r) => List<double>.from(_rows[r]),
      growable: false,
    );

    int pivotRow = 0;
    for (int col = 0; col < n && pivotRow < m; col++) {
      // Find pivot
      int maxRow = pivotRow;
      double maxVal = work[pivotRow][col].abs();
      for (int r = pivotRow + 1; r < m; r++) {
        if (work[r][col].abs() > maxVal) {
          maxVal = work[r][col].abs();
          maxRow = r;
        }
      }

      if (maxVal <= absoluteTolerance) {
        continue;
      }

      // Swap
      if (maxRow != pivotRow) {
        final List<double> temp = work[pivotRow];
        work[pivotRow] = work[maxRow];
        work[maxRow] = temp;
      }

      // Eliminate below
      final double pivot = work[pivotRow][col];
      for (int r = pivotRow + 1; r < m; r++) {
        final double factor = work[r][col] / pivot;
        if (factor.abs() <= absoluteTolerance) continue;
        for (int c = col; c < n; c++) {
          work[r][c] -= factor * work[pivotRow][c];
        }
      }

      pivotRow++;
    }

    return Matrix.scalar(pivotRow.toDouble());
  }

  Matrix minor(int row, int column) {
    _requireSquare(operation: 'minor');

    if (rowCount < 2) {
      throw MatrixShapeError(
        'Minor requires at least a 2x2 matrix.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    final int n = rowCount;
    final List<List<double>> result = <List<double>>[];

    for (int r = 0; r < n; r++) {
      if (r == row) continue;
      final List<double> newRow = <double>[];
      for (int c = 0; c < n; c++) {
        if (c == column) continue;
        newRow.add(_rows[r][c]);
      }
      result.add(newRow);
    }

    return Matrix(result);
  }

  Matrix cofactor(int row, int column) {
    _requireSquare(operation: 'cofactor');

    final Matrix minorMatrix = minor(row, column);
    final double det = minorMatrix.determinant().scalarValue;
    final double sign = (row + column).isEven ? 1 : -1;
    return Matrix.scalar(sign * det);
  }

  Matrix cofactorMatrix() {
    _requireSquare(operation: 'cofactor matrix');

    final int n = rowCount;
    final List<List<double>> result = List<List<double>>.generate(
      n,
      (int r) => List<double>.generate(
        n,
        (int c) {
          final Matrix minorMatrix = minor(r, c);
          final double det = minorMatrix.determinant().scalarValue;
          final double sign = (r + c).isEven ? 1 : -1;
          return sign * det;
        },
        growable: false,
      ),
      growable: false,
    );

    return Matrix(result);
  }

  Matrix adjugate() {
    _requireSquare(operation: 'adjugate');

    return cofactorMatrix().transpose();
  }

  /// Returns the dot product of two column vectors: Aᵀ · B.
  ///
  /// Both `this` and [other] must be column vectors (n×1) of the same dimension.
  /// The result is a 1×1 scalar matrix.
  Matrix dot(Matrix other) {
    if (columnCount != 1) {
      throw MatrixShapeError(
        'dot product requires a column vector (n×1), '
        'got ${rowCount}×$columnCount',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
    if (other.columnCount != 1) {
      throw MatrixShapeError(
        'dot product requires a column vector (n×1), '
        'got ${other.rowCount}×${other.columnCount}',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
    if (rowCount != other.rowCount) {
      throw MatrixShapeError(
        'dot product requires vectors of the same dimension, '
        'got ${rowCount}×1 and ${other.rowCount}×1',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    double sum = 0;
    for (int i = 0; i < rowCount; i++) {
      sum += _rows[i][0] * other._rows[i][0];
    }
    return Matrix.scalar(sum);
  }

  /// Returns the cross product of two 3×1 column vectors: skew(A) · B.
  ///
  /// Both `this` and [other] must be 3×1 column vectors.
  /// The result is a 3×1 column vector.
  Matrix cross(Matrix other) {
    if (columnCount != 1 || rowCount != 3) {
      throw MatrixShapeError(
        'cross product requires a 3×1 column vector, '
        'got ${rowCount}×$columnCount',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
    if (other.columnCount != 1 || other.rowCount != 3) {
      throw MatrixShapeError(
        'cross product requires a 3×1 column vector, '
        'got ${other.rowCount}×${other.columnCount}',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    final double x = _rows[0][0];
    final double y = _rows[1][0];
    final double z = _rows[2][0];

    // skew(A) · B where skew = [[0, -z, y], [z, 0, -x], [-y, x, 0]]
    final double bx = other._rows[0][0];
    final double by = other._rows[1][0];
    final double bz = other._rows[2][0];

    return Matrix(<List<double>>[
      <double>[-z * by + y * bz],
      <double>[z * bx - x * bz],
      <double>[-y * bx + x * by],
    ]);
  }

  /// Returns the Reduced Row Echelon Form (RREF) of this matrix using
  /// Gaussian elimination with partial pivoting and back-substitution.
  ///
  /// Works for any m×n matrix. Pivot columns get leading 1s with zeros
  /// above and below.
  Matrix rref({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    final int m = rowCount;
    final int n = columnCount;
    // Mutable working copy.
    final List<List<double>> rows = <List<double>>[
      for (final List<double> r in _rows) List<double>.of(r),
    ];

    int pivotRow = 0;
    for (int col = 0; col < n && pivotRow < m; col++) {
      // Partial pivot: find row with largest absolute value in this column.
      int maxRow = pivotRow;
      double maxVal = rows[pivotRow][col].abs();
      for (int r = pivotRow + 1; r < m; r++) {
        final double val = rows[r][col].abs();
        if (val > maxVal) {
          maxVal = val;
          maxRow = r;
        }
      }

      if (maxVal < absoluteTolerance) continue; // Skip zero column.

      // Swap rows.
      if (maxRow != pivotRow) {
        final List<double> temp = rows[pivotRow];
        rows[pivotRow] = rows[maxRow];
        rows[maxRow] = temp;
      }

      // Scale pivot row so leading entry is 1.
      final double pivot = rows[pivotRow][col];
      for (int j = 0; j < n; j++) {
        rows[pivotRow][j] /= pivot;
      }

      // Eliminate all other entries in this column.
      for (int r = 0; r < m; r++) {
        if (r == pivotRow) continue;
        final double factor = rows[r][col];
        if (factor.abs() < absoluteTolerance) continue;
        for (int j = 0; j < n; j++) {
          rows[r][j] -= factor * rows[pivotRow][j];
        }
      }

      pivotRow++;
    }

    // Clean near-zero entries.
    for (int r = 0; r < m; r++) {
      for (int c = 0; c < n; c++) {
        if (rows[r][c].abs() < absoluteTolerance) rows[r][c] = 0;
      }
    }

    return Matrix(rows);
  }

  /// Returns the spectral norm (induced 2-norm) of this matrix: ‖A‖₂ = σ_max.
  ///
  /// Computed as sqrt of the largest eigenvalue of AᵀA. Works for any m×n
  /// matrix.
  Matrix spectralNorm({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    final Matrix ata = transpose() * this;
    final Matrix eigs = ata.eigenvalues(absoluteTolerance: absoluteTolerance);
    double maxEig = 0;
    for (int i = 0; i < eigs.rowCount; i++) {
      final double val = eigs.at(i, 0).abs();
      if (val > maxEig) maxEig = val;
    }
    return Matrix.scalar(math.sqrt(maxEig));
  }

  /// Reduces the matrix to upper Hessenberg form using Householder reflections.
  List<List<double>> _toHessenberg(double absoluteTolerance) {
    final int n = rowCount;
    final List<List<double>> h = List<List<double>>.generate(
      n,
      (int row) => List<double>.from(_rows[row]),
      growable: false,
    );

    for (int k = 0; k < n - 2; k++) {
      // Build Householder vector for column k, rows k+1..n-1
      final int m = n - k - 1;
      final List<double> x = List<double>.generate(
        m,
        (int i) => h[k + 1 + i][k],
        growable: false,
      );

      double norm = 0;
      for (int i = 0; i < m; i++) {
        norm += x[i] * x[i];
      }
      norm = math.sqrt(norm);

      if (norm <= absoluteTolerance) {
        continue;
      }

      final double sign = x[0] >= 0 ? 1 : -1;
      x[0] += sign * norm;

      // Normalize the Householder vector
      double vNorm = 0;
      for (int i = 0; i < m; i++) {
        vNorm += x[i] * x[i];
      }
      vNorm = math.sqrt(vNorm);
      for (int i = 0; i < m; i++) {
        x[i] /= vNorm;
      }

      // Apply H from the left: H[k+1:n, k:n] -= 2*v*(v^T * H[k+1:n, k:n])
      for (int j = k; j < n; j++) {
        double dot = 0;
        for (int i = 0; i < m; i++) {
          dot += x[i] * h[k + 1 + i][j];
        }
        for (int i = 0; i < m; i++) {
          h[k + 1 + i][j] -= 2 * x[i] * dot;
        }
      }

      // Apply H from the right: H[0:n, k+1:n] -= 2*(H[0:n, k+1:n]*v)*v^T
      for (int i = 0; i < n; i++) {
        double dot = 0;
        for (int j = 0; j < m; j++) {
          dot += h[i][k + 1 + j] * x[j];
        }
        for (int j = 0; j < m; j++) {
          h[i][k + 1 + j] -= 2 * dot * x[j];
        }
      }
    }

    // Clean up sub-subdiagonal entries
    for (int i = 2; i < n; i++) {
      for (int j = 0; j < i - 1; j++) {
        if (h[i][j].abs() <= absoluteTolerance) {
          h[i][j] = 0;
        }
      }
    }

    return h;
  }

  /// Cancellation-resistant real-eigenvalue solver for a 2x2 block with
  /// characteristic polynomial lambda^2 - trace*lambda + det = 0.
  ///
  /// Two numerical hazards are handled deliberately:
  ///
  /// - Classifying the discriminant as zero (a repeated real root) rather
  ///   than negative (a complex-conjugate pair) by comparing it against a
  ///   *fixed* absolute tolerance is wrong at any matrix scale other than
  ///   the one the tolerance happened to be tuned for: a block with tiny
  ///   entries (e.g. all O(1e-8)) has a discriminant that is itself tiny
  ///   even when it is genuinely, unambiguously negative, so an absolute
  ///   floor like 1e-12 clamps it to 0 and manufactures a spurious
  ///   repeated real eigenvalue. Comparing the discriminant's magnitude to
  ///   `eps * (trace^2 + |det|)` instead scales the zero test to the
  ///   block's own magnitude.
  /// - Computing both roots as `(trace +/- sqrt(disc)) / 2` subtracts two
  ///   nearly-equal quantities whenever the block has one eigenvalue much
  ///   larger than the other (sqrt(disc) is then close to |trace|), which
  ///   erases the smaller root to rounding noise. The standard stable
  ///   quadratic formula avoids this: pick the root `q` that adds
  ///   same-signed terms (so it never cancels), then recover the other
  ///   root as `det / q`, a plain division that carries no cancellation
  ///   error of its own.
  static ({bool isComplex, double lambda1, double lambda2})
  _stableRealEigen2x2(double a, double b, double c, double d) {
    final double trace = a + d;
    final double det = (a * d) - (b * c);
    final double discriminant = (trace * trace) - (4 * det);

    const double eps =
        CalculatrixNumericPolicy.eigenvalueRoundingNoiseTolerance;
    final double scale = (trace * trace) + det.abs();
    final bool isZeroDiscriminant =
        scale == 0 ? discriminant == 0 : discriminant.abs() <= eps * scale;

    if (!isZeroDiscriminant && discriminant < 0) {
      return (isComplex: true, lambda1: 0, lambda2: 0);
    }

    if (isZeroDiscriminant) {
      final double repeated = trace / 2;
      return (isComplex: false, lambda1: repeated, lambda2: repeated);
    }

    final double sqrtD = math.sqrt(discriminant);
    // Characteristic polynomial in standard form a*x^2 + b*x + c with
    // a = 1, b = -trace, c = det.
    final double bCoefficient = -trace;
    final double signB = bCoefficient >= 0 ? 1.0 : -1.0;
    final double q = -(bCoefficient + (signB * sqrtD)) / 2;
    final double lambda1 = q;
    final double lambda2 = q == 0 ? 0 : det / q;
    return (isComplex: false, lambda1: lambda1, lambda2: lambda2);
  }

  /// Solves the eigenvalues of a 2x2 block and adds them to the list.
  /// Throws MatrixDomainError if the eigenvalues are complex.
  static void _solve2x2Block(
    double a,
    double b,
    double c,
    double d,
    List<double> eigenvaluesList,
    double absoluteTolerance,
  ) {
    final ({bool isComplex, double lambda1, double lambda2}) result =
        _stableRealEigen2x2(a, b, c, d);

    if (result.isComplex) {
      throw MatrixDomainError(
        'Eigenvalues are undefined in the real domain for this matrix.',
      );
    }

    eigenvaluesList.add(result.lambda1);
    eigenvaluesList.add(result.lambda2);
  }

  /// Solves the eigenvalues of a 2x2 block and adds them to the list, only
  /// when they are real. A block with a negative discriminant is a genuine
  /// complex-conjugate pair and simply contributes nothing to the list,
  /// rather than throwing: used where a complex pair elsewhere in the
  /// spectrum must not by itself disqualify the real eigenvalues found in
  /// other blocks (see [_realEigenvaluesIgnoringComplexPairs]).
  static void _solve2x2BlockIgnoringComplexPairs(
    double a,
    double b,
    double c,
    double d,
    List<double> realEigenvaluesList,
    double absoluteTolerance,
  ) {
    final ({bool isComplex, double lambda1, double lambda2}) result =
        _stableRealEigen2x2(a, b, c, d);

    if (result.isComplex) {
      return;
    }

    realEigenvaluesList.add(result.lambda1);
    realEigenvaluesList.add(result.lambda2);
  }

  /// Computes the Wilkinson shift from a trailing 2x2 block.
  static double _wilkinsonShift(
    double a,
    double b,
    double c,
    double d,
  ) {
    final double trace = a + d;
    final double det = (a * d) - (b * c);
    final double discriminant = (trace * trace) - (4 * det);

    if (discriminant < 0) {
      // Complex eigenvalues in the 2x2 block — use the diagonal entry
      return d;
    }

    final double sqrtD = math.sqrt(discriminant);
    final double lambda1 = (trace + sqrtD) / 2;
    final double lambda2 = (trace - sqrtD) / 2;

    // Pick the eigenvalue closest to d
    return (lambda1 - d).abs() < (lambda2 - d).abs() ? lambda1 : lambda2;
  }

  /// Performs one QR step using Givens rotations on the upper Hessenberg
  /// matrix h (operating on the top-left size x size submatrix).
  static void _qrStepGivens(
    List<List<double>> h,
    int size,
    double absoluteTolerance,
  ) {
    // Store Givens rotation parameters
    final List<double> cosines = List<double>.filled(size - 1, 0);
    final List<double> sines = List<double>.filled(size - 1, 0);

    // Apply Givens rotations from left to zero subdiagonal (Q^T * H = R)
    for (int i = 0; i < size - 1; i++) {
      final double x = h[i][i];
      final double y = h[i + 1][i];
      final double r = math.sqrt(x * x + y * y);

      if (r <= absoluteTolerance) {
        cosines[i] = 1;
        sines[i] = 0;
        continue;
      }

      final double cos = x / r;
      final double sin = y / r;
      cosines[i] = cos;
      sines[i] = sin;

      // Apply G(i, i+1, theta)^T to rows i and i+1
      for (int j = i; j < size; j++) {
        final double hi = h[i][j];
        final double hi1 = h[i + 1][j];
        h[i][j] = cos * hi + sin * hi1;
        h[i + 1][j] = -sin * hi + cos * hi1;
      }
    }

    // Apply Givens rotations from right (R * Q)
    for (int i = 0; i < size - 1; i++) {
      final double cos = cosines[i];
      final double sin = sines[i];

      // Apply G(i, i+1, theta) to columns i and i+1
      for (int j = 0; j <= math.min(i + 2, size - 1); j++) {
        final double hj = h[j][i];
        final double hj1 = h[j][i + 1];
        h[j][i] = cos * hj + sin * hj1;
        h[j][i + 1] = -sin * hj + cos * hj1;
      }
    }

    // Clean near-zero subdiagonal entries
    for (int i = 0; i < size - 1; i++) {
      if (h[i + 1][i].abs() <= absoluteTolerance) {
        h[i + 1][i] = 0;
      }
    }
  }


  LuDecomposition luDecomposition({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    _requireSquare(operation: 'LU decomposition');

    final int size = rowCount;
    final List<List<double>> permutation = List<List<double>>.generate(
      size,
      (int row) => List<double>.generate(
        size,
        (int column) => row == column ? 1 : 0,
        growable: false,
      ),
      growable: false,
    );
    final List<List<double>> lower = List<List<double>>.generate(
      size,
      (int row) => List<double>.generate(
        size,
        (int column) => row == column ? 1 : 0,
        growable: false,
      ),
      growable: false,
    );
    final List<List<double>> upper = List<List<double>>.generate(
      size,
      (int row) => List<double>.from(_rows[row]),
      growable: false,
    );

    for (int pivotColumn = 0; pivotColumn < size; pivotColumn++) {
      int pivotRow = pivotColumn;
      double pivotMagnitude = upper[pivotRow][pivotColumn].abs();

      for (int row = pivotColumn + 1; row < size; row++) {
        final double candidateMagnitude = upper[row][pivotColumn].abs();
        if (candidateMagnitude > pivotMagnitude) {
          pivotMagnitude = candidateMagnitude;
          pivotRow = row;
        }
      }

      if (pivotRow != pivotColumn) {
        final List<double> upperTemp = upper[pivotColumn];
        upper[pivotColumn] = upper[pivotRow];
        upper[pivotRow] = upperTemp;

        final List<double> permutationTemp = permutation[pivotColumn];
        permutation[pivotColumn] = permutation[pivotRow];
        permutation[pivotRow] = permutationTemp;

        for (int column = 0; column < pivotColumn; column++) {
          final double lowerTemp = lower[pivotColumn][column];
          lower[pivotColumn][column] = lower[pivotRow][column];
          lower[pivotRow][column] = lowerTemp;
        }
      }

      final double pivot = upper[pivotColumn][pivotColumn];
      if (pivot.abs() <= absoluteTolerance) {
        continue;
      }

      for (int row = pivotColumn + 1; row < size; row++) {
        final double factor = upper[row][pivotColumn] / pivot;
        lower[row][pivotColumn] = factor.abs() <= absoluteTolerance
            ? 0
            : factor;
        upper[row][pivotColumn] = 0;

        for (int column = pivotColumn + 1; column < size; column++) {
          final double nextValue =
              upper[row][column] - (factor * upper[pivotColumn][column]);
          upper[row][column] = nextValue.abs() <= absoluteTolerance
              ? 0
              : nextValue;
        }
      }
    }

    return LuDecomposition(
      permutation: Matrix(permutation),
      lower: Matrix(lower),
      upper: Matrix(upper),
    );
  }

  QrDecomposition qrDecomposition({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    if (rowCount < columnCount) {
      throw MatrixShapeError(
        'QR decomposition requires row count >= column count, found '
        '${rowCount}x${columnCount}.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    double dotProduct(List<double> left, List<double> right) {
      double sum = 0;
      for (int index = 0; index < left.length; index++) {
        sum += left[index] * right[index];
      }
      return sum;
    }

    final int m = rowCount;
    final int n = columnCount;
    final List<List<double>> qColumns = List<List<double>>.generate(
      n,
      (_) => List<double>.filled(m, 0, growable: false),
      growable: false,
    );
    final List<List<double>> r = List<List<double>>.generate(
      n,
      (_) => List<double>.filled(n, 0, growable: false),
      growable: false,
    );

    for (int column = 0; column < n; column++) {
      final List<double> vector = List<double>.generate(
        m,
        (int row) => _rows[row][column],
        growable: false,
      );

      for (int basis = 0; basis < column; basis++) {
        final double projection = dotProduct(qColumns[basis], vector);
        r[basis][column] = projection.abs() <= absoluteTolerance
            ? 0
            : projection;

        for (int row = 0; row < m; row++) {
          final double nextValue =
              vector[row] - (projection * qColumns[basis][row]);
          vector[row] = nextValue.abs() <= absoluteTolerance ? 0 : nextValue;
        }
      }

      final double norm = math.sqrt(dotProduct(vector, vector));
      r[column][column] = norm.abs() <= absoluteTolerance ? 0 : norm;
      if (norm <= absoluteTolerance) {
        continue;
      }

      for (int row = 0; row < m; row++) {
        final double normalized = vector[row] / norm;
        qColumns[column][row] = normalized.abs() <= absoluteTolerance
            ? 0
            : normalized;
      }
    }

    final List<List<double>> q = List<List<double>>.generate(
      m,
      (int row) => List<double>.generate(
        n,
        (int column) => qColumns[column][row],
        growable: false,
      ),
      growable: false,
    );

    return QrDecomposition(q: Matrix(q), r: Matrix(r));
  }

  Matrix sqrt({
    double relativeTolerance =
        CalculatrixNumericPolicy.defaultRelativeTolerance,
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
    int maxIterations = 64,
  }) {
    _requireSquare(operation: 'square root');
    _checkFiniteMatrix(this);

    if (isScalar) {
      final double source = scalarValue;
      if (source < 0) {
        return Matrix.i.scale(math.sqrt(-source));
      }
      return Matrix.scalar(math.sqrt(source));
    }

    // Exact-diagonal fast path: for a diagonal matrix, sqrt decouples into
    // an independent scalar Newton sqrt per diagonal entry (dart:math's
    // math.sqrt, exact to the last ULP), so there is no coupling between
    // entries and therefore no need to run — or to devise a convergence
    // test for — the general Denman-Beavers Newton iteration below at all.
    // This matters specifically for a diagonal matrix whose entries span
    // many orders of magnitude (e.g. diag(1, 1e20)): the general loop's
    // uniform matrix-wide scaling step (scaling every entry by the same
    // power of 4 to bring the whole matrix's norm under control) leaves
    // the *smallest* entry's target value many orders of magnitude below
    // the largest, and no single norm-based or even entrywise-relative
    // convergence test reliably captures that every entry has actually
    // converged without either being fooled by the dominant entry or
    // becoming unreachable for the tiny one. Computing each entry's sqrt
    // directly sidesteps the problem rather than working around it.
    if (_isExactlyDiagonal()) {
      final List<List<double>> resultRows = List<List<double>>.generate(
        rowCount,
        (int r) => List<double>.generate(
          columnCount,
          (int c) {
            if (r != c) return 0.0;
            final double value = _rows[r][c];
            if (value < 0) {
              throw MatrixDomainError(
                'Square root is undefined for this matrix in the real '
                'domain.',
              );
            }
            return math.sqrt(value);
          },
          growable: false,
        ),
        growable: false,
      );
      return _checkFiniteMatrix(Matrix(resultRows));
    }

    final double norm = _infinityNorm();
    if (norm == 0) {
      return Matrix(
        List<List<double>>.generate(
          rowCount,
          (_) => List<double>.filled(columnCount, 0, growable: false),
          growable: false,
        ),
      );
    }

    // Exact-triangular fast path (round 5 correction): the Bjorck and
    // Hammarling recurrence (Higham 2008, Algorithm 6.3) solves `S*S = T`
    // for an upper triangular `T` in closed form — the diagonal exactly as
    // `sqrt(T[i][i])`, then each off-diagonal entry from a single division,
    // by increasing distance from the diagonal — with no iteration, no
    // convergence tolerance, and therefore none of the scaling/Newton
    // machinery below. A lower triangular input is solved via its
    // transpose (`sqrt(Aᵀ) = sqrt(A)ᵀ` for a real matrix), since the
    // recurrence itself is only stated for the upper form. This is tried
    // only for a non-diagonal triangular matrix; the diagonal case above
    // already has its own simpler, decoupled fast path.
    if (_isExactlyTriangular() && !_isExactlyDiagonal()) {
      return _checkFiniteMatrix(_triangularSqrt());
    }

    final bool inputIsSymmetric = _isApproximatelySymmetric();

    // Real-eigenvalue fast path (round 5 correction: generalized from a
    // symmetric-only gate). For any real matrix diagonalizable over the
    // reals, `A = P*D*P^-1` gives `sqrt(A) = P*diag(sqrt(d_i))*P^-1`
    // directly. [diagonalization] itself already rejects a matrix with any
    // genuine complex-conjugate eigenvalue pair (via the existing typed
    // domain error from the eigenvalue pipeline), so this never
    // approximates a complex spectrum — it simply cannot be attempted for
    // one, and falls through to the Newton loop below, which raises its
    // own `no-convergence` if that loop cannot find a real root either.
    // For a symmetric matrix `P` is orthogonal, so `P^T` is used in place
    // of an explicit (costlier, less accurate) inverse; for a
    // non-symmetric matrix, `P^-1` is computed directly. Either way the
    // result is verified against the same residual check the Newton loop
    // uses below before being trusted.
    //
    // Scope note (documented simplification, per the standing brief's
    // escape valve): the prescribed general algorithm is the real Schur
    // form plus the Bjorck-Hammarling/Parlett recurrences run on the
    // (quasi-triangular) Schur form itself. This codebase's QR eigenvalue
    // step extracts eigenvalues only — it does not accumulate the
    // orthogonal Schur-vector matrix `Q` needed to form that Schur form,
    // and adding that accumulation is a substantial change to the
    // Hessenberg/QR pipeline shared by [eigenvalues]. Diagonalization is
    // used instead wherever it succeeds (identical for any
    // diagonalizable matrix, which is the overwhelming common case, and
    // the same reconstruction-residual gate that guards the symmetric
    // case already catches a genuinely defective/non-diagonalizable
    // input by refusing to trust an unverified result).
    final Matrix? realEigenSqrt = _tryRealEigenSqrt(
      relativeTolerance: relativeTolerance,
      absoluteTolerance: absoluteTolerance,
      symmetric: inputIsSymmetric,
    );
    if (realEigenSqrt != null) {
      return realEigenSqrt;
    }

    // Exact scale normalization (round 4 correction, rule 1): scale by
    // 2^-k for the k nearest log2(‖this‖), rather than repeatedly
    // quartering until the norm merely drops under an ad hoc threshold.
    // Both the Newton loop's own internal comparisons (via [_inverse]'s
    // pivot cutoff) and this method's own stepDeviation/residualDeviation
    // floors below are only sound once applied to a matrix of norm ~1 —
    // exactly what this guarantees regardless of `this`'s own scale, and
    // exactly (a power-of-two scale factor changes only a double's
    // exponent bits, never its mantissa).
    final ({int k, Matrix scaled}) normalization = _normalizedByPowerOfTwo();
    final Matrix scaledTarget = normalization.scaled;

    Matrix current = Matrix.identity(rowCount);
    double bestResidualDeviation = double.infinity;
    Matrix bestCandidate = current;

    for (int iteration = 0; iteration < maxIterations; iteration++) {
      final Matrix inverseCurrent;
      try {
        inverseCurrent = current._inverse(absoluteTolerance: absoluteTolerance);
      } on MatrixDomainError {
        // A singular (or numerically indistinguishable from singular)
        // intermediate iterate does not, by itself, mean the true square
        // root does not exist or was not already well approximated: for a
        // genuinely ill-conditioned input (e.g. condition ~2.5e7), the
        // Newton map X <- 0.5*(X + X^-1*A) can lose symmetry to rounding
        // error after enough iterations and diverge in magnitude well
        // *after* passing arbitrarily close to the true root — the best
        // iterate seen so far (tracked below) is very likely already a
        // numerically correct answer at that point. So this stops the
        // loop and falls through to the same best-candidate acceptance
        // check used when the iteration budget is exhausted, rather than
        // discarding a good earlier iterate just because a later one blew
        // up; only if no iterate ever got close enough does that check
        // fall through to the genuine "did not converge" error below.
        break;
      }

      Matrix next = (current + (inverseCurrent * scaledTarget)).scale(0.5);
      if (inputIsSymmetric) {
        next = (next + next.transpose()).scale(0.5);
      }

      // Norm-relative, not entrywise: this general loop only ever runs on
      // a genuinely coupled (non-diagonal) matrix now that the diagonal
      // case is handled above, and for such a matrix the Newton iteration
      // X <- 0.5*(X + X^-1*A) amplifies rounding error by roughly the
      // matrix's own condition number. Demanding an entrywise-relative
      // deviation as tight as [relativeTolerance] (1e-10 by default) is
      // provably unreachable once condition * machine-epsilon exceeds it
      // — e.g. a symmetric positive-definite matrix with condition number
      // ~2.5e7 already limits the achievable relative accuracy to roughly
      // 2.5e7 * 2.22e-16 =~ 5.5e-9, comfortably above 1e-10.
      //
      // The loop deliberately does not try to detect a convergence
      // "plateau" and stop early: Newton's method for a matrix/scalar far
      // from its own scale (e.g. a target eigenvalue of 1e-20 starting
      // from the identity's eigenvalue of 1) spends its first several
      // iterations in a linear-convergence descent phase where the step
      // size stays roughly *constant* (it keeps roughly halving the
      // distance-to-target, not the absolute step) before quadratic
      // convergence takes over near the root — a naive "step stopped
      // shrinking" test fires immediately during that phase and cuts the
      // iteration off long before it has actually converged. Instead,
      // every iterate's residual is tracked and the best one seen across
      // the whole run — never just whichever happened to be last — is
      // what gets checked for acceptance below.
      final double stepDeviation =
          (next - current)._infinityNorm() /
          math.max(current._infinityNorm(), absoluteTolerance);
      final double residualDeviation =
          (next * next - scaledTarget)._infinityNorm() /
          math.max(scaledTarget._infinityNorm(), absoluteTolerance);

      if (residualDeviation < bestResidualDeviation) {
        bestResidualDeviation = residualDeviation;
        bestCandidate = next;
      }

      current = next;

      // Round 5 correction: this used to break out of the loop as soon as
      // both deviations first dropped under [relativeTolerance] (1e-10 by
      // default). That contradicted the very comment above it — Newton's
      // method keeps converging quadratically well past that point for a
      // well-conditioned input, so stopping the instant it is merely
      // "good enough" threw away a lot of free accuracy: the loop is
      // already bounded at a fixed [maxIterations] (data-independent), and
      // [bestCandidate]/[bestResidualDeviation] above already track the
      // best iterate seen across the *entire* run, so simply letting every
      // iteration run costs nothing extra in correctness and only helps
      // precision. A well-conditioned input converges to the entrywise
      // residual floor (double precision) within a handful more
      // iterations after crossing 1e-10; an ill-conditioned one is caught
      // either by the `on MatrixDomainError` break above once `current`
      // goes singular, or simply never improves on [bestCandidate] and the
      // acceptance check below reports it honestly.
      if (stepDeviation == 0 && residualDeviation == 0) {
        break;
      }
    }

    // The acceptance floor is the *looser* of the caller's own
    // [relativeTolerance] and [CalculatrixNumericPolicy.
    // sqrtResidualAcceptanceTolerance]: a well-conditioned input already
    // converges far tighter than either, so this never loosens what such
    // an input actually achieves; it only stops an ill-conditioned-but-
    // genuinely-real-square-rootable input from being rejected merely for
    // not reaching a precision double-precision arithmetic cannot deliver
    // for it (see the doc comment above).
    final double acceptanceTolerance = math.max(
      relativeTolerance,
      CalculatrixNumericPolicy.sqrtResidualAcceptanceTolerance,
    );

    if (bestResidualDeviation <= acceptanceTolerance) {
      return _checkFiniteMatrix(
        _scaleByPowerOfTwo(bestCandidate, normalization.k / 2.0),
      );
    }

    throw MatrixDomainError(
      'Square root did not converge for this matrix in the real domain.',
      errorId: CalculatrixErrorId.noConvergence,
    );
  }

  /// Computes the matrix exponential.
  ///
  /// Cases, tried in order:
  ///
  /// - Complex-form input (`aI + bJ`, 2x2 only): the closed form
  ///   `e^a * (cos(b)*I + sin(b)*J)` — no series at all, so `cos`/`sin`
  ///   (always bounded in `[-1, 1]`) can never blow up the way a
  ///   scaling-and-squaring series does for a huge `b` (e.g. a rotation by
  ///   `1e16` radians): repeated squaring of an only-approximately-bounded
  ///   intermediate compounds rounding error exponentially.
  /// - An exact scalar multiple of the identity (`aI`, any size): `e^a * I`
  ///   directly — exact, and needed for `n != 2` since [isComplexForm] only
  ///   ever applies to 2x2 matrices.
  /// - Exactly diagonal: `exp` decouples entrywise, exact to the last ULP
  ///   per entry (`math.exp`), same rationale as [sqrt]'s own diagonal fast
  ///   path — a matrix whose entries span many orders of magnitude (e.g.
  ///   `diag(-1000, -500)`) has no single scaling-and-squaring parameter
  ///   that serves every entry well simultaneously.
  /// - Otherwise (round 5 correction): scaling and squaring with the
  ///   degree-13 Padé approximant (Higham, "The Scaling and Squaring
  ///   Method for the Matrix Exponential Revisited", SIAM J. Matrix Anal.
  ///   Appl., 2005) — see [_expByPadeScalingAndSquaring] for the algorithm
  ///   itself. This replaces the previous trace-shift-plus-Taylor-series
  ///   approach entirely: a fixed-degree Padé approximant needs no
  ///   caller-tunable convergence tolerance or term-count budget at all,
  ///   and its accuracy is provably uniform across scales once the
  ///   pre-squaring norm is brought under the Higham `theta_13` threshold,
  ///   unlike a Taylor series' term count, which would have to grow
  ///   without bound to hold accuracy for some inputs no matter how
  ///   aggressively pre-scaled.
  ///   - If this matrix is also exactly triangular (including diagonal,
  ///     though that case is already handled above), [_correctTriangularExp]
  ///     overwrites the Padé result's diagonal with the exact `exp(t_ii)`
  ///     and its first superdiagonal with the Al-Mohy and Higham divided-
  ///     difference formula (Al-Mohy and Higham, "Computing the Frechet
  ///     Derivative of the Matrix Exponential, with an Application to
  ///     Condition Number Estimation", 2009) — both closed-form, so neither
  ///     carries any scaling-and-squaring rounding at all. Round 5
  ///     correction, per the standing brief: no entry beyond the first
  ///     superdiagonal is corrected (that would need the full Parlett-style
  ///     triangular recurrence [log] uses, which does not have a clean
  ///     divided-difference closed form for the exponential of an arbitrary
  ///     interior entry the way it does for `log`) — documented scope
  ///     limitation.
  ///
  /// Every matrix/scalar involved is checked finite before it is used in a
  /// loop, and the scaling loop itself carries an explicit iteration bound
  /// independent of the data.
  Matrix exp({
    @Deprecated(
      'Unused since round 5: the degree-13 Pade approximant needs no '
      'caller-tunable convergence tolerance (Higham 2005).',
    )
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    _requireSquare(operation: 'exponential');
    _checkFiniteMatrix(this);

    if (isScalar) {
      return Matrix.scalar(_checkFiniteScalar(math.exp(scalarValue)));
    }

    if (isComplexForm) {
      final double a = realPart;
      final double b = imagPart;
      final double magnitude = _checkFiniteScalar(math.exp(a));
      return _checkFiniteMatrix(
        Matrix.complex(magnitude * math.cos(b), magnitude * math.sin(b)),
      );
    }

    final double? scalarMultiple = _asScalarMultipleOfIdentity();
    if (scalarMultiple != null) {
      return Matrix.identity(rowCount).scale(
        _checkFiniteScalar(math.exp(scalarMultiple)),
      );
    }

    if (_isExactlyDiagonal()) {
      final List<List<double>> resultRows = List<List<double>>.generate(
        rowCount,
        (int r) => List<double>.generate(
          columnCount,
          (int c) => r == c ? _checkFiniteScalar(math.exp(_rows[r][c])) : 0,
          growable: false,
        ),
        growable: false,
      );
      return Matrix(resultRows);
    }

    final Matrix padeResult = _expByPadeScalingAndSquaring();

    if (_isExactlyTriangular()) {
      return _checkFiniteMatrix(_correctTriangularExp(padeResult));
    }

    return padeResult;
  }

  /// Degree-13 Padé approximant, scaling-and-squaring implementation of
  /// [exp] (Higham 2005). If `‖A‖ > theta_13`, `A` is first scaled by
  /// `2^-s` (via the bounded-step [_scaleByPowerOfTwo], round 5 correction
  /// case 6) for the smallest `s` bringing the scaled norm at or under
  /// `theta_13 = 5.371920351148152` (Higham 2005, Table 3.1 — the largest
  /// norm for which the degree-13 approximant alone already meets double
  /// precision, with no further scaling needed); the degree-13 rational
  /// approximant `R13(A) = Q13(A)^-1 * P13(A)` is then formed via
  /// [_pade13Terms] and, finally, squared `s` times to undo the scaling
  /// (`exp(A) = exp(A/2^s)^(2^s)`).
  ///
  /// The scaling-step count `s` is capped at a fixed, data-independent
  /// bound (1100 — comfortably above `log2(2^1024/theta_13)`, the largest
  /// `s` any finite double-precision norm can ever require): a norm large
  /// enough to need more than that is already outside representable double
  /// range or on its way there, and this raises `non-finite` rather than
  /// looping further.
  ///
  /// This codebase already computes every other scale-normalization
  /// decision ([sqrt], [log], [eigenvalues], [_inverse]) from the
  /// infinity norm rather than the 1-norm Higham's paper states the
  /// `theta_m` thresholds for; the two norms differ by at most a factor of
  /// `n` for an `n x n` matrix, so using the infinity norm here is a
  /// conservative approximation (it can only trigger scaling slightly
  /// earlier than strictly necessary, never later) consistent with the
  /// rest of this codebase's scale-normalization machinery.
  Matrix _expByPadeScalingAndSquaring() {
    const double theta13 = 5.371920351148152;
    const int maxScalingSteps = 1100;

    final double norm = _infinityNorm();
    if (!norm.isFinite) {
      throw MatrixDomainError(
        'Matrix infinity-norm overflowed to a non-finite value before '
        'scale normalization.',
        errorId: CalculatrixErrorId.nonFinite,
      );
    }

    int s = 0;
    Matrix scaled = this;
    if (norm > theta13) {
      s = (math.log(norm / theta13) / math.ln2).ceil();
      if (s > maxScalingSteps) {
        throw MatrixDomainError(
          'Matrix exponential scaling exceeded the maximum number of '
          'steps.',
          errorId: CalculatrixErrorId.nonFinite,
        );
      }
      scaled = _scaleByPowerOfTwo(this, -s.toDouble());
    }

    final ({Matrix u, Matrix v}) terms = _pade13Terms(scaled);
    final Matrix p13 = terms.u + terms.v;
    final Matrix q13 = terms.v - terms.u;

    Matrix result = q13._inverse() * p13;

    for (int i = 0; i < s; i++) {
      result = _checkFiniteMatrix(result * result);
    }

    return _checkFiniteMatrix(result);
  }

  /// The `U`, `V` terms of the degree-13 Padé numerator/denominator for
  /// [exp] (Higham 2005, Eq. 3.4, coefficients from Table 3.1):
  /// `P13(A) = U + V`, `Q13(A) = -U + V`, where
  ///
  /// ```
  /// U = A * (A6*(b13*A6 + b11*A4 + b9*A2) + b7*A6 + b5*A4 + b3*A2 + b1*I)
  /// V = A6*(b12*A6 + b10*A4 + b8*A2) + b6*A6 + b4*A4 + b2*A2 + b0*I
  /// ```
  ///
  /// with `A2 = A*A`, `A4 = A2*A2`, `A6 = A2*A4`, computed once and shared
  /// between `U` and `V` (six matrix multiplies total for both, instead of
  /// the naive 13 one per power).
  static ({Matrix u, Matrix v}) _pade13Terms(Matrix a) {
    const List<double> b = <double>[
      64764752532480000,
      32382376266240000,
      7771770303897600,
      1187353796428800,
      129060195264000,
      10559470521600,
      670442572800,
      33522128640,
      1323241920,
      40840800,
      960960,
      16380,
      182,
      1,
    ];

    final Matrix identity = Matrix.identity(a.rowCount);
    final Matrix a2 = a * a;
    final Matrix a4 = a2 * a2;
    final Matrix a6 = a2 * a4;

    final Matrix u =
        a *
        (a6 * (a6.scale(b[13]) + a4.scale(b[11]) + a2.scale(b[9])) +
            a6.scale(b[7]) +
            a4.scale(b[5]) +
            a2.scale(b[3]) +
            identity.scale(b[1]));
    final Matrix v =
        a6 * (a6.scale(b[12]) + a4.scale(b[10]) + a2.scale(b[8])) +
        a6.scale(b[6]) +
        a4.scale(b[4]) +
        a2.scale(b[2]) +
        identity.scale(b[0]);

    return (u: u, v: v);
  }

  /// The divided difference of `exp` at `a` and `b`:
  /// `(exp(a) - exp(b)) / (a - b)` when `a != b`, or `exp(a)` (the limit as
  /// `b -> a`) when `a == b`. Used by [_correctTriangularExp] for the
  /// closed-form first superdiagonal of a triangular matrix's exponential
  /// (Al-Mohy and Higham 2009).
  static double _expDividedDifference(double a, double b) {
    if (a == b) {
      return math.exp(a);
    }
    return (math.exp(a) - math.exp(b)) / (a - b);
  }

  /// Overwrites [padeResult]'s diagonal and first superdiagonal with the
  /// closed-form values for an exactly triangular matrix's exponential,
  /// leaving every other entry as the Padé scaling-and-squaring result —
  /// see [exp]'s own doc comment for why nothing past the first
  /// superdiagonal is corrected here. A lower triangular input is
  /// transposed in, corrected, and transposed back, matching
  /// [_triangularSqrt]/[_triangularLog].
  Matrix _correctTriangularExp(Matrix padeResult) {
    final bool upper = _isUpperTriangular();
    final Matrix triangular = upper ? this : transpose();
    final Matrix approx = upper ? padeResult : padeResult.transpose();
    final int n = triangular.rowCount;
    final List<List<double>> t = triangular._rows;

    final List<List<double>> f = List<List<double>>.generate(
      n,
      (int r) => List<double>.from(approx._rows[r]),
      growable: false,
    );

    for (int i = 0; i < n; i++) {
      f[i][i] = _checkFiniteScalar(math.exp(t[i][i]));
    }
    for (int i = 0; i + 1 < n; i++) {
      f[i][i + 1] =
          t[i][i + 1] * _expDividedDifference(t[i][i], t[i + 1][i + 1]);
    }

    final Matrix corrected = Matrix(f);
    return upper ? corrected : corrected.transpose();
  }

  /// Computes the principal matrix logarithm.
  ///
  /// Scalar domain:
  /// - log(x) for x > 0 returns scalar ln(x)
  /// - log(x) for x < 0 returns the complex-form matrix ln(|x|) + π·i
  /// - log(0) is undefined
  ///
  /// Complex-form 2x2 matrices use the principal branch:
  /// log(a + bi) = ln(r) + θ·i, where r = sqrt(a² + b²), θ = atan2(b, a)
  Matrix log({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
    double relativeTolerance =
        CalculatrixNumericPolicy.defaultRelativeTolerance,
  }) {
    _requireSquare(operation: 'logarithm');

    if (isScalar) {
      final double source = scalarValue;
      if (source == 0) {
        throw MatrixDomainError(
          'Logarithm is undefined for zero in the real domain.',
          errorId: CalculatrixErrorId.logUndefined,
        );
      }
      if (source > 0) {
        return Matrix.scalar(math.log(source));
      }
      return Matrix.complex(math.log(-source), math.pi);
    }

    if (isComplexForm) {
      final double a = realPart;
      final double b = imagPart;

      // Exact-zero check, not a tolerance comparison (round 4 correction,
      // rule 3): a fixed [absoluteTolerance] (1e-12 by default) wrongly
      // rejects a genuinely nonzero but tiny magnitude, such as a=1e-20,
      // b=0, as if it were zero. The magnitude itself is only ever exactly
      // zero when both parts are exactly zero.
      if (a == 0 && b == 0) {
        throw MatrixDomainError(
          'Logarithm is undefined for zero magnitude in the complex domain.',
          errorId: CalculatrixErrorId.logUndefined,
        );
      }

      // Hypot-style magnitude, not `sqrt(a*a+b*b)` (round 4 correction,
      // rule 3): squaring a merely-large `a` (e.g. 1e200) overflows to
      // `Infinity` well before the true magnitude does, silently poisoning
      // every downstream computation (including, previously, `exp`'s own
      // scaling loop, which could never terminate once fed an
      // infinite-norm matrix). `_hypot` factors out the larger magnitude
      // before squaring, so only the bounded ratio `min/max` is ever
      // squared.
      final double radius = _hypot(a, b);
      if (!radius.isFinite) {
        throw MatrixDomainError(
          'Logarithm magnitude overflowed to a non-finite value.',
          errorId: CalculatrixErrorId.nonFinite,
        );
      }

      final double angle = math.atan2(b, a);
      return Matrix.complex(math.log(radius), angle);
    }

    // Outside the scalar and complex-form (aI + bJ) subalgebras, the only
    // representable results are real matrices. The principal log exists as
    // long as no eigenvalue sits on the closed negative real axis, which for
    // a real matrix means: no real eigenvalue is non-positive. A genuine
    // complex-conjugate pair elsewhere in the spectrum never sits on the
    // real axis, so it does not by itself make the log undefined; this
    // deliberately does not attempt a general complex-eigenvalue extension
    // of the result (per the owner's decision: "the only complex
    // representation is a*I + b*J; do not add complex entries").
    //
    // Triangular matrices (including diagonal ones) get a dedicated,
    // tolerance-free path (round 5 correction: now computing the VALUE
    // directly via the Parlett recurrence, not just validating the
    // domain): their eigenvalues ARE their diagonal entries, exactly, by
    // definition of the characteristic polynomial of a triangular matrix
    // — no QR iteration, no discriminant, no rounding to second-guess.
    // This matters because no *fixed* tolerance can gate a diagonal entry
    // correctly at every scale: `eigenvalueRoundingNoiseTolerance`
    // (1e-14) would wrongly reject a genuinely positive diagonal entry as
    // small as 4e-16 or 1e-18, and no single fixed floor can be tight
    // enough for those yet loose enough for an O(1) matrix's own rounding
    // noise.
    if (_isExactlyTriangular()) {
      for (int i = 0; i < rowCount; i++) {
        if (_rows[i][i] <= 0) {
          throw MatrixDomainError(
            'Logarithm is undefined for matrices with non-positive real '
            'eigenvalues.',
            errorId: CalculatrixErrorId.logUndefined,
          );
        }
      }
      return _checkFiniteMatrix(_triangularLog());
    }

    final List<double> realEigenvalues = _realEigenvaluesIgnoringComplexPairs(
      absoluteTolerance: absoluteTolerance,
    );

    // For a non-triangular matrix, eigenvalues are *computed* (Hessenberg
    // reduction plus shifted QR, or the stable 2x2 quadratic formula), so
    // unlike the triangular case above they do carry rounding noise from
    // that pipeline and a real zero eigenvalue can come back as a tiny
    // nonzero double. The floor below is scale-relative (`8 * n * u *
    // ‖A‖∞`, u = double's unit roundoff, n = matrix size) rather than
    // fixed, so it tracks the matrix's own scale instead of rejecting
    // genuinely tiny-but-real eigenvalues (as a fixed floor like
    // eigenvalueRoundingNoiseTolerance did) or accepting rounding noise as
    // real for a huge-scale matrix.
    const double u = CalculatrixNumericPolicy.machineEpsilon;
    final double zeroFloor = 8 * rowCount * u * _infinityNorm();
    for (final double eigenvalue in realEigenvalues) {
      if (eigenvalue <= 0) {
        throw MatrixDomainError(
          'Logarithm is undefined for matrices with non-positive real '
          'eigenvalues.',
          errorId: CalculatrixErrorId.logUndefined,
        );
      }
      if (eigenvalue <= zeroFloor) {
        throw MatrixDomainError(
          'Logarithm is undefined because an eigenvalue is '
          'indistinguishable from zero at double precision.',
          errorId: CalculatrixErrorId.logUndefined,
        );
      }
    }

    // Real-eigenvalue fast path (round 5 correction), tried before the
    // general scaling-and-squaring loop: once every real eigenvalue is
    // already confirmed positive (above), a matrix diagonalizable over the
    // reals gives `log(A) = P*diag(log(d_i))*P^-1` directly, with no
    // iteration at all. Just as in [sqrt] (see its call site for the full
    // scope note on why diagonalization substitutes for the prescribed
    // real-Schur-form approach here), [diagonalization] itself already
    // rejects a genuine complex-conjugate eigenvalue pair, so this can
    // never silently approximate one; it simply is not attempted for one,
    // and this falls through to the scaling-and-squaring loop below, which
    // handles that case (and any defective/non-diagonalizable one)
    // directly without an eigenbasis.
    final Matrix? realEigenLog = _tryRealEigenLog(
      relativeTolerance: relativeTolerance,
      absoluteTolerance: absoluteTolerance,
    );
    if (realEigenLog != null) {
      return realEigenLog;
    }

    // Principal log via inverse scaling and squaring: repeatedly take the
    // matrix square root (Denman-Beavers Newton iteration, valid for any
    // matrix without eigenvalues on the non-positive real axis, including
    // defective/non-diagonalizable ones) until the result is close to the
    // identity, then sum the Mercator series on the near-identity residual,
    // then rescale by 2^k. This avoids diagonalization entirely, so it also
    // handles matrices with repeated eigenvalues and no full eigenbasis
    // (e.g. a Jordan block), where an eigendecomposition-based log fails.
    return _principalLogByScalingAndSquaring(
      absoluteTolerance: absoluteTolerance,
      relativeTolerance: relativeTolerance,
    );
  }

  /// Inverse scaling and squaring principal logarithm for a square matrix
  /// whose eigenvalues have already been confirmed real and positive.
  ///
  /// Round 5 correction: this used to take repeated square roots until the
  /// residual `current - I` merely dropped under a fixed absolute
  /// threshold (`1e-2`), then sum a Taylor (Mercator) series for
  /// `log(I + residual)` until a term size fell under a runtime-computed
  /// "seriesTolerance" — an absolute-tolerance-driven series stop the
  /// standing brief explicitly rules out ("No absolute 1e-10 series
  /// stop"). This is replaced with Higham's inverse scaling-and-squaring
  /// method (Higham 2008, "Functions of Matrices", Algorithm 11.9;
  /// Al-Mohy and Higham 2012): square-root down until the residual's
  /// infinity norm is at or below [_gaussLegendreLogThreshold], the
  /// convergence radius for an 8-point Gauss-Legendre quadrature of the
  /// integral `log(I+X) = integral_0^1 X (I + tX)^-1 dt`, which is
  /// algebraically identical to the [8/8] Pade approximant to log(1+x)
  /// (Higham 2008, Theorem 11.13). The quadrature order is fixed a
  /// priori — evaluating it is a single fixed-length sum, never a
  /// runtime "has this converged yet" loop — so accuracy is guaranteed in
  /// advance by the norm bound on the residual, not decided at runtime by
  /// comparing a shrinking term against a tolerance.
  Matrix _principalLogByScalingAndSquaring({
    required double absoluteTolerance,
    required double relativeTolerance,
    int maxSquarings = 60,
  }) {
    final Matrix identity = Matrix.identity(rowCount);
    const double gaussLegendreLogThreshold = 0.25;

    Matrix current = this;
    int squarings = 0;
    while ((current - identity)._infinityNorm() > gaussLegendreLogThreshold &&
        squarings < maxSquarings) {
      current = current.sqrt(
        absoluteTolerance: absoluteTolerance,
        relativeTolerance: relativeTolerance,
      );
      squarings++;
    }

    if ((current - identity)._infinityNorm() > gaussLegendreLogThreshold) {
      throw MatrixDomainError(
        'Matrix logarithm did not converge while scaling toward the '
        'identity.',
        errorId: CalculatrixErrorId.noConvergence,
      );
    }

    final Matrix residual = current - identity;
    final Matrix logResidual = _logByGaussLegendreQuadrature(residual);

    return _checkFiniteMatrix(
      logResidual.scale(math.pow(2.0, squarings).toDouble()),
    );
  }

  /// Evaluates `log(I + x)` via an 8-point Gauss-Legendre quadrature of
  /// `integral_0^1 x (I + t*x)^-1 dt`, algebraically the [8/8] Pade
  /// approximant to `log(1+x)` (Higham 2008, Theorem 11.13 / Algorithm
  /// 11.9). The node/weight pairs are the standard 8-point Gauss-Legendre
  /// rule on `[-1,1]`, affine-mapped to `[0,1]`. This is only accurate to
  /// double precision when `‖x‖` is at or below the threshold enforced by
  /// the caller before invoking this — it performs no internal
  /// convergence check of its own, by design (see
  /// [_principalLogByScalingAndSquaring]).
  Matrix _logByGaussLegendreQuadrature(Matrix x) {
    const List<double> halfNodes = <double>[
      0.1834346424956498,
      0.5255324099163290,
      0.7966664774136267,
      0.9602898564975363,
    ];
    const List<double> halfWeights = <double>[
      0.3626837833783620,
      0.3137066458778873,
      0.2223810344533745,
      0.1012285362903763,
    ];

    final int n = x.rowCount;
    final Matrix identity = Matrix.identity(n);
    Matrix sum = Matrix.zeros(n, n);

    for (int i = 0; i < halfNodes.length; i++) {
      for (final double signedNode in <double>[-halfNodes[i], halfNodes[i]]) {
        final double t = (signedNode + 1.0) / 2.0;
        final double weight = halfWeights[i] / 2.0;
        final Matrix factor = (identity + x.scale(t))._inverse();
        sum = sum + (x * factor).scale(weight);
      }
    }

    return sum;
  }

  /// Computes `this ^ exponent` (issue #5, power semantics table D25/D34).
  ///
  /// The checks run strictly by kind, never by a numerical commutation
  /// test: dimensions first (base and exponent both square; when neither is
  /// scalar they must be the same size), then by whether the exponent is
  /// scalar, then by sign/complex-form. Every combination the table does
  /// not cover raises a typed domain error (`ambiguous-power`,
  /// `log-undefined`, `dimension-mismatch`, `non-finite` or
  /// `singular-matrix`) rather than guessing a result: no fallbacks, no
  /// silent defaults.
  Matrix power(Matrix exponent) {
    if (!isSquare) {
      throw MatrixShapeError(
        'Power base must be square, found ${rowCount}x${columnCount}.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    if (!exponent.isSquare) {
      throw MatrixShapeError(
        'Power exponent must be square, found '
        '${exponent.rowCount}x${exponent.columnCount}.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    if (!isScalar && !exponent.isScalar && rowCount != exponent.rowCount) {
      throw MatrixShapeError(
        'Power base ${rowCount}x$rowCount and exponent '
        '${exponent.rowCount}x${exponent.rowCount} must be the same size.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    if (exponent.isScalar) {
      return _powerByScalarExponent(exponent.scalarValue);
    }

    return _powerByMatrixExponent(exponent);
  }

  Matrix _powerByScalarExponent(double y) {
    // Round 5 correction, case 1: a non-finite exponent must be rejected
    // before it is ever classified as "an integer" — `double.infinity ==
    // double.infinity.roundToDouble()` is true, which used to route
    // Infinity into the binary-exponentiation loop below, whose only exit
    // condition ("count > 0") never becomes false for Infinity (halving it
    // stays Infinity, and `Infinity % 2` is NaN, so "is it odd" never even
    // resolves either way). Rejecting non-finite input here, before any
    // loop sees it, makes every loop below it unconditionally
    // data-independent-bounded for a genuinely finite exponent.
    if (!y.isFinite) {
      throw MatrixDomainError(
        'Power exponent must be a finite number.',
        errorId: CalculatrixErrorId.nonFinite,
      );
    }

    final bool integerExponent = y == y.roundToDouble();

    if (isScalar) {
      final double b = scalarValue;

      if (integerExponent || b >= 0) {
        // Integer exponent (any base) and non-negative base use ordinary
        // real exponentiation directly; this also yields the 0^y cases
        // (0^0 = 1, 0^positive = 0, 0^negative = +Infinity) for free.
        return Matrix.scalar(_checkFiniteScalar(math.pow(b, y).toDouble()));
      }

      // b < 0, non-integer exponent: complex principal value via
      // B^Y = exp(Y * log(B)), where log(B) is the complex principal log
      // this class already gives negative scalars.
      final Matrix scaled = log().scale(y);
      return _checkFiniteMatrix(scaled.exp());
    }

    // Square, non-scalar base.
    if (integerExponent) {
      return _integerMatrixPower(y);
    }

    final Matrix scaled = log().scale(y);
    return _checkFiniteMatrix(scaled.exp());
  }

  Matrix _powerByMatrixExponent(Matrix exponent) {
    if (isScalar) {
      final double b = scalarValue;

      if (b == 0) {
        throw MatrixDomainError(
          '0 raised to a matrix power requires log(0), which is undefined.',
          errorId: CalculatrixErrorId.logUndefined,
        );
      }

      if (b > 0) {
        final Matrix scaled = exponent.scale(math.log(b));
        return _checkFiniteMatrix(scaled.exp());
      }

      // b < 0: only defined when the exponent is also a complex number
      // (aI + bJ), since complex numbers commute and the branch of
      // log(B) is then unambiguous.
      if (exponent.isComplexForm) {
        final Matrix product = log() * exponent;
        return _checkFiniteMatrix(product.exp());
      }

      throw MatrixDomainError(
        'A negative scalar base raised to a non-complex matrix exponent is '
        'ambiguous: the branch of the logarithm is not determined.',
        errorId: CalculatrixErrorId.ambiguousPower,
      );
    }

    // Square, non-scalar base with a square, non-scalar exponent: only the
    // complex-form (aI + bJ) subalgebra commutes unconditionally, so it is
    // the only pairing with an unambiguous result.
    if (isComplexForm && exponent.isComplexForm) {
      final Matrix product = log() * exponent;
      return _checkFiniteMatrix(product.exp());
    }

    throw MatrixDomainError(
      'A matrix base raised to a matrix exponent is ambiguous outside the '
      'scalar, positive-scalar-base and complex-form cases.',
      errorId: CalculatrixErrorId.ambiguousPower,
    );
  }

  /// Integer power of a square, non-scalar matrix via exponentiation by
  /// squaring (or by squaring the inverse, for a negative exponent).
  ///
  /// [exponent] is taken and driven entirely as a `double` (never rounded
  /// or negated through `int`): `int` on the native VM is a wrapping
  /// 64-bit type, so `exponent.round()`/`.abs()` silently clamp or
  /// overflow for magnitudes near or beyond 2^63 (e.g. the minimum 64-bit
  /// int negated overflows back to itself). A `double` has no such trap —
  /// every finite double is an exact dyadic rational, so halving it via
  /// `count / 2` and reading its parity via `count % 2` stay exact for any
  /// whole-number magnitude a double can represent, which is exactly what
  /// binary exponentiation needs. `count` reaches 0 in O(log2(|exponent|))
  /// iterations even for exponents like 1e30, instead of the O(|exponent|)
  /// iterations a naive repeated-multiplication loop would need (which
  /// would never finish for such an exponent). Each squaring/multiplication
  /// step is finiteness-checked so an overflowing result raises
  /// `non-finite` instead of silently returning `Infinity` entries.
  Matrix _integerMatrixPower(double exponent) {
    if (exponent == 0) {
      return Matrix.identity(rowCount);
    }

    final bool negative = exponent < 0;
    Matrix base = negative ? _inverse() : this;
    double count = negative ? -exponent : exponent;

    Matrix result = Matrix.identity(rowCount);
    while (count > 0) {
      if (count % 2 == 1) {
        result = _checkFiniteMatrix(result * base);
      }
      count = (count / 2).floorToDouble();
      if (count > 0) {
        base = _checkFiniteMatrix(base * base);
      }
    }
    return result;
  }

  static double _checkFiniteScalar(double value) {
    if (!value.isFinite) {
      throw MatrixDomainError(
        'Result is not a finite number.',
        errorId: CalculatrixErrorId.nonFinite,
      );
    }
    return value;
  }

  static Matrix _checkFiniteMatrix(Matrix matrix) {
    for (int row = 0; row < matrix.rowCount; row++) {
      for (int column = 0; column < matrix.columnCount; column++) {
        if (!matrix.at(row, column).isFinite) {
          throw MatrixDomainError(
            'Result is not a finite number.',
            errorId: CalculatrixErrorId.nonFinite,
          );
        }
      }
    }
    return matrix;
  }

  /// Computes a matrix-first singular value decomposition.
  ///
  /// Returns matrices (U, S, Vᵀ) such that A ≈ U·S·Vᵀ, where S is diagonal
  /// with non-negative singular values sorted in descending order.
  SvdDecomposition svd({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    final Matrix ata = transpose() * this;
    final Diagonalization decomposition = ata.diagonalization(
      absoluteTolerance: absoluteTolerance,
    );

    final Matrix v = decomposition.p;
    final Matrix vT = v.transpose();
    final int n = columnCount;

    final List<double> singularValues = List<double>.generate(
      n,
      (int index) {
        final double lambda = decomposition.d.at(index, index);
        if (lambda <= absoluteTolerance) {
          return 0;
        }
        return math.sqrt(lambda);
      },
      growable: false,
    );

    final List<List<double>> sRows = List<List<double>>.generate(
      n,
      (int row) => List<double>.generate(
        n,
        (int column) => row == column ? singularValues[row] : 0,
        growable: false,
      ),
      growable: false,
    );

    final List<List<double>> uRows = List<List<double>>.generate(
      rowCount,
      (_) => List<double>.filled(n, 0, growable: false),
      growable: false,
    );

    for (int column = 0; column < n; column++) {
      final List<double> vColumn = List<double>.generate(
        n,
        (int row) => v.at(row, column),
        growable: false,
      );

      if (singularValues[column] <= absoluteTolerance) {
        continue;
      }

      final Matrix projected = this * Matrix(
        vColumn
            .map((double value) => <double>[value])
            .toList(growable: false),
      );
      final double sigma = singularValues[column];
      for (int row = 0; row < rowCount; row++) {
        final double normalized = projected.at(row, 0) / sigma;
        uRows[row][column] = normalized.abs() <= absoluteTolerance
            ? 0
            : normalized;
      }
    }

    return SvdDecomposition(
      u: Matrix(uRows),
      s: Matrix(sRows),
      vT: vT,
    );
  }

  Matrix transpose() {
    final List<List<double>> result = List<List<double>>.generate(
      columnCount,
      (int c) => List<double>.generate(
        rowCount,
        (int r) => _rows[r][c],
        growable: false,
      ),
      growable: false,
    );

    return Matrix(result);
  }

  Matrix appendRow(Matrix row) {
    if (row.rowCount != 1 || row.columnCount != columnCount) {
      throw MatrixShapeError(
        'Cannot append ${row.rowCount}x${row.columnCount} row operand to '
        '${rowCount}x${columnCount} matrix.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    return Matrix(<List<double>>[
      ..._rows.map((List<double> source) => List<double>.from(source)),
      List<double>.from(row._rows.first),
    ]);
  }

  Matrix appendColumn(Matrix column) {
    if (column.columnCount != 1 || column.rowCount != rowCount) {
      throw MatrixShapeError(
        'Cannot append ${column.rowCount}x${column.columnCount} column operand '
        'to ${rowCount}x${columnCount} matrix.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    return Matrix(
      List<List<double>>.generate(
        rowCount,
        (int rowIndex) => <double>[
          ..._rows[rowIndex],
          column._rows[rowIndex].first,
        ],
        growable: false,
      ),
    );
  }

  Matrix deleteRow(int rowIndex) {
    _requireRowIndex(rowIndex);
    if (rowCount == 1) {
      throw MatrixShapeError(
        'Cannot delete the only row in a matrix.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    return Matrix(
      List<List<double>>.generate(
        rowCount - 1,
        (int targetIndex) {
          final int sourceIndex = targetIndex < rowIndex
              ? targetIndex
              : targetIndex + 1;
          return List<double>.from(_rows[sourceIndex]);
        },
        growable: false,
      ),
    );
  }

  Matrix deleteColumn(int columnIndex) {
    _requireColumnIndex(columnIndex);
    if (columnCount == 1) {
      throw MatrixShapeError(
        'Cannot delete the only column in a matrix.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    return Matrix(
      List<List<double>>.generate(
        rowCount,
        (int rowIndex) => List<double>.generate(
          columnCount - 1,
          (int targetIndex) {
            final int sourceIndex = targetIndex < columnIndex
                ? targetIndex
                : targetIndex + 1;
            return _rows[rowIndex][sourceIndex];
          },
          growable: false,
        ),
        growable: false,
      ),
    );
  }

  Matrix duplicateRow(int rowIndex) {
    _requireRowIndex(rowIndex);

    final List<List<double>> rows = _rows
        .map((List<double> row) => List<double>.from(row))
        .toList(growable: true);
    rows.insert(rowIndex + 1, List<double>.from(_rows[rowIndex]));
    return Matrix(rows);
  }

  Matrix duplicateColumn(int columnIndex) {
    _requireColumnIndex(columnIndex);

    return Matrix(
      List<List<double>>.generate(
        rowCount,
        (int rowIndex) {
          final List<double> row = List<double>.from(_rows[rowIndex]);
          row.insert(columnIndex + 1, _rows[rowIndex][columnIndex]);
          return row;
        },
        growable: false,
      ),
    );
  }

  Matrix moveRow(int fromIndex, int toIndex) {
    _requireRowIndex(fromIndex);
    _requireRowIndex(toIndex);
    if (fromIndex == toIndex) {
      return this;
    }

    final List<List<double>> rows = _rows
        .map((List<double> row) => List<double>.from(row))
        .toList(growable: true);
    final List<double> moved = rows.removeAt(fromIndex);
    rows.insert(toIndex, moved);
    return Matrix(rows);
  }

  Matrix moveColumn(int fromIndex, int toIndex) {
    _requireColumnIndex(fromIndex);
    _requireColumnIndex(toIndex);
    if (fromIndex == toIndex) {
      return this;
    }

    return Matrix(
      List<List<double>>.generate(
        rowCount,
        (int rowIndex) {
          final List<double> row = List<double>.from(_rows[rowIndex]);
          final double moved = row.removeAt(fromIndex);
          row.insert(toIndex, moved);
          return row;
        },
        growable: false,
      ),
    );
  }

  bool almostEquals(
    Matrix other, {
    double relativeTolerance =
        CalculatrixNumericPolicy.defaultRelativeTolerance,
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    if (rowCount != other.rowCount || columnCount != other.columnCount) {
      return false;
    }

    for (int r = 0; r < rowCount; r++) {
      for (int c = 0; c < columnCount; c++) {
        if (!CalculatrixNumericPolicy.nearlyEqual(
          _rows[r][c],
          other._rows[r][c],
          relativeTolerance: relativeTolerance,
          absoluteTolerance: absoluteTolerance,
        )) {
          return false;
        }
      }
    }

    return true;
  }

  static List<List<double>> _normalize(List<List<double>> rows) {
    return rows
        .map(
          (List<double> row) =>
              List<double>.unmodifiable(List<double>.from(row)),
        )
        .toList(growable: false);
  }

  static void _validateRectangular(List<List<double>> rows) {
    if (rows.isEmpty) {
      throw MatrixShapeError(
        'Matrix cannot be empty.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    if (rows.first.isEmpty) {
      throw MatrixShapeError(
        'Matrix rows cannot be empty.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    final int width = rows.first.length;
    for (final List<double> row in rows) {
      if (row.length != width) {
        throw MatrixShapeError(
          'All rows must have the same number of columns.',
          errorId: CalculatrixErrorId.dimensionMismatch,
        );
      }
    }
  }

  static void _validateShape(int rowCount, int columnCount, {required String label}) {
    if (rowCount < 1 || columnCount < 1) {
      throw MatrixShapeError(
        '$label matrix dimensions must be greater than zero.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
  }

  void _requireSameDimensions(Matrix other, {required String operation}) {
    if (rowCount != other.rowCount || columnCount != other.columnCount) {
      throw MatrixShapeError(
        'Cannot perform $operation for ${rowCount}x${columnCount} and '
        '${other.rowCount}x${other.columnCount}.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
  }

  /// Scalar promotion: if [candidate] is 1×1 and [reference] is n×n square
  /// (n > 1), returns `candidate.scalarValue · Iₙ`; otherwise returns
  /// [candidate] unchanged.
  ///
  /// This enables natural complex arithmetic: `3 + Matrix.i` promotes 3 to
  /// `3·I₂` before the element-wise addition, yielding `[[3,-1],[1,3]]`.
  static Matrix _promoteScalar(Matrix candidate, Matrix reference) {
    if (candidate.isScalar &&
        reference.isSquare &&
        reference.rowCount > 1) {
      return Matrix.identity(reference.rowCount).scale(candidate.scalarValue);
    }
    return candidate;
  }

  void _requireSquare({required String operation}) {
    if (!isSquare) {
      throw MatrixShapeError(
        'Cannot perform $operation for non-square '
        '${rowCount}x${columnCount} matrix.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
  }

  void _requireRowIndex(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= rowCount) {
      throw MatrixIndexError(
        'Row index $rowIndex is out of range for $rowCount rows.',
      );
    }
  }

  void _requireColumnIndex(int columnIndex) {
    if (columnIndex < 0 || columnIndex >= columnCount) {
      throw MatrixIndexError(
        'Column index $columnIndex is out of range for $columnCount columns.',
      );
    }
  }

  double _infinityNorm() {
    double maxRowSum = 0;

    for (final List<double> row in _rows) {
      double rowSum = 0;
      for (final double value in row) {
        rowSum += value.abs();
      }

      if (rowSum > maxRowSum) {
        maxRowSum = rowSum;
      }
    }

    return maxRowSum;
  }

  /// The largest absolute value among this matrix's entries — a plain
  /// `max`, never a sum, so it stays finite whenever every entry
  /// individually is, unlike [_infinityNorm] (a row sum, which can
  /// genuinely overflow even though no single entry does). Used wherever a
  /// scale-relative tolerance must never itself become non-finite as a
  /// side effect of the very overflow it exists to guard against (round 5
  /// correction, case 4).
  double _maxAbsEntry() {
    double maxAbs = 0;
    for (final List<double> row in _rows) {
      for (final double value in row) {
        final double magnitude = value.abs();
        if (magnitude > maxAbs) {
          maxAbs = magnitude;
        }
      }
    }
    return maxAbs;
  }

  /// Exact power-of-two scale normalization (round 4 correction, rule 1).
  ///
  /// Returns `k` such that `2^k` is the power of two nearest this matrix's
  /// infinity norm, and `scaled = this * 2^-k`. Multiplying or dividing a
  /// finite double by an exact power of two changes only its exponent bits
  /// (never its mantissa), so `scaled` carries no rounding error beyond
  /// what `this` already had, and `scaled`'s own norm always lands within
  /// a factor of `sqrt(2)` of 1 (never zero unless `this` is the zero
  /// matrix). [sqrt], [log], [_inverse] and [eigenvalues] each run their
  /// numerically-sensitive core on `scaled` rather than `this`, then undo
  /// this scaling analytically on the result (`sqrt(cA) = sqrt(c) *
  /// sqrt(A)`, `log(cA) = log(c)*I + log(A)`, `inv(cA) = inv(A) / c`,
  /// `eig(cA) = c * eig(A)`, for `c = 2^k`) — so every *internal*
  /// comparison against [CalculatrixNumericPolicy.defaultAbsoluteTolerance]
  /// deep inside those algorithms (a pivot cutoff, a deflation check, an
  /// eigenvalue-near-zero cleanup) is implicitly relative to this matrix's
  /// own scale, without needing to be rewritten as its own scale-relative
  /// formula at every comparison site: a fixed floor tuned for a norm ~1
  /// matrix is safe exactly because every matrix reaching it now has norm
  /// ~1, regardless of how large or small the original matrix truly was.
  ///
  /// Returns `k = 0` unchanged for the zero matrix (nothing to normalize)
  /// or a matrix whose norm is not finite (the caller is expected to have
  /// already rejected a non-finite matrix before this is ever called).
  ({int k, Matrix scaled}) _normalizedByPowerOfTwo() {
    final double norm = _infinityNorm();
    if (norm == 0) {
      return (k: 0, scaled: this);
    }
    if (!norm.isFinite) {
      // Round 5 correction, case 4: a non-finite infinity-norm here means
      // this matrix's row sums genuinely overflow double precision (every
      // entry can still be individually finite, e.g. all entries at
      // 1e308), not that normalization is inapplicable. Silently returning
      // `(k: 0, scaled: this)` (the previous behavior) let every caller's
      // numerically-sensitive core run directly on data it has no scale
      // handle on at all — this raises the typed error instead, so the
      // caller sees exactly why no result could be produced rather than
      // getting a wrong one (e.g. a spurious rotation from `isComplexForm`
      // wrongly comparing Infinity <= Infinity).
      throw MatrixDomainError(
        'Matrix infinity-norm overflowed to a non-finite value before '
        'scale normalization.',
        errorId: CalculatrixErrorId.nonFinite,
      );
    }
    final int k = (math.log(norm) / math.ln2).round();
    if (k == 0) {
      return (k: 0, scaled: this);
    }
    return (k: k, scaled: _scaleByPowerOfTwo(this, -k.toDouble()));
  }

  /// Scales [source] by `2^exponent` in bounded steps of at most `2^1000`
  /// per multiply, rather than computing `math.pow(2.0, exponent)` as a
  /// single double and multiplying by it once.
  ///
  /// A single-step `2^k` overflows to `Infinity` (or underflows to `0`)
  /// once `|k|` exceeds double's representable exponent range (~1023),
  /// *even when the final, fully-scaled result would itself be finite* —
  /// e.g. undoing a `k = 1024` normalization on an already-tiny matrix.
  /// Multiplying by `2^1000` and then `2^24` (say) instead of `2^1024` in
  /// one step keeps every intermediate matrix in double's representable
  /// range whenever the true mathematical result is representable, exactly
  /// like `ldexp` in C. The loop bound is `ceil(|exponent| / 1000) + 1`,
  /// which is always finite for a finite `exponent` (the only kind this is
  /// ever called with, since every call site normalizes or undoes a
  /// normalization derived from a matrix that already passed a finiteness
  /// check).
  static Matrix _scaleByPowerOfTwo(Matrix source, double exponent) {
    const double maxStep = 1000;
    Matrix result = source;
    double remaining = exponent;
    while (remaining.abs() > maxStep) {
      final double step = remaining > 0 ? maxStep : -maxStep;
      result = result.scale(math.pow(2.0, step).toDouble());
      remaining -= step;
    }
    if (remaining != 0) {
      result = result.scale(math.pow(2.0, remaining).toDouble());
    }
    return result;
  }

  /// Scalar analog of [_scaleByPowerOfTwo], for call sites that scale a
  /// single `double` (an eigenvalue) rather than a whole [Matrix].
  static double _scalarScaleByPowerOfTwo(double value, double exponent) {
    const double maxStep = 1000;
    double result = value;
    double remaining = exponent;
    while (remaining.abs() > maxStep) {
      final double step = remaining > 0 ? maxStep : -maxStep;
      result *= math.pow(2.0, step).toDouble();
      remaining -= step;
    }
    if (remaining != 0) {
      result *= math.pow(2.0, remaining).toDouble();
    }
    return result;
  }

  /// Hypot-style magnitude of `a + bi`, computed as
  /// `max(|a|,|b|) * sqrt(1 + (min(|a|,|b|)/max(|a|,|b|))^2)` rather than
  /// the naive `sqrt(a*a + b*b)`. The naive form squares each term first,
  /// which overflows to `Infinity` once `|a|` or `|b|` exceeds ~1.34e154
  /// (`sqrt(double.maxFinite)`) even though the true magnitude is still
  /// finite (round 4 correction, case B: `a=1e200` overflows `a*a` to
  /// `Infinity` well before the true magnitude `1e200` itself is anywhere
  /// near double's range) — and can equally underflow the *ratio* of two
  /// tiny values to 0 when both are subnormal. Dividing by the larger
  /// magnitude first keeps every intermediate value between 0 and
  /// `sqrt(2)`, so this only overflows when the true magnitude itself is
  /// no longer representable.
  static double _hypot(double a, double b) {
    final double absA = a.abs();
    final double absB = b.abs();
    final double maxAB = math.max(absA, absB);
    if (maxAB == 0) {
      return 0;
    }
    final double minAB = math.min(absA, absB);
    final double ratio = minAB / maxAB;
    return maxAB * math.sqrt(1 + (ratio * ratio));
  }

  /// Whether this square matrix is exactly upper triangular, exactly lower
  /// triangular, or both (diagonal) — checked with a plain `== 0`, not a
  /// tolerance. This is deliberately exact: it exists to give
  /// [log]/[power] a route to read a triangular matrix's eigenvalues
  /// straight off the diagonal, with no discriminant, no QR iteration, and
  /// therefore no rounding noise to second-guess with a tolerance in the
  /// first place. A matrix whose off-triangular entries are merely *close*
  /// to zero (not exactly zero) does not qualify — it goes through the
  /// general eigenvalue pipeline instead, where the rounding it does carry
  /// is handled by a scale-relative floor.
  bool _isExactlyTriangular() {
    bool isUpper = true;
    bool isLower = true;

    for (int r = 0; r < rowCount; r++) {
      for (int c = 0; c < columnCount; c++) {
        if (r == c) continue;
        if (r > c && _rows[r][c] != 0) isLower = false;
        if (r < c && _rows[r][c] != 0) isUpper = false;
      }
      if (!isUpper && !isLower) return false;
    }

    return isUpper || isLower;
  }

  /// Whether this square matrix's strictly-lower-triangular entries are all
  /// exactly zero (upper triangular; a diagonal matrix also qualifies).
  /// Used to pick the recurrence direction for [sqrt]'s and [log]'s
  /// triangular fast paths: both closed-form recurrences (Bjorck-Hammarling,
  /// Parlett) are stated for an upper triangular matrix; a lower triangular
  /// input is transposed in, solved, and transposed back, since
  /// `f(Aᵀ) = f(A)ᵀ` for any of these functions on a real matrix.
  bool _isUpperTriangular() {
    for (int r = 0; r < rowCount; r++) {
      for (int c = 0; c < r; c++) {
        if (_rows[r][c] != 0) return false;
      }
    }
    return true;
  }

  /// [sqrt] fast path for an exactly triangular (but not exactly diagonal)
  /// matrix: the Bjorck and Hammarling recurrence (Higham, "Functions of
  /// Matrices", 2008, Algorithm 6.3) for the square root of an upper
  /// triangular matrix `T`. Reading off entry `(i,j)` of `S*S = T` gives:
  ///
  /// - `S[i][i] = sqrt(T[i][i])` — the diagonal, exact.
  /// - For `i < j`: `S[i][j] = (T[i][j] - sum_{k=i+1}^{j-1} S[i][k]*S[k][j])
  ///   / (S[i][i] + S[j][j])`, solved by increasing distance from the
  ///   diagonal (`gap = j - i`), so every `S[i][k]`/`S[k][j]` used in the
  ///   sum for a given `gap` was already computed at a smaller `gap`.
  ///
  /// No iteration, no convergence tolerance: closed form throughout. Throws
  /// the same typed domain errors [sqrt]'s diagonal fast path throws — a
  /// negative diagonal entry (no real square root exists), or a zero
  /// `S[i][i] + S[j][j]` denominator (a repeated zero eigenvalue makes the
  /// recurrence itself singular; this is a genuine case where the real
  /// square root either fails to exist or is not unique, not a numerical
  /// artifact to work around).
  Matrix _triangularSqrt() {
    final bool upper = _isUpperTriangular();
    final Matrix triangular = upper ? this : transpose();
    final int n = triangular.rowCount;
    final List<List<double>> t = triangular._rows;

    final List<List<double>> s = List<List<double>>.generate(
      n,
      (_) => List<double>.filled(n, 0),
      growable: false,
    );

    for (int i = 0; i < n; i++) {
      final double diagonalValue = t[i][i];
      if (diagonalValue < 0) {
        throw MatrixDomainError(
          'Square root is undefined for this matrix in the real domain.',
        );
      }
      s[i][i] = math.sqrt(diagonalValue);
    }

    for (int gap = 1; gap < n; gap++) {
      for (int i = 0; i + gap < n; i++) {
        final int j = i + gap;
        double sum = 0;
        for (int k = i + 1; k < j; k++) {
          sum += s[i][k] * s[k][j];
        }
        final double denominator = s[i][i] + s[j][j];
        if (denominator == 0) {
          throw MatrixDomainError(
            'Square root is undefined for this matrix: a repeated zero '
            'eigenvalue makes the Bjorck-Hammarling recurrence singular.',
          );
        }
        s[i][j] = (t[i][j] - sum) / denominator;
      }
    }

    final Matrix result = Matrix(s);
    return upper ? result : result.transpose();
  }

  /// [log] fast path for an exactly triangular matrix (diagonal included):
  /// the Parlett recurrence (Parlett, "A recurrence for the elements of
  /// function of triangular matrices", 1976; restated in Higham, "Functions
  /// of Matrices", 2008, Algorithm 4.13) for `L = log(T)` of an upper
  /// triangular `T` whose diagonal is already known strictly positive by
  /// [log]'s domain check. Reading `L*T = T*L` (any function of a
  /// triangular matrix commutes with it) off entry `(i,j)` gives:
  ///
  /// - `L[i][i] = log(T[i][i])` — the diagonal, exact.
  /// - For `i < j` with `T[i][i] != T[j][j]`:
  ///   `L[i][j] = (T[i][j]*(L[i][i]-L[j][j]) + sum_{k=i+1}^{j-1}
  ///   (L[i][k]*T[k][j] - T[i][k]*L[k][j])) / (T[i][i]-T[j][j])`, solved by
  ///   increasing distance from the diagonal (`gap = j - i`).
  /// - For `i < j` with `T[i][i] == T[j][j]` and `gap == 1`: the divided
  ///   difference of `log` at a repeated point is `1/T[i][i]`, giving
  ///   `L[i][j] = T[i][j] / T[i][i]` directly.
  /// - For `i < j` with `T[i][i] == T[j][j]` and `gap >= 2`: if the
  ///   coupling sum above happens to be exactly zero, the same
  ///   `L[i][j] = T[i][j] / T[i][i]` still applies (there is no coupling to
  ///   resolve); otherwise this is a genuine repeated eigenvalue with
  ///   nonzero coupling beyond the first superdiagonal, which needs a
  ///   higher-order divided-difference extension of the Parlett recurrence
  ///   this implementation does not carry — it is rejected with a typed
  ///   domain error rather than approximated (documented scope limitation,
  ///   per the standing brief's escape valve).
  Matrix _triangularLog() {
    final bool upper = _isUpperTriangular();
    final Matrix triangular = upper ? this : transpose();
    final int n = triangular.rowCount;
    final List<List<double>> t = triangular._rows;

    final List<List<double>> l = List<List<double>>.generate(
      n,
      (_) => List<double>.filled(n, 0),
      growable: false,
    );

    for (int i = 0; i < n; i++) {
      l[i][i] = math.log(t[i][i]);
    }

    for (int gap = 1; gap < n; gap++) {
      for (int i = 0; i + gap < n; i++) {
        final int j = i + gap;
        double sum = 0;
        for (int k = i + 1; k < j; k++) {
          sum += l[i][k] * t[k][j] - t[i][k] * l[k][j];
        }
        final double diagonalGap = t[i][i] - t[j][j];
        if (diagonalGap != 0) {
          l[i][j] = (t[i][j] * (l[i][i] - l[j][j]) + sum) / diagonalGap;
        } else if (gap == 1 || sum == 0) {
          l[i][j] = t[i][j] / t[i][i];
        } else {
          throw MatrixDomainError(
            'Logarithm requires a higher-order Parlett recurrence for a '
            'repeated eigenvalue with nonzero coupling beyond the first '
            'superdiagonal, which this implementation does not support.',
          );
        }
      }
    }

    final Matrix result = Matrix(l);
    return upper ? result : result.transpose();
  }

  /// Whether every off-diagonal entry of this square matrix is exactly
  /// zero — checked with a plain `== 0`, not a tolerance, for the same
  /// reason as [_isExactlyTriangular]: it exists to give [sqrt] a route to
  /// compute each diagonal entry's root independently (a decoupled scalar
  /// Newton sqrt per entry), which needs no convergence tolerance to
  /// reason about in the first place because it carries no cross-entry
  /// rounding coupling at all.
  bool _isExactlyDiagonal() {
    for (int r = 0; r < rowCount; r++) {
      for (int c = 0; c < columnCount; c++) {
        if (r != c && _rows[r][c] != 0) return false;
      }
    }
    return true;
  }

  /// Returns the common value `a` if this square matrix equals `a * I`
  /// exactly — every diagonal entry bit-for-bit the same double, every
  /// off-diagonal entry bit-for-bit exactly zero — or `null` otherwise.
  ///
  /// Used by [exp] (round 4 correction, rule 2) to take a closed-form
  /// `e^a * I` shortcut for any size `n`, not just the `n == 2` case
  /// [isComplexForm] already covers implicitly (a 2x2 `aI` is complex-form
  /// with `b == 0`).
  double? _asScalarMultipleOfIdentity() {
    if (!_isExactlyDiagonal()) {
      return null;
    }
    final double a = _rows[0][0];
    for (int i = 1; i < rowCount; i++) {
      if (_rows[i][i] != a) {
        return null;
      }
    }
    return a;
  }

  /// Whether this square matrix is symmetric to within double-precision
  /// rounding noise: `|A[i][j] - A[j][i]| <= 4*u*max(|A[i][j]|, |A[j][i]|)`
  /// for every pair, the same scale-relative pattern used by
  /// [isComplexForm] (a fixed absolute tolerance would be wrong at every
  /// scale but the one it was tuned for). A plain `==` check is
  /// deliberately not used here: a matrix produced by a prior symmetric
  /// computation (e.g. [sqrt]'s own eigendecomposition fast path, `P *
  /// diag(...) * Pᵀ`) is symmetric *up to rounding* but essentially never
  /// bit-for-bit symmetric, and both call sites below need to recognize
  /// that as symmetric to remain effective across chained calls (e.g.
  /// [log]'s repeated squarings-and-square-roots).
  ///
  /// Used by [sqrt]'s Newton loop for two purposes: to gate the
  /// eigendecomposition fast path (only meaningful for a symmetric
  /// matrix, whose true square root is itself symmetric), and to
  /// re-symmetrize every Newton iterate (`0.5*(X + Xᵀ)`), projecting it
  /// back onto that manifold each step. Without the latter, a small
  /// asymmetric rounding perturbation orthogonal to a near-singular
  /// direction gets amplified by the iteration's own matrix inverse and
  /// compounds across iterations — for an ill-conditioned input this can
  /// blow the iterate up in magnitude well after it already passed close
  /// to the true root, long before [maxIterations] is reached.
  bool _isApproximatelySymmetric() {
    const double u = CalculatrixNumericPolicy.machineEpsilon;
    for (int r = 0; r < rowCount; r++) {
      for (int c = r + 1; c < columnCount; c++) {
        final double x = _rows[r][c];
        final double y = _rows[c][r];
        final double tolerance = 4 * u * math.max(x.abs(), y.abs());
        if ((x - y).abs() > tolerance) return false;
      }
    }
    return true;
  }

  /// Attempts [sqrt] via eigendecomposition for any real matrix
  /// diagonalizable over the reals (round 5 correction: generalized from a
  /// symmetric-only gate — see [sqrt]'s call site for the scope note), or
  /// returns `null` if [diagonalization] itself fails (a genuine complex
  /// eigenvalue pair, or a defective matrix with no full eigenbasis), any
  /// eigenvalue is negative (the real square root is undefined; the caller
  /// falls through to the Newton loop, which raises the appropriate domain
  /// error), or the reconstructed candidate fails its own residual check
  /// (e.g. a near-degenerate eigenvalue cluster made the computed
  /// eigenvectors themselves inaccurate, or `P` was too ill-conditioned to
  /// invert). See the call site in [sqrt] for why this is preferred over
  /// Denman-Beavers Newton iteration whenever it applies.
  Matrix? _tryRealEigenSqrt({
    required double relativeTolerance,
    required double absoluteTolerance,
    required bool symmetric,
  }) {
    final Diagonalization eigen;
    try {
      eigen = diagonalization(absoluteTolerance: absoluteTolerance);
    } on MatrixDomainError {
      return null;
    }

    final int n = rowCount;
    final List<double> sqrtLambdas = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final double lambda = eigen.d.at(i, i);
      if (lambda < 0) {
        return null;
      }
      sqrtLambdas[i] = math.sqrt(lambda);
    }

    final Matrix diagSqrt = Matrix(
      List<List<double>>.generate(
        n,
        (int r) => List<double>.generate(
          n,
          (int c) => r == c ? sqrtLambdas[r] : 0,
          growable: false,
        ),
        growable: false,
      ),
    );

    // P is orthogonal only when the input is symmetric (eigenvectors of a
    // symmetric matrix), so P^T substitutes for P^-1 only in that case,
    // without the extra numerical work — and error — of an explicit
    // inversion. For a non-symmetric matrix, P^-1 is computed directly; a
    // singular (or numerically indistinguishable from singular) P means
    // the matrix is not diagonalizable in a numerically usable way here,
    // which falls through to the Newton loop rather than trusting a
    // meaningless result.
    final Matrix pInverse;
    try {
      pInverse = symmetric
          ? eigen.p.transpose()
          : eigen.p._inverse(absoluteTolerance: absoluteTolerance);
    } on MatrixDomainError {
      return null;
    }

    final Matrix candidate = eigen.p * diagSqrt * pInverse;

    // Purely scale-relative (round 4 correction, rule 4): `this._infinityNorm()`
    // is guaranteed nonzero here (sqrt's own zero-norm shortcut runs before
    // this is ever called), so flooring it at [absoluteTolerance] would only
    // ever loosen — never tighten — the check, and for a tiny-scale `this`
    // (e.g. norm ~1e-30, far below the 1e-12 floor) it would wrongly let
    // through a candidate whose absolute residual is many orders of
    // magnitude larger than `this` itself, just because that residual still
    // happens to be smaller than the unrelated fixed floor.
    final double residualDeviation =
        (candidate * candidate - this)._infinityNorm() / _infinityNorm();
    final double acceptanceTolerance = math.max(
      relativeTolerance,
      CalculatrixNumericPolicy.sqrtResidualAcceptanceTolerance,
    );

    if (residualDeviation > acceptanceTolerance) {
      return null;
    }

    return _checkFiniteMatrix(candidate);
  }

  /// Attempts [log] via eigendecomposition for any real matrix
  /// diagonalizable over the reals (round 5 correction) — the same
  /// approach, and the same documented scope note, as [_tryRealEigenSqrt];
  /// see that method's call site in [sqrt] for the full explanation of why
  /// diagonalization substitutes for the prescribed real-Schur-form
  /// approach here. Returns `null` if [diagonalization] itself fails (a
  /// genuine complex eigenvalue pair, or a defective matrix with no full
  /// eigenbasis) or `P` is too ill-conditioned to invert, or — crucially,
  /// since unlike [_tryRealEigenSqrt] there is no cheap way to verify a
  /// candidate logarithm's residual directly — if `P*D*P^-1` fails to
  /// reconstruct `this` itself within tolerance, which is exactly the
  /// condition under which the eigenbasis `P` would be untrustworthy to
  /// build `log(A) = P*diag(log(d_i))*P^-1` from in the first place. Every
  /// eigenvalue in `D` is already known real and strictly positive by the
  /// domain check [log] performs before calling this.
  Matrix? _tryRealEigenLog({
    required double relativeTolerance,
    required double absoluteTolerance,
  }) {
    final bool symmetric = _isApproximatelySymmetric();
    final Diagonalization eigen;
    try {
      eigen = diagonalization(absoluteTolerance: absoluteTolerance);
    } on MatrixDomainError {
      return null;
    }

    final Matrix pInverse;
    try {
      pInverse = symmetric
          ? eigen.p.transpose()
          : eigen.p._inverse(absoluteTolerance: absoluteTolerance);
    } on MatrixDomainError {
      return null;
    }

    final Matrix reconstructed = eigen.p * eigen.d * pInverse;
    final double acceptanceTolerance = math.max(
      relativeTolerance,
      CalculatrixNumericPolicy.sqrtResidualAcceptanceTolerance,
    );
    final double reconstructionDeviation =
        (reconstructed - this)._infinityNorm() / _infinityNorm();
    if (reconstructionDeviation > acceptanceTolerance) {
      return null;
    }

    final int n = rowCount;
    final Matrix logDiag = Matrix(
      List<List<double>>.generate(
        n,
        (int r) => List<double>.generate(
          n,
          (int c) => r == c ? math.log(eigen.d.at(r, r)) : 0,
          growable: false,
        ),
        growable: false,
      ),
    );

    return _checkFiniteMatrix(eigen.p * logDiag * pInverse);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Matrix && _rowsEqual(_rows, other._rows);
  }

  @override
  int get hashCode {
    return Object.hashAll(_rows.map((List<double> row) => Object.hashAll(row)));
  }

  @override
  String toString() {
    return 'Matrix($_rows)';
  }

  static bool _rowsEqual(List<List<double>> a, List<List<double>> b) {
    if (a.length != b.length) {
      return false;
    }

    for (int r = 0; r < a.length; r++) {
      if (a[r].length != b[r].length) {
        return false;
      }
      for (int c = 0; c < a[r].length; c++) {
        if (a[r][c] != b[r][c]) {
          return false;
        }
      }
    }

    return true;
  }
}
