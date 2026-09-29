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
  bool get isComplexForm {
    if (rowCount != 2 || columnCount != 2) return false;
    final double tol = CalculatrixNumericPolicy.defaultAbsoluteTolerance;
    return (_rows[0][0] - _rows[1][1]).abs() < tol &&
        (_rows[0][1] + _rows[1][0]).abs() < tol;
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

  Matrix _inverse({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    _requireSquare(operation: 'inverse');

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

  Matrix eigenvalues({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
    int maxIterations = 200,
  }) {
    _requireSquare(operation: 'eigenvalues');

    if (isScalar) {
      return this;
    }

    if (rowCount == 2) {
      return _eigenvalues2x2(absoluteTolerance);
    }

    // General NxN: Hessenberg reduction then QR iteration with Wilkinson shift
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

        // Wilkinson shift: eigenvalue of trailing 2x2 block closest to h[n-1][n-1]
        final double a = h[size - 2][size - 2];
        final double b = h[size - 2][size - 1];
        final double c = h[size - 1][size - 2];
        final double d = h[size - 1][size - 1];
        final double shift = _wilkinsonShift(a, b, c, d);

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
          'Eigenvalues are undefined in the real domain for this matrix.',
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

  Diagonalization diagonalization({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    _requireSquare(operation: 'diagonalization');

    final Matrix eigenvalueColumn = eigenvalues(
      absoluteTolerance: absoluteTolerance,
    );

    final int n = rowCount;
    final List<double> lambdas = List<double>.generate(
      n,
      (int i) => eigenvalueColumn.at(i, 0),
      growable: false,
    );

    // Build D as a diagonal matrix
    final List<List<double>> dRows = List<List<double>>.generate(
      n,
      (int r) => List<double>.generate(
        n,
        (int c) => r == c ? lambdas[r] : 0,
        growable: false,
      ),
      growable: false,
    );

    // Build P: for each eigenvalue, solve (A - λI)x = 0 via row reduction
    final List<List<double>> pColumns = <List<double>>[];

    for (int k = 0; k < n; k++) {
      final double lambda = lambdas[k];

      // Form A - λI
      final List<List<double>> augmented = List<List<double>>.generate(
        n,
        (int r) => List<double>.generate(
          n,
          (int c) => _rows[r][c] - (r == c ? lambda : 0),
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
      (int r) =>
          List<double>.generate(n, (int c) => pColumns[c][r], growable: false),
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
      (int r) => List<double>.generate(n, (int c) {
        final Matrix minorMatrix = minor(r, c);
        final double det = minorMatrix.determinant().scalarValue;
        final double sign = (r + c).isEven ? 1 : -1;
        return sign * det;
      }, growable: false),
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
    final double trace = a + d;
    final double det = (a * d) - (b * c);
    double discriminant = (trace * trace) - (4 * det);

    if (discriminant.abs() <= absoluteTolerance) {
      discriminant = 0;
    }

    if (discriminant < 0) {
      throw MatrixDomainError(
        'Eigenvalues are undefined in the real domain for this matrix.',
      );
    }

    final double sqrtD = math.sqrt(discriminant);
    eigenvaluesList.add((trace + sqrtD) / 2);
    eigenvaluesList.add((trace - sqrtD) / 2);
  }

  /// Computes the Wilkinson shift from a trailing 2x2 block.
  static double _wilkinsonShift(double a, double b, double c, double d) {
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

    if (isScalar) {
      final double source = scalarValue;
      if (source < 0) {
        return Matrix.i.scale(math.sqrt(-source));
      }
      return Matrix.scalar(math.sqrt(source));
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

    // Every tolerance-based decision below (the structural-singularity
    // pre-check, and internally, Newton's own convergence check and the
    // range/null-space split's rank comparisons) is calibrated for a
    // target whose infinity norm is around 1: that is what makes an
    // absolute tolerance like 1e-12 meaningful. A matrix that is
    // uniformly tiny or uniformly huge in absolute terms, but otherwise
    // perfectly well-conditioned, breaks that calibration in either
    // direction: e.g. [[1e-20,2e-20],[2e-20,5e-20]] is nonsingular
    // (det/s^2 = 1) yet every entry sits far below any fixed absolute
    // tolerance, so it looks structurally singular; a uniformly huge
    // analogue could just as easily hide genuine singularity above any
    // fixed absolute tolerance. Normalizing by the target's own norm
    // first, and rescaling the result back afterward, makes every
    // downstream tolerance check scale invariant:
    // sqrt(A) = sqrt(s) * sqrt(A/s) for s = norm(A) > 0, since s*I
    // commutes with everything A/s does.
    final Matrix normalized = scale(1 / norm);
    final double sqrtNorm = math.sqrt(norm);

    // Keep main's Newton path as the first attempt, unchanged, but only
    // when the (normalized) target is not itself structurally singular.
    // Two different things can go wrong when the target is singular, and
    // only one of them is visible from inside the Newton loop:
    //
    //   1. An intermediate iterate goes exactly singular and `_inverse`
    //      throws mid-loop: this is the failure issue #19 described.
    //   2. Subtler, and silent: along a genuinely zero eigenvalue
    //      direction, the Denman-Beavers iterate for that component
    //      halves every step (linear convergence, not Newton's usual
    //      quadratic rate). It can cross the loop's own relative-tolerance
    //      exit threshold while still many orders of magnitude away from
    //      zero, so the loop returns "successfully", with no throw, no
    //      residual in X*X - A (squaring a tiny leftover makes it
    //      negligible), and no signal at all that the entry should have
    //      been exactly zero.
    //
    // Case 2 cannot be caught after the fact by verifying Newton's
    // output, so it is avoided instead by checking beforehand, with a
    // strict, machine-epsilon-scaled tolerance (not the caller's
    // relativeTolerance/absoluteTolerance, which default to 1e-10/1e-12
    // and are the same looseness that let the bug through in the first
    // place), whether A/s is structurally singular. This is deliberately
    // stricter than the caller's own tolerance so a merely tiny but
    // nonzero eigenvalue relative to the target's own norm (e.g. 1e-13
    // on a unit-norm matrix) is not misclassified as singular: that case
    // still converges quadratically through the ordinary Newton path
    // below. Eigenvalues genuinely below this threshold relative to the
    // target's norm are numerically indistinguishable from zero; the
    // range/null-space split returns exactly 0 for them, which is
    // backward stable (X*X reconstructs A to the same tolerance) even
    // when it is not forward-accurate.
    final double machineEpsilon = 2.220446049250313e-16;
    final double structuralZeroTolerance = rowCount * machineEpsilon;
    final bool isStructurallySingular =
        normalized
            .rank(absoluteTolerance: structuralZeroTolerance)
            .scalarValue
            .round() <
        rowCount;

    if (isStructurallySingular) {
      return normalized
          ._sqrtViaRangeNullSplit(
            relativeTolerance: relativeTolerance,
            absoluteTolerance: absoluteTolerance,
            maxIterations: maxIterations,
          )
          .scale(sqrtNorm);
    }

    try {
      return normalized
          ._sqrtViaNewton(
            relativeTolerance: relativeTolerance,
            absoluteTolerance: absoluteTolerance,
            maxIterations: maxIterations,
          )
          .scale(sqrtNorm);
    } on MatrixDomainError {
      return normalized
          ._sqrtViaRangeNullSplit(
            relativeTolerance: relativeTolerance,
            absoluteTolerance: absoluteTolerance,
            maxIterations: maxIterations,
          )
          .scale(sqrtNorm);
    }
  }

  /// The Newton (Denman-Beavers averaging) iteration for the principal
  /// square root, Y(k+1) = (Y(k) + Y(k)⁻¹·A) / 2 starting from Y(0) = I,
  /// with scaling and squaring to keep the target's norm bounded. This is
  /// the original algorithm, unmodified by issue #19: it inverts the
  /// current iterate on every step, so it raises "undefined in the real
  /// domain" the moment that iterate itself goes exactly singular, and
  /// "did not converge" if it exhausts [maxIterations] without meeting
  /// its own (relative) tolerance. [sqrt] independently verifies whatever
  /// this returns against the true target, since a singular target can
  /// make this converge "successfully" here while still being
  /// inaccurate; see [sqrt] for why.
  Matrix _sqrtViaNewton({
    required double relativeTolerance,
    required double absoluteTolerance,
    required int maxIterations,
  }) {
    Matrix scaledTarget = this;
    int scalingSteps = 0;
    while (scaledTarget._infinityNorm() > 4) {
      scaledTarget = scaledTarget.scale(0.25);
      scalingSteps++;
    }

    Matrix current = Matrix.identity(rowCount);
    final double targetNorm = scaledTarget._infinityNorm();
    final double threshold = math.max(
      absoluteTolerance,
      relativeTolerance * math.max(targetNorm, 1),
    );

    for (int iteration = 0; iteration < maxIterations; iteration++) {
      final Matrix inverseCurrent;
      try {
        inverseCurrent = current._inverse(absoluteTolerance: absoluteTolerance);
      } on MatrixDomainError {
        throw MatrixDomainError(
          'Square root is undefined for this matrix in the real domain.',
        );
      }

      final Matrix next = (current + (inverseCurrent * scaledTarget)).scale(
        0.5,
      );
      final double stepNorm = (next - current)._infinityNorm();
      final double residualNorm = ((next * next) - scaledTarget)
          ._infinityNorm();

      current = next;
      if (stepNorm <= threshold && residualNorm <= threshold) {
        return current.scale(math.pow(2, scalingSteps).toDouble());
      }
    }

    final Matrix result = current.scale(math.pow(2, scalingSteps).toDouble());
    final double norm = _infinityNorm();
    final double residualNorm = ((result * result) - this)._infinityNorm();
    if (residualNorm <= math.max(absoluteTolerance, relativeTolerance * norm)) {
      return result;
    }

    throw MatrixDomainError(
      'Square root did not converge for this matrix in the real domain.',
    );
  }

  /// Computes the principal square root of a matrix whose Newton iterate
  /// went singular mid-iteration (issue #19), by splitting off the part
  /// of the matrix that actually causes the singularity: its range
  /// (column space) and null space.
  ///
  /// For any square A, range(A) and ker(A) are complementary A-invariant
  /// subspaces (ℝⁿ = range(A) ⊕ ker(A)) exactly when the zero eigenvalue
  /// is semisimple, which holds if and only if rank(A) == rank(A²) (the
  /// ascent of the zero eigenvalue is at most 1: it has no nontrivial
  /// Jordan block). When that holds:
  ///
  ///   - Build V = [basis of range(A) | basis of ker(A)]. Then
  ///     V⁻¹·A·V = blockdiag(B, 0), where B is A restricted to its own
  ///     range: it is nonsingular, because Bv = 0 for v in range(A) would
  ///     put v in range(A) ∩ ker(A) = {0}.
  ///   - sqrt(A) = V · blockdiag(sqrt(B), 0) · V⁻¹, and sqrt(B) is
  ///     computed with the very same Newton iteration above, which never
  ///     goes singular for B (B is nonsingular by construction). This
  ///     means complex eigenvalue pairs and non-semisimple *nonzero*
  ///     eigenvalues on B are handled exactly as the unmodified Newton
  ///     path already handles them for any nonsingular target.
  ///
  /// When rank(A) != rank(A²), the zero eigenvalue is not semisimple (a
  /// nilpotent Jordan block, for instance): range(A) and ker(A) overlap,
  /// there is no real principal square root, and this raises
  /// MatrixDomainError, unchanged from before issue #19.
  Matrix _sqrtViaRangeNullSplit({
    required double relativeTolerance,
    required double absoluteTolerance,
    required int maxIterations,
  }) {
    final int n = rowCount;

    final int rankA = rank(
      absoluteTolerance: absoluteTolerance,
    ).scalarValue.round();
    final int rankASquared = (this * this)
        .rank(absoluteTolerance: absoluteTolerance)
        .scalarValue
        .round();

    if (rankA != rankASquared) {
      throw MatrixDomainError(
        'Square root is undefined for this matrix in the real domain.',
      );
    }

    final Matrix reduced = rref(absoluteTolerance: absoluteTolerance);
    final List<int> pivotColumns = _pivotColumnIndices(
      reduced.rows,
      n,
      absoluteTolerance,
    );
    final List<List<double>> nullBasis = _nullSpaceBasis(
      reduced.rows,
      n,
      absoluteTolerance,
    );

    final int rangeDimension = pivotColumns.length;
    if (rangeDimension == 0) {
      // A completely empty range basis would make V degenerate (built
      // only from the null space) and leave no block to extract B from.
      // This cannot happen for a target whose caller (sqrt) has already
      // normalized it to infinity norm 1, since the row achieving that
      // norm always has a pivot. Guarded anyway, so an unexpected input
      // (this method is also reachable directly in tests) raises a clear
      // domain error instead of an empty-matrix shape error from the
      // Matrix constructor below.
      throw MatrixDomainError(
        'Square root is undefined for this matrix in the real domain.',
      );
    }
    if (rangeDimension != rankA || rangeDimension + nullBasis.length != n) {
      // Should not happen given the rank(A) == rank(A²) check above; a
      // defensive guard against an unforeseen numerical edge case.
      throw MatrixDomainError(
        'Square root is undefined for this matrix in the real domain.',
      );
    }

    final List<List<double>> rangeBasis = <List<double>>[
      for (final int column in pivotColumns)
        <double>[for (int row = 0; row < n; row++) _rows[row][column]],
    ];

    final List<List<double>> vColumns = <List<double>>[
      ...rangeBasis,
      ...nullBasis,
    ];
    final Matrix v = Matrix(
      List<List<double>>.generate(
        n,
        (int row) => List<double>.generate(
          n,
          (int column) => vColumns[column][row],
          growable: false,
        ),
        growable: false,
      ),
    );

    final Matrix vInverse;
    try {
      vInverse = v._inverse(absoluteTolerance: absoluteTolerance);
    } on MatrixDomainError {
      throw MatrixDomainError(
        'Square root is undefined for this matrix in the real domain.',
      );
    }

    final Matrix transformed = vInverse * this * v;
    final Matrix b = transformed._extractBlock(
      List<int>.generate(rangeDimension, (int i) => i),
    );

    // B is guaranteed nonsingular by construction, so it is safe (and
    // cheap, given Newton's quadratic convergence) to converge it well
    // past the caller's tolerance here: any residual left in sqrt(B)
    // propagates directly into the reconstructed sqrt(A) below, with no
    // further cancellation to absorb it.
    final Matrix sqrtB = b._sqrtViaNewton(
      relativeTolerance: math.min(relativeTolerance, 1e-13),
      absoluteTolerance: math.min(absoluteTolerance, 1e-14),
      maxIterations: maxIterations,
    );

    final Matrix blockDiagonal = Matrix(
      List<List<double>>.generate(
        n,
        (int row) => List<double>.generate(
          n,
          (int column) => row < rangeDimension && column < rangeDimension
              ? sqrtB.at(row, column)
              : 0,
          growable: false,
        ),
        growable: false,
      ),
    );

    return v * blockDiagonal * vInverse;
  }

  /// Returns the pivot column indices of a square matrix already in
  /// reduced row-echelon form: for each nonzero row (in row order), the
  /// column of its leading (first) nonzero entry.
  List<int> _pivotColumnIndices(
    List<List<double>> reduced,
    int n,
    double absoluteTolerance,
  ) {
    final List<int> pivotColumns = <int>[];
    for (int row = 0; row < n; row++) {
      for (int column = 0; column < n; column++) {
        if (reduced[row][column].abs() > absoluteTolerance) {
          pivotColumns.add(column);
          break;
        }
      }
    }
    return pivotColumns;
  }

  /// Returns a basis of the null space of a square matrix already in
  /// reduced row-echelon form, i.e. every solution direction of `reduced *
  /// x = 0`, one vector per free (non-pivot) column. Each vector is
  /// normalized to unit length.
  List<List<double>> _nullSpaceBasis(
    List<List<double>> reduced,
    int n,
    double absoluteTolerance,
  ) {
    final List<int> pivotColumns = _pivotColumnIndices(
      reduced,
      n,
      absoluteTolerance,
    );
    final Set<int> pivotColumnSet = pivotColumns.toSet();

    final List<List<double>> basis = <List<double>>[];
    for (int freeColumn = 0; freeColumn < n; freeColumn++) {
      if (pivotColumnSet.contains(freeColumn)) {
        continue;
      }

      final List<double> vector = List<double>.filled(n, 0);
      vector[freeColumn] = 1;
      for (int i = 0; i < pivotColumns.length; i++) {
        vector[pivotColumns[i]] = -reduced[i][freeColumn];
      }

      double normSquared = 0;
      for (final double value in vector) {
        normSquared += value * value;
      }
      final double norm = math.sqrt(normSquared);
      if (norm > absoluteTolerance) {
        for (int i = 0; i < n; i++) {
          vector[i] /= norm;
        }
      }

      basis.add(vector);
    }

    return basis;
  }

  /// Computes the matrix exponential by splitting A into its independent
  /// diagonal blocks (up to a permutation) and exponentiating each block
  /// separately, via scaling and squaring or, when the shifted block is
  /// exactly nilpotent, an exact finite sum.
  ///
  /// For a square matrix A, expm(A) = I + A + A²/2! + A³/3! + ..., but
  /// summing that series directly on A is only accurate while ‖A‖ stays
  /// small: for a moderate-to-large norm, the terms needed for convergence
  /// grow past any practical cap, and truncating early is silently wrong
  /// rather than merely imprecise.
  ///
  /// Block decomposition: build the coupling graph on A's indices (i ~ j
  /// when A[i][j] != 0 or A[j][i] != 0) and take its connected components.
  /// Up to permuting rows and columns, A is block-diagonal over these
  /// components (every entry connecting two different components is zero
  /// in both directions), so expm(A) is block-diagonal too, with expm of
  /// each block on the diagonal and zero elsewhere: exponentiating each
  /// block on its own, smaller matrix avoids mixing an ill-conditioned
  /// block's error into a well-conditioned one, and lets the per-block
  /// shift below apply independently to each block's own mean eigenvalue
  /// rather than a single shift for the whole matrix.
  ///
  /// Per block B (m x m): let mu = trace(B) / m. If B - mu*I is exactly
  /// nilpotent (its power reaches the exact zero matrix within m steps),
  /// expm(B) = e^mu * (I + N + N²/2! + ... ), computed as an exact finite
  /// sum, with no truncation and no scaling/squaring rounding to introduce
  /// error: this is what lets a matrix like lambda*I + nilpotent (not
  /// itself nilpotent, since its diagonal is lambda, not zero) still use
  /// the exact path. A whole-matrix shift was tried in an earlier revision
  /// and reverted because a single mu applied across independent blocks
  /// with different traces perturbs every block, destroying exactness
  /// everywhere; computing mu per block (after decomposition) avoids that.
  ///
  /// Otherwise, plain scaling and squaring proceeds on B itself (no
  /// shift), using the identity `expm(B) = expm(B / 2^s) ^ (2^s)`: choose
  /// `s` so that `‖B / 2^s‖_inf <= 0.5`, where the Taylor series converges
  /// to double precision in a handful of terms, sum that series, then
  /// square the result `s` times to undo the scaling.
  ///
  /// A 1x1 block is just e^b (the shift and nilpotency check above already
  /// reduce to this: mu = b exactly, B - mu*I is the exact 1x1 zero
  /// matrix, and the finite sum is the single term e^mu = e^b).
  ///
  /// For pure imaginary matrices θ·J (where J = i), this yields:
  /// expm(θ·J) = [[cos(θ), -sin(θ)], [sin(θ), cos(θ)]] (rotation matrix).
  ///
  /// Throws [MatrixDomainError] with [CalculatrixErrorId.nonFinite] when the
  /// true result overflows double precision (D25 row 13): squaring back up
  /// an exponential whose true value is too large to represent yields an
  /// infinite or NaN entry, which is caught here instead of returned
  /// silently.
  /// Returns `matrix * e^mu`. When e^mu alone is not a normal double (it
  /// underflows below 2^-1022 or overflows) while the scaled entries may
  /// still be representable, e^mu is applied in k equal factors e^(mu/k),
  /// each a normal double, so an entry is rounded once at the end instead of
  /// being flushed to zero (or to infinity) before it is multiplied.
  static Matrix _scaleByExp(Matrix matrix, double mu) {
    final double direct = math.exp(mu);
    const double smallestNormal = 2.2250738585072014e-308;
    if (direct.isFinite && direct >= smallestNormal) {
      return matrix.scale(direct);
    }
    const double safeExponent = 700;
    final int factors = (mu.abs() / safeExponent).ceil();
    final double factor = math.exp(mu / factors);
    Matrix result = matrix;
    for (int i = 0; i < factors; i++) {
      result = result.scale(factor);
    }
    return result;
  }

  Matrix exp({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
  }) {
    _requireSquare(operation: 'exponential');

    if (rowCount == 1 && columnCount == 1) {
      // Scalar case: exp(a) = e^a
      return Matrix.scalar(math.exp(scalarValue));
    }

    final List<List<int>> components = _connectedComponents();
    if (components.length == 1) {
      return _expBlock(this, absoluteTolerance: absoluteTolerance);
    }

    final List<List<double>> assembled = List<List<double>>.generate(
      rowCount,
      (_) => List<double>.filled(columnCount, 0, growable: false),
      growable: false,
    );

    for (final List<int> component in components) {
      final Matrix block = _extractBlock(component);
      final Matrix blockExp = _expBlock(
        block,
        absoluteTolerance: absoluteTolerance,
      );
      for (int row = 0; row < component.length; row++) {
        for (int column = 0; column < component.length; column++) {
          assembled[component[row]][component[column]] = blockExp.at(
            row,
            column,
          );
        }
      }
    }

    return _checkFiniteMatrix(Matrix(assembled));
  }

  /// Returns the connected components of the coupling graph on this
  /// matrix's indices (i ~ j when at(i, j) != 0 or at(j, i) != 0), each as
  /// an ascending list of original indices. A diagonal-only entry never
  /// links two different indices, so an all-zero row and column outside
  /// the diagonal makes that index its own singleton component.
  List<List<int>> _connectedComponents() {
    final int size = rowCount;
    final List<bool> visited = List<bool>.filled(size, false);
    final List<List<int>> components = <List<int>>[];

    for (int start = 0; start < size; start++) {
      if (visited[start]) {
        continue;
      }
      final List<int> component = <int>[];
      final List<int> queue = <int>[start];
      visited[start] = true;
      int head = 0;
      while (head < queue.length) {
        final int node = queue[head++];
        component.add(node);
        for (int neighbor = 0; neighbor < size; neighbor++) {
          if (visited[neighbor]) {
            continue;
          }
          if (at(node, neighbor) != 0.0 || at(neighbor, node) != 0.0) {
            visited[neighbor] = true;
            queue.add(neighbor);
          }
        }
      }
      component.sort();
      components.add(component);
    }

    return components;
  }

  /// Extracts the principal submatrix of this matrix at the given
  /// (ascending) indices, preserving their relative order.
  Matrix _extractBlock(List<int> indices) {
    final int size = indices.length;
    return Matrix(
      List<List<double>>.generate(
        size,
        (int row) => List<double>.generate(
          size,
          (int column) => at(indices[row], indices[column]),
          growable: false,
        ),
        growable: false,
      ),
    );
  }

  /// Computes expm(block) for a single block, per the algorithm documented
  /// on [exp]: an exact finite sum when block - mu*I is exactly nilpotent
  /// (mu = trace(block) / size), otherwise plain scaling and squaring on
  /// block itself.
  static Matrix _expBlock(Matrix block, {required double absoluteTolerance}) {
    final int size = block.rowCount;

    if (size == 1) {
      return Matrix.scalar(math.exp(block.scalarValue));
    }

    double traceValue = 0;
    for (int i = 0; i < size; i++) {
      traceValue += block.at(i, i);
    }
    final double mu = traceValue / size;

    final Matrix shifted = Matrix(
      List<List<double>>.generate(
        size,
        (int row) => List<double>.generate(
          size,
          (int column) => row == column
              ? block.at(row, column) - mu
              : block.at(row, column),
          growable: false,
        ),
        growable: false,
      ),
    );

    // Exact nilpotent path (after the per-block shift): no truncation, no
    // scaling.
    final int? nilpotencyIndex = _exactNilpotencyIndex(shifted);
    if (nilpotencyIndex != null) {
      Matrix sum = Matrix.identity(size);
      Matrix nilpotentTerm = Matrix.identity(size);
      double nilpotentFactorial = 1;

      for (int power = 1; power < nilpotencyIndex; power++) {
        nilpotentFactorial *= power;
        nilpotentTerm = nilpotentTerm * shifted;
        sum = sum + nilpotentTerm.scale(1 / nilpotentFactorial);
      }

      return _checkFiniteMatrix(_scaleByExp(sum, mu));
    }

    // Choose s so that ‖block / 2^s‖_inf <= 0.5 (0 when the norm is
    // already small enough that no scaling is needed).
    const double convergenceNormBound = 0.5;
    final double norm = block._infinityNorm();
    final int scalingSteps = norm > convergenceNormBound
        ? (math.log(norm / convergenceNormBound) / math.ln2).ceil()
        : 0;
    final double scaleFactor = math.pow(2, scalingSteps).toDouble();
    final Matrix scaledSource = scalingSteps == 0
        ? block
        : block.scale(1 / scaleFactor);

    // Taylor series on the scaled block: expm(B) = I + B + B²/2! + ...
    // The scaled norm is at most 0.5, so this converges to double precision
    // in well under 50 terms; the cap is only a safety net.
    //
    // Squaring back up `scalingSteps` times roughly doubles the relative
    // error of the running result at each step (for small errors,
    // (X + dX)² ≈ X² + 2 X dX), so the series must converge to a tolerance
    // tighter than the caller's by roughly a factor of `scaleFactor` for the
    // final, squared-up result to still meet it.
    final double seriesTolerance = scalingSteps == 0
        ? absoluteTolerance
        : absoluteTolerance / scaleFactor;
    Matrix result = Matrix.identity(size);
    Matrix term = Matrix.identity(size);
    double factorial = 1;

    for (int n = 1; n <= 100; n++) {
      factorial *= n;
      term = term * scaledSource;
      final Matrix scaledTerm = term.scale(1 / factorial);
      result = result + scaledTerm;

      if (scaledTerm._infinityNorm() < seriesTolerance) {
        break;
      }
    }

    // Undo the scaling: expm(B) = expm(B / 2^s) ^ (2^s), by repeated
    // squaring.
    for (int step = 0; step < scalingSteps; step++) {
      result = result * result;
    }

    return _checkFiniteMatrix(result);
  }

  /// Returns the smallest k in [1, matrix.rowCount] such that matrix^k is
  /// exactly the zero matrix (every entry bit-identical to 0.0), or null if
  /// no such k exists. For an n x n nilpotent matrix the nilpotency index is
  /// always at most n, so checking up to k = n is decisive, not a heuristic
  /// cutoff.
  static int? _exactNilpotencyIndex(Matrix matrix) {
    Matrix power = matrix;
    for (int k = 1; k <= matrix.rowCount; k++) {
      if (_isExactZeroMatrix(power)) {
        return k;
      }
      power = power * matrix;
    }
    return null;
  }

  static bool _isExactZeroMatrix(Matrix matrix) {
    for (int row = 0; row < matrix.rowCount; row++) {
      for (int column = 0; column < matrix.columnCount; column++) {
        if (matrix.at(row, column) != 0.0) {
          return false;
        }
      }
    }
    return true;
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
  ///
  /// A general (non complex-form) 2x2 matrix uses a closed form driven by
  /// its eigenvalues, rather than [diagonalization]: this is what makes a
  /// defective 2x2 base (a repeated eigenvalue with only one independent
  /// eigenvector, so diagonalization's eigenvector matrix P is singular)
  /// still have a well-defined log. Two real eigenvalues use
  /// [_log2x2ClosedForm]; a genuine complex-conjugate pair (off the closed
  /// negative real axis, so never on the branch cut) uses
  /// [_log2x2ComplexConjugateClosedForm] instead of raising
  /// `log-undefined`. `log-undefined` is still raised for a real
  /// eigenvalue `<= 0` (on or across the branch cut) or a singular matrix.
  /// Sizes above 2x2 keep using [diagonalization], unchanged from before.
  Matrix log({
    double absoluteTolerance =
        CalculatrixNumericPolicy.defaultAbsoluteTolerance,
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
      final double radius = math.sqrt((a * a) + (b * b));

      if (radius <= absoluteTolerance) {
        throw MatrixDomainError(
          'Logarithm is undefined for zero magnitude in the complex domain.',
          errorId: CalculatrixErrorId.logUndefined,
        );
      }

      final double angle = math.atan2(b, a);
      return Matrix.complex(math.log(radius), angle);
    }

    if (rowCount == 2) {
      final List<double> realEigenvalues = _realEigenvalues2x2(
        absoluteTolerance,
      );

      if (realEigenvalues.isEmpty) {
        return _log2x2ComplexConjugateClosedForm(absoluteTolerance);
      }
      for (final double eigenvalue in realEigenvalues) {
        if (eigenvalue <= absoluteTolerance) {
          throw MatrixDomainError(
            'Logarithm is undefined for matrices with non-positive real '
            'eigenvalues.',
            errorId: CalculatrixErrorId.logUndefined,
          );
        }
      }

      return _log2x2ClosedForm(realEigenvalues, absoluteTolerance);
    }

    final Diagonalization decomposition = diagonalization(
      absoluteTolerance: absoluteTolerance,
    );

    final List<List<double>> logDiagonal = List<List<double>>.generate(
      rowCount,
      (int row) => List<double>.filled(rowCount, 0, growable: false),
      growable: false,
    );

    for (int index = 0; index < rowCount; index++) {
      final double eigenvalue = decomposition.d.at(index, index);
      if (eigenvalue <= absoluteTolerance) {
        throw MatrixDomainError(
          'Logarithm is undefined for matrices with non-positive eigenvalues '
          'in the real domain.',
          errorId: CalculatrixErrorId.logUndefined,
        );
      }
      logDiagonal[index][index] = math.log(eigenvalue);
    }

    final Matrix p = decomposition.p;
    return p * Matrix(logDiagonal) * p.inverse();
  }

  /// Computes the real eigenvalues of a 2x2 matrix for [log], without
  /// throwing for a genuine complex-conjugate pair (unlike [eigenvalues]):
  /// such a pair simply yields an empty list instead. This is what lets
  /// [log] tell "no real eigenvalue" (log is undefined; a complex result
  /// is not representable outside complex form) apart from "some real
  /// eigenvalue is non-positive" (also log-undefined, but for a real
  /// input off the domain of ln).
  List<double> _realEigenvalues2x2(double absoluteTolerance) {
    final double discriminant = _trace2x2Discriminant(absoluteTolerance);
    if (discriminant < 0) {
      return const <double>[];
    }

    final double trace = _rows[0][0] + _rows[1][1];
    final double sqrtDiscriminant = math.sqrt(discriminant);
    return <double>[
      (trace + sqrtDiscriminant) / 2,
      (trace - sqrtDiscriminant) / 2,
    ];
  }

  // The discriminant of the 2x2 characteristic polynomial, trace^2 -
  // 4*determinant, snapped to exactly 0 within [absoluteTolerance] so a
  // matrix with a genuinely repeated eigenvalue (or one that is repeated
  // up to floating-point noise) is never misclassified as a complex pair
  // by a discriminant that is negative only by rounding error. Shared by
  // [_realEigenvalues2x2] and [_log2x2ComplexConjugateClosedForm] so both
  // agree on exactly the same trace/determinant/discriminant.
  double _trace2x2Discriminant(double absoluteTolerance) {
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
    return discriminant;
  }

  /// Computes `log A` for a 2x2 matrix whose eigenvalues are a genuine
  /// complex-conjugate pair `a +/- bi` (`b > 0`), by the same Sylvester
  /// closed form as [_log2x2ClosedForm], `f(A) = c1*A + c0*I`, solved in
  /// real arithmetic instead of going through complex numbers.
  ///
  /// Writing `log(a+bi) = c1*(a+bi) + c0` and its conjugate equation for
  /// `log(a-bi)`, subtracting and adding the two gives:
  ///   `c1 = arg(a+bi) / b`
  ///   `c0 = ln|a+bi| - a*c1`
  /// (both real, since the imaginary parts of the two equations cancel by
  /// construction). A genuine complex-conjugate pair (`b > 0`) can never
  /// sit on the branch cut of `log` (the closed negative real axis is
  /// purely real), so this never raises `log-undefined`; only a real
  /// eigenvalue `<= 0`, or a singular matrix (which always has real
  /// eigenvalues for a 2x2, so never reaches this method), does.
  Matrix _log2x2ComplexConjugateClosedForm(double absoluteTolerance) {
    final double discriminant = _trace2x2Discriminant(absoluteTolerance);
    final double trace = _rows[0][0] + _rows[1][1];

    final double realPart = trace / 2;
    final double imagPart = math.sqrt(-discriminant) / 2;

    final double magnitude = math.sqrt(
      (realPart * realPart) + (imagPart * imagPart),
    );
    final double angle = math.atan2(imagPart, realPart);

    final double c1 = angle / imagPart;
    final double c0 = math.log(magnitude) - (realPart * c1);

    return scale(c1) + Matrix.identity(rowCount).scale(c0);
  }

  /// Computes `log A` for a 2x2 matrix directly from its two real
  /// eigenvalues via Sylvester's formula for a function of a 2x2 matrix,
  /// `f(A) = c1*A + c0*I`. This works even when `A` is defective (a
  /// repeated eigenvalue with only one independent eigenvector, e.g. the
  /// Jordan block `[[1, 1], [0, 1]]`): [diagonalization] cannot
  /// diagonalize such a matrix (its eigenvector matrix P is singular), but
  /// this closed form never needs P at all.
  ///
  /// For a repeated eigenvalue this uses the derivative of `f`,
  /// `f'(x) = 1/x`, which is the limit of the distinct-eigenvalue formula
  /// as one eigenvalue approaches the other, and is exact whether or not
  /// `A` is actually defective (for `A = lambda * I` it reduces to
  /// `log(lambda) * I`, as expected).
  Matrix _log2x2ClosedForm(
    List<double> realEigenvalues,
    double absoluteTolerance,
  ) {
    final double lambda1 = realEigenvalues[0];
    final double lambda2 = realEigenvalues[1];

    final double c1;
    final double c0;
    if ((lambda1 - lambda2).abs() <= absoluteTolerance) {
      final double lambda = (lambda1 + lambda2) / 2;
      c1 = 1 / lambda;
      c0 = math.log(lambda) - 1;
    } else {
      final double logLambda1 = math.log(lambda1);
      final double logLambda2 = math.log(lambda2);
      c1 = (logLambda1 - logLambda2) / (lambda1 - lambda2);
      c0 = logLambda1 - (c1 * lambda1);
    }

    return scale(c1) + Matrix.identity(rowCount).scale(c0);
  }

  /// Computes `this ^ exponent` per the power dispatch table (issue #5,
  /// spec section 3): `B^Y = exp(Y * log B)`, using the principal log/exp.
  Matrix power(Matrix exponent) {
    if (!isSquare) {
      throw MatrixShapeError(
        'Power base must be square, found ${rowCount}x$columnCount.',
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
        return Matrix.scalar(_checkFiniteScalar(math.pow(b, y).toDouble()));
      }
      final Matrix scaled = log().scale(y);
      return _checkFiniteMatrix(scaled.exp());
    }

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

    final List<double> singularValues = List<double>.generate(n, (int index) {
      final double lambda = decomposition.d.at(index, index);
      if (lambda <= absoluteTolerance) {
        return 0;
      }
      return math.sqrt(lambda);
    }, growable: false);

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

      final Matrix projected =
          this *
          Matrix(
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

    return SvdDecomposition(u: Matrix(uRows), s: Matrix(sRows), vT: vT);
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
      List<List<double>>.generate(rowCount - 1, (int targetIndex) {
        final int sourceIndex = targetIndex < rowIndex
            ? targetIndex
            : targetIndex + 1;
        return List<double>.from(_rows[sourceIndex]);
      }, growable: false),
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
        (int rowIndex) =>
            List<double>.generate(columnCount - 1, (int targetIndex) {
              final int sourceIndex = targetIndex < columnIndex
                  ? targetIndex
                  : targetIndex + 1;
              return _rows[rowIndex][sourceIndex];
            }, growable: false),
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
      List<List<double>>.generate(rowCount, (int rowIndex) {
        final List<double> row = List<double>.from(_rows[rowIndex]);
        row.insert(columnIndex + 1, _rows[rowIndex][columnIndex]);
        return row;
      }, growable: false),
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
      List<List<double>>.generate(rowCount, (int rowIndex) {
        final List<double> row = List<double>.from(_rows[rowIndex]);
        final double moved = row.removeAt(fromIndex);
        row.insert(toIndex, moved);
        return row;
      }, growable: false),
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

  static void _validateShape(
    int rowCount,
    int columnCount, {
    required String label,
  }) {
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
    if (candidate.isScalar && reference.isSquare && reference.rowCount > 1) {
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
