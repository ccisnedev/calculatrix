import '../errors/errors.dart';
import '../matrix/matrix.dart';
import 'rational.dart';

/// The exact operations of runbook D53 for step T2: `+ - * /`, `negate`,
/// `percent` and integer powers, on exact matrices only. The caller
/// dispatches here when every operand is exact and takes the approximate
/// route otherwise (runbook D51).
///
/// Shapes follow the approximate operators of [Matrix] exactly, with the
/// same error ids, so a program fails the same way whichever kind of value
/// it carries.
///
/// Every result is held to [maxDigits] digits per numerator or denominator
/// (runbook D55). An elementary operation on operands within the limit
/// computes at most about twice the limit, so it is checked on its result;
/// a power can grow without bound, so it is estimated before computing.
final class ExactArithmetic {
  const ExactArithmetic({this.maxDigits = defaultMaxDigits});

  /// The default digit limit of runbook D55.
  static const int defaultMaxDigits = 10000;

  /// The digit limit per numerator or denominator.
  final int maxDigits;

  Matrix add(Matrix a, Matrix b) =>
      _elementwise(a, b, 'addition', (Rational x, Rational y) => x + y);

  Matrix subtract(Matrix a, Matrix b) =>
      _elementwise(a, b, 'subtraction', (Rational x, Rational y) => x - y);

  Matrix multiply(Matrix a, Matrix b) {
    if (a.isScalar) {
      return scale(b, a.exactAt(0, 0));
    }
    if (b.isScalar) {
      return scale(a, b.exactAt(0, 0));
    }
    if (a.columnCount != b.rowCount) {
      throw MatrixShapeError(
        'Cannot multiply ${a.rowCount}x${a.columnCount} by '
        '${b.rowCount}x${b.columnCount}.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
    return Matrix.exact(_product(a.exactRows, b.exactRows));
  }

  /// Division by a scalar (1x1) only, as for approximate values.
  Matrix divide(Matrix a, Matrix b) {
    if (!b.isScalar) {
      throw UnsupportedCalculatrixOperationError(
        'Matrix division is only supported by scalar (1x1) denominator.',
        errorId: CalculatrixErrorId.typeMismatch,
      );
    }
    final Rational divisor = b.exactAt(0, 0);
    if (divisor.isZero) {
      throw MatrixDomainError(
        'Division by zero scalar is undefined.',
        errorId: CalculatrixErrorId.nonFinite,
      );
    }
    return scale(a, divisor.reciprocal());
  }

  Matrix negate(Matrix a) => _map(a, (Rational x) => -x);

  /// `percent`: one hundredth of [a].
  Matrix percent(Matrix a) => scale(a, Rational(BigInt.one, BigInt.from(100)));

  Matrix scale(Matrix a, Rational factor) =>
      _map(a, (Rational x) => _checked(x * factor));

  /// [base] raised to the integer [exponent]. A scalar base takes any
  /// integer; a square matrix takes a non-negative one (a negative power
  /// of a matrix needs its inverse, exact from step T3). The caller has
  /// already checked that [base] is square.
  Matrix power(Matrix base, BigInt exponent) {
    if (base.isScalar) {
      return Matrix.exactScalar(_scalarPower(base.exactAt(0, 0), exponent));
    }
    assert(!exponent.isNegative);
    Matrix result = Matrix.exactIdentity(base.rowCount);
    List<List<Rational>> square = base.exactRows;
    BigInt remaining = exponent;
    while (remaining > BigInt.zero) {
      if (remaining.isOdd) {
        result = Matrix.exact(_product(result.exactRows, square));
      }
      remaining = remaining >> 1;
      if (remaining > BigInt.zero) {
        square = _product(square, square);
      }
    }
    return result;
  }

  Rational _scalarPower(Rational base, BigInt exponent) {
    if (exponent == BigInt.zero) {
      return Rational.one;
    }
    if (base.isZero) {
      if (exponent.isNegative) {
        throw MatrixDomainError(
          '0 raised to a negative power is a division by zero.',
          errorId: CalculatrixErrorId.nonFinite,
        );
      }
      return Rational.zero;
    }
    if (base.numerator.abs() == BigInt.one && base.denominator == BigInt.one) {
      return base.isNegative && exponent.isOdd ? -Rational.one : Rational.one;
    }

    // The digits of p^n are floor(n * log10 |p|) + 1, and those of q^n
    // likewise; p and q stay coprime, so nothing cancels.
    final double largestLog = _max(
      base.numerator == BigInt.zero ? 0 : Rational.log10Of(base.numerator),
      Rational.log10Of(base.denominator),
    );
    final double estimate = exponent.abs().toDouble() * largestLog + 1;
    final int estimated = estimate.isFinite && estimate < 9007199254740991
        ? estimate.floor()
        : 9007199254740991;
    if (estimated > maxDigits) {
      throw LimitExceededError(
        '${_powerText(base, exponent)} has about $estimated digits, over '
        'the limit of $maxDigits.',
        limit: maxDigits,
        estimated: estimated,
      );
    }

    final Rational magnitude = base.powNonNegative(exponent.abs().toInt());
    return _checked(exponent.isNegative ? magnitude.reciprocal() : magnitude);
  }

  static String _powerText(Rational base, BigInt exponent) {
    final String text = base.toDisplayString();
    final bool plain = base.isInteger && !base.isNegative;
    return plain ? '$text^$exponent' : '($text)^$exponent';
  }

  static double _max(double a, double b) => a > b ? a : b;

  Matrix _elementwise(
    Matrix a,
    Matrix b,
    String operation,
    Rational Function(Rational x, Rational y) combine,
  ) {
    final Matrix left = _promoteScalar(a, b);
    final Matrix right = _promoteScalar(b, a);
    if (left.rowCount != right.rowCount ||
        left.columnCount != right.columnCount) {
      throw MatrixShapeError(
        'Cannot perform $operation for ${left.rowCount}x${left.columnCount} '
        'and ${right.rowCount}x${right.columnCount}.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
    return Matrix.exact(
      List<List<Rational>>.generate(
        left.rowCount,
        (int r) => List<Rational>.generate(
          left.columnCount,
          (int c) => _checked(combine(left.exactAt(r, c), right.exactAt(r, c))),
          growable: false,
        ),
        growable: false,
      ),
    );
  }

  // A scalar meets a square matrix of size n > 1 as itself times the
  // identity, as in Matrix's own scalar promotion (complex arithmetic:
  // `3 + i`).
  static Matrix _promoteScalar(Matrix candidate, Matrix reference) {
    if (candidate.isScalar && reference.isSquare && reference.rowCount > 1) {
      final Rational value = candidate.exactAt(0, 0);
      final int size = reference.rowCount;
      return Matrix.exact(
        List<List<Rational>>.generate(
          size,
          (int r) => List<Rational>.generate(
            size,
            (int c) => r == c ? value : Rational.zero,
          ),
        ),
      );
    }
    return candidate;
  }

  Matrix _map(Matrix a, Rational Function(Rational x) transform) {
    return Matrix.exact(
      a.exactRows
          .map(
            (List<Rational> row) => row.map(transform).toList(growable: false),
          )
          .toList(growable: false),
    );
  }

  List<List<Rational>> _product(
    List<List<Rational>> a,
    List<List<Rational>> b,
  ) {
    final int inner = b.length;
    final int columns = b.first.length;
    return List<List<Rational>>.generate(
      a.length,
      (int r) => List<Rational>.generate(columns, (int c) {
        Rational sum = Rational.zero;
        for (int i = 0; i < inner; i++) {
          sum = _checked(sum + _checked(a[r][i] * b[i][c]));
        }
        return sum;
      }, growable: false),
      growable: false,
    );
  }

  // Holds one result to the limit. The bit length bounds the digits from
  // above, so the exact count is only needed near the limit.
  Rational _checked(Rational value) {
    if (Rational.digitUpperBound(value.numerator) <= maxDigits &&
        Rational.digitUpperBound(value.denominator) <= maxDigits) {
      return value;
    }
    final int digits = value.digits;
    if (digits > maxDigits) {
      throw LimitExceededError(
        'The exact result would have about $digits digits, over the limit '
        'of $maxDigits.',
        limit: maxDigits,
        estimated: digits,
      );
    }
    return value;
  }
}
