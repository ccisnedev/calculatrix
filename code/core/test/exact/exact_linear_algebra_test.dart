// Exact linear algebra in core (runbook-trust.md, step T3): `inverse`,
// `determinant`, `rref`, `rank`, `trace`, `adjugate`, `cofactors`, `lu`,
// `dot`, `cross` and negative matrix powers on exact values (D53), and the
// Hadamard estimate of the size limit (D55). Giac checks the same words on
// generated inputs in giac_differential_test.dart.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

Rational _q(int numerator, [int denominator = 1]) =>
    Rational(BigInt.from(numerator), BigInt.from(denominator));

List<List<Rational>> _ints(List<List<int>> rows) =>
    rows.map((List<int> row) => row.map((int v) => _q(v)).toList()).toList();

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
  group('inverse and negative powers', () {
    test('the inverse of the 4x4 Hilbert matrix is an integer matrix', () {
      final List<List<Rational>> hilbert = List<List<Rational>>.generate(
        4,
        (int r) => List<Rational>.generate(4, (int c) => _q(1, r + c + 1)),
      );
      final Matrix inverse = const ExactArithmetic().inverse(
        Matrix.exact(hilbert),
      );
      expect(
        inverse,
        _exactRows(
          _ints(<List<int>>[
            <int>[16, -120, 240, -140],
            <int>[-120, 1200, -2700, 1680],
            <int>[240, -2700, 6480, -4200],
            <int>[-140, 1680, -4200, 2800],
          ]),
        ),
      );
    });

    test('inverse, -1 ^ and -2 ^ on an exact matrix', () {
      final List<List<Rational>> inverse = <List<Rational>>[
        <Rational>[_q(-2), _q(1)],
        <Rational>[_q(3, 2), _q(-1, 2)],
      ];
      expect(_rpn('[[1 2] [3 4]] inverse'), _exactRows(inverse));
      expect(_rpn('[[1 2] [3 4]] -1 ^'), _exactRows(inverse));
      expect(
        _rpn('[[1 2] [3 4]] -2 ^'),
        _exactRows(<List<Rational>>[
          <Rational>[_q(11, 2), _q(-5, 2)],
          <Rational>[_q(-15, 4), _q(7, 4)],
        ]),
      );
      expect(
        _rpn('[[1 2] [3 4]] -1 ^ [[1 2] [3 4]] *'),
        _exactRows(
          _ints(<List<int>>[
            <int>[1, 0],
            <int>[0, 1],
          ]),
        ),
      );
    });

    test('a row swap is needed when the first pivot is zero', () {
      expect(
        _rpn('[[0 1] [1 0]] inverse'),
        _exactRows(
          _ints(<List<int>>[
            <int>[0, 1],
            <int>[1, 0],
          ]),
        ),
      );
    });

    test('an exact singular matrix is singular-matrix, with no tolerance', () {
      expect(
        () => _rpn('[[1 2] [2 4]] inverse'),
        _errorId(CalculatrixErrorId.singularMatrix),
      );
      expect(
        () => _rpn('[[1 2] [2 4]] -1 ^'),
        _errorId(CalculatrixErrorId.singularMatrix),
      );
      // A 1x1 inverse is the scalar -1 power, as for approximate values.
      expect(
        () => _rpn('[[0]] inverse'),
        _errorId(CalculatrixErrorId.nonFinite),
      );
      // Nearly singular is still invertible when it is exact.
      expect(
        _rpn('[[1 1] [1 1.0000000000000000001]] inverse'),
        _exactRows(<List<Rational>>[
          <Rational>[
            Rational(BigInt.parse('10000000000000000001')),
            Rational(BigInt.parse('-10000000000000000000')),
          ],
          <Rational>[
            Rational(BigInt.parse('-10000000000000000000')),
            Rational(BigInt.parse('10000000000000000000')),
          ],
        ]),
      );
    });
  });

  group('determinant, trace and rank', () {
    test('exact results', () {
      expect(_rpn('[[1 2] [3 4]] determinant'), _exactScalar(_q(-2)));
      expect(_rpn('[[1 2] [3 4]] 3 / determinant'), _exactScalar(_q(-2, 9)));
      expect(_rpn('[[0 1] [1 0]] determinant'), _exactScalar(_q(-1)));
      expect(_rpn('[[1 2] [2 4]] determinant'), _exactScalar(Rational.zero));
      expect(_rpn('7 3 / determinant'), _exactScalar(_q(7, 3)));
      expect(
        _rpn('[[1 2 3] [4 5 6] [7 8 10]] determinant'),
        _exactScalar(_q(-3)),
      );
      expect(
        _rpn('[[1 2 3] [4 5 6] [7 8 10]] 1 2 / * trace'),
        _exactScalar(_q(8)),
      );
      expect(_rpn('[[1 2] [2 4]] rank'), _exactScalar(_q(1)));
      expect(_rpn('[[1 2 3] [2 4 7]] rank'), _exactScalar(_q(2)));
      expect(_rpn('[[0 0] [0 0]] rank'), _exactScalar(Rational.zero));
    });

    test('a tiny exact difference counts', () {
      expect(
        _rpn('[[1 1] [1 1.0000000000000000001]] determinant'),
        _exactScalar(Rational(BigInt.one, BigInt.from(10).pow(19))),
      );
      expect(
        _rpn('[[1 1] [1 1.0000000000000000001]] rank'),
        _exactScalar(_q(2)),
      );
      // The same matrix approximately is rank 1: the double of the last
      // entry is 1.
      expect(
        _rpn('~[[1 1] [1 1.0000000000000000001]] rank'),
        isA<Matrix>()
            .having((Matrix m) => m.isExact, 'isExact', isFalse)
            .having((Matrix m) => m.scalarValue, 'value', 1),
      );
    });
  });

  group('rref', () {
    test('any shape, with zero rows at the bottom', () {
      expect(
        _rpn('[[1 2] [2 4]] rref'),
        _exactRows(
          _ints(<List<int>>[
            <int>[1, 2],
            <int>[0, 0],
          ]),
        ),
      );
      expect(
        _rpn('[[1 2 3] [2 4 7]] 3 / rref'),
        _exactRows(
          _ints(<List<int>>[
            <int>[1, 2, 0],
            <int>[0, 0, 1],
          ]),
        ),
      );
      expect(
        _rpn('[[0 2] [3 0] [1 1]] rref'),
        _exactRows(
          _ints(<List<int>>[
            <int>[1, 0],
            <int>[0, 1],
            <int>[0, 0],
          ]),
        ),
      );
      expect(
        _rpn('[[2 1 1] [4 3 3]] rref'),
        _exactRows(<List<Rational>>[
          <Rational>[_q(1), Rational.zero, Rational.zero],
          <Rational>[Rational.zero, _q(1), _q(1)],
        ]),
      );
    });
  });

  group('cofactors and adjugate', () {
    test('a nonsingular matrix', () {
      expect(
        _rpn('[[1 2] [3 4]] cofactors'),
        _exactRows(
          _ints(<List<int>>[
            <int>[4, -3],
            <int>[-2, 1],
          ]),
        ),
      );
      expect(
        _rpn('[[1 2] [3 4]] adjugate'),
        _exactRows(
          _ints(<List<int>>[
            <int>[4, -2],
            <int>[-3, 1],
          ]),
        ),
      );
      expect(
        _rpn('[[1 2 3] [4 5 6] [7 8 10]] cofactors'),
        _exactRows(
          _ints(<List<int>>[
            <int>[2, 2, -3],
            <int>[4, -11, 6],
            <int>[-3, 6, -3],
          ]),
        ),
      );
      expect(
        _rpn('[[0 1] [1 0]] 2 / adjugate'),
        _exactRows(<List<Rational>>[
          <Rational>[Rational.zero, _q(-1, 2)],
          <Rational>[_q(-1, 2), Rational.zero],
        ]),
      );
    });

    test('singular matrices of rank n - 1 and below', () {
      expect(
        _rpn('[[1 2] [2 4]] cofactors'),
        _exactRows(
          _ints(<List<int>>[
            <int>[4, -2],
            <int>[-2, 1],
          ]),
        ),
      );
      expect(
        _rpn('[[1 2 3] [4 5 6] [5 7 9]] adjugate'),
        _exactRows(
          _ints(<List<int>>[
            <int>[3, 3, -3],
            <int>[-6, -6, 6],
            <int>[3, 3, -3],
          ]),
        ),
      );
      expect(
        _rpn('[[1 1 1] [1 1 1] [1 1 1]] cofactors'),
        _exactRows(
          _ints(<List<int>>[
            <int>[0, 0, 0],
            <int>[0, 0, 0],
            <int>[0, 0, 0],
          ]),
        ),
      );
    });

    test('a 1x1 matrix fails as the approximate word does', () {
      expect(
        () => _rpn('5 cofactors'),
        _errorId(CalculatrixErrorId.dimensionMismatch),
      );
      expect(
        () => _rpn('~5 cofactors'),
        _errorId(CalculatrixErrorId.dimensionMismatch),
      );
    });
  });

  group('lu', () {
    test('the pivot is the entry of largest magnitude, as approximate', () {
      final List<Matrix> stack = _stack('[[1 2] [3 4]] lu');
      expect(stack, hasLength(3));
      expect(
        stack[0],
        _exactRows(
          _ints(<List<int>>[
            <int>[0, 1],
            <int>[1, 0],
          ]),
        ),
      );
      expect(
        stack[1],
        _exactRows(<List<Rational>>[
          <Rational>[_q(1), _q(0)],
          <Rational>[_q(1, 3), _q(1)],
        ]),
      );
      expect(
        stack[2],
        _exactRows(<List<Rational>>[
          <Rational>[_q(3), _q(4)],
          <Rational>[_q(0), _q(2, 3)],
        ]),
      );
      // The same P as the approximate decomposition.
      expect(
        _stack('~[[1 2] [3 4]] lu')[0].rows,
        stack[0].toApproximate().rows,
      );

      final List<Matrix> swapped = _stack('[[0 1] [1 1]] lu');
      expect(
        swapped[0],
        _exactRows(
          _ints(<List<int>>[
            <int>[0, 1],
            <int>[1, 0],
          ]),
        ),
      );
      expect(
        swapped[2],
        _exactRows(
          _ints(<List<int>>[
            <int>[1, 1],
            <int>[0, 1],
          ]),
        ),
      );
    });

    test(
      'P A = L U holds exactly on generated matrices, singular ones too',
      () {
        final math.Random random = math.Random(3);
        for (int i = 0; i < 60; i++) {
          final int size = random.nextInt(4) + 1;
          final List<List<Rational>> rows = List<List<Rational>>.generate(
            size,
            (_) => List<Rational>.generate(
              size,
              (_) => random.nextInt(3) == 0
                  ? Rational.zero
                  : _q(random.nextInt(19) - 9, random.nextInt(4) + 1),
            ),
          );
          if (i.isOdd && size > 1) {
            // Make it singular: the last row repeats the first.
            rows[size - 1] = List<Rational>.of(rows[0]);
          }
          final Matrix a = Matrix.exact(rows);
          final LuDecomposition lu = const ExactArithmetic().lu(a);
          const ExactArithmetic exact = ExactArithmetic();
          expect(
            exact.multiply(lu.permutation, a),
            _exactRows(exact.multiply(lu.lower, lu.upper).exactRows),
            reason: '$rows',
          );
          if (i.isEven) {
            // The same P as the approximate decomposition.
            expect(
              lu.permutation.toApproximate(),
              a.toApproximate().luDecomposition().permutation,
              reason: '$rows',
            );
          }
          for (int r = 0; r < size; r++) {
            expect(lu.lower.exactAt(r, r), Rational.one);
            for (int c = r + 1; c < size; c++) {
              expect(lu.lower.exactAt(r, c), Rational.zero);
              expect(lu.upper.exactAt(c, r), Rational.zero);
            }
          }
        }
      },
    );
  });

  group('dot and cross', () {
    test('exact on exact vectors', () {
      expect(
        _rpn('[[1] [2] [3]] 5 / [[4] [5] [6]] 7 / dot'),
        _exactScalar(_q(32, 35)),
      );
      expect(
        _rpn('[[1] [2] [3]] 5 / [[4] [5] [6]] cross'),
        _exactRows(<List<Rational>>[
          <Rational>[_q(-3, 5)],
          <Rational>[_q(6, 5)],
          <Rational>[_q(-3, 5)],
        ]),
      );
    });

    test('one approximate vector makes the result approximate (D51)', () {
      expect(_rpn('[[1] [2]] ~[[3] [4]] dot').isExact, isFalse);
      expect(_rpn('~[[1] [2] [3]] [[4] [5] [6]] cross').isExact, isFalse);
    });
  });

  group('errors match the approximate words', () {
    for (final String program in <String>[
      '[[1 2 3] [4 5 6]] inverse',
      '[[1 2 3] [4 5 6]] determinant',
      '[[1 2 3] [4 5 6]] trace',
      '[[1 2 3] [4 5 6]] cofactors',
      '[[1 2 3] [4 5 6]] adjugate',
      '[[1 2 3] [4 5 6]] lu',
      '[[1 2]] [[1] [2]] dot',
      '[[1] [2]] [[1] [2] [3]] dot',
      '[[1] [2]] [[1] [2]] cross',
    ]) {
      test(program, () {
        CalculatrixError? exactError;
        CalculatrixError? approximateError;
        try {
          _rpn(program);
        } on CalculatrixError catch (error) {
          exactError = error;
        }
        try {
          _rpn(program.replaceAll('[[', '~[[').replaceAll('~~', '~'));
        } on CalculatrixError catch (error) {
          approximateError = error;
        }
        expect(exactError, isNotNull);
        expect(exactError!.errorId, approximateError!.errorId);
        expect(exactError.message, approximateError.message);
      });
    }
  });

  group('the size limit (D55)', () {
    test('a determinant over the limit fails before computing', () {
      expect(
        () => _rpn('[[1e30 1] [1 1e30]] determinant', maxDigits: 50),
        throwsA(
          isA<LimitExceededError>()
              .having((LimitExceededError e) => e.limit, 'limit', 50)
              .having((LimitExceededError e) => e.estimated, 'estimated', 61)
              .having(
                (LimitExceededError e) => e.message,
                'message',
                'The exact determinant could have up to 61 digits '
                    '(Hadamard bound), over the limit of 50.',
              ),
        ),
      );
      expect(
        _rpn('[[1e30 1] [1 1e30]] determinant', maxDigits: 61),
        _exactScalar(Rational(BigInt.from(10).pow(60) - BigInt.one)),
      );
    });

    test('every elimination word is held to the limit', () {
      for (final String word in <String>[
        'inverse',
        'rref',
        'rank',
        'cofactors',
        'adjugate',
        'lu',
        '-1 ^',
      ]) {
        expect(
          () => _rpn('[[1e30 1] [1 1e30]] $word', maxDigits: 40),
          _errorId(CalculatrixErrorId.limitExceeded),
          reason: word,
        );
      }
    });

    test('trace, dot and cross check their result', () {
      expect(
        () => _rpn('[[9e28 0] [0 9e28]] trace', maxDigits: 29),
        _errorId(CalculatrixErrorId.limitExceeded),
      );
      expect(
        () => _rpn('[[1e14] [1]] [[1e14] [1]] dot', maxDigits: 20),
        _errorId(CalculatrixErrorId.limitExceeded),
      );
    });

    test('a sum is checked after each term, even if it cancels later', () {
      // 1/7 + 1/9 = 16/63 is over a limit of 1 digit, as with `+`.
      final Matrix a = Matrix.exact(<List<Rational>>[
        <Rational>[_q(1, 7)],
        <Rational>[_q(1, 9)],
        <Rational>[_q(-1, 7)],
        <Rational>[_q(-1, 9)],
      ]);
      final Matrix ones = Matrix.exact(
        List<List<Rational>>.generate(4, (_) => <Rational>[_q(1)]),
      );
      const ExactArithmetic tight = ExactArithmetic(maxDigits: 1);
      expect(
        () => tight.dot(a, ones),
        _errorId(CalculatrixErrorId.limitExceeded),
      );
      expect(
        () => tight.trace(
          Matrix.exact(<List<Rational>>[
            <Rational>[_q(1, 7), _q(0), _q(0)],
            <Rational>[_q(0), _q(1, 9), _q(0)],
            <Rational>[_q(0), _q(0), _q(-1, 9)],
          ]),
        ),
        _errorId(CalculatrixErrorId.limitExceeded),
      );
    });

    test('a huge common denominator is refused before it is used', () {
      // lcm(1, ..., 3000) has about 1300 digits, though every entry is
      // small.
      final Matrix row = Matrix.exact(<List<Rational>>[
        List<Rational>.generate(3000, (int i) => _q(1, i + 1)),
      ]);
      expect(
        () => const ExactArithmetic(maxDigits: 100).rref(row),
        _errorId(CalculatrixErrorId.limitExceeded),
      );
    });

    test('rank checks its own digits', () {
      expect(
        () => const ExactArithmetic(maxDigits: 1).rank(
          Matrix.exact(
            _ints(
              List<List<int>>.generate(
                10,
                (int r) => List<int>.generate(10, (int c) => r == c ? 1 : 0),
              ),
            ),
          ),
        ),
        _errorId(CalculatrixErrorId.limitExceeded),
      );
    });
  });

  test('infix reaches the exact inverse through ^', () {
    expect(
      Calculatrix.evaluateInfix('[[1 2] [3 4]]^(-1)'),
      _exactRows(<List<Rational>>[
        <Rational>[_q(-2), _q(1)],
        <Rational>[_q(3, 2), _q(-1, 2)],
      ]),
    );
  });
}
