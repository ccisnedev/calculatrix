import '../errors/errors.dart';
import '../matrix/matrix.dart';
import 'exact_arithmetic.dart';
import 'exact_linear_algebra.dart';
import 'rational.dart';

/// The exact roots of runbook D53 for step T4: non-integer powers (and so
/// `sqrt`, which is `0.5 power`), `frobenius-norm` and the trivial cases of
/// `exp` and `ln`, on exact values only. The caller dispatches here when
/// every operand is exact (runbook D51).
///
/// Each word returns an exact value only when its result is rational and
/// checked exactly; otherwise it returns what the approximate method of
/// [Matrix] computes for the same value, errors included, so a result that
/// is not rational stays approximate and marked.
extension ExactRoots on ExactArithmetic {
  /// The principal value of [base] raised to the non-integer [exponent]
  /// p/q, as the approximate `power` defines it.
  ///
  /// A scalar, a complex number in its 2x2 form (for q = 2) and a diagonal
  /// matrix have closed forms: their result is rational exactly when the
  /// q-th roots involved are, so the exact path decides alone. Any other
  /// matrix is computed approximately, converted entry by entry to the
  /// simplest rational (runbook D52) and kept exact only when X^q = B^p
  /// holds exactly.
  Matrix fractionalPower(Matrix base, Rational exponent) {
    assert(!exponent.isInteger);
    final BigInt p = exponent.numerator;
    final BigInt q = exponent.denominator;
    if (!base.isSquare) {
      return _approximatePower(base, exponent);
    }
    if (base.isScalar) {
      return _scalarRootPower(base.exactAt(0, 0), p, q) ??
          _approximatePower(base, exponent);
    }
    if (q == _two && _isComplexForm(base)) {
      return _complexRootPower(base, p) ?? _approximatePower(base, exponent);
    }
    if (_isDiagonal(base)) {
      return _diagonalRootPower(base, p, q) ??
          _approximatePower(base, exponent);
    }
    return _verifiedRootPower(base, p, q, exponent);
  }

  /// The Frobenius norm of [a]: exact when the sum of the squares of its
  /// entries is the square of a rational.
  Matrix frobeniusNorm(Matrix a) {
    Rational sum = Rational.zero;
    for (final List<Rational> row in a.exactRows) {
      for (final Rational entry in row) {
        sum = _within(sum + _within(entry * entry));
      }
    }
    final Rational? root = sum.root(_two);
    return root == null
        ? a.toApproximate().frobeniusNorm()
        : Matrix.exactScalar(root);
  }

  /// `exp`: exact for a zero matrix, whose exponential is the identity.
  Matrix exp(Matrix a) {
    if (a.isSquare && _isZero(a)) {
      return Matrix.exactIdentity(a.rowCount);
    }
    return a.toApproximate().exp();
  }

  /// `ln`: exact for the identity, whose logarithm is the zero matrix.
  Matrix ln(Matrix a) {
    if (a.isSquare && _isIdentity(a)) {
      return Matrix.exactFilled(a.rowCount, a.columnCount, Rational.zero);
    }
    return a.toApproximate().log();
  }

  // b^(p/q) for a scalar b, or null when it is not rational. A negative b
  // has a complex principal root, |b|^(p/q) * e^(i*pi*p/q), with rational
  // parts only for q = 2 (p is odd there, so e^(i*pi*p/2) is i or -i) and
  // q = 4 (e^(i*pi/4) is (1 + i) / sqrt(2)).
  Matrix? _scalarRootPower(Rational b, BigInt p, BigInt q) {
    if (b.isZero) {
      return p.isNegative ? null : Matrix.exactScalar(Rational.zero);
    }
    if (b.isNegative && q == _four) {
      // The principal fourth root is the principal square root of the
      // principal square root, |b|^(1/2) * i: rational parts need |b| to be
      // a square, not a fourth power ((1 + i)^4 = -4).
      final Matrix? squareRoot = _scalarRootPower(b, BigInt.one, _two);
      return squareRoot == null ? null : _complexRootPower(squareRoot, p);
    }
    final Rational? root = b.abs().root(q);
    if (root == null) {
      return null;
    }
    final Rational magnitude = power(Matrix.exactScalar(root), p).exactAt(0, 0);
    if (!b.isNegative) {
      return Matrix.exactScalar(magnitude);
    }
    if (q != _two) {
      return null;
    }
    final Rational imaginary = p % _four == BigInt.one ? magnitude : -magnitude;
    return Matrix.exact(<List<Rational>>[
      <Rational>[Rational.zero, -imaginary],
      <Rational>[imaginary, Rational.zero],
    ]);
  }

  // z^(p/2) for z = a + bi in its form [[a -b] [b a]], or null when it is
  // not rational. The principal root x + yi has x >= 0, and y >= 0 when x
  // is 0, as in the approximate square root; it is rational only when |z|
  // and (|z| + a) / 2 or (|z| - a) / 2 are squares of rationals.
  Matrix? _complexRootPower(Matrix base, BigInt p) {
    final Rational a = base.exactAt(0, 0);
    final Rational b = base.exactAt(1, 0);
    if (a.isZero && b.isZero) {
      // The approximate power takes only the square root of zero.
      return p == BigInt.one ? base : null;
    }
    final Rational? modulus = _within(a * a + b * b).root(_two);
    if (modulus == null) {
      return null;
    }
    final Rational half = Rational(BigInt.one, _two);
    final Rational x;
    final Rational y;
    if (!a.isNegative) {
      final Rational? real = ((modulus + a) * half).root(_two);
      if (real == null) {
        return null;
      }
      x = real;
      y = b / (x + x);
    } else {
      final Rational? imaginary = ((modulus - a) * half).root(_two);
      if (imaginary == null) {
        return null;
      }
      y = b.isNegative ? -imaginary : imaginary;
      x = b / (y + y);
    }
    final Matrix root = check(
      Matrix.exact(<List<Rational>>[
        <Rational>[x, -y],
        <Rational>[y, x],
      ]),
    );
    return p.isNegative ? power(inverse(root), -p) : power(root, p);
  }

  // diag(d)^(p/q) as diag(d^(p/q)), or null when an entry has no rational
  // root. A negative entry has a complex root, which a real matrix cannot
  // hold; a zero entry is allowed only in the square root, where the
  // approximate power accepts a singular matrix.
  Matrix? _diagonalRootPower(Matrix base, BigInt p, BigInt q) {
    final int size = base.rowCount;
    final List<Rational> diagonal = <Rational>[];
    for (int i = 0; i < size; i++) {
      final Rational entry = base.exactAt(i, i);
      if (entry.isNegative) {
        return null;
      }
      if (entry.isZero) {
        if (p != BigInt.one || q != _two) {
          return null;
        }
        diagonal.add(Rational.zero);
        continue;
      }
      final Rational? root = entry.root(q);
      if (root == null) {
        return null;
      }
      diagonal.add(power(Matrix.exactScalar(root), p).exactAt(0, 0));
    }
    return Matrix.exact(
      List<List<Rational>>.generate(
        size,
        (int r) => List<Rational>.generate(
          size,
          (int c) => r == c ? diagonal[r] : Rational.zero,
          growable: false,
        ),
        growable: false,
      ),
    );
  }

  // B^(p/q) as Y^p for the principal q-th root Y of B, when a rational
  // guess for Y satisfies Y^q = B exactly; otherwise the approximate
  // B^(p/q), errors included. Y is guessed from two approximate roots, the
  // power 1/q and exp(log(B) / q), since either can fail to converge where
  // the other does; its entries are simpler than those of Y^p. Y^p itself
  // is an exact power like any other, limit included.
  Matrix _verifiedRootPower(
    Matrix base,
    BigInt p,
    BigInt q,
    Rational exponent,
  ) {
    final Rational inverseQ = Rational(BigInt.one, q);
    for (final Matrix Function() guess in <Matrix Function()>[
      () => _approximatePower(base, inverseQ),
      () => base.toApproximate().log().scale(inverseQ.toDouble()).exp(),
    ]) {
      final Matrix approximateRoot;
      try {
        approximateRoot = guess();
      } on CalculatrixError {
        continue;
      }
      final Matrix? root = _exactRoot(base, q, approximateRoot);
      if (root == null) {
        continue;
      }
      // A singular B has only a square root, as in the approximate power,
      // whose logarithm is undefined there; the approximate error stands.
      if ((p != BigInt.one || q != _two) &&
          determinant(root).exactAt(0, 0).isZero) {
        break;
      }
      return p.isNegative ? power(inverse(root), -p) : power(root, p);
    }
    return _approximatePower(base, exponent);
  }

  // A rational Y near [approximateRoot] with Y^q = [base] exactly, or null.
  // The guesses are the simplest rationals within 1e-9 of its largest
  // entry (the computation may miss by more than one unit in the last
  // place), then the simplest that round to it. The check needs about q
  // times the digits of Y; past the limit there is no guess.
  Matrix? _exactRoot(Matrix base, BigInt q, Matrix approximateRoot) {
    if (approximateRoot.rows.any(
      (List<double> row) => row.any((double entry) => !entry.isFinite),
    )) {
      return null;
    }
    final BigInt sizeDigits = BigInt.from('${base.rowCount}'.length);
    final BigInt limit = BigInt.from(maxDigits);
    for (final Matrix candidate in <Matrix>[
      _nearbyRationals(approximateRoot),
      approximateRoot.toExact(),
    ]) {
      if (q * (BigInt.from(_largestDigits(candidate)) + sizeDigits) > limit) {
        continue;
      }
      try {
        if (_sameEntries(power(candidate, q), base)) {
          return candidate;
        }
      } on LimitExceededError {
        return null;
      }
    }
    return null;
  }

  static Matrix _nearbyRationals(Matrix approximate) {
    double largest = 0;
    for (final List<double> row in approximate.rows) {
      for (final double entry in row) {
        if (entry.abs() > largest) {
          largest = entry.abs();
        }
      }
    }
    final double tolerance = largest * 1e-9;
    return Matrix.exact(
      approximate.rows
          .map(
            (List<double> row) => row
                .map(
                  (double entry) => tolerance == 0
                      ? Rational.zero
                      : Rational.simplestWithin(entry, tolerance),
                )
                .toList(growable: false),
          )
          .toList(growable: false),
    );
  }

  static Matrix _approximatePower(Matrix base, Rational exponent) =>
      base.toApproximate().power(Matrix.scalar(exponent.toDouble()));

  // [value], or `limit-exceeded` when it has more digits than the limit.
  Rational _within(Rational value) {
    check(Matrix.exactScalar(value));
    return value;
  }

  static bool _isComplexForm(Matrix a) =>
      a.rowCount == 2 &&
      a.columnCount == 2 &&
      a.exactAt(0, 0) == a.exactAt(1, 1) &&
      a.exactAt(0, 1) == -a.exactAt(1, 0);

  static bool _isDiagonal(Matrix a) {
    for (int r = 0; r < a.rowCount; r++) {
      for (int c = 0; c < a.columnCount; c++) {
        if (r != c && !a.exactAt(r, c).isZero) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _isZero(Matrix a) => a.exactRows.every(
    (List<Rational> row) => row.every((Rational entry) => entry.isZero),
  );

  static bool _isIdentity(Matrix a) {
    for (int r = 0; r < a.rowCount; r++) {
      for (int c = 0; c < a.columnCount; c++) {
        if (a.exactAt(r, c) != (r == c ? Rational.one : Rational.zero)) {
          return false;
        }
      }
    }
    return true;
  }

  static int _largestDigits(Matrix a) {
    int largest = 1;
    for (final List<Rational> row in a.exactRows) {
      for (final Rational entry in row) {
        final int digits = entry.digits;
        if (digits > largest) {
          largest = digits;
        }
      }
    }
    return largest;
  }

  static bool _sameEntries(Matrix a, Matrix b) {
    for (int r = 0; r < a.rowCount; r++) {
      for (int c = 0; c < a.columnCount; c++) {
        if (a.exactAt(r, c) != b.exactAt(r, c)) {
          return false;
        }
      }
    }
    return true;
  }
}

final BigInt _two = BigInt.two;
final BigInt _four = BigInt.from(4);
