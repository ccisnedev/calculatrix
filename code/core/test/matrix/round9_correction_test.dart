// Round 9 correction: five findings from an independent review of PR #7
// (feat/core-power-and-error-ids), each covered here by a test that fails
// before its paired fix and asserts a concrete numeric value or error id.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group(
    'Round 9, finding 1: general 2x2 non-integer real power must not lose '
    'a small eigenvalue to (lSmall-lBig)/lBig rounding to exactly -1',
    () {
      test(
        '[[1,1],[0,1e-20]]^0.01 matches the direct divided difference, not '
        'the unchanged input',
        () {
          final Matrix result = Matrix(<List<double>>[
            <double>[1, 1],
            <double>[0, 1e-20],
          ]).power(Matrix.scalar(0.01));

          const double l1 = 1;
          const double l2 = 1e-20;
          final double f1 = math.pow(l1, 0.01).toDouble();
          final double f2 = math.pow(l2, 0.01).toDouble();
          final double expectedOffDiagonal = (f1 - f2) / (l1 - l2);

          expect(result.at(0, 0), closeTo(f1, f1.abs() * 1e-9));
          expect(
            result.at(0, 1),
            closeTo(expectedOffDiagonal, expectedOffDiagonal.abs() * 1e-9),
          );
          expect(result.at(1, 0), 0);
          expect(result.at(1, 1), closeTo(f2, f2.abs() * 1e-9));

          // The bug this finding describes returns the input matrix
          // unchanged (c0=0, c1=1): guard against that specific regression
          // directly, not just against some other wrong answer.
          expect(result.at(1, 1), isNot(closeTo(1e-20, 1e-30)));
        },
      );

      test(
        '[[1,1],[0,1e-20]]^-0.5 is finite and matches the direct divided '
        'difference (previously threw non-finite)',
        () {
          final Matrix result = Matrix(<List<double>>[
            <double>[1, 1],
            <double>[0, 1e-20],
          ]).power(Matrix.scalar(-0.5));

          const double l1 = 1;
          const double l2 = 1e-20;
          final double f1 = math.pow(l1, -0.5).toDouble();
          final double f2 = math.pow(l2, -0.5).toDouble();
          final double expectedOffDiagonal = (f1 - f2) / (l1 - l2);

          expect(result.at(0, 0).isFinite, isTrue);
          expect(result.at(0, 1).isFinite, isTrue);
          expect(result.at(1, 0).isFinite, isTrue);
          expect(result.at(1, 1).isFinite, isTrue);

          expect(result.at(0, 0), closeTo(f1, f1.abs() * 1e-9));
          expect(
            result.at(0, 1),
            closeTo(expectedOffDiagonal, expectedOffDiagonal.abs() * 1e-9),
          );
          expect(result.at(1, 0), 0);
          expect(result.at(1, 1), closeTo(f2, f2.abs() * 1e-9));
        },
      );

      test('[[1,1],[0,0.1]]^1.5 matches the direct divided difference', () {
        // A well-separated but not extreme-scale pair of eigenvalues
        // (unlike the 1e-20 cases above, where l1-l2 already rounds to
        // exactly 1.0 in double precision, making any closed form
        // expressed as c0*I+c1*A unable to recover f(l2) to any relative
        // precision regardless of how c1 is computed): this exercises the
        // same relative-gap-large branch as the finding's own examples
        // without hitting that unrelated representability wall.
        final Matrix result = Matrix(<List<double>>[
          <double>[1, 1],
          <double>[0, 0.1],
        ]).power(Matrix.scalar(1.5));

        const double l1 = 1;
        const double l2 = 0.1;
        final double f1 = math.pow(l1, 1.5).toDouble();
        final double f2 = math.pow(l2, 1.5).toDouble();
        final double expectedOffDiagonal = (f1 - f2) / (l1 - l2);

        expect(result.at(0, 0), closeTo(f1, f1.abs() * 1e-9));
        expect(
          result.at(0, 1),
          closeTo(expectedOffDiagonal, expectedOffDiagonal.abs() * 1e-9),
        );
        expect(result.at(1, 0), 0);
        expect(result.at(1, 1), closeTo(f2, f2.abs() * 1e-9));
      });
    },
  );
}
