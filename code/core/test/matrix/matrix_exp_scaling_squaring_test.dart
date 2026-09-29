// Tests for issue #13 (Core: matrix exp is silently wrong for moderate
// norms). Before this fix, Matrix.exp() summed a Taylor series truncated at
// 50 terms with no scaling: for a matrix whose entries grow, the dropped
// terms are still large and the result is silently wrong (or, when it does
// not converge at all, wrong without even overflowing to signal the
// problem). The fix uses scaling and squaring: exp(A) = (exp(A / 2^s))^(2^s),
// choosing s so the series on A / 2^s converges to machine precision in a
// handful of terms.
//
// Expected values for finite cases were computed with Julia 1.12.7
// (`using LinearAlgebra; exp(A)`), printed at full double precision. Each
// test carries the exact Julia expression used.

import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group(
    'Matrix.exp - scaling and squaring (issue #13, acceptance 1 and 2)',
    () {
      test('a=10: [[10 0] [0 10]] exp matches Julia to 1e-12 relative', () {
        // Julia: A = [10.0 0.0; 0.0 10.0]; exp(A)
        // -> [22026.465794806718 0; 0 22026.465794806718]
        final Matrix a = Matrix(<List<double>>[
          <double>[10, 0],
          <double>[0, 10],
        ]);
        final Matrix result = a.exp();
        _expectRelativelyClose(result.at(0, 0), 22026.465794806718);
        _expectRelativelyClose(result.at(1, 1), 22026.465794806718);
        expect(result.at(0, 1), closeTo(0, 1e-6));
        expect(result.at(1, 0), closeTo(0, 1e-6));
      });

      test('a=20: [[20 0] [0 20]] exp matches Julia to 1e-12 relative', () {
        // Julia: A = [20.0 0.0; 0.0 20.0]; exp(A)
        // -> [485165195.40979028 0; 0 485165195.40979028]
        final Matrix a = Matrix(<List<double>>[
          <double>[20, 0],
          <double>[0, 20],
        ]);
        final Matrix result = a.exp();
        _expectRelativelyClose(result.at(0, 0), 485165195.40979028);
        _expectRelativelyClose(result.at(1, 1), 485165195.40979028);
        expect(result.at(0, 1), closeTo(0, 1e-6));
        expect(result.at(1, 0), closeTo(0, 1e-6));
      });

      test('a=30: [[30 0] [0 30]] exp matches Julia to 1e-12 relative', () {
        // Julia: A = [30.0 0.0; 0.0 30.0]; exp(A)
        // -> [10686474581524.463 0; 0 10686474581524.463]
        final Matrix a = Matrix(<List<double>>[
          <double>[30, 0],
          <double>[0, 30],
        ]);
        final Matrix result = a.exp();
        _expectRelativelyClose(result.at(0, 0), 10686474581524.463);
        _expectRelativelyClose(result.at(1, 1), 10686474581524.463);
      });

      test('a=40: [[40 0] [0 40]] exp matches Julia to 1e-12 relative', () {
        // Julia: A = [40.0 0.0; 0.0 40.0]; exp(A)
        // -> [2.3538526683702e17 0; 0 2.3538526683702e17]
        final Matrix a = Matrix(<List<double>>[
          <double>[40, 0],
          <double>[0, 40],
        ]);
        final Matrix result = a.exp();
        _expectRelativelyClose(result.at(0, 0), 2.3538526683702e17);
        _expectRelativelyClose(result.at(1, 1), 2.3538526683702e17);
      });

      test('a=100: [[100 0] [0 100]] exp matches Julia to 1e-12 relative', () {
        // Julia: A = [100.0 0.0; 0.0 100.0]; exp(A)
        // -> [2.6881171418161356e43 0; 0 2.6881171418161356e43]
        final Matrix a = Matrix(<List<double>>[
          <double>[100, 0],
          <double>[0, 100],
        ]);
        final Matrix result = a.exp();
        _expectRelativelyClose(result.at(0, 0), 2.6881171418161356e43);
        _expectRelativelyClose(result.at(1, 1), 2.6881171418161356e43);
      });

      test('non-diagonal matrix [[10 20] [30 40]] exp matches Julia to 1e-12 '
          'relative', () {
        // Julia: A = [10.0 20.0; 30.0 40.0]; exp(A)
        // -> [5.1251611092776047e22 7.4695487322797254e22;
        //     1.1204323098419586e23 1.6329484207697193e23]
        final Matrix a = Matrix(<List<double>>[
          <double>[10, 20],
          <double>[30, 40],
        ]);
        final Matrix result = a.exp();
        _expectRelativelyClose(result.at(0, 0), 5.1251611092776047e22);
        _expectRelativelyClose(result.at(0, 1), 7.4695487322797254e22);
        _expectRelativelyClose(result.at(1, 0), 1.1204323098419586e23);
        _expectRelativelyClose(result.at(1, 1), 1.6329484207697193e23);
      });

      test('Jordan block [[2 1 0] [0 2 1] [0 0 2]] scaled by 10 exp matches '
          'Julia to 1e-12 relative', () {
        // Julia: J = [20.0 10.0 0.0; 0.0 20.0 10.0; 0.0 0.0 20.0]; exp(J)
        // -> [485165195.40979546 4851651954.0979595 24258259770.48983;
        //     0 485165195.40979546 4851651954.0979595;
        //     0 0 485165195.40979546]
        final Matrix jordan = Matrix(<List<double>>[
          <double>[2, 1, 0],
          <double>[0, 2, 1],
          <double>[0, 0, 2],
        ]).scale(10);
        final Matrix result = jordan.exp();
        _expectRelativelyClose(result.at(0, 0), 485165195.40979546);
        _expectRelativelyClose(result.at(0, 1), 4851651954.0979595);
        _expectRelativelyClose(result.at(0, 2), 24258259770.48983);
        expect(result.at(1, 0), closeTo(0, 1e-6));
        _expectRelativelyClose(result.at(1, 1), 485165195.40979546);
        _expectRelativelyClose(result.at(1, 2), 4851651954.0979595);
        expect(result.at(2, 0), closeTo(0, 1e-6));
        expect(result.at(2, 1), closeTo(0, 1e-6));
        _expectRelativelyClose(result.at(2, 2), 485165195.40979546);
      });

      test('complex-form matrix [[20 -15] [15 20]] exp matches Julia to 1e-12 '
          'relative', () {
        // Julia: C = [20.0 -15.0; 15.0 20.0]; exp(C)
        // -> [-368574134.69260252 -315497027.04243803;
        //     315497027.04243803 -368574134.6926024]
        final Matrix complexForm = Matrix.complex(20, 15);
        final Matrix result = complexForm.exp();
        _expectRelativelyClose(result.at(0, 0), -368574134.69260252);
        _expectRelativelyClose(result.at(0, 1), -315497027.04243803);
        _expectRelativelyClose(result.at(1, 0), 315497027.04243803);
        _expectRelativelyClose(result.at(1, 1), -368574134.6926024);
      });
    },
  );

  group('Matrix.exp / Matrix.power - overflow raises non-finite (issue #13, '
      'acceptance 3, D25 row 13)', () {
    test('[[921 0] [0 921]] exp overflows and raises non-finite', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[921, 0],
        <double>[0, 921],
      ]);
      expect(
        () => a.exp(),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.nonFinite,
          ),
        ),
      );
    });

    test('10 [[400 0] [0 400]] ^ overflows and raises non-finite', () {
      final Matrix exponent = Matrix(<List<double>>[
        <double>[400, 0],
        <double>[0, 400],
      ]);
      expect(
        () => Matrix.scalar(10).power(exponent),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.nonFinite,
          ),
        ),
      );
    });
  });

  group('Matrix.exp - trace shift and exact nilpotent path (issue #13, '
      'review round 1)', () {
    test('highly non-normal nilpotent matrix [[400.1 400.1] '
        '[-400.1 -400.1]] exp equals I + A within 1e-15 relative, since '
        'A^2 = 0 exactly and expm(A) = I + A + A^2/2! + ... terminates '
        'after one term', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[400.1, 400.1],
        <double>[-400.1, -400.1],
      ]);
      final Matrix result = a.exp();
      _expectRelativelyClose(result.at(0, 0), 401.1, relativeTolerance: 1e-15);
      _expectRelativelyClose(result.at(0, 1), 400.1, relativeTolerance: 1e-15);
      _expectRelativelyClose(result.at(1, 0), -400.1, relativeTolerance: 1e-15);
      _expectRelativelyClose(result.at(1, 1), -399.1, relativeTolerance: 1e-15);
    });

    test('Jordan block 5*I + N (3x3, N the superdiagonal ones) exp equals '
        'e^5 times the closed form within 1e-14 relative', () {
      final Matrix jordan = Matrix(<List<double>>[
        <double>[5, 1, 0],
        <double>[0, 5, 1],
        <double>[0, 0, 5],
      ]);
      final Matrix result = jordan.exp();
      final double e5 = math.exp(5);
      _expectRelativelyClose(result.at(0, 0), e5, relativeTolerance: 1e-14);
      _expectRelativelyClose(result.at(0, 1), e5, relativeTolerance: 1e-14);
      _expectRelativelyClose(
        result.at(0, 2),
        e5 * 0.5,
        relativeTolerance: 1e-14,
      );
      expect(result.at(1, 0), closeTo(0, 1e-6));
      _expectRelativelyClose(result.at(1, 1), e5, relativeTolerance: 1e-14);
      _expectRelativelyClose(result.at(1, 2), e5, relativeTolerance: 1e-14);
      expect(result.at(2, 0), closeTo(0, 1e-6));
      expect(result.at(2, 1), closeTo(0, 1e-6));
      _expectRelativelyClose(result.at(2, 2), e5, relativeTolerance: 1e-14);
    });
  });

  group('Matrix.exp - no trace shift on already-exact block structure '
      '(issue #13, review round 2)', () {
    test('block-diagonal [[400 400 0] [-400 -400 0] [0 0 1]] exp equals '
        '[[401 400 0] [-400 -399 0] [0 0 e]] within 1e-15 whole-matrix '
        'relative infinity-norm error, since the upper block is exactly '
        'nilpotent (A^2 = 0 there) and the corner is the scalar 1; a trace '
        'shift with mu = 1/3 destroys this exactness', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[400, 400, 0],
        <double>[-400, -400, 0],
        <double>[0, 0, 1],
      ]);
      final Matrix expected = Matrix(<List<double>>[
        <double>[401, 400, 0],
        <double>[-400, -399, 0],
        <double>[0, 0, math.e],
      ]);
      final Matrix result = a.exp();
      final double relativeError = _relativeInfinityNormError(result, expected);
      expect(
        relativeError,
        lessThanOrEqualTo(1e-15),
        reason:
            'expected $expected, got $result (relative error $relativeError)',
      );
    });
  });
}

void _expectRelativelyClose(
  double actual,
  double expected, {
  double relativeTolerance = 1e-12,
}) {
  final double scale = math.max(actual.abs(), expected.abs());
  final double relativeError = scale == 0
      ? 0
      : (actual - expected).abs() / scale;
  expect(
    relativeError,
    lessThanOrEqualTo(relativeTolerance),
    reason: 'expected $expected, got $actual (relative error $relativeError)',
  );
}

double _infinityNormOf(Matrix matrix) {
  double maxRowSum = 0;
  for (int row = 0; row < matrix.rowCount; row++) {
    double rowSum = 0;
    for (int column = 0; column < matrix.columnCount; column++) {
      rowSum += matrix.at(row, column).abs();
    }
    if (rowSum > maxRowSum) {
      maxRowSum = rowSum;
    }
  }
  return maxRowSum;
}

double _relativeInfinityNormError(Matrix actual, Matrix expected) {
  final Matrix difference = actual - expected;
  final double diffNorm = _infinityNormOf(difference);
  final double referenceNorm = _infinityNormOf(expected);
  if (referenceNorm == 0) {
    return diffNorm == 0 ? 0 : diffNorm;
  }
  return diffNorm / referenceNorm;
}
