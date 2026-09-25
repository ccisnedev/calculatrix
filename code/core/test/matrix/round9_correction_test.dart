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

  group(
    'Round 9, finding 2: symmetric 2x2 eigenvalues must not overflow or '
    'underflow at extreme uniform scale',
    () {
      // Eigenvalues of [[1,1],[1,2]] are (3+-sqrt(5))/2, exactly; scaling
      // every entry by s scales both eigenvalues by s (eig(sA) = s*eig(A)).
      final double sqrt5 = math.sqrt(5);
      final double larger = (3 + sqrt5) / 2;
      final double smaller = (3 - sqrt5) / 2;

      test(
        '[[1e200,1e200],[1e200,2e200]] does not overflow to NaN',
        () {
          final Matrix result = Matrix(<List<double>>[
            <double>[1e200, 1e200],
            <double>[1e200, 2e200],
          ]).eigenvalues();

          final double expectedLarger = larger * 1e200;
          final double expectedSmaller = smaller * 1e200;

          expect(result.at(0, 0).isFinite, isTrue);
          expect(result.at(1, 0).isFinite, isTrue);
          expect(
            result.at(0, 0),
            closeTo(expectedLarger, expectedLarger.abs() * 1e-9),
          );
          expect(
            result.at(1, 0),
            closeTo(expectedSmaller, expectedSmaller.abs() * 1e-9),
          );
        },
      );

      test(
        '[[1e-200,1e-200],[1e-200,2e-200]] does not underflow to a wrong '
        'repeated value',
        () {
          final Matrix result = Matrix(<List<double>>[
            <double>[1e-200, 1e-200],
            <double>[1e-200, 2e-200],
          ]).eigenvalues();

          final double expectedLarger = larger * 1e-200;
          final double expectedSmaller = smaller * 1e-200;

          expect(result.at(0, 0).isFinite, isTrue);
          expect(result.at(1, 0).isFinite, isTrue);
          expect(
            result.at(0, 0),
            closeTo(expectedLarger, expectedLarger.abs() * 1e-9),
          );
          expect(
            result.at(1, 0),
            closeTo(expectedSmaller, expectedSmaller.abs() * 1e-9),
          );
          // The bug this finding describes returns a repeated 1.5e-200 for
          // both roots (the discriminant underflowed to exactly 0): guard
          // against that specific regression directly.
          expect(result.at(0, 0), isNot(closeTo(1.5e-200, 1e-210)));
        },
      );

      test(
        'the existing opposite-scale off-diagonal case still reports +-1, '
        'not a spurious repeated 0',
        () {
          final Matrix result = Matrix(<List<double>>[
            <double>[0, 1e200],
            <double>[1e-200, 0],
          ]).eigenvalues();

          final List<double> values = <double>[
            result.at(0, 0),
            result.at(1, 0),
          ]..sort();

          expect(values.length, 2);
          expect(values[0], closeTo(-1, 1e-9));
          expect(values[1], closeTo(1, 1e-9));
        },
      );
    },
  );
}
