import '../errors/errors.dart';
import '../matrix/matrix.dart';
import 'exact_arithmetic.dart';
import 'rational.dart';

/// The exact linear algebra of runbook D53 for step T3: `inverse`,
/// `determinant`, `rref`, `rank`, `trace`, `adjugate`, `cofactors`, `lu`,
/// `dot` and `cross`, on exact matrices only. The caller dispatches here
/// when every operand is exact and takes the approximate route otherwise
/// (runbook D51).
///
/// Shapes and error ids follow the approximate methods of [Matrix], so a
/// program fails the same way whichever kind of value it carries; only
/// singularity differs, since an exact value is singular or not, with no
/// tolerance.
///
/// Elimination is fraction-free (Bareiss): the matrix is brought to
/// integers over one common denominator, and every value the elimination
/// produces is then a minor of that integer matrix. Hadamard's bound (the
/// product of the row lengths) bounds every minor, so it estimates the
/// size of the result before anything is computed (runbook D55).
extension ExactLinearAlgebra on ExactArithmetic {
  /// The inverse of the square matrix [a]; `singular-matrix` when it has
  /// none.
  Matrix inverse(Matrix a) {
    _requireSquare(a, 'inverse');
    final _IntegerForm form = _IntegerForm.of(a);
    final int size = a.rowCount;
    final List<List<BigInt>> augmented = _augmentWithIdentity(form.rows);
    // The inverse is g * X / p for the X and the pivot p below, so its
    // entries are minors of [B | I] over minors of B, times g.
    _requireWithin(
      'The exact inverse',
      _hadamardLog10(augmented) + Rational.log10Of(form.scale),
    );
    final _Elimination elimination = _Elimination.run(
      augmented,
      pivotLimit: size,
      reduce: true,
    );
    if (elimination.rank < size) {
      throw MatrixDomainError(
        'Matrix is singular and cannot be inverted.',
        errorId: CalculatrixErrorId.singularMatrix,
      );
    }
    final Rational factor = Rational(form.scale, elimination.lastPivot);
    return check(
      Matrix.exact(
        List<List<Rational>>.generate(
          size,
          (int r) => List<Rational>.generate(
            size,
            (int c) => Rational(augmented[r][size + c]) * factor,
            growable: false,
          ),
          growable: false,
        ),
      ),
    );
  }

  /// The determinant of the square matrix [a], as a 1x1 matrix.
  Matrix determinant(Matrix a) {
    _requireSquare(a, 'determinant');
    if (a.isScalar) {
      return a;
    }
    final _IntegerForm form = _IntegerForm.of(a);
    final int size = a.rowCount;
    // det(A) = det(B) / g^n: a minor of B over a power of g.
    _requireWithin(
      'The exact determinant',
      _larger(_hadamardLog10(form.rows), size * Rational.log10Of(form.scale)),
    );
    return check(Matrix.exactScalar(_determinant(form, size)));
  }

  /// The reduced row echelon form of [a], any shape.
  Matrix rref(Matrix a) {
    final _IntegerForm form = _IntegerForm.of(a);
    // Row operations do not change the echelon form, so rref(A) is
    // rref(B): ratios of minors of B.
    _requireWithin('The exact row echelon form', _hadamardLog10(form.rows));
    final _Elimination elimination = _Elimination.run(
      form.rows,
      pivotLimit: a.columnCount,
      reduce: true,
    );
    final List<List<Rational>> rows = <List<Rational>>[];
    for (int r = 0; r < a.rowCount; r++) {
      final List<BigInt> row = form.rows[r];
      final BigInt pivot = r < elimination.rank
          ? row[elimination.pivotColumns[r]]
          : BigInt.one;
      rows.add(
        row
            .map((BigInt entry) => Rational(entry, pivot))
            .toList(growable: false),
      );
    }
    return check(Matrix.exact(rows));
  }

  /// The rank of [a], any shape, as a 1x1 matrix.
  Matrix rank(Matrix a) {
    final _IntegerForm form = _IntegerForm.of(a);
    // The result is small, but the elimination still produces minors of B.
    _requireWithin('The exact rank computation', _hadamardLog10(form.rows));
    final _Elimination elimination = _Elimination.run(
      form.rows,
      pivotLimit: a.columnCount,
      reduce: false,
    );
    return Matrix.exactScalar(Rational.fromInt(elimination.rank));
  }

  /// The sum of the diagonal of the square matrix [a], as a 1x1 matrix.
  Matrix trace(Matrix a) {
    _requireSquare(a, 'trace');
    Rational sum = Rational.zero;
    for (int i = 0; i < a.rowCount; i++) {
      sum += a.exactAt(i, i);
    }
    return check(Matrix.exactScalar(sum));
  }

  /// The matrix of cofactors of the square matrix [a]: entry (i, j) is
  /// (-1)^(i+j) times the determinant of [a] without row i and column j.
  Matrix cofactors(Matrix a) {
    _requireSquare(a, 'cofactor matrix');
    if (a.rowCount < 2) {
      throw MatrixShapeError(
        'Minor requires at least a 2x2 matrix.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
    final _IntegerForm form = _IntegerForm.of(a);
    final int size = a.rowCount;
    final List<List<BigInt>> augmented = _augmentWithIdentity(form.rows);
    // A cofactor is a minor of B of size n - 1 over g^(n-1); the
    // elimination below works on [B | I].
    _requireWithin(
      'The exact cofactor matrix',
      _larger(
        _hadamardLog10(augmented),
        (size - 1) * Rational.log10Of(form.scale),
      ),
    );
    final Rational unscale = Rational(BigInt.one, form.scale.pow(size - 1));
    final _Elimination elimination = _Elimination.run(
      augmented,
      pivotLimit: size,
      reduce: true,
    );

    final List<List<Rational>> adjugate;
    if (elimination.rank == size) {
      // [B | I] became [p I | p B^-1], with p = det(B) up to the sign of
      // the row swaps, so the right half times that sign is adj(B).
      final Rational sign = elimination.oddSwaps ? -Rational.one : Rational.one;
      adjugate = List<List<Rational>>.generate(
        size,
        (int r) => List<Rational>.generate(
          size,
          (int c) => Rational(augmented[r][size + c]) * sign * unscale,
          growable: false,
        ),
        growable: false,
      );
    } else if (elimination.rank < size - 1) {
      // Every minor of size n - 1 vanishes.
      adjugate = List<List<Rational>>.generate(
        size,
        (_) => List<Rational>.filled(size, Rational.zero),
        growable: false,
      );
    } else {
      adjugate = List<List<Rational>>.generate(
        size,
        (int r) => List<Rational>.generate(
          size,
          (int c) => _cofactor(form, column: r, row: c) * unscale,
          growable: false,
        ),
        growable: false,
      );
    }
    // The cofactor matrix is the transpose of the adjugate.
    return check(
      Matrix.exact(
        List<List<Rational>>.generate(
          size,
          (int r) => List<Rational>.generate(
            size,
            (int c) => adjugate[c][r],
            growable: false,
          ),
          growable: false,
        ),
      ),
    );
  }

  /// The adjugate of the square matrix [a]: the transpose of its cofactor
  /// matrix.
  Matrix adjugate(Matrix a) {
    _requireSquare(a, 'adjugate');
    return cofactors(a).transpose();
  }

  /// The LU decomposition of the square matrix [a]: P A = L U, with P a
  /// permutation, L unit lower triangular and U upper triangular. The
  /// pivot of each column is its entry of largest magnitude on or below
  /// the diagonal (the first one on a tie), as in the approximate
  /// decomposition, so both give the same P; a column of zeros is left as
  /// it is.
  LuDecomposition lu(Matrix a) {
    _requireSquare(a, 'LU decomposition');
    final _IntegerForm form = _IntegerForm.of(a);
    // L and U are ratios of minors of B; U carries a further 1/g.
    _requireWithin(
      'The exact LU decomposition',
      _hadamardLog10(form.rows) + Rational.log10Of(form.scale),
    );
    final int size = a.rowCount;
    final List<List<Rational>> upper = a.exactRows
        .map((List<Rational> row) => List<Rational>.of(row))
        .toList(growable: false);
    final List<List<Rational>> lower = _identityRows(size);
    final List<int> order = List<int>.generate(size, (int i) => i);

    for (int k = 0; k < size; k++) {
      int pivotRow = k;
      for (int r = k + 1; r < size; r++) {
        if (upper[r][k].abs().compareTo(upper[pivotRow][k].abs()) > 0) {
          pivotRow = r;
        }
      }
      if (upper[pivotRow][k].isZero) {
        continue;
      }
      if (pivotRow != k) {
        _swap(upper, k, pivotRow);
        _swap(order, k, pivotRow);
        for (int c = 0; c < k; c++) {
          final Rational held = lower[k][c];
          lower[k][c] = lower[pivotRow][c];
          lower[pivotRow][c] = held;
        }
      }
      final Rational pivot = upper[k][k];
      for (int r = k + 1; r < size; r++) {
        if (upper[r][k].isZero) {
          continue;
        }
        final Rational factor = upper[r][k] / pivot;
        lower[r][k] = factor;
        upper[r][k] = Rational.zero;
        for (int c = k + 1; c < size; c++) {
          upper[r][c] -= factor * upper[k][c];
        }
      }
    }

    final List<List<Rational>> permutation = List<List<Rational>>.generate(
      size,
      (int r) => List<Rational>.generate(
        size,
        (int c) => c == order[r] ? Rational.one : Rational.zero,
        growable: false,
      ),
      growable: false,
    );
    return LuDecomposition(
      permutation: Matrix.exact(permutation),
      lower: check(Matrix.exact(lower)),
      upper: check(Matrix.exact(upper)),
    );
  }

  /// The dot product of two column vectors of the same length, as a 1x1
  /// matrix.
  Matrix dot(Matrix a, Matrix b) {
    for (final Matrix vector in <Matrix>[a, b]) {
      if (vector.columnCount != 1) {
        throw MatrixShapeError(
          'dot product requires a column vector (n×1), '
          'got ${vector.rowCount}×${vector.columnCount}',
          errorId: CalculatrixErrorId.dimensionMismatch,
        );
      }
    }
    if (a.rowCount != b.rowCount) {
      throw MatrixShapeError(
        'dot product requires vectors of the same dimension, '
        'got ${a.rowCount}×1 and ${b.rowCount}×1',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
    Rational sum = Rational.zero;
    for (int i = 0; i < a.rowCount; i++) {
      sum += a.exactAt(i, 0) * b.exactAt(i, 0);
    }
    return check(Matrix.exactScalar(sum));
  }

  /// The cross product of two 3x1 column vectors.
  Matrix cross(Matrix a, Matrix b) {
    for (final Matrix vector in <Matrix>[a, b]) {
      if (vector.columnCount != 1 || vector.rowCount != 3) {
        throw MatrixShapeError(
          'cross product requires a 3×1 column vector, '
          'got ${vector.rowCount}×${vector.columnCount}',
          errorId: CalculatrixErrorId.dimensionMismatch,
        );
      }
    }
    final Rational x = a.exactAt(0, 0);
    final Rational y = a.exactAt(1, 0);
    final Rational z = a.exactAt(2, 0);
    final Rational bx = b.exactAt(0, 0);
    final Rational by = b.exactAt(1, 0);
    final Rational bz = b.exactAt(2, 0);
    return check(
      Matrix.exact(<List<Rational>>[
        <Rational>[y * bz - z * by],
        <Rational>[z * bx - x * bz],
        <Rational>[x * by - y * bx],
      ]),
    );
  }

  // The determinant of A from its integer form: det(B) / g^n.
  Rational _determinant(_IntegerForm form, int size) {
    final List<List<BigInt>> rows = form.rows
        .map((List<BigInt> row) => List<BigInt>.of(row))
        .toList(growable: false);
    final _Elimination elimination = _Elimination.run(
      rows,
      pivotLimit: size,
      reduce: false,
    );
    if (elimination.rank < size) {
      return Rational.zero;
    }
    final BigInt det = elimination.oddSwaps
        ? -elimination.lastPivot
        : elimination.lastPivot;
    return Rational(det, form.scale.pow(size));
  }

  // The cofactor (row, column) of B, as an integer: (-1)^(row+column)
  // times the determinant of B without that row and column.
  Rational _cofactor(
    _IntegerForm form, {
    required int row,
    required int column,
  }) {
    final List<List<BigInt>> minor = <List<BigInt>>[
      for (int r = 0; r < form.rows.length; r++)
        if (r != row)
          <BigInt>[
            for (int c = 0; c < form.rows[r].length; c++)
              if (c != column) form.rows[r][c],
          ],
    ];
    final Rational value = _determinant(
      _IntegerForm(minor, BigInt.one),
      minor.length,
    );
    return (row + column).isEven ? value : -value;
  }

  // Raises `limit-exceeded` when a result bounded by 10^[log10Bound] can
  // have more digits than the limit (runbook D55). The small margin keeps
  // the rounding of the logarithms from undercounting a digit.
  void _requireWithin(String what, double log10Bound) {
    final double margin = log10Bound * 1e-12 + 1e-9;
    final double estimate = (log10Bound + margin).floorToDouble() + 1;
    final int estimated = estimate.isFinite && estimate < Rational.maxEstimate
        ? estimate.toInt()
        : Rational.maxEstimate;
    if (estimated > maxDigits) {
      throw LimitExceededError(
        '$what could have up to $estimated digits (Hadamard bound), over '
        'the limit of $maxDigits.',
        limit: maxDigits,
        estimated: estimated,
      );
    }
  }

  static void _requireSquare(Matrix a, String operation) {
    if (!a.isSquare) {
      throw MatrixShapeError(
        'Cannot perform $operation for non-square '
        '${a.rowCount}x${a.columnCount} matrix.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
  }

  static double _larger(double a, double b) => a > b ? a : b;

  static List<List<Rational>> _identityRows(int size) =>
      List<List<Rational>>.generate(
        size,
        (int r) => List<Rational>.generate(
          size,
          (int c) => r == c ? Rational.one : Rational.zero,
          growable: false,
        ),
        growable: false,
      );

  static List<List<BigInt>> _augmentWithIdentity(List<List<BigInt>> rows) =>
      List<List<BigInt>>.generate(
        rows.length,
        (int r) => <BigInt>[
          ...rows[r],
          for (int c = 0; c < rows.length; c++)
            r == c ? BigInt.one : BigInt.zero,
        ],
        growable: false,
      );

  static void _swap<T>(List<T> list, int i, int j) {
    final T held = list[i];
    list[i] = list[j];
    list[j] = held;
  }
}

/// An exact matrix A as integers over one common denominator g: A = B / g.
final class _IntegerForm {
  _IntegerForm(this.rows, this.scale);

  factory _IntegerForm.of(Matrix a) {
    BigInt scale = BigInt.one;
    for (final List<Rational> row in a.exactRows) {
      for (final Rational entry in row) {
        scale = scale ~/ scale.gcd(entry.denominator) * entry.denominator;
      }
    }
    return _IntegerForm(
      a.exactRows
          .map(
            (List<Rational> row) => row
                .map(
                  (Rational entry) =>
                      entry.numerator * (scale ~/ entry.denominator),
                )
                .toList(growable: false),
          )
          .toList(growable: false),
      scale,
    );
  }

  /// B, row by row; the elimination works on it in place.
  final List<List<BigInt>> rows;

  /// g.
  final BigInt scale;
}

// log10 of Hadamard's bound for [rows]: the product of the lengths of its
// nonzero rows. Each nonzero integer row has length at least 1, so this
// bounds every minor of [rows], of any size.
double _hadamardLog10(List<List<BigInt>> rows) {
  double sum = 0;
  for (final List<BigInt> row in rows) {
    BigInt squares = BigInt.zero;
    for (final BigInt entry in row) {
      squares += entry * entry;
    }
    if (squares > BigInt.zero) {
      sum += Rational.log10Of(squares) / 2;
    }
  }
  return sum;
}

/// Fraction-free elimination (Bareiss) of an integer matrix, in place.
///
/// The pivot of each step is the first nonzero entry on or below the
/// current row, in the first `pivotLimit` columns. Each update is
/// `(p * x - f * y) / q`, with p the current pivot and q the previous one;
/// the division is exact because every entry stays a minor of the input.
/// With `reduce`, rows above the pivot are cleared too (Gauss-Jordan), and
/// every pivot entry ends equal to the last pivot.
final class _Elimination {
  _Elimination._(this.pivotColumns, this.lastPivot, this.oddSwaps);

  factory _Elimination.run(
    List<List<BigInt>> rows, {
    required int pivotLimit,
    required bool reduce,
  }) {
    final int rowCount = rows.length;
    final int columnCount = rowCount == 0 ? 0 : rows.first.length;
    final List<int> pivotColumns = <int>[];
    BigInt previous = BigInt.one;
    bool oddSwaps = false;
    int current = 0;

    for (int c = 0; c < pivotLimit && current < rowCount; c++) {
      int pivotRow = current;
      while (pivotRow < rowCount && rows[pivotRow][c] == BigInt.zero) {
        pivotRow++;
      }
      if (pivotRow == rowCount) {
        continue;
      }
      if (pivotRow != current) {
        final List<BigInt> held = rows[current];
        rows[current] = rows[pivotRow];
        rows[pivotRow] = held;
        oddSwaps = !oddSwaps;
      }
      final List<BigInt> pivotRowValues = rows[current];
      final BigInt pivot = pivotRowValues[c];
      for (int r = reduce ? 0 : current + 1; r < rowCount; r++) {
        if (r == current) {
          continue;
        }
        final List<BigInt> row = rows[r];
        final BigInt factor = row[c];
        for (int j = 0; j < columnCount; j++) {
          final BigInt value = pivot * row[j] - factor * pivotRowValues[j];
          assert(
            value.remainder(previous) == BigInt.zero,
            'Bareiss division must be exact',
          );
          row[j] = value ~/ previous;
        }
      }
      previous = pivot;
      pivotColumns.add(c);
      current++;
    }
    return _Elimination._(pivotColumns, previous, oddSwaps);
  }

  /// The column of each pivot, row by row.
  final List<int> pivotColumns;

  /// The pivot of the last step: det(B) up to sign for a nonsingular
  /// square B (1 when there was no step).
  final BigInt lastPivot;

  /// Whether the elimination swapped rows an odd number of times.
  final bool oddSwaps;

  int get rank => pivotColumns.length;
}
