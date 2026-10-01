import 'dart:math' as math;
import 'dart:typed_data';

/// An exact rational number (runbook D49): a pair of [BigInt], always
/// reduced, with a positive denominator. An integer is a rational whose
/// denominator is 1.
///
/// Immutable. Every operation returns a new, reduced value.
final class Rational implements Comparable<Rational> {
  /// `numerator / denominator`, reduced. Throws [ArgumentError] when
  /// [denominator] is zero: a caller that can meet a zero divisor checks
  /// for it first and raises its own domain error.
  factory Rational(BigInt numerator, [BigInt? denominator]) {
    BigInt n = numerator;
    BigInt d = denominator ?? BigInt.one;
    if (d == BigInt.zero) {
      throw ArgumentError('Rational denominator cannot be zero.');
    }
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    if (d == BigInt.one) {
      return Rational._(n, d);
    }
    final BigInt g = n.gcd(d);
    if (g != BigInt.one && g != BigInt.zero) {
      n = n ~/ g;
      d = d ~/ g;
    }
    return Rational._(n, d);
  }

  const Rational._(this.numerator, this.denominator);

  factory Rational.fromInt(int value) =>
      Rational._(BigInt.from(value), BigInt.one);

  static final Rational zero = Rational._(BigInt.zero, BigInt.one);
  static final Rational one = Rational._(BigInt.one, BigInt.one);

  final BigInt numerator;

  /// Always positive.
  final BigInt denominator;

  bool get isInteger => denominator == BigInt.one;

  bool get isZero => numerator == BigInt.zero;

  bool get isNegative => numerator.isNegative;

  Rational operator +(Rational other) {
    if (denominator == other.denominator) {
      return Rational(numerator + other.numerator, denominator);
    }
    return Rational(
      numerator * other.denominator + other.numerator * denominator,
      denominator * other.denominator,
    );
  }

  Rational operator -(Rational other) => this + (-other);

  Rational operator -() => Rational._(-numerator, denominator);

  Rational operator *(Rational other) {
    if (isZero || other.isZero) {
      return zero;
    }
    // Cross-reducing first keeps the intermediate products as small as the
    // result itself.
    final BigInt g1 = numerator.gcd(other.denominator);
    final BigInt g2 = other.numerator.gcd(denominator);
    return Rational._(
      (numerator ~/ g1) * (other.numerator ~/ g2),
      (denominator ~/ g2) * (other.denominator ~/ g1),
    );
  }

  /// Throws [ArgumentError] when [other] is zero (see the constructor).
  Rational operator /(Rational other) => this * other.reciprocal();

  /// Throws [ArgumentError] when this value is zero.
  Rational reciprocal() => Rational(denominator, numerator);

  Rational abs() => isNegative ? -this : this;

  /// This value raised to the non-negative integer [exponent]. `0^0` is 1.
  Rational powNonNegative(int exponent) {
    assert(exponent >= 0);
    return Rational._(numerator.pow(exponent), denominator.pow(exponent));
  }

  /// The non-negative [index]-th root of this non-negative value when it
  /// is rational, else null: a reduced fraction has a rational root only
  /// when its numerator and denominator are both perfect powers.
  Rational? root(BigInt index) {
    assert(!isNegative && index >= BigInt.one);
    final BigInt? n = integerRoot(numerator, index);
    if (n == null) {
      return null;
    }
    final BigInt? d = integerRoot(denominator, index);
    return d == null ? null : Rational._(n, d);
  }

  /// The [index]-th root of the integer [value] >= 0 when it is an
  /// integer, else null.
  static BigInt? integerRoot(BigInt value, BigInt index) {
    if (value <= BigInt.one || index == BigInt.one) {
      return value;
    }
    // Past this index the floor of the root is 1, whose powers are 1.
    if (index >= BigInt.from(value.bitLength)) {
      return null;
    }
    final BigInt root = floorRoot(value, index);
    return root.pow(index.toInt()) == value ? root : null;
  }

  /// The largest integer whose [index]-th power is at most [value] >= 0.
  static BigInt floorRoot(BigInt value, BigInt index) {
    assert(!value.isNegative && index >= BigInt.one);
    if (value <= BigInt.one || index == BigInt.one) {
      return value;
    }
    final int bits = value.bitLength;
    // value < 2^bits, so a root of 2 or more needs index < bits.
    if (index >= BigInt.from(bits)) {
      return BigInt.one;
    }
    final int k = index.toInt();
    // Integer Newton iteration from a start above the root; it decreases
    // to the floor of the root and stops there.
    BigInt x = BigInt.one << ((bits + k - 1) ~/ k);
    final BigInt previousIndex = BigInt.from(k - 1);
    while (true) {
      final BigInt next = (previousIndex * x + value ~/ x.pow(k - 1)) ~/ index;
      if (next >= x) {
        break;
      }
      x = next;
    }
    return x;
  }

  @override
  int compareTo(Rational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  @override
  bool operator ==(Object other) =>
      other is Rational &&
      numerator == other.numerator &&
      denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  /// The decimal digits of the larger of numerator and denominator, the
  /// quantity the size limit of runbook D55 counts.
  int get digits {
    final int n = digitCount(numerator);
    final int d = digitCount(denominator);
    return n > d ? n : d;
  }

  /// The number of decimal digits of `value.abs()` (1 for zero).
  static int digitCount(BigInt value) {
    final BigInt magnitude = value.abs();
    if (magnitude < _ten18) {
      return magnitude.toString().length;
    }
    // From the bit length, the count is one of two neighbors; a single
    // comparison against a power of ten settles which.
    final int upper = (magnitude.bitLength * _log10Of2).floor() + 1;
    return magnitude < BigInt.from(10).pow(upper - 1) ? upper - 1 : upper;
  }

  /// An upper bound for the number of decimal digits of `value.abs()`,
  /// from its bit length alone, never below the exact count and at most
  /// one above it.
  static int digitUpperBound(BigInt value) {
    final int bits = value.abs().bitLength;
    return bits == 0 ? 1 : (bits * _log10Of2).floor() + 1;
  }

  /// log10 of `value.abs()`, for `value != 0`, accurate to about 15
  /// significant digits even when the value has no finite `double` form.
  static double log10Of(BigInt value) {
    final BigInt magnitude = value.abs();
    final int bits = magnitude.bitLength;
    if (bits <= 1000) {
      return math.log(magnitude.toDouble()) / math.ln10;
    }
    final int shift = bits - 64;
    return math.log((magnitude >> shift).toDouble()) / math.ln10 +
        shift * _log10Of2;
  }

  static const double _log10Of2 = 0.30102999566398120;
  static final BigInt _ten18 = BigInt.from(10).pow(18);

  /// The `double` nearest to this value, ties to even (IEEE 754
  /// round-to-nearest), or an infinity when it is beyond the largest
  /// finite `double`. Correctly rounded, unlike `numerator.toDouble() /
  /// denominator.toDouble()`, which rounds twice and overflows for large
  /// numerators and denominators.
  double toDouble() {
    if (isZero) {
      return 0.0;
    }
    final bool negative = isNegative;
    final BigInt a = numerator.abs();
    final BigInt q = denominator;

    // Scale so the integer quotient has 55 or 56 bits: 53 for the
    // significand, one to round on, and at least one more; the remainder is
    // the sticky bit.
    final int shift = 55 - (a.bitLength - q.bitLength);
    final BigInt scaledNumerator = shift >= 0 ? a << shift : a;
    final BigInt scaledDenominator = shift >= 0 ? q : q << -shift;
    final BigInt quotient = scaledNumerator ~/ scaledDenominator;
    final bool sticky =
        scaledNumerator.remainder(scaledDenominator) != BigInt.zero;

    // value = quotient * 2^-shift, in [2^e2, 2^(e2 + 1)).
    final int quotientBits = quotient.bitLength;
    final int e2 = quotientBits - 1 - shift;
    if (e2 > 1023) {
      return negative ? double.negativeInfinity : double.infinity;
    }
    // Bits of the quotient dropped to fit the significand: 53 bits for a
    // normal double, fewer below 2^-1022, where the last bit is 2^-1074.
    int drop = quotientBits - 53;
    if (e2 < -1022) {
      drop = shift - 1074;
    }
    if (drop > quotientBits) {
      return negative ? -0.0 : 0.0;
    }

    BigInt significand = quotient >> drop;
    final BigInt lower = quotient - (significand << drop);
    final BigInt half = BigInt.one << (drop - 1);
    if (lower > half || (lower == half && (sticky || significand.isOdd))) {
      significand += BigInt.one;
    }
    int exponent = drop - shift;

    if (significand == BigInt.zero) {
      return negative ? -0.0 : 0.0;
    }
    if (significand == _two53) {
      significand = _two52;
      exponent += 1;
    }

    int biased;
    BigInt fraction;
    if (significand >= _two52) {
      biased = exponent + 52 + 1023;
      if (biased >= 2047) {
        return negative ? double.negativeInfinity : double.infinity;
      }
      fraction = significand - _two52;
    } else {
      // Subnormal: the exponent of the last bit is exactly -1074.
      biased = 0;
      fraction = significand;
    }

    final ByteData bytes = ByteData(8);
    final int high =
        (negative ? 0x80000000 : 0) | (biased << 20) | (fraction >> 32).toInt();
    bytes.setUint32(0, high);
    bytes.setUint32(4, (fraction & _mask32).toInt());
    return bytes.getFloat64(0);
  }

  static final BigInt _two52 = BigInt.one << 52;
  static final BigInt _two53 = BigInt.one << 53;
  static final BigInt _mask32 = BigInt.from(0xFFFFFFFF);

  /// The exact value of the finite [value]: every finite `double` is a
  /// dyadic rational. Throws [ArgumentError] for NaN or an infinity.
  factory Rational.fromDouble(double value) {
    if (!value.isFinite) {
      throw ArgumentError('$value has no exact rational value.');
    }
    final ByteData bytes = ByteData(8)..setFloat64(0, value);
    final int high = bytes.getUint32(0);
    final int low = bytes.getUint32(4);
    final bool negative = (high & 0x80000000) != 0;
    final int biased = (high >> 20) & 0x7FF;
    BigInt significand = (BigInt.from(high & 0xFFFFF) << 32) | BigInt.from(low);
    int exponent;
    if (biased == 0) {
      exponent = -1074;
    } else {
      significand += _two52;
      exponent = biased - 1075;
    }
    if (negative) {
      significand = -significand;
    }
    return exponent >= 0
        ? Rational(significand << exponent)
        : Rational(significand, BigInt.one << -exponent);
  }

  /// The simplest rational (smallest denominator, then smallest numerator)
  /// whose nearest `double` is the finite [value] (runbook D52, the `exact`
  /// word): `0.1` gives 1/10 and the `double` nearest 1/3 gives 1/3. A
  /// `double` that is a whole number gives that whole number, the value it
  /// spells. Never beyond the precision of the `double`: the result rounds
  /// back to [value] exactly.
  factory Rational.simplestForDouble(double value) {
    final Rational exact = Rational.fromDouble(value);
    if (exact.isInteger) {
      return exact;
    }
    final bool negative = value < 0;
    final Rational magnitude = exact.abs();

    // The values that round to `value` lie strictly within half a unit in
    // the last place on either side (the ends round to it only on a tie to
    // an even significand, and an end is never simpler than `value`
    // itself, whose denominator is smaller).
    final Rational below = Rational.fromDouble(_nextDown(value.abs()));
    final Rational above = Rational.fromDouble(_nextUp(value.abs()));
    final Rational two = Rational.fromInt(2);
    final Rational low = (magnitude + below) / two;
    final Rational high = (magnitude + above) / two;

    final Rational found = _simplestBetween(low, high);
    final Rational result = negative ? -found : found;
    return result.toDouble() == value ? result : exact;
  }

  /// The simplest rational strictly within [tolerance] > 0 of the finite
  /// [value]: a guess for a rational that a rounded computation missed by
  /// more than one unit in the last place. Unlike [Rational.simplestForDouble]
  /// it may not round back to [value]; callers check it exactly.
  factory Rational.simplestWithin(double value, double tolerance) {
    final Rational center = Rational.fromDouble(value.abs());
    final Rational radius = Rational.fromDouble(tolerance);
    final Rational low = center - radius;
    if (!(Rational.zero < low)) {
      return Rational.zero;
    }
    final Rational found = _simplestBetween(low, center + radius);
    return value < 0 ? -found : found;
  }

  // The simplest rational strictly between 0 <= low < high, by the
  // continued-fraction (Stern-Brocot) descent.
  static Rational _simplestBetween(Rational low, Rational high) {
    final BigInt floorLow = low.numerator ~/ low.denominator;
    final Rational next = Rational(floorLow + BigInt.one);
    if (next < high) {
      return next;
    }
    final Rational base = Rational(floorLow);
    final Rational lowFraction = low - base;
    final Rational highFraction = high - base;
    if (lowFraction.isZero) {
      // (0, h): the simplest is 1/n with the smallest n where 1/n < h.
      final Rational inverse = highFraction.reciprocal();
      final BigInt n = inverse.numerator ~/ inverse.denominator + BigInt.one;
      return base + Rational(BigInt.one, n);
    }
    final Rational inner = _simplestBetween(
      highFraction.reciprocal(),
      lowFraction.reciprocal(),
    );
    return base + inner.reciprocal();
  }

  bool operator <(Rational other) => compareTo(other) < 0;

  static double _nextUp(double value) {
    final ByteData bytes = ByteData(8)..setFloat64(0, value);
    _addToBits(bytes, 1);
    return bytes.getFloat64(0);
  }

  static double _nextDown(double value) {
    if (value == 0) {
      return 0;
    }
    final ByteData bytes = ByteData(8)..setFloat64(0, value);
    _addToBits(bytes, -1);
    return bytes.getFloat64(0);
  }

  // Adds +1 or -1 to the 64-bit pattern of a non-negative double, which
  // steps it to the neighboring double above or below.
  static void _addToBits(ByteData bytes, int delta) {
    int high = bytes.getUint32(0);
    int low = bytes.getUint32(4);
    if (delta > 0) {
      low += 1;
      if (low > 0xFFFFFFFF) {
        low = 0;
        high += 1;
      }
    } else {
      low -= 1;
      if (low < 0) {
        low = 0xFFFFFFFF;
        high -= 1;
      }
    }
    bytes.setUint32(0, high);
    bytes.setUint32(4, low);
  }

  /// The exact value a numeric literal spells (runbook D50), or null when
  /// [text] is not a decimal literal: an optional sign, digits with an
  /// optional decimal point (`1`, `1.`, `.5`, `1.25`), and an optional
  /// exponent (`1e-3`, `2.5E+10`). `NaN` and `Infinity` are not literals of
  /// this grammar.
  ///
  /// The size is checked before any [BigInt] is built, so a literal such as
  /// `1e1000000000` cannot exhaust memory: when the value would have more
  /// than [maxDigits] digits in its numerator or denominator,
  /// [onTooLarge] is called with the estimated count and its result
  /// thrown.
  static Rational? tryParseDecimal(
    String text, {
    required int maxDigits,
    required Object Function(int estimatedDigits) onTooLarge,
  }) {
    final RegExpMatch? match = _decimalPattern.firstMatch(text);
    if (match == null) {
      return null;
    }
    final bool negative = match.group(1) == '-';
    final String integerDigits = match.group(2) ?? '';
    final String fractionDigits = match.group(3) ?? match.group(4) ?? '';
    final String? exponentText = match.group(5);

    String mantissa = (integerDigits + fractionDigits).replaceFirst(
      RegExp(r'^0+'),
      '',
    );
    if (mantissa.isEmpty) {
      return zero;
    }
    // Trailing zeros of the mantissa move into the exponent.
    int trailingZeros = 0;
    while (mantissa.endsWith('0')) {
      mantissa = mantissa.substring(0, mantissa.length - 1);
      trailingZeros++;
    }

    // value = mantissa * 10^scale.
    final BigInt exponent = exponentText == null
        ? BigInt.zero
        : BigInt.parse(exponentText);
    final BigInt scale =
        exponent + BigInt.from(trailingZeros - fractionDigits.length);
    final BigInt numeratorDigits = scale.isNegative
        ? BigInt.from(mantissa.length)
        : BigInt.from(mantissa.length) + scale;
    final BigInt denominatorDigits = scale.isNegative
        ? -scale + BigInt.one
        : BigInt.one;
    final BigInt estimated = numeratorDigits > denominatorDigits
        ? numeratorDigits
        : denominatorDigits;
    if (estimated > BigInt.from(maxDigits)) {
      throw onTooLarge(_clampToInt(estimated));
    }

    final BigInt m = BigInt.parse(mantissa);
    final int s = scale.toInt();
    final Rational magnitude = s >= 0
        ? Rational._(m * BigInt.from(10).pow(s), BigInt.one)
        : Rational(m, BigInt.from(10).pow(-s));
    return negative ? -magnitude : magnitude;
  }

  static int _clampToInt(BigInt value) =>
      value > BigInt.from(maxEstimate) ? maxEstimate : value.toInt();

  /// The largest digit estimate a `limit-exceeded` reports: the largest
  /// `int` of the platform (2^63 - 1 on the VM, 2^53 - 1 on the web).
  /// Larger estimates are reported as this value.
  static final int maxEstimate = _largestInt();

  static int _largestInt() {
    final BigInt vm = (BigInt.one << 63) - BigInt.one;
    return vm.isValidInt ? vm.toInt() : 9007199254740991;
  }

  static final RegExp _decimalPattern = RegExp(
    r'^([+-])?(?:(\d+)(?:\.(\d*))?|\.(\d+))(?:[eE]([+-]?\d+))?$',
  );

  /// The text of runbook D54: an integer as an integer; a rational with a
  /// finite decimal expansion of at most 20 digits after the point as a
  /// decimal (`0.6`, `0.0009765625`); every other rational as a fraction
  /// (`1/3`).
  String toDisplayString() {
    if (isInteger) {
      return numerator.toString();
    }
    final int? places = _terminatingPlaces(denominator);
    if (places != null && places <= 20) {
      final BigInt scaled =
          numerator.abs() * (BigInt.from(10).pow(places) ~/ denominator);
      final String digits = scaled.toString().padLeft(places + 1, '0');
      final String whole = digits.substring(0, digits.length - places);
      final String fraction = digits.substring(digits.length - places);
      return '${isNegative ? '-' : ''}$whole.$fraction';
    }
    return '$numerator/$denominator';
  }

  // The number of digits after the decimal point of 1/denominator when it
  // terminates within 20 places (denominator = 2^a 5^b gives max(a, b)),
  // or null. Stops early: a longer expansion prints as a fraction anyway.
  static int? _terminatingPlaces(BigInt denominator) {
    final int twos = (denominator & -denominator).bitLength - 1;
    if (twos > 20) {
      return null;
    }
    BigInt rest = denominator >> twos;
    int fives = 0;
    final BigInt five = BigInt.from(5);
    while (fives <= 20 && rest.remainder(five) == BigInt.zero) {
      rest = rest ~/ five;
      fives++;
    }
    if (rest != BigInt.one) {
      return null;
    }
    return twos > fives ? twos : fives;
  }

  @override
  String toString() => toDisplayString();
}
