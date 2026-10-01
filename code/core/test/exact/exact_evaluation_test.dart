// Exact numbers in core (runbook-trust.md, step T2): exact literals (D50),
// the approximate mark (D56), contagion (D51), approx and exact (D52),
// which words keep exactness (D53) and the size limit (D55).
import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

Rational _q(int numerator, [int denominator = 1]) =>
    Rational(BigInt.from(numerator), BigInt.from(denominator));

Matrix _rpn(String program, {int? maxDigits}) => maxDigits == null
    ? Calculatrix.evaluateRpn(Calculatrix.tokenizeRpnLine(program))
    : Calculatrix.evaluateRpn(
        Calculatrix.tokenizeRpnLine(program),
        maxDigits: maxDigits,
      );

List<Matrix> _stack(String program) =>
    Calculatrix.evaluateRpnStack(Calculatrix.tokenizeRpnLine(program));

Matcher _exactScalar(Rational value) => isA<Matrix>()
    .having((Matrix m) => m.isExact, 'isExact', isTrue)
    .having((Matrix m) => m.isScalar, 'isScalar', isTrue)
    .having((Matrix m) => m.exactAt(0, 0), 'value', value);

Matcher _approximateScalar(double value) => isA<Matrix>()
    .having((Matrix m) => m.isExact, 'isExact', isFalse)
    .having((Matrix m) => m.scalarValue, 'value', value);

Matcher _exactRows(List<List<Rational>> rows) => isA<Matrix>()
    .having((Matrix m) => m.isExact, 'isExact', isTrue)
    .having((Matrix m) => m.exactRows, 'rows', rows);

Matcher _errorId(CalculatrixErrorId id) => throwsA(
  isA<CalculatrixError>().having(
    (CalculatrixError error) => error.errorId,
    'errorId',
    id,
  ),
);

void main() {
  group('exact literals (D50)', () {
    test('a decimal literal is the rational it spells', () {
      expect(_rpn('0.1'), _exactScalar(_q(1, 10)));
      expect(_rpn('-2.5e1'), _exactScalar(_q(-25)));
      expect(_rpn('0.1 0.2 +'), _exactScalar(_q(3, 10)));
    });

    test('a literal out of the double range is still exact', () {
      final Matrix value = _rpn('1e400');
      expect(value.isExact, isTrue);
      expect(value.exactAt(0, 0).digits, 401);
      expect(_rpn('1e400 1e400 /'), _exactScalar(Rational.one));
    });

    test('a matrix literal is exact, in every accepted form', () {
      final Matcher expected = _exactRows([
        [_q(1), _q(1, 2)],
        [_q(-3), _q(0)],
      ]);
      expect(_rpn('[[1 0.5] [-3 0]]'), expected);
      expect(_rpn('[[1,0.5],[-3,0]]'), expected);
      expect(_rpn('[[1 .5][-3 0]]'), expected);
      expect(_rpn('-[[-1 -0.5] [3 0]]'), expected);
      expect(
        _rpn('[1 2 3]'),
        _exactRows([
          [_q(1), _q(2), _q(3)],
        ]),
      );
    });

    test('NaN and Infinity are non-finite literals', () {
      expect(() => _rpn('NaN'), _errorId(CalculatrixErrorId.nonFinite));
      expect(() => _rpn('-Infinity'), _errorId(CalculatrixErrorId.nonFinite));
      expect(() => _rpn('[[1 NaN]]'), _errorId(CalculatrixErrorId.nonFinite));
    });
  });

  group('the approximate mark (D56)', () {
    test('~ before a literal makes it approximate, sign included', () {
      expect(_rpn('~0.1'), _approximateScalar(0.1));
      expect(_rpn('~-0.1'), _approximateScalar(-0.1));
      expect(_rpn('~-0.1 0.1 +'), _approximateScalar(0));
    });

    test('~ on a matrix literal or on any entry marks the whole matrix', () {
      for (final String literal in ['~[[1 2]]', '[[1 ~2]]', '~-[[-1 -2]]']) {
        final Matrix value = _rpn(literal);
        expect(value.isExact, isFalse, reason: literal);
        expect(value.rows, [
          [1.0, 2.0],
        ], reason: literal);
      }
    });

    test('a sign before the mark is syntax-error showing the fixed form', () {
      expect(
        () => _rpn('-~0.1'),
        throwsA(
          isA<ExpressionSyntaxError>()
              .having(
                (e) => e.errorId,
                'errorId',
                CalculatrixErrorId.syntaxError,
              )
              .having((e) => e.message, 'message', contains('~-0.1')),
        ),
      );
      for (final String program in ['[[1 -~0.1]]', '~[[1 -~0.1]]']) {
        expect(
          () => _rpn(program),
          throwsA(
            isA<ExpressionSyntaxError>().having(
              (e) => e.message,
              'message',
              contains('~-0.1'),
            ),
          ),
          reason: program,
        );
      }
      expect(
        () => Calculatrix.evaluateInfix('2*-~0.1'),
        throwsA(
          isA<ExpressionSyntaxError>().having(
            (e) => e.message,
            'message',
            contains('~-0.1'),
          ),
        ),
      );
    });

    test('a bare ~ is syntax-error in infix', () {
      expect(
        () => Calculatrix.evaluateInfix('1+~x'),
        _errorId(CalculatrixErrorId.syntaxError),
      );
    });

    test('infix takes the mark before numbers and matrix literals', () {
      expect(
        Calculatrix.evaluateInfix('~0.1+0.2'),
        _approximateScalar(0.1 + 0.2),
      );
      expect(Calculatrix.evaluateInfix('1-~-0.5'), _approximateScalar(1.5));
      expect(Calculatrix.evaluateInfix('~[[1,2]]*2').isExact, isFalse);
      expect(Calculatrix.evaluateInfix('1/3+1/6'), _exactScalar(_q(1, 2)));
    });

    test('a marked matrix reads its entries as approximate, not exact', () {
      for (final String literal in ['~[[1e-20000 1]]', '[[1e-20000 ~1]]']) {
        final Matrix value = _rpn(literal);
        expect(value.isExact, isFalse, reason: literal);
        expect(value.rows, [
          [0.0, 1.0],
        ], reason: literal);
      }
    });

    test('a matrix literal nested too deep is syntax-error', () {
      expect(() => _rpn('[[[1]]]'), _errorId(CalculatrixErrorId.syntaxError));
      final String deep =
          '${List.filled(100000, '[').join()}1'
          '${List.filled(100000, ']').join()}';
      expect(() => _rpn(deep), _errorId(CalculatrixErrorId.syntaxError));
    });

    test('an approximate literal out of the double range is non-finite', () {
      expect(() => _rpn('~1e400'), _errorId(CalculatrixErrorId.nonFinite));
      expect(
        () => _rpn('[[~1 1e400]]'),
        _errorId(CalculatrixErrorId.nonFinite),
      );
    });
  });

  group('exact arithmetic and contagion (D51, D53)', () {
    test('+ - * / negate percent stay exact on exact operands', () {
      expect(_rpn('1 3 / 1 6 / +'), _exactScalar(_q(1, 2)));
      expect(_rpn('1 3 / 1 2 / -'), _exactScalar(_q(-1, 6)));
      expect(_rpn('2 3 / 9 *'), _exactScalar(_q(6)));
      expect(_rpn('1 7 /'), _exactScalar(_q(1, 7)));
      expect(_rpn('1 3 / negate'), _exactScalar(_q(-1, 3)));
      expect(_rpn('1 3 / %'), _exactScalar(_q(1, 300)));
    });

    test('matrix arithmetic is exact, with scalar promotion', () {
      expect(
        _rpn('[[1 2] [3 4]] [[5 6] [7 8]] *'),
        _exactRows([
          [_q(19), _q(22)],
          [_q(43), _q(50)],
        ]),
      );
      expect(
        _rpn('[[1 2] [3 4]] 3 /'),
        _exactRows([
          [_q(1, 3), _q(2, 3)],
          [_q(1), _q(4, 3)],
        ]),
      );
      expect(
        _rpn('[[0 -1] [1 0]] 3 +'),
        _exactRows([
          [_q(3), _q(-1)],
          [_q(1), _q(3)],
        ]),
      );
    });

    test('exact shapes fail with the same ids as approximate ones', () {
      expect(
        () => _rpn('[[1 2]] [[1 2]] *'),
        _errorId(CalculatrixErrorId.dimensionMismatch),
      );
      expect(
        () => _rpn('[[1 2]] [[1 2 3]] +'),
        _errorId(CalculatrixErrorId.dimensionMismatch),
      );
      expect(
        () => _rpn('1 [[1 2]] /'),
        _errorId(CalculatrixErrorId.typeMismatch),
      );
      expect(() => _rpn('1 0 /'), _errorId(CalculatrixErrorId.nonFinite));
    });

    test('one approximate operand makes the result approximate', () {
      expect(_rpn('~0.1 0.2 +'), _approximateScalar(0.1 + 0.2));
      expect(_rpn('1 ~3 /'), _approximateScalar(1 / 3));
      expect(_rpn('[[1 2]] ~2 *').isExact, isFalse);
    });

    test('a word not yet exact converts to approximate (D53)', () {
      expect(_rpn('4 sqrt').isExact, isFalse);
      expect(_rpn('[[1 2] [3 4]] eigenvalues').isExact, isFalse);
      expect(_rpn('[[1 2] [3 4]] frobenius-norm').isExact, isFalse);
    });
  });

  group('integer powers', () {
    test('an exact scalar takes any integer exponent exactly', () {
      expect(
        _rpn('3 40 ^').exactAt(0, 0).toDisplayString(),
        '12157665459056928801',
      );
      expect(_rpn('2 -10 ^'), _exactScalar(_q(1, 1024)));
      expect(_rpn('2 3 / -2 ^'), _exactScalar(_q(9, 4)));
      expect(_rpn('0 0 ^'), _exactScalar(Rational.one));
      expect(_rpn('-1 1000001 ^'), _exactScalar(_q(-1)));
    });

    test('0 to a negative power is non-finite', () {
      expect(() => _rpn('0 -1 ^'), _errorId(CalculatrixErrorId.nonFinite));
    });

    test('a square exact matrix takes a non-negative integer exactly', () {
      expect(
        _rpn('[[1 1] [1 0]] 10 ^'),
        _exactRows([
          [_q(89), _q(55)],
          [_q(55), _q(34)],
        ]),
      );
      expect(
        _rpn('[[1 2] [3 4]] 0 ^'),
        _exactRows([
          [_q(1), _q(0)],
          [_q(0), _q(1)],
        ]),
      );
    });

    test('fractional powers are approximate', () {
      expect(_rpn('4 1 2 / ^').isExact, isFalse);
      expect(_rpn('2 ~3 ^'), _approximateScalar(8));
    });
  });

  group('approx, num and exact (D52)', () {
    test('approx and num convert to approximate', () {
      expect(_rpn('1 3 / approx'), _approximateScalar(1 / 3));
      expect(_rpn('1 4 / num'), _approximateScalar(0.25));
      expect(_rpn('1e-400 approx'), _approximateScalar(0));
    });

    test('approx of an exact value too large for a double is non-finite', () {
      expect(
        () => _rpn('1e400 approx'),
        _errorId(CalculatrixErrorId.nonFinite),
      );
    });

    test('exact gives the simplest rational that rounds to the double', () {
      expect(_rpn('~0.1 exact'), _exactScalar(_q(1, 10)));
      expect(_rpn('1 3 / approx exact'), _exactScalar(_q(1, 3)));
      expect(
        _rpn('~[[0.5 0.25]] exact'),
        _exactRows([
          [_q(1, 2), _q(1, 4)],
        ]),
      );
      expect(_rpn('1 3 / exact'), _exactScalar(_q(1, 3)));
    });

    test('exact is held to the digit limit', () {
      expect(
        () => _rpn('~10 exact', maxDigits: 1),
        throwsA(
          isA<LimitExceededError>()
              .having((e) => e.limit, 'limit', 1)
              .having((e) => e.estimated, 'estimated', 2),
        ),
      );
      expect(_rpn('~9 exact', maxDigits: 1), _exactScalar(_q(9)));
    });
  });

  group('stack and structure words keep exactness (D53)', () {
    test('stack words', () {
      final List<Matrix> stack = _stack('1 3 / ~2 swap dup');
      expect(stack.map((Matrix m) => m.isExact), [false, true, true]);
      expect(_stack('1 3 / 5 2 pick').last, _exactScalar(_q(1, 3)));
      expect(_stack('1 3 / 5 7 3 roll').last, _exactScalar(_q(1, 3)));
    });

    test('structure words', () {
      expect(_rpn('[[1 2] [3 4]] transpose').isExact, isTrue);
      expect(_rpn('1 2 3 3 vector').isExact, isTrue);
      expect(_rpn('1 ~2 2 vector').isExact, isFalse);
      expect(_rpn('[[1 2]] [[3 4]] append-rows').isExact, isTrue);
      expect(_rpn('[[1 2] [3 4]] 1 delete-row').isExact, isTrue);
      expect(_rpn('[[1 2] [3 4]] 1 2 move-col').isExact, isTrue);
      expect(
        _stack('[[1 2] [3 4]] rows').every((Matrix m) => m.isExact),
        isTrue,
      );
    });

    test(
      'zeros, ones and identity are exact, even with an approximate size',
      () {
        expect(
          _rpn('~2 3 zeros'),
          _exactRows([
            [_q(0), _q(0), _q(0)],
            [_q(0), _q(0), _q(0)],
          ]),
        );
        expect(_rpn('1 2 ones').isExact, isTrue);
        expect(_rpn('2 identity').isExact, isTrue);
      },
    );

    test('a count that is not a whole number names its exact value', () {
      expect(
        () => _rpn('1 2 / 3 zeros'),
        throwsA(
          isA<CalculatrixError>().having(
            (CalculatrixError e) => e.message,
            'message',
            'zeros requires a non-negative integer count, found 0.5.',
          ),
        ),
      );
      expect(
        () => _rpn('~-1 3 zeros'),
        throwsA(
          isA<CalculatrixError>().having(
            (CalculatrixError e) => e.message,
            'message',
            'zeros requires a non-negative integer count, found ~-1.0.',
          ),
        ),
      );
    });
  });

  group('size limit (D55)', () {
    test('a power over the limit raises limit-exceeded before computing', () {
      expect(
        () => _rpn('3 1000000 ^'),
        throwsA(
          isA<LimitExceededError>()
              .having(
                (e) => e.errorId,
                'errorId',
                CalculatrixErrorId.limitExceeded,
              )
              .having((e) => e.limit, 'limit', 10000)
              .having((e) => e.estimated, 'estimated', 477122)
              .having((e) => e.token, 'token', '^')
              .having(
                (e) => e.message,
                'message',
                '3^1000000 has about 477122 digits, over the limit of 10000.',
              ),
        ),
      );
    });

    test('a non-integer base names itself in parentheses', () {
      expect(
        () => _rpn('1 3 / 100000 ^'),
        throwsA(
          isA<LimitExceededError>().having(
            (e) => e.message,
            'message',
            startsWith('(1/3)^100000 has about'),
          ),
        ),
      );
    });

    test('a huge exponent of 1, -1 or 0 is not over the limit', () {
      expect(_rpn('1 1e100 ^'), _exactScalar(Rational.one));
      expect(_rpn('-1 1e100 ^'), _exactScalar(Rational.one));
      expect(_rpn('0 1e100 ^'), _exactScalar(Rational.zero));
    });

    test('a product over the limit raises limit-exceeded', () {
      expect(
        () => _rpn('1e6000 1e6000 *'),
        _errorId(CalculatrixErrorId.limitExceeded),
      );
    });

    test('a matrix power over the limit raises limit-exceeded', () {
      expect(
        () => _rpn('[[1 1] [1 0]] 100000 ^'),
        _errorId(CalculatrixErrorId.limitExceeded),
      );
    });

    test('a literal over the limit raises limit-exceeded', () {
      expect(
        () => _rpn('1e20000'),
        throwsA(
          isA<LimitExceededError>()
              .having((e) => e.estimated, 'estimated', 20001)
              .having((e) => e.token, 'token', '1e20000')
              .having((e) => e.position, 'position', 1),
        ),
      );
    });

    test('a huge literal reports its digit count, not a clamped one', () {
      expect(
        () => _rpn('1e1000000000000000000'),
        throwsA(
          isA<LimitExceededError>().having(
            (e) => e.estimated,
            'estimated',
            1000000000000000001,
          ),
        ),
      );
    });

    test('maxDigits moves the limit', () {
      expect(_rpn('10 20 ^', maxDigits: 21).exactAt(0, 0).digits, 21);
      expect(
        () => _rpn('10 21 ^', maxDigits: 21),
        _errorId(CalculatrixErrorId.limitExceeded),
      );
      expect(
        () => Calculatrix.evaluateInfix('10^6', maxDigits: 5),
        _errorId(CalculatrixErrorId.limitExceeded),
      );
    });

    test('an approximate route has no digit limit', () {
      expect(_rpn('3 ~100 ^').isExact, isFalse);
      expect(_rpn('~1e300 1e300 /'), _approximateScalar(1));
    });
  });

  group('evaluateInfix approximate option', () {
    test(
      'converts the result for callers that only take approximate values',
      () {
        expect(
          Calculatrix.evaluateInfix('1/3', approximate: true),
          _approximateScalar(1 / 3),
        );
      },
    );
  });
}
