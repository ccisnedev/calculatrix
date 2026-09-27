// Arbitrary-precision helper for Codex round 18, finding 2's regression
// test: a plain rounded-double "reference" is not good enough to check a
// computed eigenvalue that is already accurate to within 1 ULP of the true
// answer, because the nearest double to any sufficiently precise decimal
// literal collapses right back to that same correctly-rounded double,
// silently making the "actual error" compare as exactly 0 regardless of
// whether the production code under test is actually correct. This module
// instead decomposes the stored binary64 inputs exactly (every double is a
// dyadic rational, `mantissa * 2^exponent`), solves the exact 2x2
// characteristic polynomial with BigInt arithmetic, and computes the true
// error against a computed double by subtracting two exact dyadic values,
// never by subtracting two already-rounded doubles.
import 'dart:typed_data';

/// Exact dyadic decomposition of a finite double: `value = mantissa * 2^exponent`.
class _Dyadic {
  _Dyadic(this.mantissa, this.exponent);

  final BigInt mantissa;
  final int exponent;

  static _Dyadic fromDouble(double x) {
    if (x == 0) return _Dyadic(BigInt.zero, 0);
    final ByteData bytes = ByteData(8);
    bytes.setFloat64(0, x, Endian.big);
    final int hi = bytes.getUint32(0, Endian.big);
    final int lo = bytes.getUint32(4, Endian.big);
    final BigInt bits = (BigInt.from(hi) << 32) | BigInt.from(lo);
    final BigInt signBit = (bits >> 63) & BigInt.one;
    final BigInt expField = (bits >> 52) & BigInt.from(0x7FF);
    final BigInt mantissaField = bits & ((BigInt.one << 52) - BigInt.one);
    BigInt mantissa;
    int exponent;
    if (expField == BigInt.zero) {
      // Subnormal.
      mantissa = mantissaField;
      exponent = -1074;
    } else {
      mantissa = mantissaField + (BigInt.one << 52);
      exponent = expField.toInt() - 1075;
    }
    if (signBit == BigInt.one) mantissa = -mantissa;
    return _Dyadic(mantissa, exponent);
  }

  _Dyadic add(_Dyadic other) {
    if (exponent == other.exponent) {
      return _Dyadic(mantissa + other.mantissa, exponent);
    }
    if (exponent < other.exponent) {
      return _Dyadic(
        mantissa + (other.mantissa << (other.exponent - exponent)),
        exponent,
      );
    }
    return _Dyadic(
      (mantissa << (exponent - other.exponent)) + other.mantissa,
      other.exponent,
    );
  }

  _Dyadic negate() => _Dyadic(-mantissa, exponent);

  _Dyadic subtract(_Dyadic other) => add(other.negate());

  _Dyadic multiply(_Dyadic other) =>
      _Dyadic(mantissa * other.mantissa, exponent + other.exponent);

  _Dyadic scaleByInt(int factor) =>
      _Dyadic(mantissa * BigInt.from(factor), exponent);

  bool get isNegative => mantissa.sign < 0;

  /// Integer square root of a non-negative [BigInt] (largest `r` with
  /// `r*r <= n`), via Newton's method on integers.
  static BigInt _isqrt(BigInt n) {
    if (n < BigInt.zero) {
      throw ArgumentError('isqrt of a negative BigInt');
    }
    if (n == BigInt.zero) return BigInt.zero;
    BigInt x = n;
    BigInt y = (x + BigInt.one) ~/ BigInt.two;
    while (y < x) {
      x = y;
      y = (x + n ~/ x) ~/ BigInt.two;
    }
    return x;
  }

  /// The square root of this (non-negative) dyadic value, itself returned
  /// as a dyadic value accurate to at least [extraBits] bits beyond this
  /// value's own precision. Far more precision than a double ever needs
  /// for the tiny error comparisons this module exists for.
  _Dyadic sqrt(int extraBits) {
    if (isNegative) {
      throw ArgumentError('sqrt of a negative dyadic value');
    }
    if (mantissa == BigInt.zero) return _Dyadic(BigInt.zero, 0);
    int shift = extraBits;
    if ((exponent - shift).isOdd) shift += 1;
    final BigInt scaled = mantissa << shift;
    final BigInt root = _isqrt(scaled);
    return _Dyadic(root, (exponent - shift) ~/ 2);
  }

  /// This value's magnitude as a double, computed via exact BigInt/BigInt
  /// division at [guardBits] of extra precision, never via a direct
  /// (potentially precision-losing) `BigInt.toDouble()` call on a huge
  /// mantissa.
  double toDoubleMagnitude({int guardBits = 200}) {
    if (mantissa == BigInt.zero) return 0.0;
    final BigInt m = mantissa.abs();
    // Normalize so the mantissa occupies roughly [2^guardBits, 2^(guardBits+1)).
    final int bitLength = m.bitLength;
    final int shift = guardBits - bitLength;
    final BigInt normalized =
        shift >= 0 ? (m << shift) : (m >> (-shift));
    final double mantissaAsDouble = normalized.toDouble();
    final int effectiveExponent = exponent - shift;
    // mantissaAsDouble * 2^effectiveExponent, built via repeated safe
    // scaling to avoid a single `math.pow` overflow/underflow step.
    double result = mantissaAsDouble;
    int remaining = effectiveExponent;
    const int step = 1000;
    while (remaining > 0) {
      final int s = remaining > step ? step : remaining;
      result *= _pow2(s);
      remaining -= s;
    }
    while (remaining < 0) {
      final int s = -remaining > step ? step : -remaining;
      result *= _pow2(-s);
      remaining += s;
    }
    return result;
  }

  static double _pow2(int exp) {
    double result = 1.0;
    double base = exp >= 0 ? 2.0 : 0.5;
    int n = exp.abs();
    while (n > 0) {
      if (n.isOdd) result *= base;
      base *= base;
      n >>= 1;
    }
    return result;
  }
}

/// The two exact roots of the 2x2 characteristic polynomial for the exact
/// binary64 values of [a], [b], [c], [d] (`lambda^2 - trace*lambda + det`,
/// `trace = a+d`, `det = a*d-b*c`), computed with BigInt/dyadic arithmetic,
/// and the true (exact-arithmetic) absolute error of [computedLarger] and
/// [computedSmaller] (whichever doubles the production code under test
/// actually returned) against those two exact roots.
({double largerActualError, double smallerActualError}) trueQuadraticErrors({
  required double a,
  required double b,
  required double c,
  required double d,
  required double computedLarger,
  required double computedSmaller,
}) {
  final _Dyadic da = _Dyadic.fromDouble(a);
  final _Dyadic db = _Dyadic.fromDouble(b);
  final _Dyadic dc = _Dyadic.fromDouble(c);
  final _Dyadic dd = _Dyadic.fromDouble(d);

  final _Dyadic trace = da.add(dd);
  final _Dyadic det = da.multiply(dd).subtract(db.multiply(dc));
  final _Dyadic discriminant = trace.multiply(trace).subtract(
    det.scaleByInt(4),
  );
  final _Dyadic sqrtDiscriminant = discriminant.sqrt(400);

  final _Dyadic twiceLarger = trace.add(sqrtDiscriminant);
  final _Dyadic twiceSmaller = trace.subtract(sqrtDiscriminant);
  // Both twiceLarger/twiceSmaller above are `2*root`; halve by
  // decrementing the exponent instead of dividing (dyadic division by an
  // exact power of two is itself exact).
  final _Dyadic exactLargerHalved = _Dyadic(
    twiceLarger.mantissa,
    twiceLarger.exponent - 1,
  );
  final _Dyadic exactSmallerHalved = _Dyadic(
    twiceSmaller.mantissa,
    twiceSmaller.exponent - 1,
  );

  final _Dyadic computedLargerExact = _Dyadic.fromDouble(computedLarger);
  final _Dyadic computedSmallerExact = _Dyadic.fromDouble(computedSmaller);

  final double largerActualError = exactLargerHalved
      .subtract(computedLargerExact)
      .toDoubleMagnitude()
      .abs();
  final double smallerActualError = exactSmallerHalved
      .subtract(computedSmallerExact)
      .toDoubleMagnitude()
      .abs();

  return (
    largerActualError: largerActualError,
    smallerActualError: smallerActualError,
  );
}
