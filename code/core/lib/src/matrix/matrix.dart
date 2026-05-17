import '../errors/errors.dart';
import '../numeric/numeric_policy.dart';
import 'dart:math' as math;

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

  final List<List<double>> _rows;

  int get rowCount => _rows.length;

  int get columnCount => _rows.isEmpty ? 0 : _rows.first.length;

  bool get isSquare => rowCount == columnCount;

  bool get isScalar => rowCount == 1 && columnCount == 1;

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
        throw MatrixDomainError('Square root of negative scalar is undefined.');
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
