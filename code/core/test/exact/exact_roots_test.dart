// Exact roots and eigenvalues in core (runbook-trust.md, step T4):
// fractional powers and `sqrt`, `frobenius-norm`, the trivial cases of
// `exp` and `ln`, and `eigenvalues` on exact values (D53), exact only when
// the result is rational. Giac checks the same words on generated inputs
// in giac_differential_test.dart.
import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

Rational _q(int numerator, [int denominator = 1]) =>
    Rational(BigInt.from(numerator), BigInt.from(denominator));

List<List<Rational>> _rows(List<List<Rational>> rows) => rows;

Matrix _rpn(String program, {int? maxDigits}) => maxDigits == null
    ? Calculatrix.evaluateRpn(Calculatrix.tokenizeRpnLine(program))
    : Calculatrix.evaluateRpn(
        Calculatrix.tokenizeRpnLine(program),
        maxDigits: maxDigits,
      );

Matcher _exactScalar(Rational value) => isA<Matrix>()
    .having((Matrix m) => m.isExact, 'isExact', isTrue)
    .having((Matrix m) => m.isScalar, 'isScalar', isTrue)
    .having((Matrix m) => m.exactAt(0, 0), 'value', value);

Matcher _exactRows(List<List<Rational>> rows) => isA<Matrix>()
    .having((Matrix m) => m.isExact, 'isExact', isTrue)
    .having((Matrix m) => m.exactRows, 'rows', rows);

Matcher _exactColumn(List<Rational> values) =>
    _exactRows(values.map((Rational v) => <Rational>[v]).toList());

/// An approximate result equal to the one the `~` input gives.
void _expectApproximateLike(String program, String approximateProgram) {
  final Matrix result = _rpn(program);
  expect(result.isExact, isFalse, reason: program);
  expect(result.rows, _rpn(approximateProgram).rows, reason: program);
}

/// The same error as the approximate word on the same input.
void _expectSameError(String program, String approximateProgram) {
  CalculatrixError? approximateError;
  try {
    _rpn(approximateProgram);
  } on CalculatrixError catch (error) {
    approximateError = error;
  }
  expect(approximateError, isNotNull, reason: approximateProgram);
  expect(
    () => _rpn(program),
    throwsA(
      isA<CalculatrixError>()
          .having(
            (CalculatrixError e) => e.errorId,
            'errorId',
            approximateError!.errorId,
          )
          .having(
            (CalculatrixError e) => e.message,
            'message',
            approximateError.message,
          ),
    ),
  );
}

Matcher _limitExceeded({required int limit}) => throwsA(
  isA<LimitExceededError>().having(
    (LimitExceededError e) => e.limit,
    'limit',
    limit,
  ),
);

void main() {
  group('Rational roots', () {
    test('root gives the rational root or null', () {
      expect(_q(27, 64).root(BigInt.from(3)), _q(3, 4));
      expect(_q(2).root(BigInt.two), isNull);
      expect(_q(4, 3).root(BigInt.two), isNull);
      expect(Rational.zero.root(BigInt.from(5)), Rational.zero);
      expect(Rational.one.root(BigInt.from(1000)), Rational.one);
    });

    test('integerRoot and floorRoot on large and boundary values', () {
      final BigInt big = BigInt.parse('123456789012345678901234567890');
      expect(Rational.integerRoot(big.pow(7), BigInt.from(7)), big);
      expect(
        Rational.integerRoot(big.pow(7) + BigInt.one, BigInt.from(7)),
        isNull,
      );
      expect(
        Rational.floorRoot(big.pow(2) - BigInt.one, BigInt.two),
        big - BigInt.one,
      );
      expect(Rational.floorRoot(BigInt.from(8), BigInt.from(100)), BigInt.one);
      expect(Rational.integerRoot(BigInt.from(8), BigInt.from(100)), isNull);
      for (int n = 0; n < 200; n++) {
        final BigInt root = Rational.floorRoot(BigInt.from(n), BigInt.from(3));
        expect(root.pow(3) <= BigInt.from(n), isTrue);
        expect((root + BigInt.one).pow(3) > BigInt.from(n), isTrue);
      }
    });

    test('simplestWithin finds a rational a rounded value missed', () {
      expect(Rational.simplestWithin(0.9999999999999998, 1e-9), Rational.one);
      expect(Rational.simplestWithin(-0.33333333331, 1e-9), _q(-1, 3));
      expect(Rational.simplestWithin(1e-12, 1e-9), Rational.zero);
      // Strictly within: 0 is at distance 1 from 1, so not a candidate.
      expect(Rational.simplestWithin(1.0, 1.0), Rational.one);
    });
  });

  group('scalar fractional powers', () {
    test('rational roots are exact', () {
      expect(_rpn('4 sqrt'), _exactScalar(_q(2)));
      expect(_rpn('9 0.5 power'), _exactScalar(_q(3)));
      expect(_rpn('9 0.5 ^'), _exactScalar(_q(3)));
      expect(_rpn('8 1 3 / power'), _exactScalar(_q(2)));
      expect(_rpn('27 64 / 2 3 / power'), _exactScalar(_q(9, 16)));
      expect(_rpn('4 -3 2 / power'), _exactScalar(_q(1, 8)));
      expect(_rpn('0 sqrt'), _exactScalar(Rational.zero));
      expect(_rpn('0 3 2 / power'), _exactScalar(Rational.zero));
      final BigInt big = BigInt.parse('98765432109876543210');
      expect(_rpn('${big.pow(2)} sqrt'), _exactScalar(Rational(big)));
    });

    test('irrational roots are the approximate ones', () {
      _expectApproximateLike('2 sqrt', '2 approx sqrt');
      _expectApproximateLike('2 1 3 / power', '2 approx 1 3 / power');
      _expectApproximateLike('4 1 3 / power', '4 approx 1 3 / power');
      _expectApproximateLike('-8 1 3 / power', '-8 approx 1 3 / power');
    });

    test('negative bases have the principal imaginary square root', () {
      expect(
        _rpn('-4 sqrt'),
        _exactRows(
          _rows(<List<Rational>>[
            <Rational>[Rational.zero, _q(-2)],
            <Rational>[_q(2), Rational.zero],
          ]),
        ),
      );
      // (2i)^3 = -8i, (2i)^-1 = -i/2, (2i)^-3 = i/8.
      for (final (String exponent, Rational imaginary) in <(String, Rational)>[
        ('3 2 /', _q(-8)),
        ('-1 2 /', _q(-1, 2)),
        ('-3 2 /', _q(1, 8)),
        ('5 2 /', _q(32)),
      ]) {
        expect(
          _rpn('-4 $exponent power'),
          _exactRows(
            _rows(<List<Rational>>[
              <Rational>[Rational.zero, -imaginary],
              <Rational>[imaginary, Rational.zero],
            ]),
          ),
          reason: exponent,
        );
      }
      // Same as the approximate value.
      final List<List<double>> approximate = _rpn('-4 approx 3 2 / power').rows;
      expect(approximate[1][0], closeTo(-8, 1e-9));
    });

    test('negative bases have rational principal fourth roots', () {
      // (-4)^(1/4) = 1 + i, (-4)^(3/4) = (1 + i)^3 = -2 + 2i,
      // (-64)^(1/4) = 2 + 2i.
      for (final (String program, int real, int imaginary)
          in <(String, int, int)>[
            ('-4 1 4 / power', 1, 1),
            ('-4 3 4 / power', -2, 2),
            ('-64 1 4 / power', 2, 2),
          ]) {
        final Matrix result = _rpn(program);
        expect(
          result,
          _exactRows(
            _rows(<List<Rational>>[
              <Rational>[_q(real), _q(-imaginary)],
              <Rational>[_q(imaginary), _q(real)],
            ]),
          ),
          reason: program,
        );
        final List<List<double>> approximate = _rpn(
          program.replaceFirst(' ', ' approx '),
        ).rows;
        expect(approximate[0][0], closeTo(real, 1e-9), reason: program);
        expect(approximate[1][0], closeTo(imaginary, 1e-9), reason: program);
      }
      _expectApproximateLike('-2 1 4 / power', '-2 approx 1 4 / power');
    });

    test('zero to a negative power keeps the approximate error', () {
      _expectSameError('0 -1 2 / power', '0 approx -1 2 / power');
    });

    test('an approximate operand makes the result approximate', () {
      expect(_rpn('4 approx sqrt').isExact, isFalse);
      expect(_rpn('4 0.5 approx power').isExact, isFalse);
      expect(_rpn('4 approx 1 2 / power').isExact, isFalse);
    });

    test('the result is checked against the limit', () {
      expect(
        () => _rpn('4 100001 2 / power'),
        _limitExceeded(limit: ExactArithmetic.defaultMaxDigits),
      );
      expect(
        () => _rpn('10 2000 ^ 3 2 / power', maxDigits: 2500),
        _limitExceeded(limit: 2500),
      );
      expect(_rpn('10 2000 ^ 3 2 / power', maxDigits: 3001).isExact, isTrue);
    });
  });

  group('complex and matrix fractional powers', () {
    test('complex numbers have exact principal square roots', () {
      expect(
        _rpn('[[3 -4] [4 3]] sqrt'),
        _exactRows(
          _ints2(<List<int>>[
            <int>[2, -1],
            <int>[1, 2],
          ]),
        ),
      );
      expect(
        _rpn('[[-3 -4] [4 -3]] sqrt'),
        _exactRows(
          _ints2(<List<int>>[
            <int>[1, -2],
            <int>[2, 1],
          ]),
        ),
      );
      // sqrt(-3 - 4i) = 1 - 2i.
      expect(
        _rpn('[[-3 4] [-4 -3]] sqrt'),
        _exactRows(
          _ints2(<List<int>>[
            <int>[1, 2],
            <int>[-2, 1],
          ]),
        ),
      );
      // A negative real in the complex form: sqrt(-4) = 2i.
      expect(
        _rpn('[[-4 0] [0 -4]] sqrt'),
        _exactRows(
          _ints2(<List<int>>[
            <int>[0, -2],
            <int>[2, 0],
          ]),
        ),
      );
      // (3 + 4i)^(-1/2) = 1 / (2 + i) = (2 - i) / 5.
      expect(
        _rpn('[[3 -4] [4 3]] -1 2 / power'),
        _exactRows(
          _rows(<List<Rational>>[
            <Rational>[_q(2, 5), _q(1, 5)],
            <Rational>[_q(-1, 5), _q(2, 5)],
          ]),
        ),
      );
      _expectApproximateLike(
        '[[1 -1] [1 1]] sqrt',
        '[[1 -1] [1 1]] approx sqrt',
      );
    });

    test('diagonal matrices take the root of each entry', () {
      expect(
        _rpn('[[4 0] [0 9]] sqrt'),
        _exactRows(
          _ints2(<List<int>>[
            <int>[2, 0],
            <int>[0, 3],
          ]),
        ),
      );
      expect(
        _rpn('[[8 0 0] [0 27 0] [0 0 1]] -2 3 / power'),
        _exactRows(
          _rows(<List<Rational>>[
            <Rational>[_q(1, 4), Rational.zero, Rational.zero],
            <Rational>[Rational.zero, _q(1, 9), Rational.zero],
            <Rational>[Rational.zero, Rational.zero, Rational.one],
          ]),
        ),
      );
      expect(
        _rpn('[[4 0] [0 0]] sqrt'),
        _exactRows(
          _ints2(<List<int>>[
            <int>[2, 0],
            <int>[0, 0],
          ]),
        ),
      );
      _expectApproximateLike('[[4 0] [0 2]] sqrt', '[[4 0] [0 2]] approx sqrt');
    });

    test('general matrices are exact when a rational root checks out', () {
      expect(
        _rpn('[[5 4] [4 5]] sqrt'),
        _exactRows(
          _ints2(<List<int>>[
            <int>[2, 1],
            <int>[1, 2],
          ]),
        ),
      );
      expect(
        _rpn('[[5 4] [4 5]] 3 2 / power'),
        _exactRows(
          _ints2(<List<int>>[
            <int>[14, 13],
            <int>[13, 14],
          ]),
        ),
      );
      expect(
        _rpn('[[5 4] [4 5]] -1 2 / power'),
        _exactRows(
          _rows(<List<Rational>>[
            <Rational>[_q(2, 3), _q(-1, 3)],
            <Rational>[_q(-1, 3), _q(2, 3)],
          ]),
        ),
      );
      // X = [[2 1 0] [1 3 1] [0 1 4]] / 7, B = X^2.
      expect(
        _rpn('[[5 5 1] [5 11 7] [1 7 17]] 49 / sqrt'),
        _exactRows(
          _rows(<List<Rational>>[
            <Rational>[_q(2, 7), _q(1, 7), Rational.zero],
            <Rational>[_q(1, 7), _q(3, 7), _q(1, 7)],
            <Rational>[Rational.zero, _q(1, 7), _q(4, 7)],
          ]),
        ),
      );
      _expectApproximateLike('[[2 1] [1 2]] sqrt', '[[2 1] [1 2]] approx sqrt');
    });

    test('values with no real root keep the approximate errors', () {
      _expectSameError('[[1 2] [3 4]] sqrt', '[[1 2] [3 4]] approx sqrt');
      _expectSameError('[[1 2]] sqrt', '[[1 2]] approx sqrt');
      // A singular matrix has a square root, and no other root.
      expect(
        _rpn('[[2 2] [2 2]] sqrt'),
        _exactRows(
          _rows(<List<Rational>>[
            <Rational>[_q(1), _q(1)],
            <Rational>[_q(1), _q(1)],
          ]),
        ),
      );
      _expectSameError(
        '[[2 2] [2 2]] 3 2 / power',
        '[[2 2] [2 2]] approx 3 2 / power',
      );
      _expectSameError(
        '[[1 2] [3 4]] 1 3 / power',
        '[[1 2] [3 4]] approx 1 3 / power',
      );
    });

    test('the app session sqrt is exact too', () {
      final RpnEngine engine = RpnEngine();
      engine.push(Matrix.exactScalar(_q(9, 4)));
      expect(engine.applyUnary(RpnUnaryOperator.sqrt), _exactScalar(_q(3, 2)));
      engine.push(Matrix.exactScalar(_q(2)));
      expect(engine.applyUnary(RpnUnaryOperator.sqrt).isExact, isFalse);
    });

    test('the app session sqrt keeps the non-square error', () {
      String? message(Matrix value) {
        final RpnEngine engine = RpnEngine()..push(value);
        try {
          engine.applyUnary(RpnUnaryOperator.sqrt);
        } on CalculatrixError catch (error) {
          return error.message;
        }
        return null;
      }

      final Matrix row = Matrix.exact(<List<Rational>>[
        <Rational>[_q(1), _q(2)],
      ]);
      expect(message(row), isNotNull);
      expect(message(row), message(row.toApproximate()));
    });
  });

  group('frobenius-norm', () {
    test('exact when the sum of squares is a rational square', () {
      expect(_rpn('[[3 4]] frobenius-norm'), _exactScalar(_q(5)));
      expect(_rpn('[[1 2] [2 4]] 3 / frobenius-norm'), _exactScalar(_q(5, 3)));
      expect(_rpn('-7 frobenius-norm'), _exactScalar(_q(7)));
      expect(_rpn('[[0 0] [0 0]] frobenius-norm'), _exactScalar(Rational.zero));
      _expectApproximateLike(
        '[[1 1]] frobenius-norm',
        '[[1 1]] approx frobenius-norm',
      );
      expect(_rpn('[[3 4]] approx frobenius-norm').isExact, isFalse);
    });

    test('each partial sum is checked against the limit', () {
      expect(
        () => _rpn('[[3 4]] frobenius-norm', maxDigits: 1),
        _limitExceeded(limit: 1),
      );
    });
  });

  group('exp and ln', () {
    test('the zero matrix and the identity are exact', () {
      expect(_rpn('0 exp'), _exactScalar(Rational.one));
      expect(_rpn('1 ln'), _exactScalar(Rational.zero));
      expect(
        _rpn('[[0 0] [0 0]] exp'),
        _exactRows(
          _ints2(<List<int>>[
            <int>[1, 0],
            <int>[0, 1],
          ]),
        ),
      );
      expect(
        _rpn('2 identity ln'),
        _exactRows(
          _ints2(<List<int>>[
            <int>[0, 0],
            <int>[0, 0],
          ]),
        ),
      );
    });

    test('everything else is approximate, errors included', () {
      _expectApproximateLike('1 exp', '1 approx exp');
      _expectApproximateLike('2 ln', '2 approx ln');
      _expectApproximateLike('[[1 2] [3 4]] exp', '[[1 2] [3 4]] approx exp');
      _expectSameError('[[0 0]] exp', '[[0 0]] approx exp');
      _expectSameError('[[1 0]] ln', '[[1 0]] approx ln');
      _expectSameError('0 ln', '0 approx ln');
      expect(_rpn('0 approx exp').isExact, isFalse);
    });
  });

  group('eigenvalues', () {
    test('rational eigenvalues are exact, largest first', () {
      expect(
        _rpn('[[2 1] [1 2]] eigenvalues'),
        _exactColumn(<Rational>[_q(3), _q(1)]),
      );
      expect(
        _rpn('[[1 0] [14 2]] 3 / eigenvalues'),
        _exactColumn(<Rational>[_q(2, 3), _q(1, 3)]),
      );
      expect(
        _rpn('[[5 0 0] [0 5 0] [0 0 5]] eigenvalues'),
        _exactColumn(<Rational>[_q(5), _q(5), _q(5)]),
      );
      expect(
        _rpn('[[2 1 0] [0 2 0] [0 0 -3]] eigenvalues'),
        _exactColumn(<Rational>[_q(2), _q(2), _q(-3)]),
      );
      expect(
        _rpn('[[0 1 2] [0 0 3] [0 0 0]] eigenvalues'),
        _exactColumn(<Rational>[Rational.zero, Rational.zero, Rational.zero]),
      );
      expect(_rpn('7 3 / eigenvalues'), _exactScalar(_q(7, 3)));
    });

    test('large integer eigenvalues with multiplicity', () {
      // S D S^-1 with S = [[1 1] [0 1]] and D = diag(10^30, 10^30) is D;
      // use an upper triangular matrix with a repeated large eigenvalue.
      final BigInt big = BigInt.from(10).pow(30);
      final Matrix result = _rpn(
        '[[$big 7 1] [0 $big 5] [0 0 -$big]] eigenvalues',
      );
      expect(
        result,
        _exactColumn(<Rational>[Rational(big), Rational(big), Rational(-big)]),
      );
    });

    test('irrational eigenvalues are the approximate ones', () {
      _expectApproximateLike(
        '[[1 2] [3 4]] eigenvalues',
        '[[1 2] [3 4]] approx eigenvalues',
      );
      _expectApproximateLike(
        '[[2 0 0] [0 1 1] [0 1 2]] eigenvalues',
        '[[2 0 0] [0 1 1] [0 1 2]] approx eigenvalues',
      );
    });

    test('complex eigenvalues keep the approximate error', () {
      _expectSameError(
        '[[0 -1] [1 0]] eigenvalues',
        '[[0 -1] [1 0]] approx eigenvalues',
      );
      _expectSameError('[[1 2]] eigenvalues', '[[1 2]] approx eigenvalues');
    });

    test('an approximate operand makes the result approximate', () {
      expect(_rpn('[[2 1] [1 2]] approx eigenvalues').isExact, isFalse);
    });

    test('the characteristic polynomial is bounded before computing', () {
      expect(
        () => _rpn('[[1e30 1] [1 1e30]] eigenvalues', maxDigits: 50),
        throwsA(
          isA<LimitExceededError>()
              .having((LimitExceededError e) => e.limit, 'limit', 50)
              .having(
                (LimitExceededError e) => e.message,
                'message',
                allOf(
                  startsWith(
                    'The exact characteristic polynomial could have up to ',
                  ),
                  contains('(norm bound)'),
                ),
              ),
        ),
      );
      expect(
        _rpn('[[1e30 1] [1 1e30]] eigenvalues', maxDigits: 70),
        _exactColumn(<Rational>[
          Rational(BigInt.from(10).pow(30) + BigInt.one),
          Rational(BigInt.from(10).pow(30) - BigInt.one),
        ]),
      );
    });
  });
}

List<List<Rational>> _ints2(List<List<int>> rows) =>
    rows.map((List<int> row) => row.map((int v) => _q(v)).toList()).toList();
