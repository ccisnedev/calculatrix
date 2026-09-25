import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// Asserts [actual] is within [relativeTolerance] of [expected]. Exactly 0
/// is required when [expected] is exactly 0 (no relative tolerance is
/// meaningful there); otherwise the check is purely relative, since an
/// absolute tolerance would mask large relative errors on tiny expected
/// values (some of the eigenvalues exercised here span hundreds of orders
/// of magnitude).
void expectRelativelyClose(
  double actual,
  double expected, {
  double relativeTolerance = 1e-9,
}) {
  if (expected == 0) {
    expect(actual, equals(0));
    return;
  }
  final double relativeError = (actual - expected).abs() / expected.abs();
  expect(
    relativeError,
    lessThan(relativeTolerance),
    reason: 'actual=$actual expected=$expected relativeError=$relativeError',
  );
}

void main() {
  group(
    'Matrix.log divided-difference overflow protection at extreme '
    'eigenvalue spread (finding: (l1-l2)/l2 overflows for a huge '
    'eigenvalue ratio even though (log l1 - log l2)/(l1-l2) is finite)',
    () {
      test(
        'triangular [[1e200,1],[0,1e-200]]: log no longer throws '
        'non-finite and matches the exact triangular closed form',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e200, 1],
            <double>[0, 1e-200],
          ]);

          final Matrix result = value.log();

          final double expectedOffDiagonal =
              (math.log(1e200) - math.log(1e-200)) / (1e200 - 1e-200);

          expectRelativelyClose(result.at(0, 0), math.log(1e200));
          expectRelativelyClose(result.at(1, 1), math.log(1e-200));
          expectRelativelyClose(result.at(0, 1), expectedOffDiagonal);
          expect(result.at(1, 0), equals(0));
        },
      );

      test(
        'non-triangular analogue [[1e200,1],[1e-300,1e-200]]: log no '
        'longer throws non-finite',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e200, 1],
            <double>[1e-300, 1e-200],
          ]);

          final Matrix result = value.log();

          final double expectedC1 =
              (math.log(1e200) - math.log(1e-200)) / (1e200 - 1e-200);

          // The (0,0) and (1,1) entries reconstruct through c0 + c1*entry;
          // for log the reconstruction never needs more precision than a
          // double holds (log compresses the huge eigenvalue spread down
          // to a spread of a few hundred), so both remain accurate to
          // the same tight relative tolerance as the triangular case.
          expectRelativelyClose(result.at(0, 0), math.log(1e200));
          expectRelativelyClose(result.at(1, 1), math.log(1e-200));
          expectRelativelyClose(result.at(0, 1), expectedC1, relativeTolerance: 1e-6);

          // The true (1,0) entry is c1*c, on the order of 1e-498: far
          // below the smallest representable subnormal double, so 0 is
          // the correctly-rounded result, not a precision loss.
          expect(result.at(1, 0), equals(0));
        },
      );
    },
  );

  group(
    'General 2x2 spectrum helper: smaller eigenvalue via scale-safe '
    'determinant (finding: the smaller root was derived as trace minus '
    'the larger root, which cancels to exactly 0 once the matrix entries '
    'themselves span a huge dynamic range)',
    () {
      final Matrix wideSpread = Matrix(<List<double>>[
        <double>[1e200, 1],
        <double>[1e-300, 1e-200],
      ]);

      test(
        'log no longer raises log-undefined for a zero eigenvalue that '
        'was only ever a cancellation artifact',
        () {
          final Matrix result = wideSpread.log();

          expectRelativelyClose(result.at(0, 0), math.log(1e200));
          expectRelativelyClose(result.at(1, 1), math.log(1e-200));
        },
      );

      test(
        'sqrt no longer raises log-undefined and recovers both diagonal '
        'entries to rounding',
        () {
          final Matrix result = wideSpread.sqrt();

          expectRelativelyClose(result.at(0, 0), 1e100);
          expectRelativelyClose(result.at(1, 1), 1e-100);
        },
      );

      test(
        'power(0.5) (the ^0.5 entry point, distinct from sqrt()) no '
        'longer raises log-undefined and recovers both diagonal entries '
        'to rounding',
        () {
          final Matrix result = wideSpread.power(Matrix.scalar(0.5));

          expectRelativelyClose(result.at(0, 0), 1e100);
          expectRelativelyClose(result.at(1, 1), 1e-100);
        },
      );

      test(
        'power(1.5) also recovers both diagonal entries to rounding '
        '(regression for the Lagrange-form diagonal reconstruction '
        'needed once the eigenvalue fix stops rejecting this matrix)',
        () {
          final Matrix result = wideSpread.power(Matrix.scalar(1.5));

          expectRelativelyClose(result.at(0, 0), 1e300);
          expectRelativelyClose(result.at(1, 1), 1e-300);
        },
      );

      test(
        'a genuinely singular matrix like [[1,1],[1,1]] still raises '
        'log-undefined for log (the zero-eigenvalue gate is unaffected)',
        () {
          final Matrix singular = Matrix(<List<double>>[
            <double>[1, 1],
            <double>[1, 1],
          ]);

          expect(
            () => singular.log(),
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
        'a genuinely singular matrix like [[1,1],[1,1]] still raises '
        'log-undefined for power(0.5) (the zero-eigenvalue gate is '
        'unaffected)',
        () {
          final Matrix singular = Matrix(<List<double>>[
            <double>[1, 1],
            <double>[1, 1],
          ]);

          expect(
            () => singular.power(Matrix.scalar(0.5)),
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
    },
  );
}
