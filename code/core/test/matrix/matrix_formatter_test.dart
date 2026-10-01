import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// The rational [numerator]/[denominator].
Rational _q(int numerator, [int denominator = 1]) =>
    Rational(BigInt.from(numerator), BigInt.from(denominator));

/// The exact complex form `[[a, -b], [b, a]]`.
Matrix _exactComplex(Rational a, Rational b) => Matrix.exact(<List<Rational>>[
  <Rational>[a, -b],
  <Rational>[b, a],
]);

void main() {
  group('MatrixDisplayFormatter (approximate values, runbook D54)', () {
    final Matrix matrix = Matrix(<List<double>>[
      <double>[1, 2],
      <double>[30, 400],
    ]);

    test('renders compact one-line matrix output with the mark', () {
      expect(MatrixDisplayFormatter.compact(matrix), '~[[1, 2], [30, 400]]');
    });

    test('renders expanded aligned matrix output, rows aligned', () {
      expect(MatrixDisplayFormatter.expanded(matrix), '~[ 1   2]\n [30 400]');
    });

    test('text is the cx stack-line form', () {
      expect(MatrixDisplayFormatter.text(matrix), '~[[1 2] [30 400]]');
      expect(
        MatrixDisplayFormatter.text(Matrix.scalar(2 / 3)),
        '~0.666666666667',
      );
    });

    test('mark is ~ and entries carry none', () {
      expect(MatrixDisplayFormatter.mark(matrix), '~');
      expect(MatrixDisplayFormatter.entry(matrix, 1, 1), '400');
    });
  });

  group('MatrixDisplayFormatter (exact values, runbook D54)', () {
    final Matrix matrix = Matrix.exact(<List<Rational>>[
      <Rational>[_q(1, 3), _q(2)],
      <Rational>[_q(-3, 5), _q(400)],
    ]);

    test('compact prints every entry in full, unmarked', () {
      expect(MatrixDisplayFormatter.compact(matrix), '[[1/3, 2], [-0.6, 400]]');
    });

    test('expanded aligns full entries', () {
      expect(MatrixDisplayFormatter.expanded(matrix), '[ 1/3   2]\n[-0.6 400]');
    });

    test('text prints a scalar alone and a matrix with spaces', () {
      expect(MatrixDisplayFormatter.text(matrix), '[[1/3 2] [-0.6 400]]');
      expect(MatrixDisplayFormatter.text(Matrix.exactScalar(_q(1, 3))), '1/3');
      expect(MatrixDisplayFormatter.text(Matrix.exactScalar(_q(7))), '7');
    });

    test('an exact entry is never rounded to 12 digits', () {
      final Rational big = Rational(BigInt.parse('123456789012345678901'));
      expect(
        MatrixDisplayFormatter.text(Matrix.exactScalar(big)),
        '123456789012345678901',
      );
      expect(
        MatrixDisplayFormatter.text(Matrix.exactScalar(_q(1, 1024))),
        '0.0009765625',
      );
    });

    test('mark is empty', () {
      expect(MatrixDisplayFormatter.mark(matrix), '');
    });
  });

  group('MatrixDisplayFormatter.complex', () {
    test('2 + 3i', () {
      expect(
        MatrixDisplayFormatter.complex(_exactComplex(_q(2), _q(3))),
        '2 + 3i',
      );
    });

    test('2 - 3i (negative imaginary)', () {
      expect(
        MatrixDisplayFormatter.complex(_exactComplex(_q(2), _q(-3))),
        '2 - 3i',
      );
    });

    test('pure imaginary: i, -i and 3i', () {
      expect(MatrixDisplayFormatter.complex(_exactComplex(_q(0), _q(1))), 'i');
      expect(
        MatrixDisplayFormatter.complex(_exactComplex(_q(0), _q(-1))),
        '-i',
      );
      expect(MatrixDisplayFormatter.complex(_exactComplex(_q(0), _q(3))), '3i');
    });

    test('pure real: 5 and -7', () {
      expect(MatrixDisplayFormatter.complex(_exactComplex(_q(5), _q(0))), '5');
      expect(
        MatrixDisplayFormatter.complex(_exactComplex(_q(-7), _q(0))),
        '-7',
      );
    });

    test('zero: 0', () {
      expect(MatrixDisplayFormatter.complex(_exactComplex(_q(0), _q(0))), '0');
    });

    test('identity is 1 (no imaginary part)', () {
      expect(MatrixDisplayFormatter.complex(Matrix.exactIdentity(2)), '1');
    });

    test('coefficient 1 rendered as i not 1i', () {
      expect(
        MatrixDisplayFormatter.complex(_exactComplex(_q(2), _q(1))),
        '2 + i',
      );
    });

    test('coefficient -1 rendered as -i not -1i', () {
      expect(
        MatrixDisplayFormatter.complex(_exactComplex(_q(2), _q(-1))),
        '2 - i',
      );
    });

    test('exact fractions: 1/3 - 0.5i', () {
      expect(
        MatrixDisplayFormatter.complex(_exactComplex(_q(1, 3), _q(-1, 2))),
        '1/3 - 0.5i',
      );
    });

    test('a tiny exact imaginary part is not taken for 0', () {
      final BigInt huge = BigInt.from(10).pow(400);
      final Rational tiny = Rational(BigInt.one, huge);
      expect(
        MatrixDisplayFormatter.complex(_exactComplex(_q(1), tiny)),
        '1 + 1/${huge}i',
      );
    });

    test('an exact matrix only near the complex form is rejected', () {
      final Matrix near = Matrix.exact(<List<Rational>>[
        <Rational>[_q(1), Rational(BigInt.one, BigInt.from(10).pow(20))],
        <Rational>[_q(0), _q(1)],
      ]);
      expect(
        () => MatrixDisplayFormatter.complex(near),
        throwsA(isA<MatrixDomainError>()),
      );
    });

    test('approximate values carry the mark once', () {
      expect(MatrixDisplayFormatter.complex(Matrix.complex(2, 3)), '~2 + 3i');
      expect(MatrixDisplayFormatter.complex(Matrix.complex(0, -1)), '~-i');
      expect(
        MatrixDisplayFormatter.complex(Matrix.complex(1.5, 2.5)),
        '~1.5 + 2.5i',
      );
      expect(MatrixDisplayFormatter.complex(Matrix.identity(2)), '~1');
      expect(MatrixDisplayFormatter.complex(Matrix.i), '~i');
    });
  });

  group('MatrixDisplayFormatter large exponent display (issue #5 bug 1)', () {
    test('1e20 preserves the exponent instead of trimming its digits', () {
      expect(MatrixDisplayFormatter.compact(Matrix.scalar(1e20)), '~[[1e+20]]');
    });

    test('a mantissa with trailing zeros still trims down to the exponent', () {
      expect(
        MatrixDisplayFormatter.compact(Matrix.scalar(1.5e30)),
        '~[[1.5e+30]]',
      );
    });

    test('a negative exponent keeps its sign and digits intact', () {
      expect(
        MatrixDisplayFormatter.compact(Matrix.scalar(1e-20)),
        '~[[1e-20]]',
      );
    });
  });

  group('MatrixDisplayFormatter.number (runbook D45)', () {
    test('rounds to 12 significant digits and trims trailing zeros', () {
      expect(MatrixDisplayFormatter.number(-1.9999999999999996), '-2');
      expect(MatrixDisplayFormatter.number(1.4999999999999998), '1.5');
      expect(MatrixDisplayFormatter.number(2 / 3), '0.666666666667');
    });

    test('integers, zero and negative zero print without a point', () {
      expect(MatrixDisplayFormatter.number(14), '14');
      expect(MatrixDisplayFormatter.number(0), '0');
      expect(MatrixDisplayFormatter.number(-0.0), '0');
    });

    test('matches the entries compact prints', () {
      expect(
        MatrixDisplayFormatter.number(1e20),
        MatrixDisplayFormatter.compact(
          Matrix.scalar(1e20),
        ).replaceAll(RegExp(r'[~\[\]]'), ''),
      );
    });
  });
}
