// Tests for Matrix.power / the '^' operator, covering the D25 dispatch
// table from issue #5 (spec section 3: B^Y = exp(Y * log B), principal
// log/exp), row by row, plus the "X exp == e X ^" identity the issue
// requires. Expected values are rounded to 4 decimals, as in the issue.

import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Matrix.power (D25 dispatch table, issue #5)', () {
    test('row 1: scalar^scalar, negative base and non-integer exponent gives the complex principal value', () {
      // -4 0.5 ^ -> [[0 -2] [2 0]]
      final Matrix result = Matrix.scalar(-4).power(Matrix.scalar(0.5));
      expect(result.almostEquals(Matrix.complex(0, 2)), isTrue);
    });

    test('row 2: scalar>0 ^ square matrix uses exp(ln B * Y)', () {
      // e πi ^ -> [[-1 0] [0 -1]]
      final Matrix result = Matrix.scalar(math.e).power(
        Matrix.complex(0, math.pi),
      );
      expect(
        result.almostEquals(
          Matrix(<List<double>>[
            <double>[-1, 0],
            <double>[0, -1],
          ]),
          absoluteTolerance: 1e-6,
        ),
        isTrue,
      );
    });

    test('row 3: complex (or scalar<0) ^ complex uses exp(Y * log B)', () {
      // i i ^ -> [[0.2079 0] [0 0.2079]]
      final Matrix result = Matrix.complex(0, 1).power(Matrix.complex(0, 1));
      expect(
        result.almostEquals(
          Matrix(<List<double>>[
            <double>[0.2079, 0],
            <double>[0, 0.2079],
          ]),
          absoluteTolerance: 1e-4,
        ),
        isTrue,
      );
    });

    test('row 4: square ^ integer scalar uses repeated multiplication', () {
      // [[1 1] [0 1]] 3 ^ -> [[1 3] [0 1]]
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 1],
        <double>[0, 1],
      ]);
      final Matrix result = base.power(Matrix.scalar(3));
      expect(
        result,
        Matrix(<List<double>>[
          <double>[1, 3],
          <double>[0, 1],
        ]),
      );
    });

    test('row 4: negative integer scalar exponent uses the inverse', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 1],
        <double>[0, 1],
      ]);
      final Matrix result = base.power(Matrix.scalar(-1));
      expect(
        result,
        Matrix(<List<double>>[
          <double>[1, -1],
          <double>[0, 1],
        ]),
      );
    });

    test('row 4: singular base with a negative integer exponent is singular-matrix', () {
      final Matrix singular = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[2, 4],
      ]);
      expect(
        () => singular.power(Matrix.scalar(-1)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.singularMatrix,
          ),
        ),
      );
    });

    test('row 5: square ^ non-integer scalar uses exp(y * log B)', () {
      // [[2 0] [0 3]] 0.5 ^ -> [[1.414 0] [0 1.732]]
      final Matrix base = Matrix(<List<double>>[
        <double>[2, 0],
        <double>[0, 3],
      ]);
      final Matrix result = base.power(Matrix.scalar(0.5));
      expect(
        result.almostEquals(
          Matrix(<List<double>>[
            <double>[1.4142, 0],
            <double>[0, 1.7320],
          ]),
          absoluteTolerance: 1e-4,
        ),
        isTrue,
      );
    });

    test('row 6: square (not complex, not scalar) ^ square (not scalar) is ambiguous-power', () {
      // [[1 1] [0 1]] [[0 1] [1 0]] ^
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 1],
        <double>[0, 1],
      ]);
      final Matrix exponent = Matrix(<List<double>>[
        <double>[0, 1],
        <double>[1, 0],
      ]);
      expect(
        () => base.power(exponent),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.ambiguousPower,
          ),
        ),
      );
    });

    test('row 7: 0 ^ positive scalar is 0', () {
      final Matrix result = Matrix.scalar(0).power(Matrix.scalar(1));
      expect(result, Matrix.scalar(0));
    });

    test('row 7: 0 ^ 0 is 1', () {
      final Matrix result = Matrix.scalar(0).power(Matrix.scalar(0));
      expect(result, Matrix.scalar(1));
    });

    test('row 7: 0 ^ negative scalar is non-finite', () {
      // 0 -1 ^
      expect(
        () => Matrix.scalar(0).power(Matrix.scalar(-1)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.nonFinite,
          ),
        ),
      );
    });

    test('row 8: 0 ^ matrix exponent requires log(0), which is log-undefined', () {
      // 0 πi ^
      expect(
        () => Matrix.scalar(0).power(Matrix.complex(0, math.pi)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.logUndefined,
          ),
        ),
      );
    });

    test('row 9: non-square base ^ anything is dimension-mismatch', () {
      // [[1 2]] 2 ^
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
      ]);
      expect(
        () => base.power(Matrix.scalar(2)),
        throwsA(
          isA<MatrixShapeError>().having(
            (MatrixShapeError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });

    test('row 10: scalar ^ non-square exponent is dimension-mismatch', () {
      // 2 [[1 2]] ^
      final Matrix exponent = Matrix(<List<double>>[
        <double>[1, 2],
      ]);
      expect(
        () => Matrix.scalar(2).power(exponent),
        throwsA(
          isA<MatrixShapeError>().having(
            (MatrixShapeError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });

    test('row 11: n x n ^ m x m with n != m is dimension-mismatch', () {
      // [[1 0] [0 1]] [[1 0 0] [0 1 0] [0 0 1]] ^
      final Matrix base = Matrix.identity(2);
      final Matrix exponent = Matrix.identity(3);
      expect(
        () => base.power(exponent),
        throwsA(
          isA<MatrixShapeError>().having(
            (MatrixShapeError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });

    test('row 12: scalar<0 ^ square (not complex, not scalar) is ambiguous-power', () {
      // -2 [[1 0] [0 2]] ^
      final Matrix exponent = Matrix(<List<double>>[
        <double>[1, 0],
        <double>[0, 2],
      ]);
      expect(
        () => Matrix.scalar(-2).power(exponent),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.ambiguousPower,
          ),
        ),
      );
    });

    test('row 13: any ^ any that overflows is non-finite', () {
      // 10 400 ^
      expect(
        () => Matrix.scalar(10).power(Matrix.scalar(400)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.nonFinite,
          ),
        ),
      );
    });

    test('integer power by binary exponentiation does not hang for huge exponents', () {
      // A real fix for a hang at exponents like -2^63: the identity matrix
      // raised to an extreme integer power must resolve immediately instead
      // of looping once per unit of the exponent's magnitude.
      final Matrix identity = Matrix.identity(2);
      expect(identity.power(Matrix.scalar(9223372036854775807)), identity);
      expect(identity.power(Matrix.scalar(-9223372036854775807)), identity);
    });

    test('X exp equals e X ^ for a sample of matrices', () {
      final List<Matrix> samples = <Matrix>[
        Matrix(<List<double>>[
          <double>[0, 1],
          <double>[-1, 0],
        ]),
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
        ]),
        Matrix.complex(0.5, -1.5),
      ];

      for (final Matrix sample in samples) {
        final Matrix viaExp = sample.exp();
        final Matrix viaPower = Matrix.scalar(math.e).power(sample);
        expect(viaExp.almostEquals(viaPower, absoluteTolerance: 1e-6), isTrue);
      }
    });
  });
}
