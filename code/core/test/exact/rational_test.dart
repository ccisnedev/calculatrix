import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  Rational parse(String text, {int maxDigits = 10000}) =>
      Rational.tryParseDecimal(
        text,
        maxDigits: maxDigits,
        onTooLarge: (int estimated) => StateError('too large: $estimated'),
      )!;

  group('Rational.tryParseDecimal', () {
    test('reads decimals and exponents exactly (runbook D50)', () {
      expect(parse('0.1'), Rational(BigInt.one, BigInt.from(10)));
      expect(parse('1e-3').toDisplayString(), '0.001');
      expect(parse('-2.50e1').toDisplayString(), '-25');
      expect(parse('+.5').toDisplayString(), '0.5');
      expect(parse('1.').toDisplayString(), '1');
      expect(parse('007').toDisplayString(), '7');
      expect(parse('1e400').digits, 401);
    });

    test('returns null for text that is not a decimal', () {
      for (final String text in ['', '-', '1e', 'e5', '1.2.3', 'NaN', '0x10']) {
        expect(
          Rational.tryParseDecimal(
            text,
            maxDigits: 10000,
            onTooLarge: (int estimated) => StateError('$estimated'),
          ),
          isNull,
          reason: text,
        );
      }
    });

    test('raises before building a number over the limit (runbook D55)', () {
      expect(() => parse('1e1000000000'), throwsStateError);
      expect(() => parse('1e-20000'), throwsStateError);
      expect(parse('1e9999').digits, 10000);
      expect(() => parse('1e10000'), throwsStateError);
    });
  });

  group('Rational.toDisplayString (runbook D54)', () {
    test('integers, short decimals and fractions', () {
      expect(Rational.fromInt(-12).toDisplayString(), '-12');
      expect((Rational.one / Rational.fromInt(3)).toDisplayString(), '1/3');
      expect(
        Rational(BigInt.one, BigInt.from(1024)).toDisplayString(),
        '0.0009765625',
      );
      expect(
        Rational(BigInt.one, BigInt.from(1073741824)).toDisplayString(),
        '1/1073741824',
      );
      expect(
        Rational(BigInt.from(-3), BigInt.from(5)).toDisplayString(),
        '-0.6',
      );
    });

    test('a terminating decimal with more than 20 places is a fraction', () {
      expect(parse('1e-20').toDisplayString(), '0.00000000000000000001');
      expect(parse('1e-21').toDisplayString(), '1/1000000000000000000000');
    });
  });

  group('Rational and double', () {
    test('toDouble rounds correctly at the edges of the double range', () {
      expect(parse('4.9406564584124654e-324').toDouble(), 5e-324);
      expect(parse('2.4703282292062327e-324').toDouble(), 0.0);
      expect(parse('2.4703282292062328e-324').toDouble(), 5e-324);
      expect(
        parse('1.7976931348623158e308').toDouble(),
        1.7976931348623157e308,
      );
      expect(parse('1.7976931348623159e308').toDouble(), double.infinity);
      expect(parse('1e400').toDouble(), double.infinity);
    });

    test('toDouble rounds half to even', () {
      expect(parse('9007199254740993').toDouble(), 9007199254740992.0);
      expect(parse('9007199254740995').toDouble(), 9007199254740996.0);
    });

    test('simplestForDouble gives the simplest rational of a double', () {
      expect(Rational.simplestForDouble(0.1).toDisplayString(), '0.1');
      expect(Rational.simplestForDouble(1 / 3).toDisplayString(), '1/3');
      expect(Rational.simplestForDouble(-2 / 7).toDisplayString(), '-2/7');
      expect(Rational.simplestForDouble(5e-324).toDouble(), 5e-324);
    });

    test('round trips on random doubles', () {
      final math.Random random = math.Random(1);
      for (int i = 0; i < 20000; i++) {
        final double bits =
            random.nextInt(1 << 32) * 4294967296.0 + random.nextInt(1 << 32);
        final int exponent = random.nextInt(2000) - 1000;
        final double value =
            (random.nextBool() ? -1 : 1) *
            bits *
            math.pow(2, exponent - 64).toDouble();
        if (!value.isFinite || value == 0) {
          continue;
        }
        expect(Rational.fromDouble(value).toDouble(), value);
        expect(Rational.simplestForDouble(value).toDouble(), value);
        expect(parse(value.toString()).toDouble(), value, reason: '$value');
      }
    });
  });

  group('Rational digits', () {
    test('digitCount counts decimal digits', () {
      expect(Rational.digitCount(BigInt.from(10).pow(9999)), 10000);
      expect(Rational.digitCount(BigInt.from(10).pow(9999) - BigInt.one), 9999);
      expect(Rational.digitCount(BigInt.zero), 1);
    });

    test('digitUpperBound never undercounts', () {
      final math.Random random = math.Random(2);
      for (int i = 0; i < 500; i++) {
        final BigInt value = BigInt.from(
          random.nextInt(1 << 30),
        ).pow(random.nextInt(40) + 1);
        expect(
          Rational.digitUpperBound(value),
          greaterThanOrEqualTo(Rational.digitCount(value)),
        );
      }
    });
  });
}
