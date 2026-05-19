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
    _requireSameDimensions(other, operation: 'addition');

    final List<List<double>> result = List<List<double>>.generate(
      rowCount,
      (int r) => List<double>.generate(
        columnCount,
        (int c) => _rows[r][c] + other._rows[r][c],
        growable: false,
      ),
      growable: false,
    );

    return Matrix(result);
  }

  Matrix operator -(Matrix other) {
    _requireSameDimensions(other, operation: 'subtraction');

    final List<List<double>> result = List<List<double>>.generate(
      rowCount,
      (int r) => List<double>.generate(
        columnCount,
        (int c) => _rows[r][c] - other._rows[r][c],
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
        throw MatrixDomainError('Division by zero scalar is undefined.');
      }

      return scale(1 / divisor);
    }

    throw UnsupportedCalculatrixOperationError(
      'Matrix division is only supported by scalar (1x1) denominator.',
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
        throw MatrixDomainError('Matrix is singular and cannot be inverted.');
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
      );
    }
    if (other.columnCount != 1) {
      throw MatrixShapeError(
        'dot product requires a column vector (n×1), '
        'got ${other.rowCount}×${other.columnCount}',
      );
    }
    if (rowCount != other.rowCount) {
      throw MatrixShapeError(
        'dot product requires vectors of the same dimension, '
        'got ${rowCount}×1 and ${other.rowCount}×1',
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
      );
    }
    if (other.columnCount != 1 || other.rowCount != 3) {
      throw MatrixShapeError(
        'cross product requires a 3×1 column vector, '
        'got ${other.rowCount}×${other.columnCount}',
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

      final Matrix next = (current + (inverseCurrent * scaledTarget)).scale(0.5);
      final double stepNorm = (next - current)._infinityNorm();
      final double residualNorm = ((next * next) - scaledTarget)._infinityNorm();

      current = next;
      if (stepNorm <= threshold && residualNorm <= threshold) {
        return current.scale(math.pow(2, scalingSteps).toDouble());
      }
    }

    final Matrix result = current.scale(math.pow(2, scalingSteps).toDouble());
    final double residualNorm = ((result * result) - this)._infinityNorm();
    if (residualNorm <= math.max(absoluteTolerance, relativeTolerance * norm)) {
      return result;
    }

    throw MatrixDomainError(
      'Square root did not converge for this matrix in the real domain.',
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
      throw MatrixShapeError('Cannot delete the only row in a matrix.');
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
      throw MatrixShapeError('Cannot delete the only column in a matrix.');
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
      throw MatrixShapeError('Matrix cannot be empty.');
    }

    if (rows.first.isEmpty) {
      throw MatrixShapeError('Matrix rows cannot be empty.');
    }

    final int width = rows.first.length;
    for (final List<double> row in rows) {
      if (row.length != width) {
        throw MatrixShapeError(
          'All rows must have the same number of columns.',
        );
      }
    }
  }

  static void _validateShape(int rowCount, int columnCount, {required String label}) {
    if (rowCount < 1 || columnCount < 1) {
      throw MatrixShapeError(
        '$label matrix dimensions must be greater than zero.',
      );
    }
  }

  void _requireSameDimensions(Matrix other, {required String operation}) {
    if (rowCount != other.rowCount || columnCount != other.columnCount) {
      throw MatrixShapeError(
        'Cannot perform $operation for ${rowCount}x${columnCount} and '
        '${other.rowCount}x${other.columnCount}.',
      );
    }
  }

  void _requireSquare({required String operation}) {
    if (!isSquare) {
      throw MatrixShapeError(
        'Cannot perform $operation for non-square '
        '${rowCount}x${columnCount} matrix.',
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
