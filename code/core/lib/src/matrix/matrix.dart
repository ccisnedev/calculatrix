import 'package:meta/meta.dart';

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
  /// A 2x2 matrix is in complex form iff `M[0,0] == M[1,1]` and
  /// `M[0,1] == -M[1,0]`, which is necessary and sufficient for the matrix
  /// to belong to the subalgebra `{aI + bJ}` isomorphic to the complex
  /// numbers.
  ///
  /// Both equalities are tested exactly (round 8 correction, finding 5),
  /// never against a tolerance of any kind, scale-relative or otherwise.
  /// A scale-relative tolerance (the previous version used
  /// `4 * u * max(|M[0,0]|, |M[1,1]|)` for the diagonal pair and
  /// `4 * u * the matrix's own largest entry` for the off-diagonal pair,
  /// u = double's unit roundoff, see [CalculatrixNumericPolicy.
  /// machineEpsilon]) grows with the matrix's own scale, so at a large
  /// enough scale it can exceed a genuine, exactly-representable
  /// difference between two entries: `[[-1e20,1],[0,-1e20]]` is a genuine
  /// Jordan block (not diagonalizable), but its scale-relative
  /// off-diagonal tolerance at that magnitude (about 8.88e4) is far larger
  /// than the true gap between its off-diagonal entries (1), so the old
  /// tolerance wrongly called it complex form. Complex form is a structural
  /// property of the caller-supplied entries themselves, not a
  /// numerically-derived quantity accumulating its own rounding noise
  /// (unlike, for example, [eigenvalues], whose scale-relative tolerances
  /// exist to absorb rounding noise from the iterative QR pipeline that
  /// produced them), so there is no rounding noise here to tolerate.
  bool get isComplexForm {
    if (rowCount != 2 || columnCount != 2) return false;
    return _rows[0][0] == _rows[1][1] && _rows[0][1] == -_rows[1][0];
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

  /// Computes the inverse directly on this matrix's own entries, no
  /// global power-of-two normalization (round 6 correction, item 10: a
  /// *single* scale factor `c = 2^k` is wrong for a matrix whose entries
  /// themselves span a huge dynamic range, e.g. `diag(1e200, 1e-200)`.
  /// Undoing one global `k` chosen from the matrix's infinity norm (~1e200
  /// here) shrinks the *other* entry (1e-200) by the same factor, which
  /// can underflow it to exact zero, turning a perfectly invertible
  /// diagonal matrix into a false "singular" result, or, for a matrix
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

  /// Genuine LU decomposition with partial pivoting (round 8 correction,
  /// finding 9; Higham 2002 Ch. 9), replacing the previous Gauss-Jordan
  /// elimination on an augmented `[A | I]` matrix. The doc comment above
  /// `_inverse` already claimed "LU with partial pivoting" before this
  /// correction, which was not actually true: Gauss-Jordan updates the
  /// entire augmented row, including columns already reduced toward the
  /// identity, at every pivot step, which does materially more arithmetic
  /// (and accumulates materially more rounding error on an ill-conditioned
  /// matrix) than eliminating once below the pivot and solving each
  /// right-hand side with a single forward and back substitution.
  ///
  /// `lu` is overwritten in place: its strictly-lower part stores the unit
  /// lower-triangular factor `L`'s off-diagonal multipliers, and its
  /// upper part (including the diagonal) stores `U`. `pivotOf[i]` records
  /// which original row ended up in position `i` after partial pivoting,
  /// so each unit column `e_k` of the identity is permuted the same way
  /// before being solved.
  Matrix _inverseRaw() {
    final int size = rowCount;
    final List<List<double>> lu = List<List<double>>.generate(
      size,
      (int row) => List<double>.from(_rows[row]),
      growable: false,
    );
    final List<int> pivotOf = List<int>.generate(size, (int i) => i);

    for (int pivotColumn = 0; pivotColumn < size; pivotColumn++) {
      int pivotRow = pivotColumn;
      double pivotMagnitude = lu[pivotRow][pivotColumn].abs();

      for (int row = pivotColumn + 1; row < size; row++) {
        final double candidateMagnitude = lu[row][pivotColumn].abs();
        if (candidateMagnitude > pivotMagnitude) {
          pivotMagnitude = candidateMagnitude;
          pivotRow = row;
        }
      }

      // Round 5/6 correction (kept): singularity is declared only on an
      // exact zero pivot, never on an absolute cutoff compared against the
      // pivot's own magnitude. This runs directly on `_inverse`'s raw
      // (un-normalized, round 6 correction, item 10) matrix, so a
      // genuinely tiny-but-real pivot (e.g. one column scaled far below
      // another by the input's own structure, such as `[[1,1e20],[0,1]]`)
      // is not singular. Only a pivot that is bit-for-bit zero (every
      // candidate in the column is zero, meaning the column truly has no
      // component outside the already-eliminated rows) is. A
      // merely-huge-but-finite result is instead caught by `_inverse`'s
      // own unconditional `_checkFiniteMatrix` call on the result.
      if (pivotMagnitude == 0) {
        throw MatrixDomainError(
          'Matrix is singular and cannot be inverted.',
          errorId: CalculatrixErrorId.singularMatrix,
        );
      }

      if (pivotRow != pivotColumn) {
        final List<double> tempRow = lu[pivotColumn];
        lu[pivotColumn] = lu[pivotRow];
        lu[pivotRow] = tempRow;
        final int tempPivot = pivotOf[pivotColumn];
        pivotOf[pivotColumn] = pivotOf[pivotRow];
        pivotOf[pivotRow] = tempPivot;
      }

      final double pivot = lu[pivotColumn][pivotColumn];
      for (int row = pivotColumn + 1; row < size; row++) {
        final double factor = lu[row][pivotColumn] / pivot;
        lu[row][pivotColumn] = factor;
        if (factor == 0) {
          continue;
        }
        for (int column = pivotColumn + 1; column < size; column++) {
          lu[row][column] -= factor * lu[pivotColumn][column];
        }
      }
    }

    final List<List<double>> inverseColumns = List<List<double>>.generate(
      size,
      (int _) => List<double>.filled(size, 0),
      growable: false,
    );

    for (int rhsColumn = 0; rhsColumn < size; rhsColumn++) {
      // Forward substitution: L*y = P*e_rhsColumn, L unit lower-triangular
      // (its diagonal is implicitly 1, never stored).
      final List<double> y = List<double>.filled(size, 0);
      for (int i = 0; i < size; i++) {
        double sum = pivotOf[i] == rhsColumn ? 1 : 0;
        for (int j = 0; j < i; j++) {
          sum -= lu[i][j] * y[j];
        }
        y[i] = sum;
      }

      // Back substitution: U*x = y.
      final List<double> x = List<double>.filled(size, 0);
      for (int i = size - 1; i >= 0; i--) {
        double sum = y[i];
        for (int j = i + 1; j < size; j++) {
          sum -= lu[i][j] * x[j];
        }
        x[i] = sum / lu[i][i];
      }

      for (int row = 0; row < size; row++) {
        inverseColumns[row][rhsColumn] = x[row];
      }
    }

    return Matrix(inverseColumns);
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
  /// floor when the matrix it is applied to has norm ~1, exactly what
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

    // Round 8 correction, finding 7: the 2x2 case bypasses the whole-matrix
    // normalization below entirely and goes straight to [_eigenvalues2x2],
    // which does its own local, exact power-of-two balancing of `b` and
    // `c` individually (see that method's doc comment). A single shared
    // scale factor derived from the whole matrix's infinity norm is wrong
    // here in a way balancing avoids: for `[[0,1e200],[1e-200,0]]`, the
    // one factor that brings 1e200 down to O(1) drives 1e-200 down past
    // the smallest representable subnormal double, underflowing it to
    // exactly 0 and manufacturing a spurious repeated eigenvalue of 0
    // instead of the true +-1.
    if (rowCount == 2) {
      return _eigenvalues2x2();
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
    // The rowCount == 2 case is handled directly by [eigenvalues] itself
    // (round 8 correction, finding 7), before this method is ever called,
    // so this method only ever runs for rowCount > 2.

    // General NxN (round 6 correction, item 11): genuine Francis
    // double-shift QR on Hessenberg form (Golub & Van Loan, Algorithm
    // 7.5.1/7.5.2), with deflation, exceptional shifts and the 30n bound,
    // accumulating the orthogonal Schur vectors so `A = Q T Q^T`. See
    // [_realSchurDecomposition] for the full citation and the one
    // disclosed implementation-detail deviation (explicit-form shift
    // steps rather than hand-coded implicit bulge-chasing).
    //
    // A complex-conjugate pair anywhere in the spectrum throws: this is
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

  /// The 2x2 eigenvalue solver (round 6 correction, item 7, and round 8
  /// correction, finding 7). Delegates to [_stableRealEigen2x2], which
  /// already has no absolute cutoffs anywhere: its zero-discriminant test
  /// is scale-relative (`eps * (trace^2 + |det|)`), and neither root is
  /// ever compared against a fixed floor. The previous version's
  /// `value.abs() <= absoluteTolerance ? 0 : value` zeroed any eigenvalue
  /// at or below a fixed 1e-12 after this class's matrix-wide power-of-two
  /// normalization, which wrongly discarded a genuinely tiny-but-nonzero
  /// eigenvalue whenever the *other* eigenvalue dominated the
  /// normalization's scale choice (for example, `[[0,1e20],[1e-20,0]]`
  /// normalizes to a matrix whose true eigenvalues are `~+-1.355e-20`,
  /// both of which that fixed cutoff zeroed outright, producing `{0,0}`
  /// instead of the correct `{1,-1}` after rescaling).
  ///
  /// Round 8, finding 7: this method is now called directly on `this`,
  /// never on a whole-matrix-normalized copy (that normalization is
  /// applied by [eigenvalues] only for `rowCount > 2`). A single shared
  /// power-of-two factor derived from the whole matrix's infinity norm is
  /// wrong here: for `[[0,1e200],[1e-200,0]]`, the one factor that brings
  /// `1e200` down to O(1) drives `1e-200` down past the smallest
  /// representable subnormal double, underflowing it to exactly 0 before
  /// the solver ever sees it (true eigenvalues +-1, wrongly reported as a
  /// repeated 0). Instead, `b` and `c` are balanced against each other by
  /// an exact power-of-two diagonal similarity transform
  /// `D = diag(1, 2^k)`, `A' = D^-1 A D` (so `a` and `d` are unchanged,
  /// `b' = b * 2^k`, `c' = c / 2^k`), choosing `k` so `|b'|` and `|c'|`
  /// land close to each other rather than one of them landing far from
  /// double's representable range. A diagonal similarity transform leaves
  /// eigenvalues exactly unchanged, so no undo step is needed afterward,
  /// and multiplying or dividing by an exact power of two changes only a
  /// double's exponent bits, so `b'` and `c'` carry no extra rounding
  /// error beyond what `b` and `c` already had (other than the underflow
  /// or overflow this balancing exists to avoid).
  Matrix _eigenvalues2x2() {
    final double a = _rows[0][0];
    final double b = _rows[0][1];
    final double c = _rows[1][0];
    final double d = _rows[1][1];

    double balancedB = b;
    double balancedC = c;
    if (b != 0 && c != 0) {
      final double k = ((math.log(c.abs()) - math.log(b.abs())) / math.ln2) / 2;
      final double kRounded = k.roundToDouble();
      if (kRounded != 0) {
        balancedB = _scalarScaleByPowerOfTwo(b, kRounded);
        balancedC = _scalarScaleByPowerOfTwo(c, -kRounded);
      }
    }

    // Round 9 correction, finding 2: the b/c balancing above only protects
    // the off-diagonal pair against each other; it does nothing for a
    // uniformly huge or uniformly tiny block (all four entries at the same
    // extreme scale), where `trace*trace` inside [_stableRealEigen2x2]
    // still overflows to Infinity (Infinity - Infinity = NaN) or `det`
    // underflows to exactly 0, misclassifying the discriminant as zero.
    // Scale the whole balanced block by the power of two nearest its own
    // largest-magnitude entry (applied after the b/c balance: doing it
    // before would undo that balance's own protection, underflowing `c` in
    // the existing `[[0,1e200],[1e-200,0]]` case back to 0), solve on the
    // scaled block, then rescale the resulting roots back. This is an exact
    // similarity-free rescaling (`eig(cA) = c*eig(A)`), so it changes no
    // eigenvalue's true value, only which magnitudes the solver sees.
    final double maxAbs = <double>[
      a.abs(),
      balancedB.abs(),
      balancedC.abs(),
      d.abs(),
    ].reduce(math.max);

    int k = 0;
    double scaledA = a;
    double scaledB = balancedB;
    double scaledC = balancedC;
    double scaledD = d;
    if (maxAbs != 0) {
      k = (math.log(maxAbs) / math.ln2).round();
      if (k != 0) {
        scaledA = _scalarScaleByPowerOfTwo(a, -k.toDouble());
        scaledB = _scalarScaleByPowerOfTwo(balancedB, -k.toDouble());
        scaledC = _scalarScaleByPowerOfTwo(balancedC, -k.toDouble());
        scaledD = _scalarScaleByPowerOfTwo(d, -k.toDouble());
      }
    }

    final ({bool isComplex, double lambda1, double lambda2}) solved =
        _stableRealEigen2x2(scaledA, scaledB, scaledC, scaledD);

    if (solved.isComplex) {
      throw MatrixDomainError(
        'Eigenvalues are undefined in the real domain for this matrix.',
      );
    }

    final double lambda1 = k == 0
        ? solved.lambda1
        : _scalarScaleByPowerOfTwo(solved.lambda1, k.toDouble());
    final double lambda2 = k == 0
        ? solved.lambda2
        : _scalarScaleByPowerOfTwo(solved.lambda2, k.toDouble());

    if (!lambda1.isFinite || !lambda2.isFinite) {
      throw MatrixDomainError(
        'Result is not a finite number.',
        errorId: CalculatrixErrorId.nonFinite,
      );
    }

    final List<double> values = <double>[lambda1, lambda2]
      ..sort((double left, double right) => right.compareTo(left));

    return Matrix(
      values.map((double value) => <double>[value]).toList(growable: false),
    );
  }

  /// Normalize-then-undo wrapper (round 4 correction, rule 1): the
  /// eigenvector Gaussian elimination below has its own pivot/free-column
  /// cutoffs against [absoluteTolerance], which are only sound for a
  /// matrix of norm ~1, exactly the same defect [_inverseRaw] and
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

    // Structurally exact zero below the subdiagonal, see doc comment.
    for (int i = 2; i < n; i++) {
      for (int j = 0; j < i - 1; j++) {
        h[i][j] = 0;
      }
    }

    return (h: h, q: q);
  }

  /// Builds the Householder vector that reflects [w] onto a multiple of
  /// the first standard basis vector, or `null` if [w] is already exactly
  /// zero (no reflection needed: an exact structural fact, not an
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
  /// unreduced Hessenberg `Ha`, and, because `Ha` is Hessenberg, `Ha^2`
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
  /// orthogonal: the accumulated Schur vectors.
  ///
  /// Deflation test (round 8 correction, finding 6): the LAPACK DLAHQR
  /// two-stage small-subdiagonal criterion (Ahues and Tisseur, LAWN 122,
  /// 1997), not the single-stage `|h[i][i-1]| <= eps*(|h[i-1][i-1]| +
  /// |h[i][i]|)` test alone. The single-stage test only weighs the
  /// subdiagonal entry against the two adjacent diagonal magnitudes; it
  /// never looks at the matching superdiagonal entry or the gap between
  /// the diagonal entries, so a genuinely coupled 2x2 block can pass as
  /// negligible purely because its subdiagonal happens to be tiny, even
  /// when its superdiagonal is huge (an actual repeated-1-instead-of-
  /// 1.001/0.999 misread was reproduced this way). The refinement only
  /// ever narrows what the basic test accepts: it takes `AB = max(|h[l]
  /// [l-1]|, |h[l-1][l]|)`, `BA = min(...)`, `AA = max(|h[l][l]|, |h[l-1]
  /// [l-1]-h[l][l]|)`, `BB = min(...)`, `S = AA+AB`, and only confirms
  /// deflation when `BA*(AB/S) <= max(smlnum, eps*(BB*(AA/S)))`, where
  /// `smlnum` is a safe-minimum floor scaled to the active block's size so
  /// the comparison never divides by an underflowed `S`.
  ///
  /// Exceptional shift (round 4 correction, case G's remedy, adapted to
  /// the double-shift form used here): every 11th QR step taken without a
  /// deflation substitutes an ad hoc repeated shift derived from nearby
  /// subdiagonal magnitudes, which breaks the stagnation a plain Wilkinson
  /// double shift can hit on certain spectra (e.g. a permutation matrix's
  /// eigenvalues sitting equally spaced on the unit circle).
  ///
  /// Iteration bound: `30*n` total QR steps taken without an intervening
  /// deflation (Higham 2008 Ch. 2 / LAPACK's own convergence budget): a
  /// data-independent loop bound that throws `no-convergence` if
  /// exhausted, never a silent fallback.
  ({List<List<double>> t, List<List<double>> q}) _realSchurDecomposition() {
    final int n = rowCount;
    final ({List<List<double>> h, List<List<double>> q}) hessenberg =
        _hessenbergWithSchurVectors();
    final List<List<double>> h = hessenberg.h;
    final List<List<double>> q = hessenberg.q;

    const double eps = CalculatrixNumericPolicy.machineEpsilon;
    // Smallest normalized positive double: the LAPACK DLAHQR safe-minimum
    // floor below, scaled by the active block's size, stands in for
    // DLAMCH('Safe minimum') so the refined test's division by `s` never
    // trips on an underflowed denominator.
    const double safeMinimum = 2.2250738585072014e-308;
    final int maxIterations = 30 * n;
    int iterationsSinceDeflation = 0;

    int hi = n - 1;
    while (hi > 0) {
      int lo = hi;
      while (lo > 0) {
        final double h10 = h[lo][lo - 1].abs();
        final double h00 = h[lo - 1][lo - 1].abs();
        final double h11 = h[lo][lo].abs();

        bool negligible = h10 <= eps * (h00 + h11);
        if (negligible) {
          // Ahues and Tisseur (LAWN 122, 1997) refinement: the basic test
          // above ignores the matching superdiagonal entry and the gap
          // between the diagonal entries, so confirm with the stronger
          // two-sided bound before actually treating h[lo][lo-1] as zero.
          final double h01 = h[lo - 1][lo].abs();
          final double ab = math.max(h10, h01);
          final double ba = math.min(h10, h01);
          final double diagGap = (h[lo - 1][lo - 1] - h[lo][lo]).abs();
          final double aa = math.max(h[lo][lo].abs(), diagGap);
          final double bb = math.min(h[lo][lo].abs(), diagGap);
          final double s = aa + ab;
          if (s == 0) {
            negligible = true;
          } else {
            final double activeSize = (hi - lo + 1).toDouble();
            final double smlnum = safeMinimum * (activeSize / eps);
            negligible =
                ba * (ab / s) <= math.max(smlnum, eps * (bb * (aa / s)));
          }
        }

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
        // (real pair or complex-conjugate pair), leave it and deflate.
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
      // (applied across every row and column of the *whole* working
      // matrix, not just the local `[lo, hi]` block, so that a similarity
      // transform on a sub-block stays correct for the matrix as a whole)
      // do not themselves know about the band. This reaches beyond the
      // active block too: a row below `hi` that was already deflated
      // (its own sub-subdiagonal entries columns `lo..hi` explicitly
      // zeroed by an earlier deflation) gets touched again by this step's
      // right-multiply across all `n` rows, turning what was an exact
      // zero back into a few-ULP residue. Left alone, that noise would
      // make [_schurEigenvalues]'s exact-zero block-boundary test wrongly
      // read two adjacent Schur blocks as fused into one larger block:
      // this is exactly what round 6's own probe against a 5x5 symmetric
      // tridiagonal matrix caught: three eigenvalues collapsed to one
      // repeated (wrong) value where two isolated blocks should have
      // stayed separate. Re-imposing the structural zero across the
      // *entire* matrix here (unconditional, not a tolerance comparison,
      // since these entries are exactly zero in exact arithmetic) keeps
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
  /// via [_stableRealEigen2x2]. If complex, both conjugates are reported.
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
  /// individually tiny off-diagonal entries) is not rounding noise: it is
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
    // Round 9 correction, finding 3: an exactly-triangular 2x2 block's
    // eigenvalues are its diagonal entries, exactly, by definition (same
    // reasoning as the whole-matrix triangular fast path in [eigenvalues]).
    // Returning them directly avoids computing `halfDiff*halfDiff` at all,
    // which is what underflows to exactly 0 at extreme scale (e.g. `a` and
    // `d` both ~1e-200, whose half-difference is ~1e-200 and squares to
    // ~1e-400, below the smallest representable subnormal double),
    // spuriously classifying two genuinely distinct eigenvalues as a
    // repeated one at their mean.
    if (b == 0 || c == 0) {
      return (isComplex: false, lambda1: a, lambda2: d, m: (a + d) / 2, w: 0);
    }

    // Round 12 correction, finding 3: balance `b` and `c` against each
    // other by an exact power-of-two diagonal similarity transform before
    // the whole-block magnitude scale below, the same fix already applied
    // in [_eigenvalues2x2] (see its doc comment for the full derivation).
    // A single block-wide scale factor is tuned to the block's own
    // largest-magnitude entry; when `b` and `c` sit at wildly different
    // scales from each other (for example `b` around 1e200, `c` around
    // 1e-200), that one factor brings `b` down to a representable
    // magnitude while driving `c` past the smallest representable
    // subnormal double, underflowing it to exactly 0 before `b*c` is ever
    // formed. The discriminant `halfDiff^2 + b*c` then sees a spuriously
    // zeroed `b*c` term and misclassifies a genuine complex-conjugate pair
    // (true discriminant `-1`, here) as a repeated real eigenvalue at the
    // pair's mean. `D = diag(1, 2^k)`, `A' = D^-1 A D` leaves `a` and `d`
    // unchanged and leaves the product `b*c` exactly unchanged too
    // (`b' * c' = (b*2^k) * (c/2^k) = b*c`), so this balancing changes no
    // eigenvalue, discriminant, `m` or `w`; it only avoids underflow in
    // forming their intermediate product.
    double balancedB = b;
    double balancedC = c;
    final double kBalance =
        ((math.log(c.abs()) - math.log(b.abs())) / math.ln2) / 2;
    final double kBalanceRounded = kBalance.roundToDouble();
    if (kBalanceRounded != 0) {
      balancedB = _scalarScaleByPowerOfTwo(b, kBalanceRounded);
      balancedC = _scalarScaleByPowerOfTwo(c, -kBalanceRounded);
    }

    // For a non-triangular block, the same extreme-scale problem can still
    // hit `halfDiff*halfDiff` and `b*c` (underflow) or `m`/`det` (overflow)
    // when every entry shares one huge or tiny scale. Scale the whole block
    // by the power of two nearest its own largest-magnitude entry, solve on
    // that scaled block, then rescale the results back (eigenvalues, `m`
    // and `w` all carry the same units as the entries, so all three scale
    // by the same `2^k`).
    final double maxAbs = <double>[
      a.abs(),
      balancedB.abs(),
      balancedC.abs(),
      d.abs(),
    ].reduce(math.max);

    int k = 0;
    double sa = a;
    double sb = balancedB;
    double sc = balancedC;
    double sd = d;
    if (maxAbs != 0) {
      k = (math.log(maxAbs) / math.ln2).round();
      if (k != 0) {
        sa = _scalarScaleByPowerOfTwo(a, -k.toDouble());
        sb = _scalarScaleByPowerOfTwo(balancedB, -k.toDouble());
        sc = _scalarScaleByPowerOfTwo(balancedC, -k.toDouble());
        sd = _scalarScaleByPowerOfTwo(d, -k.toDouble());
      }
    }

    final double m = (sa + sd) / 2;
    final double halfDiff = (sa - sd) / 2;
    final double det = (sa * sd) - (sb * sc);
    final double discriminant = (halfDiff * halfDiff) + (sb * sc);

    double rescale(double value) =>
        k == 0 ? value : _scalarScaleByPowerOfTwo(value, k.toDouble());

    if (discriminant < 0) {
      final double w = math.sqrt(-discriminant);
      return (
        isComplex: true,
        lambda1: 0,
        lambda2: 0,
        m: rescale(m),
        w: rescale(w),
      );
    }

    if (discriminant == 0) {
      final double lambda = rescale(m);
      return (isComplex: false, lambda1: lambda, lambda2: lambda, m: lambda, w: 0);
    }

    final double sqrtD = math.sqrt(discriminant);
    final double signM = m >= 0 ? 1.0 : -1.0;
    final double q = m + (signM * sqrtD);
    final double lambda1 = rescale(q);

    double lambda2;
    if (q == 0) {
      lambda2 = rescale(m - (signM * sqrtD));
    } else {
      // Round 11 correction, finding 2: `det` above is the determinant of
      // the *scaled* block (`sa*sd - sb*sc`), and a matrix whose own
      // entries already span a huge dynamic range (for example `a` around
      // 1e200 and `d` around 1e-200, in the same block) has its
      // smaller-magnitude entries driven to exactly 0 by the per-entry
      // scaling above, before they are ever multiplied, even though the
      // *unscaled* determinant (`a*d - b*c`) is perfectly representable
      // and accurate (here, `1e200*1e-200 - b*c`, nowhere near overflow).
      // Prefer that direct, unscaled determinant whenever it is finite:
      // it is immune to this per-entry underflow and at least as
      // accurate as the scaled one. Only fall back to the scaled,
      // rescaled determinant when the direct product itself overflows,
      // which is the case the scaling exists for in the first place (a
      // uniformly huge matrix, where every entry shares one extreme
      // scale rather than spanning one).
      // Round 12 correction, finding 2: `directDet.isFinite` alone is not
      // enough to trust `directDet`. `a`/`d` (or `b`/`c`) can each be so
      // small that their direct product underflows to exactly 0 (for
      // example `a` and `d` both around 1e-200: `a*d` around 1e-400 is
      // below the smallest representable subnormal double, ~4.94e-324),
      // which is still a finite double, just a wrong one: it silently
      // discards the true product's magnitude instead of ever producing
      // `Infinity`. Name that failure explicitly: a factor pair that was
      // itself genuinely nonzero (neither input is 0) but whose product
      // rounds to exactly 0 has underflowed, and `directDet` cannot be
      // trusted whenever either of its two products underflowed this way,
      // even though the subtraction of the two (both exactly 0) is itself
      // "finite". The scaled, rescaled `det / q` computed on the
      // whole-block-normalized entries above has no such risk here: this
      // whole block shares one extreme scale, so normalizing it first
      // brings every entry back to a representable magnitude before any
      // product is formed.
      final double directAD = a * d;
      final double directBC = b * c;
      final bool directAdUnderflowed = a != 0 && d != 0 && directAD == 0;
      final bool directBcUnderflowed = b != 0 && c != 0 && directBC == 0;
      final double directDet = directAD - directBC;
      final bool directDetReliable =
          directDet.isFinite && !directAdUnderflowed && !directBcUnderflowed;
      lambda2 = directDetReliable ? directDet / lambda1 : rescale(det / q);
    }

    return (
      isComplex: false,
      lambda1: lambda1,
      lambda2: lambda2,
      m: rescale(m),
      w: 0,
    );
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
  ///
  /// D38 declared precision contract: every nonzero raw entry, and every
  /// nonzero eigenvalue this computes, must lie in
  /// `[CalculatrixNumericPolicy.matrixFunctionMinMagnitude,
  /// CalculatrixNumericPolicy.matrixFunctionMaxMagnitude]`
  /// (`[1e-150, 1e150]`); otherwise this throws
  /// [CalculatrixErrorId.matrixOutOfPrecisionRange]. Inside that range, the
  /// accuracy contract is a normwise (Frobenius) relative error
  /// `||F_computed - F_true|| / ||F_true|| <= 1e-12`, not a componentwise
  /// one.
  Matrix sqrt() {
    _requireSquare(operation: 'square root');
    _checkFiniteMatrix(this);
    _requireEntriesInPrecisionRange('square root');

    if (isScalar) {
      final double source = scalarValue;
      if (source < 0) {
        return Matrix.i.scale(math.sqrt(-source));
      }
      return Matrix.scalar(math.sqrt(source));
    }

    return _matrixRealPower(
      0.5,
      maxSweeps: CalculatrixNumericPolicy.jacobiMaxSweeps,
      operation: 'square root',
      rejectZeroEigenvalue: false,
    );
  }

  /// Computes the matrix exponential.
  ///
  /// Only five input classes are supported, each with an exact or robust
  /// closed-form algorithm:
  ///
  /// - Scalars (1x1): `e^v` directly.
  /// - Complex-form input (`aI + bJ`, 2x2 only): the closed form
  ///   `e^a * (cos(b)*I + sin(b)*J)`, no series at all, so `cos`/`sin`
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
  ///
  /// D38 declared precision contract: every nonzero raw entry, and every
  /// nonzero eigenvalue (or, for a complex-conjugate pair, its real part
  /// `m` and rotation half-width `w`) this computes, must lie in
  /// `[CalculatrixNumericPolicy.matrixFunctionMinMagnitude,
  /// CalculatrixNumericPolicy.matrixFunctionMaxMagnitude]`
  /// (`[1e-150, 1e150]`); otherwise this throws
  /// [CalculatrixErrorId.matrixOutOfPrecisionRange]. Inside that range, the
  /// accuracy contract is a normwise (Frobenius) relative error
  /// `||F_computed - F_true|| / ||F_true|| <= 1e-12`, not a componentwise
  /// one. The non-finite check above is unaffected: a true result that
  /// genuinely overflows (e.g. `exp` of a large positive in-range
  /// eigenvalue) is still reported as [CalculatrixErrorId.nonFinite], not
  /// as an out-of-precision-range rejection.
  Matrix exp() {
    _requireSquare(operation: 'exponential');
    _checkFiniteMatrix(this);
    _requireEntriesInPrecisionRange('matrix exponential');

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
      return _symmetricRealFunction(
        (double v) => math.exp(v),
        maxSweeps: CalculatrixNumericPolicy.jacobiMaxSweeps,
        operation: 'matrix exponential',
      );
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
  ///
  /// D38 declared precision contract: every nonzero raw entry, and every
  /// nonzero eigenvalue (or, for a complex-conjugate pair, its real part
  /// `m` and rotation half-width `w`) this computes, must lie in
  /// `[CalculatrixNumericPolicy.matrixFunctionMinMagnitude,
  /// CalculatrixNumericPolicy.matrixFunctionMaxMagnitude]`
  /// (`[1e-150, 1e150]`); otherwise this throws
  /// [CalculatrixErrorId.matrixOutOfPrecisionRange]. Inside that range, the
  /// accuracy contract is a normwise (Frobenius) relative error
  /// `||F_computed - F_true|| / ||F_true|| <= 1e-12`, not a componentwise
  /// one.
  Matrix log() {
    _requireSquare(operation: 'logarithm');
    _checkFiniteMatrix(this);
    _requireEntriesInPrecisionRange('matrix logarithm');

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
      }, maxSweeps: CalculatrixNumericPolicy.jacobiMaxSweeps, operation: 'matrix logarithm');
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
  ///
  /// D38 declared precision contract (non-integer exponent only; an
  /// integer exponent, computed by repeated multiplication, is not
  /// affected): every nonzero raw entry, and every nonzero eigenvalue (or,
  /// for a complex-conjugate pair, its real part `m` and rotation
  /// half-width `w`) this computes, must lie in
  /// `[CalculatrixNumericPolicy.matrixFunctionMinMagnitude,
  /// CalculatrixNumericPolicy.matrixFunctionMaxMagnitude]`
  /// (`[1e-150, 1e150]`); otherwise this throws
  /// [CalculatrixErrorId.matrixOutOfPrecisionRange]. Inside that range, the
  /// accuracy contract is a normwise (Frobenius) relative error
  /// `||F_computed - F_true|| / ||F_true|| <= 1e-12`, not a componentwise
  /// one.
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
    // before it is ever classified as "an integer": `double.infinity ==
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

      if (integerExponent) {
        // Integer exponent (any base) uses ordinary real exponentiation
        // directly; this also yields the 0^0 = 1 and 0^negative =
        // +Infinity cases for free. Not a D38-governed computation (round
        // 13 / D38 correction): an integer exponent is excluded from the
        // declared precision range check, the same as
        // [_integerMatrixPower].
        return Matrix.scalar(_checkFiniteScalar(math.pow(b, y).toDouble()));
      }

      // Non-integer exponent: D38's declared precision range applies, this
      // scalar being the sole "entry" of a 1x1 matrix.
      _requireEntriesInPrecisionRange('real matrix power');

      if (b >= 0) {
        // Non-negative base, non-integer exponent uses ordinary real
        // exponentiation directly; this also yields 0^positive = 0 for
        // free.
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

    return _matrixRealPower(
      y,
      maxSweeps: CalculatrixNumericPolicy.jacobiMaxSweeps,
      operation: 'real matrix power',
      rejectZeroEigenvalue: true,
    );
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
        // Classify exponent's own, unscaled structure before scaling it by
        // log(b): scaling every entry by the same finite factor can
        // underflow a genuinely nonzero off-diagonal entry to exactly 0,
        // making a matrix that was never one of the five supported
        // matrix-function classes look diagonal (or otherwise supported)
        // only after scaling (round 8 correction, finding 10).
        if (!exponent._isSupportedMatrixFunctionClass) {
          throw exponent._unsupportedMatrixFunction('matrix exponent');
        }
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
  /// int negated overflows back to itself). A `double` has no such trap:
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

  /// D38 declared precision contract (see
  /// [CalculatrixNumericPolicy.matrixFunctionMinMagnitude]): rejects a
  /// single nonzero magnitude that falls outside
  /// `[matrixFunctionMinMagnitude, matrixFunctionMaxMagnitude]`, naming
  /// [operation] and [quantity] (which entry or eigenvalue) and the
  /// declared range in the error message, rather than guessing at a
  /// result. Zero is never passed here (callers skip zero entries and
  /// zero eigenvalues before calling this).
  static void _requireMagnitudeInPrecisionRange(
    double magnitude, {
    required String operation,
    required String quantity,
  }) {
    if (magnitude < CalculatrixNumericPolicy.matrixFunctionMinMagnitude ||
        magnitude > CalculatrixNumericPolicy.matrixFunctionMaxMagnitude) {
      throw MatrixDomainError(
        'Cannot compute the $operation: $quantity has magnitude '
        '$magnitude, outside the declared precision range '
        '[${CalculatrixNumericPolicy.matrixFunctionMinMagnitude}, '
        '${CalculatrixNumericPolicy.matrixFunctionMaxMagnitude}].',
        errorId: CalculatrixErrorId.matrixOutOfPrecisionRange,
      );
    }
  }

  /// D38 domain check, stage 1 (before anything is computed): every
  /// nonzero raw entry of this matrix must lie in the declared precision
  /// range. Called at the top of [sqrt], [exp], [log] and the non-integer
  /// branches of [power], uniformly across every one of the five
  /// supported matrix-function classes (scalar, complex-form, diagonal,
  /// exactly symmetric, general 2x2): this is a declarative gate on the
  /// input itself, not a risk-tailored one, so it applies before the
  /// input is even classified into one of those five classes.
  void _requireEntriesInPrecisionRange(String operation) {
    for (int row = 0; row < rowCount; row++) {
      for (int column = 0; column < columnCount; column++) {
        final double value = _rows[row][column];
        if (value == 0) continue;
        _requireMagnitudeInPrecisionRange(
          value.abs(),
          operation: operation,
          quantity: 'entry ($row, $column)',
        );
      }
    }
  }

  /// D38 domain check, stage 2 (after the eigenvalues are computed): every
  /// nonzero computed eigenvalue must also lie in the declared precision
  /// range. Used by the general 2x2 real-eigenvalue branches and the
  /// exactly-symmetric (cyclic Jacobi) branch; not applied to diagonal,
  /// scalar or standalone complex-form input, whose "eigenvalues" are read
  /// directly from entries already covered by
  /// [_requireEntriesInPrecisionRange].
  static void _requireEigenvaluesInPrecisionRange(
    List<double> eigenvalues,
    String operation,
  ) {
    for (int i = 0; i < eigenvalues.length; i++) {
      final double value = eigenvalues[i];
      if (value == 0) continue;
      _requireMagnitudeInPrecisionRange(
        value.abs(),
        operation: operation,
        quantity: 'computed eigenvalue $i (value $value)',
      );
    }
  }

  /// D38 domain check, stage 2, for a general 2x2 complex-conjugate
  /// eigenvalue pair: the pair's real part [m] and rotation half-width [w]
  /// (not the complex eigenvalue's own magnitude `hypot(m, w)`) must each
  /// lie in the declared precision range, per the contract's own wording.
  static void _requireComplexPairPartsInPrecisionRange(
    double m,
    double w,
    String operation,
  ) {
    if (m != 0) {
      _requireMagnitudeInPrecisionRange(
        m.abs(),
        operation: operation,
        quantity: 'computed eigenvalue real part m (value $m)',
      );
    }
    if (w != 0) {
      _requireMagnitudeInPrecisionRange(
        w.abs(),
        operation: operation,
        quantity: 'computed eigenvalue rotation half-width w (value $w)',
      );
    }
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

  /// The largest absolute value among this matrix's entries: a plain
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
  /// `eig(cA) = c * eig(A)`, for `c = 2^k`), so every *internal*
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
      // handle on at all. This raises the typed error instead, so the
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
  /// *even when the final, fully-scaled result would itself be finite*
  /// (e.g. undoing a `k = 1024` normalization on an already-tiny matrix).
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
  /// near double's range), and can equally underflow the *ratio* of two
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
  /// triangular, or both (diagonal), checked with a plain `== 0`, not a
  /// tolerance. This is deliberately exact: it exists to give
  /// [log]/[power] a route to read a triangular matrix's eigenvalues
  /// straight off the diagonal, with no discriminant, no QR iteration, and
  /// therefore no rounding noise to second-guess with a tolerance in the
  /// first place. A matrix whose off-triangular entries are merely *close*
  /// to zero (not exactly zero) does not qualify. It goes through the
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
  /// zero, checked with a plain `== 0`, not a tolerance, for the same
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
  /// [CalculatrixNumericPolicy.machineEpsilon], never an absolute
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
  /// zeroing every off-diagonal entry: the shared building block for
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
  /// and reconstructs `f(A) = Q * f(Lambda) * Qᵀ`: the shared building
  /// block for [exp]/[log]/[sqrt]/[power]'s exactly-symmetric-matrix class.
  Matrix _symmetricRealFunction(
    double Function(double value) f, {
    required int maxSweeps,
    required String operation,
  }) {
    final ({Matrix q, List<double> lambda}) eigen =
        _cyclicJacobiEigendecomposition(maxSweeps: maxSweeps);
    _requireEigenvaluesInPrecisionRange(eigen.lambda, operation);
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
  /// maximum precision parity with the diagonal-sqrt fast path); any
  /// `v < 0` is [CalculatrixErrorId.logUndefined] (a non-integer real
  /// exponent has no real value there). `y` is always finite and
  /// non-integer here, since an integer (including `y == 0`) exponent is
  /// routed to [_integerMatrixPower] before this is ever reached.
  ///
  /// `v == 0` is where [sqrt] and [power] diverge (round 9 correction,
  /// finding 4, restoring runbook D25 case 5 / issue #5 amendment D34):
  /// [power] with a non-scalar, non-complex-form base must treat a zero
  /// eigenvalue with a non-integer exponent as log-undefined outright
  /// (`rejectZeroEigenvalue: true`), the same as the negative-eigenvalue
  /// case, regardless of the sign of `y`. [sqrt] itself is unaffected
  /// (`rejectZeroEigenvalue: false`): `0^0.5 = 0` carries through its
  /// eigendecomposition as before.
  double _realScalarPower(double v, double y, {required bool rejectZeroEigenvalue}) {
    if (v > 0) {
      return y == 0.5 ? math.sqrt(v) : math.pow(v, y).toDouble();
    }
    if (v == 0) {
      if (!rejectZeroEigenvalue && y > 0) return 0;
      throw MatrixDomainError(
        'A zero eigenvalue cannot be raised to a non-integer real power.',
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
  /// non-integer case. Tries the complex-form, diagonal, exactly-symmetric
  /// and general 2x2 closed forms in order, and raises
  /// [CalculatrixErrorId.unsupportedMatrixFunction] for anything else.
  ///
  /// The complex-form check must run before the general 2x2 closed form
  /// (round 8 correction, finding 4), mirroring [exp] and [log]: the
  /// general 2x2 eigenvalue classification squares the off-diagonal entry
  /// as part of its discriminant, which underflows to exactly zero for a
  /// complex-form matrix whose imaginary part is nonzero but tiny relative
  /// to its real part, misclassifying it as a repeated real eigenvalue and
  /// wrongly rejecting a negative real part that the complex form itself
  /// has no trouble with.
  Matrix _matrixRealPower(
    double y, {
    required int maxSweeps,
    required String operation,
    required bool rejectZeroEigenvalue,
  }) {
    _requireEntriesInPrecisionRange(operation);
    if (isComplexForm) {
      return _complexFormRealPower(y);
    }
    if (_isExactlyDiagonal()) {
      return _diagonalRealFunction(
        (double v) => _realScalarPower(
          v,
          y,
          rejectZeroEigenvalue: rejectZeroEigenvalue,
        ),
      );
    }
    if (_isExactlySymmetric()) {
      return _symmetricRealFunction(
        (double v) => _realScalarPower(
          v,
          y,
          rejectZeroEigenvalue: rejectZeroEigenvalue,
        ),
        maxSweeps: maxSweeps,
        operation: operation,
      );
    }
    if (rowCount == 2) {
      return _general2x2RealPower(
        y,
        rejectZeroEigenvalue: rejectZeroEigenvalue,
        operation: operation,
      );
    }
    throw _unsupportedMatrixFunction(operation);
  }

  /// [_matrixRealPower] for a complex-form matrix (`aI + bJ`), via the
  /// polar form `z^y = r^y * (cos(y*theta) + i*sin(y*theta))`, where
  /// `r = sqrt(a^2+b^2)`, `theta = atan2(b, a)`. A zero magnitude raised to
  /// a non-positive power is [CalculatrixErrorId.logUndefined]; any other
  /// nonzero magnitude is defined for every real `y`, regardless of the
  /// sign of `a`.
  Matrix _complexFormRealPower(double y) {
    final double a = realPart;
    final double b = imagPart;

    if (a == 0 && b == 0) {
      if (y > 0) {
        return Matrix.complex(0, 0);
      }
      throw MatrixDomainError(
        'A zero magnitude cannot be raised to a non-positive real power in '
        'the complex domain.',
        errorId: CalculatrixErrorId.logUndefined,
      );
    }

    final double radius = _hypot(a, b);
    if (!radius.isFinite) {
      throw MatrixDomainError(
        'Matrix power magnitude overflowed to a non-finite value.',
        errorId: CalculatrixErrorId.nonFinite,
      );
    }
    final double angle = math.atan2(b, a);
    final double rToY = _checkFiniteScalar(math.pow(radius, y).toDouble());
    final double newAngle = y * angle;
    return _checkFiniteMatrix(
      Matrix.complex(rToY * math.cos(newAngle), rToY * math.sin(newAngle)),
    );
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

  /// Exact closed form for a triangular general 2x2 matrix `[[a,b],[c,d]]`
  /// with `b == 0` or `c == 0`, used by [_general2x2Exp], [_general2x2Log]
  /// and [_general2x2RealPower]'s distinct-real-eigenvalue branches in
  /// place of [_c0IPlusC1A]'s `c0*I + c1*A` reconstruction.
  ///
  /// For a triangular matrix, `f(A)` is known exactly (Higham, "Functions
  /// of Matrices", Theorem 4.11 / section 4.5): for upper triangular
  /// `[[a,b],[0,d]]`, `f(A) = [[f(a), b*dd],[0, f(d)]]`, where `dd` is the
  /// divided difference `(f(a)-f(d))/(a-d)` (or `f'(a)` when `a == d`,
  /// handled separately, before this is ever called); lower triangular is
  /// the transpose analogue, `f(A) = [[f(a),0],[c*dd, f(d)]]`. This
  /// method is only ever called for a matrix that is not exactly diagonal
  /// (that class is routed to [_diagonalRealFunction] before any general
  /// 2x2 path is reached), so exactly one of `b`/`c` is the genuine zero
  /// whenever it is called, and a single formula
  /// `[[fa, b*dd],[c*dd, fd]]` covers both orientations: whichever of
  /// `b`/`c` is the true zero contributes exactly 0 on its own.
  ///
  /// [fa] and [fd] must be computed by the caller directly from `a` and
  /// `d` (e.g. `math.exp(a)`, `math.exp(d)`), never derived by adding a
  /// correction to an anchor value the way [_c0IPlusC1A]'s
  /// `c0*I + c1*A` does. That anchor-plus-correction form is what loses a
  /// small diagonal entry: for the distinct-real-eigenvalue branches,
  /// `c0` is built as `f(anchor) - c1*anchor`, and the non-anchor diagonal
  /// entry is then `c0 + c1*other = f(anchor) - c1*(anchor - other)`,
  /// subtracting two quantities that are each `O(f(anchor))` to recover a
  /// target that can be many orders of magnitude smaller (e.g.
  /// `[[4,1],[0,1e-18]]^0.5`: anchor `f(4)=2`, target `f(1e-18)=1e-9`,
  /// `c1*(anchor-other) ~ 2`, so the ~1e-9 target is computed as a
  /// difference of two ~2-magnitude values and loses essentially all of
  /// its significant digits; at a wider spread, e.g. the diagonal entries
  /// of a `1e200`/`1e-200` pair, the same subtraction can even overflow or
  /// cancel to a non-finite or wildly wrong result). Reading `f(a)` and
  /// `f(d)` directly from their own scalar functions has no such
  /// subtraction: each diagonal entry is exact to the scalar function's
  /// own rounding, regardless of how far apart `a` and `d` are in
  /// magnitude.
  Matrix _triangularClosedForm2x2(
    double fa,
    double fd,
    double dividedDifference,
  ) {
    final double b = _rows[0][1];
    final double c = _rows[1][0];
    return Matrix(<List<double>>[
      <double>[fa, b * dividedDifference],
      <double>[c * dividedDifference, fd],
    ]);
  }

  /// Numerically stable two-point (Lagrange) reconstruction of `f(A)` for
  /// a general, genuinely non-triangular 2x2 matrix (`b != 0` and
  /// `c != 0`) whose two real eigenvalues [lBig] and [lSmall]
  /// (`|lBig| >= |lSmall|`) are far enough apart that [_c0IPlusC1A]'s
  /// `c0 + c1*A` reconstruction loses a diagonal entry that happens to
  /// sit close to `lSmall` (round 11 correction, finding 3, for
  /// [_general2x2RealPower]; round 12 correction, finding 1, for
  /// [_general2x2Exp]; the exactly triangular case, `b == 0` or
  /// `c == 0`, already has its own exact closed form in
  /// [_triangularClosedForm2x2]).
  ///
  /// `_c0IPlusC1A` anchors at `lBig`: `c0 = fBig - c1*lBig`, then every
  /// entry is `c0 + c1*entry`. When `lBig` and `lSmall` differ by many
  /// orders of magnitude and `f` also grows across that many orders of
  /// magnitude (as [math.pow] does, unlike [math.log]'s compression),
  /// `fBig` and `c1*lBig` are each individually `O(fBig)`, yet a
  /// diagonal entry near `lSmall` needs their difference to land on
  /// `fSmall`, many orders of magnitude smaller: `c1` would need on the
  /// order of `log10(lBig/lSmall)` extra decimal digits of precision
  /// beyond what a double holds for that cancellation to resolve
  /// correctly, which is structurally impossible once the eigenvalue
  /// ratio is large (e.g. `sqrt([[1e200,1],[1e-300,1e-200]])`'s
  /// bottom-right entry: true value `~1e-100`, `c0 + c1*d` instead
  /// returns `~1e-300`, off by 200 orders of magnitude).
  ///
  /// The Lagrange form evaluated directly at each diagonal entry `x` still
  /// is not enough on its own: a weighted average like
  /// `fBig*(x-lSmall)/(lBig-lSmall) + fSmall*(lBig-x)/(lBig-lSmall)` breaks
  /// down when `x` happens to round to the exact same double as `lSmall`
  /// (or `lBig`) even though its true, exact offset from that eigenvalue
  /// is nonzero: the weight `(x-lSmall)/denom` rounds to exactly 0, and
  /// the genuine, tiny-but-amplified contribution from that offset (round
  /// 12 correction, finding 1: `[[700,1],[1e-300,-700]]`'s `(1,1)` entry
  /// is `0.00517...`, not `exp(-700)`, because the entry `-700` is not
  /// exactly the true eigenvalue `lSmall`, even though both round to the
  /// same double) is lost entirely.
  ///
  /// The fix recovers that offset exactly via the characteristic
  /// polynomial `p(x) = (x-lBig)*(x-lSmall)`, which evaluates to `-b*c`
  /// identically at `x = a` and at `x = d` (`p(a) = a^2-(a+d)a+ad-bc =
  /// -bc`, `p(d) = d^2-(a+d)d+ad-bc = -bc`), independent of any rounding
  /// in `lBig`/`lSmall` themselves. `x - lSmall` is a subtraction of two
  /// independently rounded doubles (`x` is an exact matrix entry, but
  /// `lSmall` carries up to half a ulp of its own rounding error, roughly
  /// `machineEpsilon * |lSmall|` in absolute terms); when `x` and `lSmall`
  /// are close enough that the true difference is comparable to or
  /// smaller than that rounding error, the subtraction is dominated by
  /// noise, down to and including collapsing to exactly 0 when `x` and
  /// `lSmall` round to the same double. `x - lSmall = -bc / (x - lBig)`
  /// recovers the offset from the well-conditioned `x - lBig` instead
  /// (large whenever `x` sits close to `lSmall`, so its own relative
  /// error stays at the ordinary single-ulp level), with no cancellation
  /// anywhere in that division. [c1] (the already-computed,
  /// well-conditioned divided difference `(fBig - fSmall) / (lBig -
  /// lSmall)`) is reused unchanged for the off-diagonal entries, which
  /// never had a precision problem.
  Matrix _lagrangeClosedForm2x2(
    double fBig,
    double fSmall,
    double lBig,
    double lSmall,
    double c1,
  ) {
    final double a = _rows[0][0];
    final double b = _rows[0][1];
    final double c = _rows[1][0];
    final double d = _rows[1][1];
    final double bc = b * c;
    // `b` and `c` are both nonzero here (the exactly-triangular case has
    // its own closed form in [_triangularClosedForm2x2]), so a `bc` that
    // computes to exactly 0 is an underflow of the true, nonzero product,
    // not a genuine zero; the identity below would then silently report
    // an offset of 0 regardless of the true value, so it must not be
    // trusted in that case.
    final bool bcUnderflowed = bc == 0;

    // Cancellation-risk threshold shared with [_general2x2Exp],
    // [_general2x2Log] and [_general2x2RealPower]'s close-eigenvalue
    // gating: approximately `sqrt(machineEpsilon)`, comfortably above the
    // single-ulp rounding noise floor and comfortably below the scale at
    // which a genuinely well-separated subtraction should be trusted.
    const double closeEigenvalueThreshold = 1.4901161193847656e-08;

    // D38 / round 13 correction, finding 1: anchor at whichever of
    // fBig/fSmall has the SMALLER magnitude, not always at fSmall (the
    // eigenvalue-magnitude-smaller side), as the previous version did. `f`
    // is not always magnitude-increasing in the same direction as
    // `|lambda|`: for [_general2x2Exp] with a very negative,
    // larger-magnitude eigenvalue (lBig) paired with a smaller-magnitude
    // positive eigenvalue (lSmall), `exp(lBig)` is tiny while
    // `exp(lSmall)` is huge, i.e. `fSmall` is actually the huge value
    // (e.g. `exp([[700,1],[1e-100,-701]])`: `lBig` is the `-701`-side
    // eigenvalue, so `fBig = exp(lBig)` is tiny, while `fSmall =
    // exp(lSmall)` is huge). The same inversion happens for
    // [_general2x2RealPower] with a negative exponent `y`: raising the
    // larger-magnitude eigenvalue to a negative power can make it the
    // smaller function value. Anchoring at a huge `fSmall` and then
    // subtracting a comparably huge `c1*offset` to reach a diagonal entry
    // whose true value is the tiny `fBig` is catastrophic cancellation of
    // two huge quantities down to a tiny target, exactly the failure this
    // closed form exists to avoid. Anchoring at whichever f-value is
    // smaller in magnitude never has that problem: the other diagonal
    // entry only ever needs a moderate correction added to a value that is
    // already close to its own target.
    final bool fSmallIsSafeAnchor = fSmall.abs() <= fBig.abs();
    final double fAnchor = fSmallIsSafeAnchor ? fSmall : fBig;
    final double lAnchor = fSmallIsSafeAnchor ? lSmall : lBig;
    final double lOther = fSmallIsSafeAnchor ? lBig : lSmall;

    // Offset of `x` from `lAnchor`. The direct subtraction is trusted
    // unless it is small enough, relative to `x`/`lAnchor`'s own scale, to
    // be at risk of the rounding-noise cancellation described above; only
    // then is the characteristic-polynomial identity used instead, and
    // only when it produces a genuinely finite, non-underflowed value.
    double offsetFromAnchor(double x) {
      final double direct = x - lAnchor;
      final double scale = math.max(x.abs(), lAnchor.abs());
      final bool cancellationRisk =
          scale != 0 && (direct.abs() / scale) < closeEigenvalueThreshold;
      if (!cancellationRisk) {
        return direct;
      }
      final double viaIdentity = -bc / (x - lOther);
      final bool viaIdentityUnreliable =
          !viaIdentity.isFinite || (viaIdentity == 0 && bcUnderflowed);
      return viaIdentityUnreliable ? direct : viaIdentity;
    }

    // Anchored at whichever of fBig/fSmall is smaller in magnitude:
    // `fAnchor` is added to a term that can be many orders of magnitude
    // larger, which never cancels, unlike anchoring at the larger-
    // magnitude function value and subtracting out the diagonal entry's
    // honest offset (the bug this replaces).
    double diagonal(double x) => fAnchor + (c1 * offsetFromAnchor(x));

    return Matrix(<List<double>>[
      <double>[diagonal(a), c1 * b],
      <double>[c1 * c, diagonal(d)],
    ]);
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

  /// True when this matrix is one of the five supported matrix-function
  /// classes (scalar, complex-form, diagonal, exactly symmetric, general
  /// 2x2), the same classes [exp], [log] and [sqrt] each dispatch on
  /// (round 8 correction, finding 10). Used to classify a matrix's own
  /// class up front, before any scalar rescaling of its entries: scaling
  /// every entry by the same factor can underflow a genuinely nonzero
  /// off-diagonal entry to exactly 0 (or, symmetrically, cannot ever
  /// manufacture a genuine asymmetry out of one that was not already
  /// there), so classifying the scaled copy instead of the original can
  /// silently accept an input whose own, true structure was never one of
  /// the five supported classes to begin with.
  bool get _isSupportedMatrixFunctionClass {
    if (isScalar) {
      return true;
    }
    if (isComplexForm) {
      return true;
    }
    if (_isExactlyDiagonal()) {
      return true;
    }
    if (_isExactlySymmetric()) {
      return true;
    }
    return rowCount == 2;
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
  ///
  /// D38 / round 13 correction, finding 9: both the complex-eigenvalue-pair
  /// branch and the close-real-eigenvalue branch used to build a
  /// standalone `c0` (`em*cos(w) - c1*m`, `fLo - c1*lLo`) that can overflow
  /// even when every entry `c0` feeds into stays finite, since `c1*m`
  /// (respectively `c1*lLo`) is not itself one of the matrix's own,
  /// bounded quantities the way `c1*(a-m)` (respectively `c1*(a-lLo)`) is.
  /// Both branches now compute each diagonal entry directly in centered
  /// form, `em*cos(w) + c1*(a-m)` and `fLo + c1*(a-lLo)`, mirroring the
  /// repeated-real-eigenvalue branch below (already fixed this way).
  /// Every branch now returns directly, so no standalone `c0` is ever
  /// materialized in this method at all.
  Matrix _general2x2Exp() {
    final double a = _rows[0][0];
    final double b = _rows[0][1];
    final double c = _rows[1][0];
    final double d = _rows[1][1];
    final ({bool isComplex, double lambda1, double lambda2, double m, double w})
    eigen = _exactRealEigen2x2(a, b, c, d);

    if (eigen.isComplex) {
      final double m = eigen.m;
      final double w = eigen.w;
      _requireComplexPairPartsInPrecisionRange(m, w, 'matrix exponential');
      final double em = _checkFiniteScalar(math.exp(m));
      final double c1 = em * _sinOverX(w);
      final double emCos = em * math.cos(w);
      final double entry00 = _checkFiniteScalar(emCos + (c1 * (a - m)));
      final double entry11 = _checkFiniteScalar(emCos + (c1 * (d - m)));
      final double entry01 = _checkFiniteScalar(c1 * b);
      final double entry10 = _checkFiniteScalar(c1 * c);
      return _checkFiniteMatrix(
        Matrix(<List<double>>[
          <double>[entry00, entry01],
          <double>[entry10, entry11],
        ]),
      );
    }

    final double l1 = eigen.lambda1;
    final double l2 = eigen.lambda2;
    _requireEigenvaluesInPrecisionRange(<double>[l1, l2], 'matrix exponential');

    if (l1 == l2) {
      // Round 12 correction, finding 6: c0 = el - c1*l (c1 = el)
      // materializes c1*l, which overflows once el sits near double's
      // max even though every entry c0 actually feeds into
      // (c0 + c1*a = el + c1*(a-l), c0 + c1*d = el + c1*(d-l)) stays
      // finite, since (a-l) and (d-l) are the matrix's own,
      // well-conditioned offsets from the repeated eigenvalue. Compute
      // those offset products directly instead of going through the
      // overflow-prone standalone c0, the same pattern already used
      // for the complex-eigenvalue-pair power branch (Round 12
      // correction, finding 4).
      final double l = l1;
      final double el = _checkFiniteScalar(math.exp(l));
      final double c1 = el;
      final double entry00 = _checkFiniteScalar(el + (c1 * (a - l)));
      final double entry11 = _checkFiniteScalar(el + (c1 * (d - l)));
      final double entry01 = _checkFiniteScalar(c1 * b);
      final double entry10 = _checkFiniteScalar(c1 * c);
      return _checkFiniteMatrix(
        Matrix(<List<double>>[
          <double>[entry00, entry01],
          <double>[entry10, entry11],
        ]),
      );
    }

    final double lLo = math.min(l1, l2);
    final double lHi = math.max(l1, l2);
    final double fLo = _checkFiniteScalar(math.exp(lLo));
    final double fHi = _checkFiniteScalar(math.exp(lHi));
    final double c1 = fHi * _expm1(lLo - lHi) / (lLo - lHi);

    // Round 10 correction: an exactly triangular block (`b == 0` or
    // `c == 0`) is routed to the exact closed form directly, see
    // [_triangularClosedForm2x2]'s doc comment for why `c0*I + c1*A`
    // loses the small diagonal entry here.
    if (b == 0 || c == 0) {
      final double fa = _checkFiniteScalar(math.exp(a));
      final double fd = _checkFiniteScalar(math.exp(d));
      return _checkFiniteMatrix(_triangularClosedForm2x2(fa, fd, c1));
    }

    // Round 12 correction, finding 1: a genuinely non-triangular
    // matrix (both `b` and `c` nonzero) suffers the same near
    // triangular diagonal cancellation the triangular case above is
    // routed away from, once its two eigenvalues are far enough
    // apart that `fHi` dwarfs `fLo` (e.g.
    // `exp([[700,1],[1e-300,-700]])`: `fLo` around 9.86e-305 sits
    // hundreds of orders of magnitude below `fHi` around 1.01e304).
    // `c0 = fLo - c1*lLo` then loses `fLo` entirely to rounding
    // against `c1*lLo`, itself `O(fHi)` in magnitude, so the
    // diagonal entry that should recover `fLo` comes back as
    // exactly 0. Mirror the same closeness threshold and Lagrange
    // closed form [_general2x2RealPower] uses for its analogous far
    // apart, non-triangular case (see [_lagrangeClosedForm2x2]'s doc
    // comment).
    final bool hiIsLarger = lHi.abs() >= lLo.abs();
    final double lBig = hiIsLarger ? lHi : lLo;
    final double lSmall = hiIsLarger ? lLo : lHi;
    final double fBig = hiIsLarger ? fHi : fLo;
    final double fSmall = hiIsLarger ? fLo : fHi;
    const double closeEigenvalueThreshold = 1.4901161193847656e-08;
    final double relativeGap = (lBig - lSmall).abs() / lBig.abs();
    if (relativeGap < closeEigenvalueThreshold) {
      // D38 / round 13 correction, finding 9: see this method's own doc
      // comment above; `fLo` and `fHi` stay comparable in magnitude here
      // (`exp` never spreads two close inputs far apart in output), so
      // this centered form never loses precision, it only avoids ever
      // materializing the overflow-prone standalone `c1*lLo`.
      final double entry00 = _checkFiniteScalar(fLo + (c1 * (a - lLo)));
      final double entry11 = _checkFiniteScalar(fLo + (c1 * (d - lLo)));
      final double entry01 = _checkFiniteScalar(c1 * b);
      final double entry10 = _checkFiniteScalar(c1 * c);
      return _checkFiniteMatrix(
        Matrix(<List<double>>[
          <double>[entry00, entry01],
          <double>[entry10, entry11],
        ]),
      );
    }
    return _checkFiniteMatrix(
      _lagrangeClosedForm2x2(fBig, fSmall, lBig, lSmall, c1),
    );
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
      _requireComplexPairPartsInPrecisionRange(m, w, 'matrix logarithm');
      final double radius = _hypot(m, w);
      if (!radius.isFinite) {
        throw MatrixDomainError(
          'Logarithm magnitude overflowed to a non-finite value.',
          errorId: CalculatrixErrorId.nonFinite,
        );
      }
      final double angle = math.atan2(w, m);
      final double logRadius = _checkFiniteScalar(math.log(radius));

      // Round 12 correction, finding 10: c1 = angle/w materializes a
      // standalone value that overflows once w sits at a far smaller
      // scale than angle (bounded by pi), even though every entry it
      // actually feeds into (c0 + c1*a = logRadius + c1*(a-m),
      // c0 + c1*d = logRadius + c1*(d-m), c1*b, c1*c) is itself finite,
      // since (a-m), (d-m), b and c all share the original matrix's own
      // scale, the same scale w already sits at. Computing each ratio
      // ((a-m)/w, (d-m)/w, b/w, c/w) first, before multiplying by angle,
      // never forms that unrepresentable intermediate, mirroring the
      // same pattern already used for power's complex-eigenvalue-pair
      // branch (Round 12 correction, finding 4).
      final double aMinusM = a - m;
      final double dMinusM = d - m;
      final double entry00 = _checkFiniteScalar(
        logRadius + (angle * (aMinusM / w)),
      );
      final double entry11 = _checkFiniteScalar(
        logRadius + (angle * (dMinusM / w)),
      );
      final double entry01 = _checkFiniteScalar(angle * (b / w));
      final double entry10 = _checkFiniteScalar(angle * (c / w));
      return _checkFiniteMatrix(
        Matrix(<List<double>>[
          <double>[entry00, entry01],
          <double>[entry10, entry11],
        ]),
      );
    } else {
      final double l1 = eigen.lambda1;
      final double l2 = eigen.lambda2;
      _requireEigenvaluesInPrecisionRange(<double>[l1, l2], 'matrix logarithm');
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
        // Round 12 correction, finding 9: c1 = 1/l materializes a
        // standalone value that overflows for a subnormal-scale
        // repeated eigenvalue, even though every entry it actually
        // feeds into (logL + (1/l)*(a-l), logL + (1/l)*(d-l), (1/l)*b,
        // (1/l)*c) is itself finite, since (a-l), (d-l), b and c all
        // share the repeated eigenvalue's own scale (a genuine Jordan
        // coupling forces their magnitude down to roughly l's own).
        // Computing each ratio ((a-l)/l, (d-l)/l, b/l, c/l) first, before
        // adding logL, never forms that unrepresentable intermediate,
        // mirroring the same pattern already used for power's
        // repeated-eigenvalue branch (Round 12 correction, finding 8).
        final double logL = _checkFiniteScalar(math.log(l));
        final double entry00 = _checkFiniteScalar(logL + ((a - l) / l));
        final double entry11 = _checkFiniteScalar(logL + ((d - l) / l));
        final double entry01 = _checkFiniteScalar(b / l);
        final double entry10 = _checkFiniteScalar(c / l);
        return _checkFiniteMatrix(
          Matrix(<List<double>>[
            <double>[entry00, entry01],
            <double>[entry10, entry11],
          ]),
        );
      } else {
        if (l1 == 0 || l2 == 0) {
          throw MatrixDomainError(
            'Logarithm is undefined for a zero eigenvalue.',
            errorId: CalculatrixErrorId.logUndefined,
          );
        }

        // Round 11 correction, finding 1: `log1p((l1 - l2) / l2)` forms
        // `(l1 - l2) / l2` unconditionally, which overflows to `Infinity`
        // once `l1` and `l2` sit on wildly different scales (for example
        // `l1` around 1e200 and `l2` around 1e-200, ratio far past
        // double's ~1.8e308 range) even though the true divided
        // difference of `log`, `(log l1 - log l2) / (l1 - l2)`, is
        // perfectly finite there (log compresses both terms down to a
        // range of a few hundred, at most). Mirror the same anchor and
        // closeness threshold [_general2x2RealPower] already uses: the
        // log1p form is only needed to avoid cancellation in
        // `log(lBig) - log(lSmall)` when the two eigenvalues are close
        // together; once they are well separated, that cancellation risk
        // does not exist (the two logarithms are far apart too), so the
        // direct divided difference is both safe and exact where the
        // log1p form overflows.
        final bool l1IsLarger = l1.abs() >= l2.abs();
        final double lBig = l1IsLarger ? l1 : l2;
        final double lSmall = l1IsLarger ? l2 : l1;

        // Round 12 correction, finding 7: unlike [_general2x2Exp] and
        // [_general2x2RealPower], where the direct divided difference is
        // safe as soon as the eigenvalues are not close (their outputs
        // spread apart at least as fast as their inputs), log's direct
        // form (log(lBig) - log(lSmall)) / (lBig - lSmall) stays
        // cancellation-prone well past sqrt(machine epsilon): the
        // absolute rounding error in each independently-computed
        // math.log call is of order machineEpsilon * |log(lBig)|, and
        // log(lBig) - log(lSmall) itself is of order relativeGap (since
        // log(1+x) ~= x for small x), so the relative error in c1 is of
        // order machineEpsilon * |log(lBig)| / relativeGap. For the
        // widest magnitude a representable double's logarithm can reach
        // (|log(lBig)| up to ~745, near the underflow/overflow edges of
        // double precision), that error only drops below 1e-9 once
        // relativeGap exceeds roughly 1.65e-4, so the eigenvalue
        // closeness threshold used to route to the cancellation-safe
        // log1p form must be widened well past sqrt(machine epsilon)
        // here specifically, with margin to spare.
        const double closeEigenvalueThreshold = 1e-3;
        final double relativeGap = (lBig - lSmall).abs() / lBig.abs();
        if (relativeGap < closeEigenvalueThreshold) {
          c1 = _log1p((lSmall - lBig) / lBig) / (lSmall - lBig);
        } else {
          final double logBig = math.log(lBig);
          final double logSmall = math.log(lSmall);
          c1 = (logBig - logSmall) / (lBig - lSmall);
        }
        c0 = math.log(lBig) - c1 * lBig;

        // Round 10 correction: same triangular exact closed form as
        // [_general2x2Exp], see [_triangularClosedForm2x2]'s doc comment.
        if (b == 0 || c == 0) {
          final double fa = _checkFiniteScalar(math.log(a));
          final double fd = _checkFiniteScalar(math.log(d));
          return _checkFiniteMatrix(_triangularClosedForm2x2(fa, fd, c1));
        }
      }
    }
    return _checkFiniteMatrix(_c0IPlusC1A(c0, c1));
  }

  /// [power]'s non-integer real-exponent case for a general (non-diagonal,
  /// non-exactly-symmetric) 2x2 matrix via the divided-difference closed
  /// form. Also used, via [_matrixRealPower], for [sqrt]'s general-2x2
  /// class (`y == 0.5`). A repeated zero eigenvalue with genuine Jordan
  /// coupling (this branch is only reached for a matrix that is not
  /// diagonal, so a repeated zero here always implies real coupling) is
  /// [CalculatrixErrorId.logUndefined] regardless of the sign of `y` or of
  /// [rejectZeroEigenvalue]: a genuine Jordan block has no meaningful
  /// square root or power at all, for either caller.
  ///
  /// [rejectZeroEigenvalue] (round 9 correction, finding 4, restoring
  /// runbook D25 case 5 / issue #5 amendment D34) distinguishes the two
  /// callers for the *non*-repeated case where exactly one eigenvalue is
  /// zero: [power] (`true`) always rejects a zero eigenvalue with a
  /// non-integer exponent as log-undefined, regardless of the sign of `y`;
  /// [sqrt] (`false`) keeps its existing behavior, where `0^0.5 = 0`
  /// carries through for `y >= 0`.
  Matrix _general2x2RealPower(
    double y, {
    required bool rejectZeroEigenvalue,
    required String operation,
  }) {
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
      _requireComplexPairPartsInPrecisionRange(m, w, operation);
      final double radius = _hypot(m, w);
      if (!radius.isFinite) {
        throw MatrixDomainError(
          'Matrix power magnitude overflowed to a non-finite value.',
          errorId: CalculatrixErrorId.nonFinite,
        );
      }
      final double angle = math.atan2(w, m);
      final double rToY = _checkFiniteScalar(math.pow(radius, y).toDouble());
      final double rToYSin = rToY * math.sin(y * angle);
      final double rToYCos = rToY * math.cos(y * angle);

      // Round 12 correction, finding 4: `c1 = rToY*sin(y*angle)/w`, then
      // every entry as `c0 + c1*A` for `c0 = rToY*cos(y*angle) - c1*m`,
      // materializes `c1` itself as a standalone value, even though the
      // only quantities anything downstream actually needs are `c1*b`,
      // `c1*c` and `c1*(a-m)`/`c1*(d-m)`. `rToY` alone can already sit
      // within a few orders of magnitude of double's max or min (`radius`
      // raised to `y` controls that, independent of `w`), while `w`, `b`,
      // `c` and `a-m`/`d-m` all share the original matrix's own, possibly
      // far tinier or huger, scale: dividing `rToY*sin(y*angle)` by `w`
      // first can overflow to `Infinity`, or underflow to exactly 0, even
      // though the true `b`/`c`/`(a-m)`-scaled products are perfectly
      // representable (e.g. `[[0,1e-200],[-2e-200,0]]^-1.5`: true `(0,1)`
      // entry is `~-2.97e299`, but `c1` alone would need to be
      // `~-2.97e499`, past double's range entirely). Computing `b/w`,
      // `c/w` and `(a-m)/w`/`(d-m)/w` first instead, before multiplying
      // by `rToY*sin(y*angle)`, never forms that unrepresentable
      // intermediate: each ratio is well-conditioned (comparable
      // matrix-scale quantities divided by each other), and the result is
      // exactly the same mathematical entry, just reordered.
      final double aMinusM = a - m;
      final double dMinusM = d - m;
      final double entry00 = _checkFiniteScalar(
        rToYCos + (rToYSin * (aMinusM / w)),
      );
      final double entry11 = _checkFiniteScalar(
        rToYCos + (rToYSin * (dMinusM / w)),
      );
      final double entry01 = _checkFiniteScalar(rToYSin * (b / w));
      final double entry10 = _checkFiniteScalar(rToYSin * (c / w));
      return _checkFiniteMatrix(
        Matrix(<List<double>>[
          <double>[entry00, entry01],
          <double>[entry10, entry11],
        ]),
      );
    } else {
      final double l1 = eigen.lambda1;
      final double l2 = eigen.lambda2;
      _requireEigenvaluesInPrecisionRange(<double>[l1, l2], operation);
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
        // Round 12 correction, finding 8: c0 = pow(l,y) - c1*l
        // materializes c1*l, which overflows once pow(l,y) sits near
        // double's max even though every entry it actually feeds into
        // (c0 + c1*a = fl + c1*(a-l), c0 + c1*d = fl + c1*(d-l)) stays
        // finite, since (a-l) and (d-l) are the matrix's own,
        // well-conditioned offsets from the repeated eigenvalue. Compute
        // those offset products directly instead of going through the
        // overflow-prone standalone c0, the same pattern already used
        // for exp's repeated-eigenvalue branch (Round 12 correction,
        // finding 6) and power's complex-eigenvalue-pair branch (Round
        // 12 correction, finding 4).
        final double fl = _checkFiniteScalar(math.pow(l, y).toDouble());
        c1 = _checkFiniteScalar(y * math.pow(l, y - 1).toDouble());
        final double entry00 = _checkFiniteScalar(fl + (c1 * (a - l)));
        final double entry11 = _checkFiniteScalar(fl + (c1 * (d - l)));
        final double entry01 = _checkFiniteScalar(c1 * b);
        final double entry10 = _checkFiniteScalar(c1 * c);
        return _checkFiniteMatrix(
          Matrix(<List<double>>[
            <double>[entry00, entry01],
            <double>[entry10, entry11],
          ]),
        );
      } else {
        if (l1 == 0 || l2 == 0) {
          if (rejectZeroEigenvalue || y < 0) {
            throw MatrixDomainError(
              'A zero eigenvalue cannot be raised to a non-integer real '
              'power.',
              errorId: CalculatrixErrorId.logUndefined,
            );
          }
          final double lOther = l1 == 0 ? l2 : l1;
          c1 = _checkFiniteScalar(math.pow(lOther, y - 1).toDouble());
          c0 = 0;
        } else {
          // Round 8 correction, finding 8: anchor the divided difference
          // at whichever eigenvalue has the larger magnitude, not always
          // l2. Anchoring at a far-smaller-magnitude eigenvalue makes
          // lSmall^y prone to underflowing to exactly 0 while the paired
          // expm1(y*log1p((lBig-lSmall)/lSmall)) term, whose argument
          // scales with lBig/lSmall, is prone to overflowing to Infinity,
          // so their product is 0*Infinity = NaN. Anchoring at the
          // larger-magnitude eigenvalue instead keeps lBig^y away from
          // underflow and keeps the expm1 argument's sign safely bounded
          // (log1p((lSmall-lBig)/lBig) is always > -1, so its expm1 result
          // never overflows). This is the same linear interpolant through
          // (l1, l1^y) and (l2, l2^y) either way, just computed from the
          // other end.
          final bool l1IsLarger = l1.abs() >= l2.abs();
          final double lBig = l1IsLarger ? l1 : l2;
          final double lSmall = l1IsLarger ? l2 : l1;

          // D38 / round 13 correction, finding 11: bypass the close/far
          // divided-difference branching below entirely for `y == 0.5`
          // (this covers both a direct `power(0.5)` call and every call
          // routed in from [sqrt]), regardless of range or how close the
          // eigenvalues are. The far branch's direct divided difference
          // computes `logDiff = log(lBig) - log(lSmall)` and derives `c1`
          // from `expm1(y*logDiff)`; once `lBig` itself has a large
          // magnitude (so `log(lBig)` is itself a large number, not near
          // zero) that subtraction cancels many significant digits even
          // when `lBig` and `lSmall` are close together, e.g.
          // `lBig = 1e100`, a relative gap of ~1.49e-8: `log(lBig)` is
          // ~230.3, and the ~8 significant digits of relative closeness
          // between the two eigenvalues cancel against that, leaving only
          // ~5-6 correct digits in `c1`. This is invisible whenever
          // `lBig` happens to be near 1 (`log(lBig) ~= 0`, nothing to
          // cancel against), which is exactly why it went undetected
          // earlier. The identity `c1 = 1 / (sqrt(lBig) + sqrt(lSmall))`
          // is algebraically equivalent, in exact arithmetic, to the
          // general divided difference specialized at `y = 0.5` (since
          // `sqrt(lBig)^2 - sqrt(lSmall)^2 =
          // (sqrt(lBig)-sqrt(lSmall)) * (sqrt(lBig)+sqrt(lSmall)) =
          // lBig - lSmall`), but never routes through `math.log`/`expm1`
          // at all, so it has no cancellation risk at any scale or
          // eigenvalue gap.
          if (y == 0.5) {
            final double sqrtBig = _checkFiniteScalar(math.sqrt(lBig));
            final double sqrtSmall = _checkFiniteScalar(math.sqrt(lSmall));
            final double c1Sqrt = 1 / (sqrtBig + sqrtSmall);

            if (b == 0 || c == 0) {
              final double fa = _checkFiniteScalar(math.sqrt(a));
              final double fd = _checkFiniteScalar(math.sqrt(d));
              return _checkFiniteMatrix(
                _triangularClosedForm2x2(fa, fd, c1Sqrt),
              );
            }

            return _checkFiniteMatrix(
              _lagrangeClosedForm2x2(sqrtBig, sqrtSmall, lBig, lSmall, c1Sqrt),
            );
          }

          final double lyBig = _checkFiniteScalar(math.pow(lBig, y).toDouble());

          // Round 9 correction, finding 1: (lSmall-lBig)/lBig rounds to
          // exactly -1.0 once lSmall is negligible next to lBig (their
          // difference already loses lSmall entirely before the division
          // even runs), which sends log1p to -Infinity and collapses the
          // whole divided difference to c1=1, c0=0, i.e. the input matrix
          // returned unchanged, or to a non-finite result. The log1p/expm1
          // form is only needed to avoid cancellation in f(lBig)-f(lSmall)
          // when the two eigenvalues are close together; when they are
          // well separated (relativeGap not small) that cancellation risk
          // does not exist, so the direct divided difference is both safe
          // and exact where the log1p form breaks down.
          const double closeEigenvalueThreshold = 1.4901161193847656e-08;
          final double relativeGap = (lBig - lSmall).abs() / lBig.abs();
          if (relativeGap < closeEigenvalueThreshold) {
            c1 =
                lyBig *
                _expm1(y * _log1p((lSmall - lBig) / lBig)) /
                (lSmall - lBig);
            c0 = lyBig - c1 * lBig;
          } else {
            final double lySmall = _checkFiniteScalar(
              math.pow(lSmall, y).toDouble(),
            );

            // Round 12 correction, finding 5 (revised): even when the
            // eigenvalues themselves are far apart (relativeGap large, so
            // the branch above was not taken), pow(lBig, y) and
            // pow(lSmall, y) can still round to the same double once y is
            // astronomically small, since both collapse toward 1
            // regardless of how far apart lBig and lSmall are (e.g.
            // lBig=2, lSmall=1, y=1e-20; or, more subtly, lBig=1e200,
            // lSmall=1e-200, y=1e-20, where both pow values round to
            // exactly 1.0 even though the true divided difference is
            // ~9.21e-218). The direct divided difference
            // (lyBig - lySmall) / (lBig - lSmall) then collapses to
            // exactly 0, losing that true, tiny, nonzero result.
            //
            // The first fix gated a log1p/expm1 recovery behind a
            // "function value cancellation risk" heuristic, falling back
            // to the broken direct form whenever that heuristic's own
            // log1p argument degenerated (an extreme eigenvalue ratio
            // rounds (lSmall-lBig)/lBig to exactly -1.0), which is
            // exactly the coordinator's counterexample above: silently
            // wrong again, just for a narrower set of inputs.
            //
            // This replacement is unconditional: no branch on any
            // cancellation-risk heuristic at all. It rests on the exact
            // identity lyBig - lySmall = lySmall * expm1(t), where
            // t = y * logDiff and logDiff = ln(lBig) - ln(lSmall) is the
            // (always well-conditioned; lBig and lSmall are each
            // strictly positive here, the zero-eigenvalue case having
            // already been routed to its own branch above) log
            // difference between the two eigenvalues. logDiff and t
            // themselves never overflow (math.log of any positive double
            // is bounded in [-745, 709]), but expm1's own argument can:
            // exp(x), and therefore expm1(x), overflows for x past
            // ~709, exactly the failure this fix exists to remove, not
            // reintroduce (a naive unconditional
            // lySmall * expm1(y * logDiff) form overflows for, e.g.,
            // lBig=1e300, lSmall=1e-300, y=1.02, where t ~ 1409).
            //
            // Since logDiff > 0 always (lBig has the strictly larger
            // magnitude here, confirmed by relativeGap being above the
            // close-eigenvalue threshold), t's sign always matches y's
            // sign, and is used, not as a numerical cancellation
            // heuristic, but as the deterministic choice of which
            // already-known-finite anchor (lySmall or lyBig, both
            // finite-checked above) to scale by, so that expm1 is always
            // handed a non-positive argument, where it is always bounded
            // in [-1, 0] and therefore can never overflow:
            //   t <= 0 (y <= 0): lyBig - lySmall = lySmall * expm1(t)
            //   t >  0 (y >  0): lyBig - lySmall = -lyBig * expm1(-t)
            // (the second form follows the same identity applied from
            // the other anchor: -lyBig*expm1(-t) = lyBig*(1-exp(-t)) =
            // lyBig - lyBig*exp(-t) = lyBig - lySmall, using
            // exp(-t) = (lSmall/lBig)^y). Either way, the product of a
            // finite anchor with a [-1, 0]-bounded expm1 result is
            // itself bounded by that anchor's own magnitude, so it can
            // never overflow. The denominator (lBig - lSmall) is only
            // divided in last, and is safe here because this is
            // specifically the far-apart branch (relativeGap already
            // confirmed not small by the check above).
            final double logDiff = math.log(lBig) - math.log(lSmall);
            final double t = y * logDiff;
            final double numerator = t <= 0
                ? lySmall * _expm1(t)
                : -lyBig * _expm1(-t);
            c1 = _checkFiniteScalar(numerator) / (lBig - lSmall);

            // Round 10 correction: same triangular exact closed form as
            // [_general2x2Exp] and [_general2x2Log], see
            // [_triangularClosedForm2x2]'s doc comment.
            if (b == 0 || c == 0) {
              final double fa = _checkFiniteScalar(
                math.pow(a, y).toDouble(),
              );
              final double fd = _checkFiniteScalar(
                math.pow(d, y).toDouble(),
              );
              return _checkFiniteMatrix(
                _triangularClosedForm2x2(fa, fd, c1),
              );
            }

            // Round 11 correction, finding 3: a genuinely non-triangular
            // matrix (both `b` and `c` nonzero) can still have one
            // diagonal entry sitting close to `lSmall`, and `c0 + c1*A`
            // loses that entry the same way it lost the exactly
            // triangular case, see [_lagrangeClosedForm2x2]'s doc
            // comment.
            return _checkFiniteMatrix(
              _lagrangeClosedForm2x2(lyBig, lySmall, lBig, lSmall, c1),
            );
          }
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

/// Testing-only seam for exercising [CalculatrixErrorId.noConvergence] on
/// [Matrix.sqrt]'s exactly-symmetric-matrix path.
///
/// Behaves exactly like calling `sqrt()` on an exactly symmetric [matrix],
/// except the cyclic Jacobi sweep budget is the caller-supplied
/// [maxSweeps] instead of the fixed production budget,
/// [CalculatrixNumericPolicy.jacobiMaxSweeps]. `sqrt` itself does not
/// expose this budget as a public parameter (round 8 correction, finding
/// 11): no legitimate finite, well-posed symmetric input needs a budget
/// other than the production one, so exposing it there would only invite
/// a caller to silently trade accuracy for speed with no real benefit.
/// This function exists solely so a test can supply a matrix and a tiny
/// budget (for example 0 sweeps) and deterministically observe
/// noConvergence, without changing what `sqrt` itself accepts.
@visibleForTesting
Matrix debugCyclicJacobiSqrtWithSweepBudget(Matrix matrix, int maxSweeps) {
  return matrix._symmetricRealFunction(
    (double v) =>
        matrix._realScalarPower(v, 0.5, rejectZeroEigenvalue: false),
    maxSweeps: maxSweeps,
    operation: 'square root',
  );
}
