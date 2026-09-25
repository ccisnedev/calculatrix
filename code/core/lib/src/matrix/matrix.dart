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

  /// Computes the inverse directly on this matrix's own entries — no
  /// global power-of-two normalization (round 6 correction, item 10: a
  /// *single* scale factor `c = 2^k` is wrong for a matrix whose entries
  /// themselves span a huge dynamic range, e.g. `diag(1e200, 1e-200)`.
  /// Undoing one global `k` chosen from the matrix's infinity norm (~1e200
  /// here) shrinks the *other* entry (1e-200) by the same factor, which
  /// can underflow it to exact zero — turning a perfectly invertible
  /// diagonal matrix into a false "singular" result — or, for a matrix
  /// like `diag(1e160, 1e-160)`, overflow the rescale-back step to
  /// `Infinity` even though the true inverse is representable in double
  /// precision. Both hazards are specific to a *global* normalization
  /// scheme; they disappear once every entry is left at its own scale and
  /// [_inverseRaw]'s partial pivoting and exact-zero-pivot singularity
  /// test (Higham 2002 Ch. 9) run on the raw matrix directly.
  ///
  /// An exactly diagonal matrix is handled directly (round 6 correction,
  /// item 10's explicit "handle diagonal input directly"): its inverse is
  /// just the entrywise reciprocal of the diagonal, singular only when a
  /// diagonal entry is bit-for-bit zero, with no elimination arithmetic
  /// (and thus no elimination-order rounding) involved at all.
  ///
  /// [_checkFiniteMatrix] runs unconditionally on the result (round 6
  /// correction, item 4): the previous version only checked finiteness on
  /// the "normalization actually did something" branch, so a matrix whose
  /// normalization factor rounded to `k == 0` (e.g.
  /// `[[1e-310,0],[0,1]]`, a subnormal entry whose true reciprocal
  /// `~1e310` overflows double precision) could return a `Matrix`
  /// containing an uncaught `Infinity` instead of throwing. There is now
  /// exactly one return path, and it always passes through this check.
  Matrix _inverse({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    _requireSquare(operation: 'inverse');
    _checkFiniteMatrix(this);

    if (_isExactlyDiagonal()) {
      return _checkFiniteMatrix(_diagonalInverse());
    }

    return _checkFiniteMatrix(_inverseRaw());
  }

  /// Inverts an exactly diagonal matrix entrywise: `diag(d0,...,dn)^-1 ==
  /// diag(1/d0,...,1/dn)`. Singular only when some `di` is bit-for-bit
  /// zero (round 6 correction, item 10).
  Matrix _diagonalInverse() {
    final int size = rowCount;
    final List<List<double>> result = List<List<double>>.generate(
      size,
      (int row) => List<double>.filled(size, 0),
      growable: false,
    );

    for (int i = 0; i < size; i++) {
      final double d = _rows[i][i];
      if (d == 0) {
        throw MatrixDomainError(
          'Matrix is singular and cannot be inverted.',
          errorId: CalculatrixErrorId.singularMatrix,
        );
      }
      result[i][i] = 1 / d;
    }

    return Matrix(result);
  }

  Matrix _inverseRaw() {
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

      // Round 5/6 correction (inverse: LU with partial pivoting, Higham
      // 2002 Ch. 9): singularity is declared only on an exact zero pivot,
      // never on an absolute cutoff compared against the pivot's own
      // magnitude. This runs directly on `_inverse`'s raw (un-normalized,
      // round 6 correction, item 10) matrix, so a genuinely tiny-but-real
      // pivot (e.g. one column scaled far below another by the input's own
      // structure, such as `[[1,1e20],[0,1]]`) is not singular — only a
      // pivot that is bit-for-bit zero (every candidate in the column is
      // zero, meaning the column truly has no component outside the
      // already-eliminated rows) is. A merely-huge-but-finite result is
      // instead caught by `_inverse`'s own unconditional `_checkFiniteMatrix`
      // call on the result.
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
      return _eigenvalues2x2();
    }

    // General NxN (round 6 correction, item 11): genuine Francis
    // double-shift QR on Hessenberg form (Golub & Van Loan, Algorithm
    // 7.5.1/7.5.2), with deflation, exceptional shifts and the 30n bound,
    // accumulating the orthogonal Schur vectors so `A = Q T Q^T`. See
    // [_realSchurDecomposition] for the full citation and the one
    // disclosed implementation-detail deviation (explicit-form shift
    // steps rather than hand-coded implicit bulge-chasing).
    //
    // A complex-conjugate pair anywhere in the spectrum throws — this is
    // the real-only public contract [eigenvalues] has always had.
    final ({List<List<double>> t, List<List<double>> q}) schur =
        _realSchurDecomposition();
    final List<({double im, double re})> spectrum = _schurEigenvalues(
      schur.t,
    );

    final List<double> eigenvaluesList = <double>[];
    for (final ({double im, double re}) eigenvalue in spectrum) {
      if (eigenvalue.im != 0) {
        throw MatrixDomainError(
          'Eigenvalues are undefined in the real domain for this matrix.',
        );
      }
      eigenvaluesList.add(eigenvalue.re);
    }

    eigenvaluesList.sort((double left, double right) => right.compareTo(left));

    return Matrix(
      eigenvaluesList
          .map((double value) => <double>[value])
          .toList(growable: false),
    );
  }

  /// The 2x2 eigenvalue solver (round 6 correction, item 7): delegates
  /// entirely to [_stableRealEigen2x2], which already has no absolute
  /// cutoffs anywhere — its zero-discriminant test is scale-relative
  /// (`eps * (trace^2 + |det|)`) and neither root is ever compared against
  /// a fixed floor. The previous version's `value.abs() <= absoluteTolerance
  /// ? 0 : value` zeroed any eigenvalue at or below a fixed 1e-12 after
  /// this class's matrix-wide power-of-two normalization, which wrongly
  /// discarded a genuinely tiny-but-nonzero eigenvalue whenever the
  /// *other* eigenvalue dominated the normalization's scale choice — e.g.
  /// `[[0,1e20],[1e-20,0]]` normalizes to a matrix whose true eigenvalues
  /// are `~+-1.355e-20`, both of which that fixed cutoff zeroed outright,
  /// producing `{0,0}` instead of the correct `{1,-1}` after rescaling.
  Matrix _eigenvalues2x2() {
    final double a = _rows[0][0];
    final double b = _rows[0][1];
    final double c = _rows[1][0];
    final double d = _rows[1][1];

    final ({bool isComplex, double lambda1, double lambda2}) solved =
        _stableRealEigen2x2(a, b, c, d);

    if (solved.isComplex) {
      throw MatrixDomainError(
        'Eigenvalues are undefined in the real domain for this matrix.',
      );
    }

    final List<double> values = <double>[solved.lambda1, solved.lambda2]
      ..sort((double left, double right) => right.compareTo(left));

    return Matrix(
      values.map((double value) => <double>[value]).toList(growable: false),
    );
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

  /// Reduces the matrix to upper Hessenberg form using Householder
  /// reflections, accumulating the orthogonal reduction `Q0` so that
  /// `h == Q0^T * this * Q0` (round 6 correction, item 11: the previous
  /// `_toHessenberg` discarded the reflectors instead of accumulating
  /// them, which was sufficient for eigenvalues alone but not for the
  /// Schur vectors [_realSchurDecomposition] now needs to build on top).
  ///
  /// The trailing "clean sub-subdiagonal entries" step no longer compares
  /// against an absolute cutoff (round 6 correction, item 6's underlying
  /// pattern): a Hessenberg reduction guarantees those entries are exactly
  /// zero mathematically, so whatever floating-point noise landed there is
  /// unconditionally zeroed as a structural fact, not approximated as
  /// "small enough".
  ({List<List<double>> h, List<List<double>> q}) _hessenbergWithSchurVectors() {
    final int n = rowCount;
    final List<List<double>> h = List<List<double>>.generate(
      n,
      (int row) => List<double>.from(_rows[row]),
      growable: false,
    );
    final List<List<double>> q = List<List<double>>.generate(
      n,
      (int row) => List<double>.generate(
        n,
        (int column) => row == column ? 1.0 : 0.0,
        growable: false,
      ),
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

      if (norm == 0) {
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
      if (vNorm == 0) {
        continue;
      }
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

      // Accumulate into Q0: Q0[:, k+1:n] -= 2*(Q0[:,k+1:n]*v)*v^T
      for (int i = 0; i < n; i++) {
        double dot = 0;
        for (int j = 0; j < m; j++) {
          dot += q[i][k + 1 + j] * x[j];
        }
        for (int j = 0; j < m; j++) {
          q[i][k + 1 + j] -= 2 * dot * x[j];
        }
      }
    }

    // Structurally exact zero below the subdiagonal — see doc comment.
    for (int i = 2; i < n; i++) {
      for (int j = 0; j < i - 1; j++) {
        h[i][j] = 0;
      }
    }

    return (h: h, q: q);
  }

  /// Builds the Householder vector that reflects [w] onto a multiple of
  /// the first standard basis vector, or `null` if [w] is already exactly
  /// zero (no reflection needed — an exact structural fact, not an
  /// absolute-cutoff judgment call).
  static List<double>? _householderVector(List<double> w) {
    final int len = w.length;
    double norm = 0;
    for (int i = 0; i < len; i++) {
      norm += w[i] * w[i];
    }
    norm = math.sqrt(norm);
    if (norm == 0) {
      return null;
    }

    final List<double> v = List<double>.from(w);
    final double sign = v[0] >= 0 ? 1 : -1;
    v[0] += sign * norm;

    double vNorm = 0;
    for (int i = 0; i < len; i++) {
      vNorm += v[i] * v[i];
    }
    vNorm = math.sqrt(vNorm);
    if (vNorm == 0) {
      return null;
    }
    for (int i = 0; i < len; i++) {
      v[i] /= vNorm;
    }
    return v;
  }

  /// One Francis double-shift QR step (Golub & Van Loan, Algorithm 7.5.1)
  /// on the active block `h[lo..hi, lo..hi]` (`hi - lo >= 2`), applied as a
  /// similarity transform to the whole working matrix [h] and accumulated
  /// into [q].
  ///
  /// Implementation note (disclosed per this round's "report accurately
  /// what is implemented" instruction): this forms the *explicit* shifted
  /// matrix `M = Ha^2 - shiftSum*Ha + shiftProduct*I` for the active block
  /// `Ha` and takes its dense Householder QR factorization `M = Z*R`,
  /// using `Z` as the similarity transform, rather than hand-coding the
  /// implicit bulge-chase recurrence (the `x, y, z` shortcut through
  /// `Ha`'s own entries) that Algorithm 7.5.1 uses to avoid ever forming
  /// `M`. The Implicit Q Theorem (G&VL, Theorem 7.4.2) guarantees these
  /// produce the same next Hessenberg iterate (up to column sign) for an
  /// unreduced Hessenberg `Ha` — and, because `Ha` is Hessenberg, `Ha^2`
  /// (and so `M`) has lower bandwidth exactly 2, which means a *plain*,
  /// unmodified Householder QR sweep of `M` automatically produces
  /// reflectors confined to 3 (then 2, then 1) consecutive rows, i.e. it
  /// mechanically *is* the bulge-chase, just derived by forming `M`
  /// explicitly (O(n) more arithmetic per step, an accepted
  /// correctness-first trade-off) instead of reading `x, y, z` off `Ha`
  /// directly.
  static void _francisDoubleShiftStep(
    List<List<double>> h,
    List<List<double>> q,
    int lo,
    int hi,
    int n,
    double shiftSum,
    double shiftProduct,
  ) {
    final int m = hi - lo + 1;

    final List<List<double>> ha = List<List<double>>.generate(
      m,
      (int i) => List<double>.generate(
        m,
        (int j) => h[lo + i][lo + j],
        growable: false,
      ),
      growable: false,
    );

    final List<List<double>> shiftMatrix = List<List<double>>.generate(m, (
      int i,
    ) {
      return List<double>.generate(m, (int j) {
        double sum = 0;
        for (int k = 0; k < m; k++) {
          sum += ha[i][k] * ha[k][j];
        }
        sum -= shiftSum * ha[i][j];
        if (i == j) {
          sum += shiftProduct;
        }
        return sum;
      }, growable: false);
    }, growable: false);

    // Dense Householder QR of shiftMatrix, accumulating Z as the product
    // of its reflectors (Z := Z * P_k for each step k).
    final List<List<double>> z = List<List<double>>.generate(
      m,
      (int i) => List<double>.generate(
        m,
        (int j) => i == j ? 1.0 : 0.0,
        growable: false,
      ),
      growable: false,
    );

    for (int k = 0; k < m - 1; k++) {
      final int len = m - k;
      final List<double> column = List<double>.generate(
        len,
        (int i) => shiftMatrix[k + i][k],
        growable: false,
      );
      final List<double>? v = _householderVector(column);
      if (v == null) {
        continue;
      }

      for (int j = k; j < m; j++) {
        double dot = 0;
        for (int i = 0; i < len; i++) {
          dot += v[i] * shiftMatrix[k + i][j];
        }
        if (dot == 0) {
          continue;
        }
        for (int i = 0; i < len; i++) {
          shiftMatrix[k + i][j] -= 2 * v[i] * dot;
        }
      }

      for (int i = 0; i < m; i++) {
        double dot = 0;
        for (int j = 0; j < len; j++) {
          dot += z[i][k + j] * v[j];
        }
        if (dot == 0) {
          continue;
        }
        for (int j = 0; j < len; j++) {
          z[i][k + j] -= 2 * dot * v[j];
        }
      }
    }

    // Similarity transform Ha_new = Z^T * Ha * Z, applied to the whole
    // working matrix: h[lo:hi+1, :] := Z^T * h[lo:hi+1, :], then
    // h[:, lo:hi+1] := h[:, lo:hi+1] * Z, and the same on the right for q.
    for (int col = 0; col < n; col++) {
      final List<double> src = List<double>.generate(
        m,
        (int i) => h[lo + i][col],
        growable: false,
      );
      for (int i = 0; i < m; i++) {
        double sum = 0;
        for (int k = 0; k < m; k++) {
          sum += z[k][i] * src[k];
        }
        h[lo + i][col] = sum;
      }
    }

    for (int row = 0; row < n; row++) {
      final List<double> src = List<double>.generate(
        m,
        (int j) => h[row][lo + j],
        growable: false,
      );
      for (int j = 0; j < m; j++) {
        double sum = 0;
        for (int k = 0; k < m; k++) {
          sum += src[k] * z[k][j];
        }
        h[row][lo + j] = sum;
      }
    }

    for (int row = 0; row < n; row++) {
      final List<double> src = List<double>.generate(
        m,
        (int j) => q[row][lo + j],
        growable: false,
      );
      for (int j = 0; j < m; j++) {
        double sum = 0;
        for (int k = 0; k < m; k++) {
          sum += src[k] * z[k][j];
        }
        q[row][lo + j] = sum;
      }
    }
  }

  /// Real Schur decomposition `this == Q * T * Q^T` (round 6 correction,
  /// item 11): Hessenberg reduction ([_hessenbergWithSchurVectors]) then
  /// Francis double-shift QR iteration ([_francisDoubleShiftStep]) with
  /// deflation, exceptional shifts and the `30n` iteration bound, on a
  /// matrix with `rowCount > 2` (the `rowCount == 2` case is trivially its
  /// own 1-block real Schur form and is handled by callers directly via
  /// [_stableRealEigen2x2] without going through this method at all).
  ///
  /// `T` is quasi-upper-triangular: 1x1 diagonal blocks for real
  /// eigenvalues, 2x2 diagonal blocks for complex-conjugate pairs. `Q` is
  /// orthogonal — the accumulated Schur vectors.
  ///
  /// Deflation test (round 5 correction, kept): the LAPACK criterion
  /// `|h[i][i-1]| <= eps*(|h[i-1][i-1]| + |h[i][i]|)`, scale-relative
  /// rather than a fixed absolute floor.
  ///
  /// Exceptional shift (round 4 correction, case G's remedy, adapted to
  /// the double-shift form used here): every 11th QR step taken without a
  /// deflation substitutes an ad hoc repeated shift derived from nearby
  /// subdiagonal magnitudes, which breaks the stagnation a plain Wilkinson
  /// double shift can hit on certain spectra (e.g. a permutation matrix's
  /// eigenvalues sitting equally spaced on the unit circle).
  ///
  /// Iteration bound: `30*n` total QR steps taken without an intervening
  /// deflation (Higham 2008 Ch. 2 / LAPACK's own convergence budget) — a
  /// data-independent loop bound that throws `no-convergence` if
  /// exhausted, never a silent fallback.
  ({List<List<double>> t, List<List<double>> q}) _realSchurDecomposition() {
    final int n = rowCount;
    final ({List<List<double>> h, List<List<double>> q}) hessenberg =
        _hessenbergWithSchurVectors();
    final List<List<double>> h = hessenberg.h;
    final List<List<double>> q = hessenberg.q;

    const double eps = CalculatrixNumericPolicy.machineEpsilon;
    final int maxIterations = 30 * n;
    int iterationsSinceDeflation = 0;

    int hi = n - 1;
    while (hi > 0) {
      int lo = hi;
      while (lo > 0) {
        final bool negligible =
            h[lo][lo - 1].abs() <=
            eps * (h[lo - 1][lo - 1].abs() + h[lo][lo].abs());
        if (negligible) {
          h[lo][lo - 1] = 0;
          break;
        }
        lo--;
      }

      if (lo == hi) {
        // h[hi][hi-1] is negligible: hi is an isolated 1x1 eigenvalue.
        hi -= 1;
        iterationsSinceDeflation = 0;
        continue;
      }

      if (hi - lo == 1) {
        // An unreduced 2x2 trailing block: a valid Schur block either way
        // (real pair or complex-conjugate pair) — leave it and deflate.
        hi -= 2;
        iterationsSinceDeflation = 0;
        continue;
      }

      iterationsSinceDeflation++;
      if (iterationsSinceDeflation > maxIterations) {
        throw MatrixDomainError(
          'Eigenvalues did not converge for this matrix.',
          errorId: CalculatrixErrorId.noConvergence,
        );
      }

      double shiftSum;
      double shiftProduct;
      if (iterationsSinceDeflation % 11 == 0) {
        final double adHoc =
            0.75 * (h[hi][hi - 1].abs() + h[hi - 1][hi - 2].abs());
        shiftSum = 2 * adHoc;
        shiftProduct = adHoc * adHoc;
      } else {
        final double a = h[hi - 1][hi - 1];
        final double b = h[hi - 1][hi];
        final double c = h[hi][hi - 1];
        final double d = h[hi][hi];
        shiftSum = a + d;
        shiftProduct = (a * d) - (b * c);
      }

      _francisDoubleShiftStep(h, q, lo, hi, n, shiftSum, shiftProduct);

      // The explicit-form similarity transform above is only *provably*
      // band-limited (see [_francisDoubleShiftStep]'s doc comment) in
      // exact arithmetic: in floating point it leaves rounding noise on
      // the order of a few ULPs in entries that are structurally exactly
      // zero for a Hessenberg matrix (`h[i][j]` for `i > j+1`), because the
      // dense QR of `M` and the full-width similarity transform it drives
      // — applied across every row and column of the *whole* working
      // matrix, not just the local `[lo, hi]` block, so that a similarity
      // transform on a sub-block stays correct for the matrix as a whole
      // — do not themselves know about the band. This reaches beyond the
      // active block too: a row below `hi` that was already deflated
      // (its own sub-subdiagonal entries columns `lo..hi` explicitly
      // zeroed by an earlier deflation) gets touched again by this step's
      // right-multiply across all `n` rows, turning what was an exact
      // zero back into a few-ULP residue. Left alone, that noise would
      // make [_schurEigenvalues]'s exact-zero block-boundary test wrongly
      // read two adjacent Schur blocks as fused into one larger block —
      // this is exactly what round 6's own probe against a 5x5 symmetric
      // tridiagonal matrix caught: three eigenvalues collapsed to one
      // repeated (wrong) value where two isolated blocks should have
      // stayed separate. Re-imposing the structural zero across the
      // *entire* matrix here — unconditional, not a tolerance comparison,
      // since these entries are exactly zero in exact arithmetic — keeps
      // that invariant true after every step, the same way
      // [_hessenbergWithSchurVectors] establishes it once at the start.
      for (int row = 2; row < n; row++) {
        for (int column = 0; column < row - 1; column++) {
          h[row][column] = 0;
        }
      }
    }

    return (t: h, q: q);
  }

  /// Reads the full spectrum (real and complex) off a real-Schur
  /// quasi-triangular matrix [t] (round 6 correction, item 11), scanning
  /// its 1x1 and 2x2 diagonal blocks. A 2x2 block's eigenvalues are found
  /// via [_stableRealEigen2x2] — if complex, both conjugates are reported.
  static List<({double im, double re})> _schurEigenvalues(
    List<List<double>> t,
  ) {
    final int n = t.length;
    final List<({double im, double re})> result = <({double im, double re})>[];
    int i = 0;
    while (i < n) {
      if (i == n - 1 || t[i + 1][i] == 0) {
        result.add((im: 0, re: t[i][i]));
        i += 1;
        continue;
      }

      final double a = t[i][i];
      final double b = t[i][i + 1];
      final double c = t[i + 1][i];
      final double d = t[i + 1][i + 1];
      final ({bool isComplex, double lambda1, double lambda2}) solved =
          _stableRealEigen2x2(a, b, c, d);

      if (solved.isComplex) {
        final double re = (a + d) / 2;
        final double det = (a * d) - (b * c);
        final double discriminant = ((a + d) * (a + d)) - (4 * det);
        final double im = math.sqrt(-discriminant) / 2;
        result.add((im: im, re: re));
        result.add((im: -im, re: re));
      } else {
        result.add((im: 0, re: solved.lambda1));
        result.add((im: 0, re: solved.lambda2));
      }
      i += 2;
    }
    return result;
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

  /// Same stable quadratic-formula solver as [_stableRealEigen2x2], but
  /// with no scaled zero-discriminant tolerance: the discriminant's own
  /// computed sign is trusted directly, and only a bit-exact zero counts
  /// as a repeated root.
  ///
  /// [_stableRealEigen2x2] is tuned for eigenvalues that already went
  /// through the iterative Hessenberg/QR pipeline, where genuine rounding
  /// noise from many prior floating-point steps needs a scaled tolerance
  /// to be recognized as "really zero". The general-2x2 closed forms in
  /// [_general2x2Exp], [_general2x2Log] and [_general2x2RealPower] instead
  /// classify a raw, directly-supplied 2x2 block, computing the
  /// discriminant in a single step from the user's own entries. There, a
  /// small-but-genuinely-negative discriminant (for example, from
  /// individually tiny off-diagonal entries) is not rounding noise — it is
  /// the correct answer, and swallowing it as "zero" misclassifies a real
  /// complex-conjugate pair as a repeated real eigenvalue. That distinction
  /// matters for [_general2x2Log] and the real branch of
  /// [_general2x2RealPower], both of which reject a negative real
  /// eigenvalue but accept any complex pair.
  ///
  /// Uses the centered discriminant `halfDiff^2 + b*c` (with
  /// `m = (a+d)/2`, `halfDiff = (a-d)/2`), not `trace^2 - 4*det`. The two
  /// are algebraically identical (`trace^2 - 4*det = 4*(halfDiff^2+b*c)`),
  /// but for entries around 1e8 or larger, `trace*trace` and `4*det` are
  /// each individually rounded to the nearest double at a magnitude far
  /// above the true discriminant, so their difference can lose most or
  /// all of its significant digits. The centered form never separately
  /// forms those large intermediate values, so it does not suffer this
  /// cancellation. On the complex-pair branch, `m` and `w` (the rotation
  /// frequency, `sqrt(-discriminant)`) are returned directly so callers
  /// never need to recompute the discriminant themselves.
  static ({bool isComplex, double lambda1, double lambda2, double m, double w})
  _exactRealEigen2x2(double a, double b, double c, double d) {
    final double m = (a + d) / 2;
    final double halfDiff = (a - d) / 2;
    final double det = (a * d) - (b * c);
    final double discriminant = (halfDiff * halfDiff) + (b * c);

    if (discriminant < 0) {
      final double w = math.sqrt(-discriminant);
      return (isComplex: true, lambda1: 0, lambda2: 0, m: m, w: w);
    }

    if (discriminant == 0) {
      return (isComplex: false, lambda1: m, lambda2: m, m: m, w: 0);
    }

    final double sqrtD = math.sqrt(discriminant);
    final double signM = m >= 0 ? 1.0 : -1.0;
    final double q = m + (signM * sqrtD);
    final double lambda1 = q;
    final double lambda2 = q == 0 ? m - (signM * sqrtD) : det / q;
    return (isComplex: false, lambda1: lambda1, lambda2: lambda2, m: m, w: 0);
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

  /// Computes the principal square root.
  ///
  /// Only five input classes are supported, each with an exact or robust
  /// closed-form algorithm (see [_matrixRealPower] for the shared
  /// dispatcher used by both this and [power]'s non-integer real-exponent
  /// case):
  ///
  /// - Scalars (1x1): `sqrt(v)` directly, or `i*sqrt(-v)` for a negative
  ///   scalar.
  /// - Diagonal matrices: entrywise.
  /// - Exactly symmetric matrices: cyclic Jacobi eigendecomposition (Golub
  ///   and Van Loan, "Matrix Computations", section 8.5), then
  ///   `f(A) = Q * f(Lambda) * Q^T`.
  /// - General 2x2 matrices: the divided-difference closed form
  ///   `f(A) = c0*I + c1*A` (Higham, "Functions of Matrices", section 1.2).
  /// - Any other input: [CalculatrixErrorId.unsupportedMatrixFunction].
  Matrix sqrt({int maxSweeps = 50}) {
    _requireSquare(operation: 'square root');
    _checkFiniteMatrix(this);

    if (isScalar) {
      final double source = scalarValue;
      if (source < 0) {
        return Matrix.i.scale(math.sqrt(-source));
      }
      return Matrix.scalar(math.sqrt(source));
    }

    return _matrixRealPower(0.5, maxSweeps: maxSweeps, operation: 'square root');
  }

  /// Computes the matrix exponential.
  ///
  /// Only five input classes are supported, each with an exact or robust
  /// closed-form algorithm:
  ///
  /// - Scalars (1x1): `e^v` directly.
  /// - Complex-form input (`aI + bJ`, 2x2 only): the closed form
  ///   `e^a * (cos(b)*I + sin(b)*J)` — no series at all, so `cos`/`sin`
  ///   (always bounded in `[-1, 1]`) can never blow up the way a
  ///   scaling-and-squaring series does for a huge `b` (e.g. a rotation by
  ///   `1e16` radians): repeated squaring of an only-approximately-bounded
  ///   intermediate compounds rounding error exponentially.
  /// - Exactly diagonal: `exp` decouples entrywise, exact to the last ULP
  ///   per entry (`math.exp`).
  /// - Exactly symmetric matrices: cyclic Jacobi eigendecomposition (Golub
  ///   and Van Loan, "Matrix Computations", section 8.5), then
  ///   `f(A) = Q * f(Lambda) * Q^T`.
  /// - General 2x2 matrices: the divided-difference closed form
  ///   `f(A) = c0*I + c1*A` (Higham, "Functions of Matrices", section 1.2),
  ///   anchored at the smaller-magnitude eigenvalue for the real-pair
  ///   branch and using `sin(w)/w` computed via a short Taylor series near
  ///   `w = 0` for the complex-pair branch (see [_general2x2Exp],
  ///   [_sinOverX]).
  /// - Any other input: [CalculatrixErrorId.unsupportedMatrixFunction].
  ///
  /// Every matrix/scalar involved is checked finite before it is used.
  Matrix exp() {
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

    if (_isExactlyDiagonal()) {
      return _diagonalRealFunction((double v) => math.exp(v));
    }

    if (_isExactlySymmetric()) {
      return _symmetricRealFunction((double v) => math.exp(v), maxSweeps: 50);
    }

    if (rowCount == 2) {
      return _general2x2Exp();
    }

    throw _unsupportedMatrixFunction('matrix exponential');
  }

  /// Computes the principal matrix logarithm.
  ///
  /// Only five input classes are supported, mirroring [sqrt]/[exp]:
  ///
  /// - Scalars (1x1): `ln(v)` for `v > 0`, the complex-form matrix
  ///   `ln(|v|) + pi*i` for `v < 0`, and [CalculatrixErrorId.logUndefined]
  ///   for `v == 0`.
  /// - Complex-form input (`aI + bJ`, 2x2 only): the principal branch
  ///   `ln(r) + theta*i`, where `r = sqrt(a^2 + b^2)`, `theta = atan2(b, a)`.
  /// - Diagonal matrices: entrywise, undefined for a non-positive entry.
  /// - Exactly symmetric matrices: cyclic Jacobi eigendecomposition, then
  ///   `f(A) = Q * f(Lambda) * Q^T`, undefined for a non-positive
  ///   eigenvalue.
  /// - General 2x2 matrices: the divided-difference closed form
  ///   `f(A) = c0*I + c1*A` (Higham, "Functions of Matrices", section 1.2),
  ///   using log1p-style formulas for the divided difference near-repeated
  ///   eigenvalues; undefined for a negative or zero real eigenvalue.
  /// - Any other input: [CalculatrixErrorId.unsupportedMatrixFunction].
  Matrix log() {
    _requireSquare(operation: 'logarithm');
    _checkFiniteMatrix(this);

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

    if (_isExactlyDiagonal()) {
      return _diagonalRealFunction((double v) {
        if (v <= 0) {
          throw MatrixDomainError(
            'Logarithm is undefined for matrices with non-positive real '
            'eigenvalues.',
            errorId: CalculatrixErrorId.logUndefined,
          );
        }
        return math.log(v);
      });
    }

    if (_isExactlySymmetric()) {
      return _symmetricRealFunction((double v) {
        if (v <= 0) {
          throw MatrixDomainError(
            'Logarithm is undefined for matrices with non-positive real '
            'eigenvalues.',
            errorId: CalculatrixErrorId.logUndefined,
          );
        }
        return math.log(v);
      }, maxSweeps: 50);
    }

    if (rowCount == 2) {
      return _general2x2Log();
    }

    throw _unsupportedMatrixFunction('matrix logarithm');
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

    return _matrixRealPower(y, maxSweeps: 50, operation: 'real matrix power');
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

  /// Whether this square matrix is exactly symmetric: `A[i][j] == A[j][i]`
  /// for every pair, checked with a plain `==`, not a tolerance (the
  /// coordinator's decision: symmetric-matrix dispatch is by exact
  /// equality only, so a matrix that is merely symmetric up to rounding
  /// noise is handled by the general 2x2 closed form instead, never by
  /// eigendecomposition).
  bool _isExactlySymmetric() {
    for (int r = 0; r < rowCount; r++) {
      for (int c = r + 1; c < columnCount; c++) {
        if (_rows[r][c] != _rows[c][r]) return false;
      }
    }
    return true;
  }

  /// The Frobenius norm (`sqrt(sum of squares of every entry)`), used by
  /// [_cyclicJacobiEigendecomposition] both as the finiteness guard before
  /// its sweep loop runs and as the scale against which convergence is
  /// judged.
  ///
  /// Scales by the matrix's own [_maxAbsEntry] before squaring. Squaring an
  /// individual entry directly overflows once that entry exceeds about
  /// 1.34e154 (`sqrt(double.maxFinite)`), even though the true Frobenius
  /// norm of a matrix containing it can be far below `double.maxFinite`
  /// and perfectly representable. Dividing every entry by the largest one
  /// first keeps every squared term at most `1.0` before the sum is scaled
  /// back up, so this never overflows unless the true norm itself would.
  double _frobeniusNorm() {
    final double scale = _maxAbsEntry();
    if (scale == 0) {
      return 0;
    }
    double sumSquares = 0;
    for (final List<double> row in _rows) {
      for (final double value in row) {
        final double scaled = value / scale;
        sumSquares += scaled * scaled;
      }
    }
    return scale * math.sqrt(sumSquares);
  }

  /// Cyclic Jacobi eigendecomposition of an exactly symmetric matrix (Golub
  /// and Van Loan, "Matrix Computations", section 8.5): repeated sweeps of
  /// plane (Givens) rotations, each chosen to zero one off-diagonal pair
  /// `(p, q)`, accumulated into an orthogonal `Q` such that
  /// `Qᵀ * this * Q` converges to a diagonal matrix of eigenvalues.
  ///
  /// Convergence is judged by the off-diagonal Frobenius norm relative to
  /// the matrix's own (constant) Frobenius norm, against
  /// [CalculatrixNumericPolicy.machineEpsilon] — never an absolute
  /// threshold, so this is equally sound at any scale. The sweep count is
  /// bounded by [maxSweeps] (data-independent); exceeding it without
  /// converging raises [CalculatrixErrorId.noConvergence] rather than
  /// returning an under-converged result.
  ({Matrix q, List<double> lambda}) _cyclicJacobiEigendecomposition({
    required int maxSweeps,
  }) {
    final int n = rowCount;
    final double frobeniusNormOriginal = _frobeniusNorm();
    if (!frobeniusNormOriginal.isFinite) {
      throw MatrixDomainError(
        'Matrix Frobenius norm overflowed to a non-finite value before the '
        'Jacobi eigendecomposition ran.',
        errorId: CalculatrixErrorId.nonFinite,
      );
    }

    final List<List<double>> a = List<List<double>>.generate(
      n,
      (int r) => List<double>.from(_rows[r]),
      growable: false,
    );
    final List<List<double>> v = List<List<double>>.generate(
      n,
      (int r) => List<double>.generate(
        n,
        (int c) => r == c ? 1.0 : 0.0,
        growable: false,
      ),
      growable: false,
    );

    const double convergenceTolerance = CalculatrixNumericPolicy.machineEpsilon;
    bool converged = frobeniusNormOriginal == 0;
    // Jacobi rotations are orthogonal similarity transforms, so every
    // entry of [a] stays bounded by frobeniusNormOriginal throughout every
    // sweep. Scaling the per-sweep off-diagonal sum of squares by the same
    // value avoids the overflow-on-squaring problem [_frobeniusNorm]'s own
    // doc comment describes, for the same huge-entry inputs.
    final double sweepScale = frobeniusNormOriginal == 0 ? 1 : frobeniusNormOriginal;

    for (int sweep = 0; sweep < maxSweeps && !converged; sweep++) {
      for (int p = 0; p < n - 1; p++) {
        for (int q = p + 1; q < n; q++) {
          final double apq = a[p][q];
          if (apq == 0) continue;

          final double app = a[p][p];
          final double aqq = a[q][q];
          final double theta = (aqq - app) / (2 * apq);
          final double t;
          if (theta == 0) {
            t = 1.0;
          } else {
            final double signTheta = theta >= 0 ? 1.0 : -1.0;
            t = signTheta / (theta.abs() + math.sqrt(theta * theta + 1));
          }
          final double c = 1 / math.sqrt(t * t + 1);
          final double s = t * c;

          for (int i = 0; i < n; i++) {
            if (i != p && i != q) {
              final double aip = a[i][p];
              final double aiq = a[i][q];
              final double newAip = c * aip - s * aiq;
              final double newAiq = s * aip + c * aiq;
              a[i][p] = newAip;
              a[p][i] = newAip;
              a[i][q] = newAiq;
              a[q][i] = newAiq;
            }
          }
          a[p][p] = app - t * apq;
          a[q][q] = aqq + t * apq;
          a[p][q] = 0;
          a[q][p] = 0;

          for (int i = 0; i < n; i++) {
            final double vip = v[i][p];
            final double viq = v[i][q];
            v[i][p] = c * vip - s * viq;
            v[i][q] = s * vip + c * viq;
          }
        }
      }

      double offDiagonalSumSquares = 0;
      for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
          if (i != j) {
            final double scaled = a[i][j] / sweepScale;
            offDiagonalSumSquares += scaled * scaled;
          }
        }
      }
      final double offDiagonalNorm = sweepScale * math.sqrt(offDiagonalSumSquares);
      converged = offDiagonalNorm <= convergenceTolerance * frobeniusNormOriginal;
    }

    if (!converged) {
      throw MatrixDomainError(
        'Cyclic Jacobi eigendecomposition did not converge within the '
        'sweep budget.',
        errorId: CalculatrixErrorId.noConvergence,
      );
    }

    final List<double> lambda = List<double>.generate(
      n,
      (int i) => a[i][i],
      growable: false,
    );
    return (q: Matrix(v), lambda: lambda);
  }

  /// Applies [f] entrywise to this exactly diagonal matrix's diagonal,
  /// zeroing every off-diagonal entry — the shared building block for
  /// [exp]/[log]/[sqrt]/[power]'s diagonal-matrix class.
  Matrix _diagonalRealFunction(double Function(double value) f) {
    final List<List<double>> resultRows = List<List<double>>.generate(
      rowCount,
      (int r) => List<double>.generate(
        columnCount,
        (int c) => r == c ? _checkFiniteScalar(f(_rows[r][c])) : 0,
        growable: false,
      ),
      growable: false,
    );
    return Matrix(resultRows);
  }

  /// Applies [f] to each eigenvalue found by [_cyclicJacobiEigendecomposition]
  /// and reconstructs `f(A) = Q * f(Lambda) * Qᵀ` — the shared building
  /// block for [exp]/[log]/[sqrt]/[power]'s exactly-symmetric-matrix class.
  Matrix _symmetricRealFunction(
    double Function(double value) f, {
    required int maxSweeps,
  }) {
    final ({Matrix q, List<double> lambda}) eigen =
        _cyclicJacobiEigendecomposition(maxSweeps: maxSweeps);
    final int n = rowCount;
    final List<double> fLambda = List<double>.generate(
      n,
      (int i) => _checkFiniteScalar(f(eigen.lambda[i])),
      growable: false,
    );
    final Matrix fDiag = Matrix(
      List<List<double>>.generate(
        n,
        (int r) => List<double>.generate(
          n,
          (int c) => r == c ? fLambda[r] : 0,
          growable: false,
        ),
        growable: false,
      ),
    );
    return _checkFiniteMatrix(eigen.q * fDiag * eigen.q.transpose());
  }

  /// A real non-integer power `v^y` for a single diagonal/symmetric
  /// eigenvalue, per the coordinator's scope: `v > 0` uses ordinary real
  /// exponentiation (special-cased to `math.sqrt` for `y == 0.5`, for
  /// maximum precision parity with the diagonal-sqrt fast path); `v == 0`
  /// with `y > 0` is `0`; `v == 0` with `y <= 0` and any `v < 0` are
  /// [CalculatrixErrorId.logUndefined] (a non-integer real exponent has no
  /// real value there). `y` is always finite and non-integer here, since
  /// an integer (including `y == 0`) exponent is routed to
  /// [_integerMatrixPower] before this is ever reached.
  double _realScalarPower(double v, double y) {
    if (v > 0) {
      return y == 0.5 ? math.sqrt(v) : math.pow(v, y).toDouble();
    }
    if (v == 0) {
      if (y > 0) return 0;
      throw MatrixDomainError(
        'A zero eigenvalue cannot be raised to a non-positive real power.',
        errorId: CalculatrixErrorId.logUndefined,
      );
    }
    throw MatrixDomainError(
      'A negative eigenvalue cannot be raised to a non-integer real power '
      'in the real domain.',
      errorId: CalculatrixErrorId.logUndefined,
    );
  }

  /// Shared dispatcher for a real non-integer matrix power `A^y`, used by
  /// both [sqrt] (`y == 0.5`) and [_powerByScalarExponent]'s general
  /// non-integer case. Tries the diagonal, exactly-symmetric and general
  /// 2x2 closed forms in order, and raises
  /// [CalculatrixErrorId.unsupportedMatrixFunction] for anything else.
  Matrix _matrixRealPower(
    double y, {
    required int maxSweeps,
    required String operation,
  }) {
    if (_isExactlyDiagonal()) {
      return _diagonalRealFunction((double v) => _realScalarPower(v, y));
    }
    if (_isExactlySymmetric()) {
      return _symmetricRealFunction(
        (double v) => _realScalarPower(v, y),
        maxSweeps: maxSweeps,
      );
    }
    if (rowCount == 2) {
      return _general2x2RealPower(y);
    }
    throw _unsupportedMatrixFunction(operation);
  }

  /// Builds `c0*I + c1*A`, the Hermite-interpolation / divided-difference
  /// closed form `f(A)` for a general 2x2 matrix (Higham, "Functions of
  /// Matrices", section 1.2), shared by [_general2x2Exp], [_general2x2Log]
  /// and [_general2x2RealPower].
  Matrix _c0IPlusC1A(double c0, double c1) {
    final int n = rowCount;
    return Matrix(
      List<List<double>>.generate(
        n,
        (int r) => List<double>.generate(
          n,
          (int c) => (r == c ? c0 : 0) + c1 * _rows[r][c],
          growable: false,
        ),
        growable: false,
      ),
    );
  }

  /// `sin(x) / x`, computed via a short Taylor series (`1 - x^2/6`) below
  /// `sqrt(machineEpsilon)` to avoid dividing two quantities that both
  /// vanish as `x -> 0`. Used by [_general2x2Exp]'s complex-eigenvalue-pair
  /// branch.
  static double _sinOverX(double x) {
    const double seriesThreshold = 1.4901161193847656e-08;
    if (x.abs() < seriesThreshold) return 1 - (x * x) / 6;
    return math.sin(x) / x;
  }

  /// `log(1 + x)`, computed via Kahan's cancellation-correcting trick so
  /// that a tiny `x` does not lose precision to `1.0 + x` rounding to
  /// exactly `1.0`. Used by [_general2x2Log]/[_general2x2RealPower] for the
  /// divided difference between two close eigenvalues.
  static double _log1p(double x) {
    final double u = 1.0 + x;
    if (u == 1.0) return x;
    return math.log(u) * (x / (u - 1.0));
  }

  /// `exp(x) - 1`, computed via Kahan's cancellation-correcting trick, the
  /// `expm1` counterpart to [_log1p]. Used by [_general2x2RealPower]'s
  /// distinct-positive-eigenvalues branch.
  static double _expm1(double x) {
    final double u = math.exp(x);
    if (u == 1.0) return x;
    if (u - 1.0 == -1.0) return -1.0;
    return (u - 1.0) * x / math.log(u);
  }

  /// The typed domain error for any input outside the five supported
  /// matrix-function classes (scalar, complex-form, diagonal, exactly
  /// symmetric, general 2x2).
  MatrixDomainError _unsupportedMatrixFunction(String operation) {
    return MatrixDomainError(
      'Cannot compute the $operation for this matrix: only scalars, the '
      'complex form a*I+b*J, diagonal matrices, exactly symmetric matrices '
      '(cyclic Jacobi eigendecomposition) and general 2x2 matrices (a '
      'stable divided-difference closed form) are supported.',
      errorId: CalculatrixErrorId.unsupportedMatrixFunction,
    );
  }

  /// [exp] for a general (non-diagonal, non-exactly-symmetric) 2x2 matrix
  /// via the divided-difference closed form (Higham, "Functions of
  /// Matrices", section 1.2): `f(A) = c0*I + c1*A`.
  ///
  /// Real-eigenvalue branch (round 8 correction, finding 1): anchored at
  /// `lLo = min(l1, l2)`, never at the pair's midpoint. The previous
  /// version built `c0` from `em * cosh(halfDiff) - c1 * m` for
  /// `m = (l1+l2)/2`, two terms that are both `O(exp(max(l1,l2)))` for a
  /// well-separated pair (e.g. `l1=0, l2=50`: both terms are `~2.6e21`)
  /// even though their true difference is `O(1)` (`c0` is exactly
  /// `exp(min(l1,l2))`), which is unrepresentable: double precision
  /// cannot hold a ~1e21-magnitude value to within 1 part in 1e21, so the
  /// small, correct result was rounded away to noise. Computing
  /// `fLo = exp(lLo)` directly and setting `c0 = fLo - c1*lLo` instead
  /// never subtracts two comparable huge quantities, because `fLo` is
  /// exactly the small eigenvalue's own exponential, not a difference
  /// derived from the large one. `c1` itself still needs the
  /// cancellation-safe `expm1`/divided-difference form for two
  /// eigenvalues that are close together (not just well separated).
  Matrix _general2x2Exp() {
    final double a = _rows[0][0];
    final double b = _rows[0][1];
    final double c = _rows[1][0];
    final double d = _rows[1][1];
    final ({bool isComplex, double lambda1, double lambda2, double m, double w})
    eigen = _exactRealEigen2x2(a, b, c, d);

    double c0;
    double c1;
    if (eigen.isComplex) {
      final double m = eigen.m;
      final double w = eigen.w;
      final double em = _checkFiniteScalar(math.exp(m));
      c1 = em * _sinOverX(w);
      c0 = em * math.cos(w) - c1 * m;
    } else {
      final double l1 = eigen.lambda1;
      final double l2 = eigen.lambda2;
      if (l1 == l2) {
        final double l = l1;
        final double el = _checkFiniteScalar(math.exp(l));
        c1 = el;
        c0 = el - (c1 * l);
      } else {
        final double lLo = math.min(l1, l2);
        final double lHi = math.max(l1, l2);
        final double fLo = _checkFiniteScalar(math.exp(lLo));
        final double fHi = _checkFiniteScalar(math.exp(lHi));
        c1 = fHi * _expm1(lLo - lHi) / (lLo - lHi);
        c0 = fLo - (c1 * lLo);
      }
    }
    return _checkFiniteMatrix(_c0IPlusC1A(c0, c1));
  }

  /// [log] for a general (non-diagonal, non-exactly-symmetric) 2x2 matrix
  /// via the divided-difference closed form. Undefined
  /// ([CalculatrixErrorId.logUndefined]) for a negative or zero real
  /// eigenvalue; always defined for a genuine complex-conjugate pair
  /// (never on the negative real axis).
  Matrix _general2x2Log() {
    final double a = _rows[0][0];
    final double b = _rows[0][1];
    final double c = _rows[1][0];
    final double d = _rows[1][1];
    final ({bool isComplex, double lambda1, double lambda2, double m, double w})
    eigen = _exactRealEigen2x2(a, b, c, d);

    double c0;
    double c1;
    if (eigen.isComplex) {
      final double m = eigen.m;
      final double w = eigen.w;
      final double radius = _hypot(m, w);
      if (!radius.isFinite) {
        throw MatrixDomainError(
          'Logarithm magnitude overflowed to a non-finite value.',
          errorId: CalculatrixErrorId.nonFinite,
        );
      }
      final double angle = math.atan2(w, m);
      c1 = angle / w;
      c0 = math.log(radius) - c1 * m;
    } else {
      final double l1 = eigen.lambda1;
      final double l2 = eigen.lambda2;
      if (l1 < 0 || l2 < 0) {
        throw MatrixDomainError(
          'Logarithm is undefined for matrices with a negative real '
          'eigenvalue.',
          errorId: CalculatrixErrorId.logUndefined,
        );
      }
      if (l1 == l2) {
        final double l = l1;
        if (l == 0) {
          throw MatrixDomainError(
            'Logarithm is undefined for a zero eigenvalue.',
            errorId: CalculatrixErrorId.logUndefined,
          );
        }
        c1 = 1 / l;
        c0 = math.log(l) - 1;
      } else {
        if (l1 == 0 || l2 == 0) {
          throw MatrixDomainError(
            'Logarithm is undefined for a zero eigenvalue.',
            errorId: CalculatrixErrorId.logUndefined,
          );
        }
        c1 = _log1p((l1 - l2) / l2) / (l1 - l2);
        c0 = math.log(l2) - c1 * l2;
      }
    }
    return _checkFiniteMatrix(_c0IPlusC1A(c0, c1));
  }

  /// [power]'s non-integer real-exponent case for a general (non-diagonal,
  /// non-exactly-symmetric) 2x2 matrix via the divided-difference closed
  /// form. A repeated zero eigenvalue with genuine Jordan coupling (this
  /// branch is only reached for a matrix that is not diagonal, so a
  /// repeated zero here always implies real coupling) is
  /// [CalculatrixErrorId.logUndefined] regardless of the sign of `y`.
  Matrix _general2x2RealPower(double y) {
    final double a = _rows[0][0];
    final double b = _rows[0][1];
    final double c = _rows[1][0];
    final double d = _rows[1][1];
    final ({bool isComplex, double lambda1, double lambda2, double m, double w})
    eigen = _exactRealEigen2x2(a, b, c, d);

    double c0;
    double c1;
    if (eigen.isComplex) {
      final double m = eigen.m;
      final double w = eigen.w;
      final double radius = _hypot(m, w);
      if (!radius.isFinite) {
        throw MatrixDomainError(
          'Matrix power magnitude overflowed to a non-finite value.',
          errorId: CalculatrixErrorId.nonFinite,
        );
      }
      final double angle = math.atan2(w, m);
      final double rToY = _checkFiniteScalar(math.pow(radius, y).toDouble());
      c1 = rToY * math.sin(y * angle) / w;
      c0 = rToY * math.cos(y * angle) - c1 * m;
    } else {
      final double l1 = eigen.lambda1;
      final double l2 = eigen.lambda2;
      if (l1 < 0 || l2 < 0) {
        throw MatrixDomainError(
          'A negative eigenvalue cannot be raised to a non-integer real '
          'power in the real domain.',
          errorId: CalculatrixErrorId.logUndefined,
        );
      }
      if (l1 == l2) {
        final double l = l1;
        if (l == 0) {
          throw MatrixDomainError(
            'A repeated zero eigenvalue with a genuine Jordan coupling '
            'cannot be raised to a non-integer real power.',
            errorId: CalculatrixErrorId.logUndefined,
          );
        }
        c1 = _checkFiniteScalar(y * math.pow(l, y - 1).toDouble());
        c0 = _checkFiniteScalar(math.pow(l, y).toDouble()) - c1 * l;
      } else {
        if (l1 == 0 || l2 == 0) {
          if (y < 0) {
            throw MatrixDomainError(
              'A zero eigenvalue cannot be raised to a negative real power.',
              errorId: CalculatrixErrorId.nonFinite,
            );
          }
          final double lOther = l1 == 0 ? l2 : l1;
          c1 = _checkFiniteScalar(math.pow(lOther, y - 1).toDouble());
          c0 = 0;
        } else {
          final double ly2 = _checkFiniteScalar(math.pow(l2, y).toDouble());
          c1 = ly2 * _expm1(y * _log1p((l1 - l2) / l2)) / (l1 - l2);
          c0 = ly2 - c1 * l2;
        }
      }
    }
    return _checkFiniteMatrix(_c0IPlusC1A(c0, c1));
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
