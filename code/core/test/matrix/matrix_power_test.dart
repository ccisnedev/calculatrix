import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Matrix.power - table D25', () {
    test('row 1: scalar negative base, non-integer scalar exponent is complex', () {
      final Matrix result = Matrix.scalar(-4).power(Matrix.scalar(0.5));

      expect(result.isComplexForm, isTrue);
      expect(result.realPart, closeTo(0, 1e-4));
      expect(result.imagPart, closeTo(2, 1e-4));
    });

    test('row 2: scalar positive base, square matrix exponent', () {
      final Matrix y = Matrix.complex(0, math.pi); // pi*i
      final Matrix result = Matrix.scalar(math.e).power(y);

      expect(result.at(0, 0), closeTo(-1, 1e-4));
      expect(result.at(0, 1), closeTo(0, 1e-4));
      expect(result.at(1, 0), closeTo(0, 1e-4));
      expect(result.at(1, 1), closeTo(-1, 1e-4));
    });

    test('row 3: complex base, complex exponent', () {
      final Matrix result = Matrix.i.power(Matrix.i);
      final double expected = math.exp(-math.pi / 2);

      expect(result.at(0, 0), closeTo(expected, 1e-4));
      expect(result.at(0, 1), closeTo(0, 1e-4));
      expect(result.at(1, 0), closeTo(0, 1e-4));
      expect(result.at(1, 1), closeTo(expected, 1e-4));
    });

    test('row 4: square base, positive integer exponent via repeated multiplication', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 1],
        <double>[0, 1],
      ]);
      final Matrix result = base.power(Matrix.scalar(3));

      expect(
        result.almostEquals(
          Matrix(<List<double>>[
            <double>[1, 3],
            <double>[0, 1],
          ]),
        ),
        isTrue,
      );
    });

    test('row 4b: square base, negative integer exponent uses the inverse', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[2, 0],
        <double>[0, 4],
      ]);
      final Matrix result = base.power(Matrix.scalar(-1));

      expect(
        result.almostEquals(
          Matrix(<List<double>>[
            <double>[0.5, 0],
            <double>[0, 0.25],
          ]),
        ),
        isTrue,
      );
    });

    test('row 4c: negative integer exponent on a singular matrix is singular-matrix', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[2, 4],
      ]);

      expect(
        () => base.power(Matrix.scalar(-2)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.singularMatrix,
          ),
        ),
      );
    });

    test('row 5: square base, non-integer scalar exponent uses principal log', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[2, 0],
        <double>[0, 3],
      ]);
      final Matrix result = base.power(Matrix.scalar(0.5));

      expect(result.at(0, 0), closeTo(math.sqrt(2), 5e-5));
      expect(result.at(0, 1), closeTo(0, 5e-5));
      expect(result.at(1, 0), closeTo(0, 5e-5));
      expect(result.at(1, 1), closeTo(math.sqrt(3), 5e-5));
    });

    test(
      'row 5b (owner-added): defective square base, non-integer scalar exponent',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[1, 1],
          <double>[0, 1],
        ]);
        final Matrix result = base.power(Matrix.scalar(0.5));

        expect(
          result.almostEquals(
            Matrix(<List<double>>[
              <double>[1, 0.5],
              <double>[0, 1],
            ]),
            absoluteTolerance: 5e-5,
          ),
          isTrue,
        );
      },
    );

    test('row 6: square base and square exponent that do not commute is ambiguous-power', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 1],
        <double>[0, 1],
      ]);
      final Matrix y = Matrix(<List<double>>[
        <double>[0, 1],
        <double>[1, 0],
      ]);

      expect(
        () => base.power(y),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.ambiguousPower,
          ),
        ),
      );
    });

    test('row 7: zero base, positive scalar exponent is zero', () {
      final Matrix result = Matrix.scalar(0).power(Matrix.scalar(5));
      expect(result, Matrix.scalar(0));
    });

    test('row 7b: zero base, zero exponent is one', () {
      final Matrix result = Matrix.scalar(0).power(Matrix.scalar(0));
      expect(result, Matrix.scalar(1));
    });

    test('row 7c: zero base, negative exponent is non-finite', () {
      expect(
        () => Matrix.scalar(0).power(Matrix.scalar(-1)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.nonFinite,
          ),
        ),
      );
    });

    test('row 8: zero base with a matrix exponent needs log 0, which is undefined', () {
      final Matrix y = Matrix.complex(0, math.pi);

      expect(
        () => Matrix.scalar(0).power(y),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.logUndefined,
          ),
        ),
      );
    });

    test('row 9: non-square base is a dimension-mismatch', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
      ]);

      expect(
        () => base.power(Matrix.scalar(2)),
        throwsA(
          isA<MatrixShapeError>().having(
            (MatrixShapeError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });

    test('row 10: scalar base with a non-square exponent is a dimension-mismatch', () {
      final Matrix y = Matrix(<List<double>>[
        <double>[1, 2],
      ]);

      expect(
        () => Matrix.scalar(2).power(y),
        throwsA(
          isA<MatrixShapeError>().having(
            (MatrixShapeError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });

    test('row 11: square base and square exponent of different sizes is a dimension-mismatch', () {
      final Matrix base = Matrix.identity(2);
      final Matrix y = Matrix.identity(3);

      expect(
        () => base.power(y),
        throwsA(
          isA<MatrixShapeError>().having(
            (MatrixShapeError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });

    test('row 12: negative scalar base and a non-commuting square exponent is ambiguous-power', () {
      final Matrix y = Matrix(<List<double>>[
        <double>[1, 0],
        <double>[0, 2],
      ]);

      expect(
        () => Matrix.scalar(-2).power(y),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.ambiguousPower,
          ),
        ),
      );
    });

    test('row 13: scalar overflow is non-finite', () {
      expect(
        () => Matrix.scalar(10).power(Matrix.scalar(400)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.nonFinite,
          ),
        ),
      );
    });
  });

  group('Matrix.power - owner decisions D34', () {
    test(
      'square non-scalar base with a non-square exponent is dimension-mismatch, for any base',
      () {
        final Matrix base = Matrix.identity(2);
        final Matrix y = Matrix(<List<double>>[
          <double>[1, 2],
        ]);

        expect(
          () => base.power(y),
          throwsA(
            isA<MatrixShapeError>().having(
              (MatrixShapeError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.dimensionMismatch,
            ),
          ),
        );
      },
    );

    test(
      'complex base with a square non-complex non-scalar exponent is ambiguous-power',
      () {
        final Matrix y = Matrix(<List<double>>[
          <double>[1, 0],
          <double>[0, 2],
        ]);

        expect(
          () => Matrix.i.power(y),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.ambiguousPower,
            ),
          ),
        );
      },
    );

    test(
      'non-complex-form base with a non-positive real eigenvalue and a non-integer exponent is log-undefined',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[-1, 0],
          <double>[0, 2],
        ]);

        expect(
          () => base.power(Matrix.scalar(0.5)),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.logUndefined,
            ),
          ),
        );
      },
    );

    test(
      'non-complex-form base with a complex-conjugate eigenvalue pair and a '
      'non-integer exponent is well-defined',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[1, -2],
          <double>[0.5, 1],
        ]);

        final Matrix half = base.power(Matrix.scalar(0.5));
        final Matrix squared = half.power(Matrix.scalar(2));

        expect(squared.almostEquals(base, absoluteTolerance: 1e-9), isTrue);
      },
    );

    test(
      'non-complex-form base with a complex-conjugate eigenvalue pair and a '
      'non-positive real eigenvalue is log-undefined',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[0, -1, 0],
          <double>[1, 0, 0],
          <double>[0, 0, -2],
        ]);

        expect(
          () => base.power(Matrix.scalar(0.5)),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.logUndefined,
            ),
          ),
        );
      },
    );
  });
}
