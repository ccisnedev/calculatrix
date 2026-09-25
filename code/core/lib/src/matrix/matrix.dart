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
    final double offDiagonalTolerance = 4 * u * _infinityNorm();
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

    final double undoScale = math.pow(2.0, -normalization.k).toDouble();
    final Matrix rawInverse = normalization.scaled._inverseRaw(
      absoluteTolerance: absoluteTolerance,
    );
    return _checkFiniteMatrix(rawInverse.scale(undoScale));
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

      if (pivotMagnitude <= absoluteTolerance) {
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
    int maxIterations = 200,
  }) {
    _requireSquare(operation: 'eigenvalues');
    _checkFiniteMatrix(this);

    if (isScalar) {
      return this;
    }

    final ({int k, Matrix scaled}) normalization = _normalizedByPowerOfTwo();
    final Matrix raw = normalization.scaled._eigenvaluesRaw(
      absoluteTolerance: absoluteTolerance,
      maxIterations: maxIterations,
    );
    if (normalization.k == 0) {
      return raw;
    }
    final double undoScale = math.pow(2.0, normalization.k).toDouble();
    return _checkFiniteMatrix(raw.scale(undoScale));
  }

  Matrix _eigenvaluesRaw({
    required double absoluteTolerance,
    required int maxIterations,
  }) {
    if (rowCount == 2) {
      return _eigenvalues2x2(absoluteTolerance);
    }

    // General NxN: Hessenberg reduction then QR iteration with Wilkinson
    // shift (round 4 correction, case G: every 11th iteration without a
    // deflation instead takes an "exceptional shift" — a standard Francis
    // QR remedy for spectra a plain Wilkinson shift can stagnate on, such
    // as a permutation matrix's eigenvalues sitting equally spaced on the
    // unit circle).
    final int n = rowCount;
    final List<List<double>> h = _toHessenberg(absoluteTolerance);

    // QR iteration on upper Hessenberg form
    int size = n;
    final List<double> eigenvaluesList = <double>[];

    while (size > 2) {
      int iterations = 0;
      while (iterations < maxIterations) {
        // Check for deflation: subdiagonal element small enough
        if (h[size - 1][size - 2].abs() <= absoluteTolerance) {
          eigenvaluesList.add(h[size - 1][size - 1]);
          size--;
          break;
        }

        // Check for 2x2 block deflation
        if (size >= 3 && h[size - 2][size - 3].abs() <= absoluteTolerance) {
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

      if (iterations == maxIterations) {
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

    // Clean near-zero values and sort descending
    for (int i = 0; i < eigenvaluesList.length; i++) {
      if (eigenvaluesList[i].abs() <= absoluteTolerance) {
        eigenvaluesList[i] = 0;
      }
    }
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
    int maxIterations = 200,
  }) {
    if (isScalar) {
      return <double>[scalarValue];
    }

    final ({int k, Matrix scaled}) normalization = _normalizedByPowerOfTwo();
    final List<double> raw = normalization
        .scaled
        ._realEigenvaluesIgnoringComplexPairsRaw(
          absoluteTolerance: absoluteTolerance,
          maxIterations: maxIterations,
        );
    if (normalization.k == 0) {
      return raw;
    }
    final double undoScale = math.pow(2.0, normalization.k).toDouble();
    return raw.map((double value) => value * undoScale).toList(growable: false);
  }

  List<double> _realEigenvaluesIgnoringComplexPairsRaw({
    required double absoluteTolerance,
    int maxIterations = 200,
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
    final List<List<double>> h = _toHessenberg(absoluteTolerance);

    int size = n;
    final List<double> realEigenvaluesList = <double>[];

    while (size > 2) {
      int iterations = 0;
      while (iterations < maxIterations) {
        if (h[size - 1][size - 2].abs() <= absoluteTolerance) {
          realEigenvaluesList.add(h[size - 1][size - 1]);
          size--;
          break;
        }

        if (size >= 3 && h[size - 2][size - 3].abs() <= absoluteTolerance) {
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

      if (iterations == maxIterations) {
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

    for (int i = 0; i < realEigenvaluesList.length; i++) {
      if (realEigenvaluesList[i].abs() <= absoluteTolerance) {
        realEigenvaluesList[i] = 0;
      }
    }

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
    final double undoScale = math.pow(2.0, normalization.k).toDouble();

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
        (int c) => r == c ? lambdas[r] * undoScale : 0,
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

    final bool inputIsSymmetric = _isApproximatelySymmetric();

    // Symmetric fast path: for a symmetric matrix, the eigenvalue
    // perturbation bound is roughly `eps * ‖A‖` regardless of the
    // matrix's own condition number (Weyl's inequality) — unlike the
    // Denman-Beavers Newton iteration below, whose achievable accuracy on
    // `S` degrades with the *condition number* of A (a symmetric positive
    // definite matrix with condition ~2.5e7, e.g. eigenvalues ~5 and
    // ~2e-7, amplifies Newton's rounding error far more than it amplifies
    // eigenvalue extraction error). So for a symmetric input, computing
    // the eigendecomposition A = P D P^T and forming
    // S = P * diag(sqrt(d_i)) * P^T is both more accurate and avoids the
    // Newton iteration's own numerical-instability failure modes for
    // ill-conditioned inputs entirely. This is attempted first and its
    // result verified against the same residual check the Newton loop
    // uses below; if the check fails (e.g. because the eigenvectors
    // themselves are ill-conditioned, as can happen for near-degenerate
    // eigenvalue clusters), this falls through to the Newton loop rather
    // than trusting an unverified result.
    final Matrix? symmetricEigenSqrt = _trySymmetricEigenSqrt(
      relativeTolerance: relativeTolerance,
      absoluteTolerance: absoluteTolerance,
    );
    if (symmetricEigenSqrt != null) {
      return symmetricEigenSqrt;
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
    final double undoScale = math.pow(2.0, normalization.k / 2.0).toDouble();

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

      if (stepDeviation <= relativeTolerance &&
          residualDeviation <= relativeTolerance) {
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
      return _checkFiniteMatrix(bestCandidate.scale(undoScale));
    }

    throw MatrixDomainError(
      'Square root did not converge for this matrix in the real domain.',
      errorId: CalculatrixErrorId.noConvergence,
    );
  }

  /// Computes the matrix exponential.
  ///
  /// Three cases, tried in order (round 4 correction, rule 2):
  ///
  /// - Complex-form input (`aI + bJ`, 2x2 only): the closed form
  ///   `e^a * (cos(b)*I + sin(b)*J)` — no series at all, so `cos`/`sin`
  ///   (always bounded in `[-1, 1]`) can never blow up the way a
  ///   scaling-and-squaring Taylor series does for a huge `b` (e.g. a
  ///   rotation by `1e16` radians): repeated squaring of an
  ///   only-approximately-bounded intermediate compounds rounding error
  ///   exponentially, which previously produced entries around `1e74` for
  ///   what is mathematically a bounded rotation.
  /// - An exact scalar multiple of the identity (`aI`, any size): `e^a * I`
  ///   directly — exact, and needed for `n != 2` since [isComplexForm] only
  ///   ever applies to 2x2 matrices.
  /// - Otherwise: shift by the mean eigenvalue `μ = trace/n`, so
  ///   `exp(A) = e^μ * exp(A − μI)`, then scaling-and-squaring plus a
  ///   Taylor series on the shifted matrix `N = A − μI`. Subtracting the
  ///   mean off the diagonal before scaling (rather than after, as the
  ///   previous implementation did implicitly by never shifting at all)
  ///   keeps `N` — and therefore every power of it summed in the series —
  ///   far smaller in norm than `A` itself whenever `A`'s eigenvalues are
  ///   clustered (e.g. `[[1,1e20],[0,1]]`, whose shift makes `N` exactly
  ///   nilpotent), and multiplying by `e^μ` only once at the very end,
  ///   rather than folding it into the pre-loop matrix, avoids compounding
  ///   its own rounding error through every squaring step.
  ///
  /// Every matrix/scalar involved is checked finite before it is used in a
  /// loop, and the scaling loop itself carries an explicit iteration bound
  /// independent of the data: a loop whose only exit condition is "norm is
  /// now small enough" can never terminate once fed a non-finite norm
  /// (`Infinity > 0.5` is always true, and `Infinity * 0.5` stays
  /// `Infinity`), which previously made a merely-overflowing input hang
  /// the whole process rather than raising `non-finite`.
  Matrix exp({
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

    final int n = rowCount;
    double traceSum = 0;
    for (int i = 0; i < n; i++) {
      traceSum += _rows[i][i];
    }
    final double mu = _checkFiniteScalar(traceSum / n);
    final Matrix shifted = _checkFiniteMatrix(
      this - Matrix.identity(n).scale(mu),
    );

    Matrix scaledTarget = shifted;
    int scalingSteps = 0;
    const int maxScalingSteps = 2000;
    while (scaledTarget._infinityNorm() > 0.5 &&
        scalingSteps < maxScalingSteps) {
      scaledTarget = scaledTarget.scale(0.5);
      scalingSteps++;
    }
    if (scaledTarget._infinityNorm() > 0.5) {
      // Only reachable if [shifted]'s norm could not be brought under 0.5
      // within the bound above — i.e. it was already non-finite, which
      // [_checkFiniteMatrix] above should have caught, but this is kept as
      // a second, independent guard against ever looping on bad data.
      throw MatrixDomainError(
        'Matrix exponential scaling did not converge.',
        errorId: CalculatrixErrorId.noConvergence,
      );
    }

    // Taylor series: expm(N) = I + N + N²/2! + N³/3! + ...
    Matrix result = Matrix.identity(n);
    Matrix term = Matrix.identity(n);
    double factorial = 1;
    bool converged = false;

    const int maxTerms = 200;
    for (int i = 1; i <= maxTerms; i++) {
      factorial *= i;
      term = term * scaledTarget;
      result = result + term.scale(1 / factorial);

      // Check convergence: if term norm is small enough, stop
      if (term._infinityNorm() / factorial < absoluteTolerance) {
        converged = true;
        break;
      }
    }

    if (!converged) {
      throw MatrixDomainError(
        'Matrix exponential series did not converge.',
        errorId: CalculatrixErrorId.noConvergence,
      );
    }

    for (int i = 0; i < scalingSteps; i++) {
      result = _checkFiniteMatrix(result * result);
    }

    final double expMu = _checkFiniteScalar(math.exp(mu));
    return _checkFiniteMatrix(result.scale(expMu));
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
    // tolerance-free path: their eigenvalues ARE their diagonal entries,
    // exactly, by definition of the characteristic polynomial of a
    // triangular matrix — no QR iteration, no discriminant, no rounding to
    // second-guess. This matters because no *fixed* tolerance can gate a
    // diagonal entry correctly at every scale: `eigenvalueRoundingNoiseTolerance`
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
    } else {
      final List<double> realEigenvalues =
          _realEigenvaluesIgnoringComplexPairs(
            absoluteTolerance: absoluteTolerance,
          );

      // For a non-triangular matrix, eigenvalues are *computed* (Hessenberg
      // reduction plus shifted QR, or the stable 2x2 quadratic formula),
      // so unlike the triangular case above they do carry rounding noise
      // from that pipeline and a real zero eigenvalue can come back as a
      // tiny nonzero double. The floor below is scale-relative
      // (`8 * n * u * ‖A‖∞`, u = double's unit roundoff, n = matrix size)
      // rather than fixed, so it tracks the matrix's own scale instead of
      // rejecting genuinely tiny-but-real eigenvalues (as a fixed floor
      // like eigenvalueRoundingNoiseTolerance did) or accepting rounding
      // noise as real for a huge-scale matrix.
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
  Matrix _principalLogByScalingAndSquaring({
    required double absoluteTolerance,
    required double relativeTolerance,
    int maxSquarings = 60,
    int maxSeriesTerms = 200,
  }) {
    final Matrix identity = Matrix.identity(rowCount);
    const double residualTarget = 1e-2;

    Matrix current = this;
    int squarings = 0;
    while ((current - identity)._infinityNorm() > residualTarget &&
        squarings < maxSquarings) {
      current = current.sqrt(
        absoluteTolerance: absoluteTolerance,
        relativeTolerance: relativeTolerance,
      );
      squarings++;
    }

    if ((current - identity)._infinityNorm() > residualTarget) {
      throw MatrixDomainError(
        'Matrix logarithm did not converge while scaling toward the '
        'identity.',
        errorId: CalculatrixErrorId.noConvergence,
      );
    }

    final Matrix residual = current - identity;
    Matrix term = residual;
    Matrix sum = residual;
    final double seriesTolerance = math.max(
      absoluteTolerance,
      relativeTolerance * math.max(residual._infinityNorm(), 1),
    );

    bool converged = false;
    for (int k = 2; k <= maxSeriesTerms; k++) {
      term = term * residual;
      final double coefficient = k.isOdd ? 1.0 / k : -1.0 / k;
      sum = sum + term.scale(coefficient);

      if (term._infinityNorm() / k < seriesTolerance) {
        converged = true;
        break;
      }
    }

    if (!converged) {
      throw MatrixDomainError(
        'Matrix logarithm Mercator series did not converge.',
        errorId: CalculatrixErrorId.noConvergence,
      );
    }

    return _checkFiniteMatrix(sum.scale(math.pow(2.0, squarings).toDouble()));
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
    if (norm == 0 || !norm.isFinite) {
      return (k: 0, scaled: this);
    }
    final int k = (math.log(norm) / math.ln2).round();
    if (k == 0) {
      return (k: 0, scaled: this);
    }
    final double factor = math.pow(2.0, -k).toDouble();
    return (k: k, scaled: scale(factor));
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

  /// Attempts [sqrt] via eigendecomposition for a symmetric matrix, or
  /// returns `null` if this matrix is not exactly symmetric, has any
  /// negative eigenvalue (the real square root is undefined; the caller
  /// falls through to the Newton loop, which raises the appropriate
  /// domain error), or the reconstructed candidate fails its own residual
  /// check (e.g. a near-degenerate eigenvalue cluster made the computed
  /// eigenvectors themselves inaccurate). See the call site in [sqrt] for
  /// why this is preferred over Denman-Beavers Newton iteration whenever
  /// it applies.
  Matrix? _trySymmetricEigenSqrt({
    required double relativeTolerance,
    required double absoluteTolerance,
  }) {
    if (!_isApproximatelySymmetric()) {
      return null;
    }

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

    // P should be orthogonal (eigenvectors of a symmetric matrix), so
    // P^T approximates P^-1 without the extra numerical work — and error
    // — of an explicit inversion.
    final Matrix candidate = eigen.p * diagSqrt * eigen.p.transpose();

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
