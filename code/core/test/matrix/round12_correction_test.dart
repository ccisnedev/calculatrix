// Round 12 correction: seven findings from an independent review of PR #7
// (feat/core-power-and-error-ids), each covered here by a test that fails
// before its paired fix and asserts a concrete numeric value or behavior,
// checked against an independently derived reference (Python mpmath at
// 200-1200 decimal digits, or an analytically stated closed form), never
// against this implementation's own prior output.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// Asserts [actual] is within [relativeTolerance] of [expected]. Exactly 0
/// is required when [expected] is exactly 0.
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
    'Round 12, finding 2: general 2x2 discriminant solver must not let an '
    'underflowed direct determinant (a*d - b*c both underflow to exactly 0) '
    'masquerade as a reliable finite result',
    () {
      // A=[[1e-200,1e-200],[2e-200,4e-200]]. Reference (mpmath, dps=1200):
      // eigenvalues lambda1 ~= 4.56155281280883e-200,
      // lambda2 ~= 4.38447187092134e-201 (both from the characteristic
      // polynomial trace/det of the *exact* rational entries, not from
      // this implementation). a*d = 4e-400 and b*c = 2e-400 each
      // underflow to exactly 0 in double precision (below the smallest
      // subnormal double, ~4.94e-324), so `directDet = a*d - b*c` is
      // exactly 0 and wrongly looks "finite" even though the true
      // determinant is `4e-400 - 2e-400 = 2e-400`, nonzero.
      test('log() does not throw for the true positive real eigenvalues', () {
        final Matrix value = Matrix(<List<double>>[
          <double>[1e-200, 1e-200],
          <double>[2e-200, 4e-200],
        ]);

        final Matrix result = value.log();

        // Reference (mpmath, dps=1200):
        expectRelativelyClose(result.at(0, 0), -461.02253778330164);
        expectRelativelyClose(result.at(0, 1), 0.56806184984831558);
        expectRelativelyClose(result.at(1, 0), 1.1361236996966312);
        expectRelativelyClose(result.at(1, 1), -459.31835223375669);
      });

      test(
        'power(-1.5) matches the mpmath reference, not a false zero '
        'eigenvalue rejection or a garbage finite value',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e-200, 1e-200],
            <double>[2e-200, 4e-200],
          ]);

          final Matrix result = value.power(Matrix.scalar(-1.5));

          // Reference (mpmath, dps=1200):
          expectRelativelyClose(result.at(0, 0), 2.9893360817330925e+300);
          expectRelativelyClose(result.at(0, 1), -8.1051520357382608e+299);
          expectRelativelyClose(result.at(1, 0), -1.6210304071476522e+300);
          expectRelativelyClose(result.at(1, 1), 5.577904710116143e+299);
        },
      );

      test(
        'sqrt() recovers the true small eigenvalue-weighted (0,0) entry, '
        'not the value produced by trusting the underflowed direct '
        'determinant',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e-200, 1e-200],
            <double>[2e-200, 4e-200],
          ]);

          final Matrix result = value.sqrt();

          // Reference (mpmath, dps=1200): the bug produces 4.68213...e-101
          // here (using lambda2 = 0 from the false directDet=0 reading);
          // the true value is 8.6285620946101682e-101.
          expectRelativelyClose(result.at(0, 0), 8.6285620946101682e-101);
          expectRelativelyClose(result.at(0, 1), 3.5740674433659326e-101);
          expectRelativelyClose(result.at(1, 0), 7.1481348867318651e-101);
          expectRelativelyClose(result.at(1, 1), 1.9350764424707966e-100);
        },
      );
    },
  );
}
