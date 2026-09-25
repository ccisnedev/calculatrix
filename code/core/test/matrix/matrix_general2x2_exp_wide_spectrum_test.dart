import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// Asserts [actual] is within [relativeTolerance] of [expected]. Exactly 0
/// is required when [expected] is exactly 0; otherwise the check is purely
/// relative, since an absolute tolerance would mask large relative errors
/// on tiny expected values (some of the entries exercised here span
/// hundreds of orders of magnitude).
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
    'Matrix.exp diagonal reconstruction for a genuinely non-triangular, '
    'widely separated eigenvalue pair (finding: c0 + c1*A anchors at the '
    'smaller eigenvalue, c0 = fLo - c1*lLo, and once fHi dwarfs fLo that '
    'subtraction loses fLo entirely, the same class of bug already fixed '
    'for the power path)',
    () {
      test(
        'near triangular [[700,1],[1e-300,-700]]: exp recovers the true '
        '(1,1) entry, not exp(-700) (round 12 correction, finding 1: the '
        '(1,1) matrix entry -700 and the true eigenvalue lSmall round to '
        'the same double, but lSmall is not exactly -700, and the '
        'resulting tiny offset, amplified by c1 (of order exp(700)), '
        'contributes a non-negligible amount)',
        () {
          // Reference (mpmath, dps=800, exact eigenvalues from the
          // characteristic polynomial of the *exact* rational entries,
          // never from this implementation):
          // lambda1 = 700, lambda2 = -700 to 40+ displayed digits (the
          // perturbation from b*c=1e-300 sits far below the displayed
          // precision), yet entry (1,1) of exp(A), evaluated as
          // c0 + c1*(-700) via the *exact* divided-difference
          // coefficients, is 0.00517465334048471688497617140424, sharply
          // different from exp(-700) ~= 9.8597e-305: the (1,1) matrix
          // entry -700 is not itself an eigenvalue of this
          // non-triangular matrix, even though it agrees with lSmall to
          // double precision.
          const double expected11 = 0.005174653340484717;
          final double c1 = (math.exp(700) - math.exp(-700)) / 1400;

          final Matrix value = Matrix(<List<double>>[
            <double>[700, 1],
            <double>[1e-300, -700],
          ]);

          final Matrix result = value.exp();

          expectRelativelyClose(result.at(0, 0), math.exp(700));
          expectRelativelyClose(result.at(1, 1), expected11);
          expectRelativelyClose(result.at(0, 1), c1);
          expectRelativelyClose(result.at(1, 0), c1 * 1e-300);
        },
      );

      test(
        'triangular analogue [[700,1],[0,-700]]: already exact via the '
        'triangular closed form, unaffected by this fix',
        () {
          final double fa = math.exp(700);
          final double fd = math.exp(-700);
          final double c1 = (fa - fd) / 1400;

          final Matrix value = Matrix(<List<double>>[
            <double>[700, 1],
            <double>[0, -700],
          ]);

          final Matrix result = value.exp();

          expectRelativelyClose(result.at(0, 0), fa);
          expectRelativelyClose(result.at(1, 1), fd);
          expectRelativelyClose(result.at(0, 1), c1);
          expect(result.at(1, 0), equals(0));
        },
      );

      test(
        'mirrored [[-700,1],[1e-300,700]]: the small eigenvalue now sits '
        'at (0,0) instead of (1,1), exercising the same fix from the other '
        'orientation',
        () {
          // Reference (mpmath, dps=800): by the same characteristic
          // polynomial as the unmirrored case above (b*c is unchanged),
          // entry (0,0) is 0.00517465334048471688497617140424, not
          // exp(-700).
          const double expected00 = 0.005174653340484717;
          final double c1 = (math.exp(700) - math.exp(-700)) / 1400;

          final Matrix value = Matrix(<List<double>>[
            <double>[-700, 1],
            <double>[1e-300, 700],
          ]);

          final Matrix result = value.exp();

          expectRelativelyClose(result.at(0, 0), expected00);
          expectRelativelyClose(result.at(1, 1), math.exp(700));
          expectRelativelyClose(result.at(0, 1), c1);
          expectRelativelyClose(result.at(1, 0), c1 * 1e-300);
        },
      );

      test(
        'moderately separated [[20,1],[1e-10,-20]]: independently '
        'eigendecomposed by hand (trace 0, det -400-1e-10, so '
        'lambda = +/- sqrt(400 + 1e-10)) and checked against the direct '
        'two-point closed form, not against any helper the implementation '
        'shares',
        () {
          // trace = a + d = 20 + (-20) = 0.
          // det = a*d - b*c = -400 - 1e-10.
          // Characteristic polynomial lambda^2 - trace*lambda + det = 0
          // reduces (trace == 0) to lambda^2 = -det = 400 + 1e-10.
          final double lambdaBig = math.sqrt(400 + 1e-10);
          final double lambdaSmall = -lambdaBig;
          final double fBig = math.exp(lambdaBig);
          final double fSmall = math.exp(lambdaSmall);
          final double denom = lambdaBig - lambdaSmall;
          final double c1 = (fBig - fSmall) / denom;
          // Two-point (Lagrange) form evaluated at each diagonal entry,
          // written out independently of _lagrangeClosedForm2x2.
          double diagonal(double x) =>
              fBig * ((x - lambdaSmall) / denom) +
              fSmall * ((lambdaBig - x) / denom);

          final Matrix value = Matrix(<List<double>>[
            <double>[20, 1],
            <double>[1e-10, -20],
          ]);

          final Matrix result = value.exp();

          expectRelativelyClose(
            result.at(0, 0),
            diagonal(20),
            relativeTolerance: 1e-6,
          );

          // Round 12 correction, finding 1: `lambdaSmall` here is computed
          // as `-sqrt(400 + 1e-10)`, which is NOT the same double as
          // `-20`: unlike the `700`/`1e-300` case above, `1e-10` is well
          // within double precision's relative resolution against `400`
          // (`1e-10 / 400 ~= 2.5e-13`, far above the ~2.2e-16 machine
          // epsilon floor), so this hand-rolled `lambdaSmall` already
          // carries its true offset from `-20` to full double precision,
          // with no cancellation anywhere in its own derivation. This is
          // therefore a tight, not loosened, check: once the
          // implementation stops losing that same offset internally, it
          // should match this reference to close to full double
          // precision, not just 1e-2.
          expectRelativelyClose(
            result.at(1, 1),
            diagonal(-20),
            relativeTolerance: 1e-9,
          );
          expectRelativelyClose(result.at(0, 1), c1, relativeTolerance: 1e-6);
          expectRelativelyClose(
            result.at(1, 0),
            c1 * 1e-10,
            relativeTolerance: 1e-6,
          );
        },
      );
    },
  );

  group(
    'Matrix.sqrt general-2x2 audit: sqrt has no separate non-power general '
    '2x2 implementation, it always goes through the already-fixed power '
    'path (_matrixRealPower(0.5, ...) -> _general2x2RealPower), so these '
    'are regression tests confirming that, not a new fix',
    () {
      test(
        'sqrt([[1e200,1],[1e-300,1e-200]]) recovers both diagonal entries '
        '(same matrix the power-path Lagrange fix already covers)',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e200, 1],
            <double>[1e-300, 1e-200],
          ]);

          final Matrix result = value.sqrt();

          expectRelativelyClose(result.at(0, 0), 1e100);
          expectRelativelyClose(result.at(1, 1), 1e-100);
        },
      );

      test(
        'sqrt([[4,1],[1e-30,1e-18]]) recovers both diagonal entries '
        '(eigenvalues approximately 4 and det/4 = 1e-18, det = '
        '4e-18 - 1e-30)',
        () {
          // trace = 4 + 1e-18 ~= 4.
          // det = a*d - b*c = 4e-18 - 1e-30 ~= 4e-18.
          // lambdaBig ~= 4, lambdaSmall = det / lambdaBig ~= 1e-18.
          final double lambdaBig = 4.0;
          final double lambdaSmall = ((4 * 1e-18) - (1 * 1e-30)) / lambdaBig;
          final double fBig = math.sqrt(lambdaBig);
          final double fSmall = math.sqrt(lambdaSmall);

          final Matrix value = Matrix(<List<double>>[
            <double>[4, 1],
            <double>[1e-30, 1e-18],
          ]);

          final Matrix result = value.sqrt();

          expectRelativelyClose(result.at(0, 0), fBig, relativeTolerance: 1e-6);
          expectRelativelyClose(
            result.at(1, 1),
            fSmall,
            relativeTolerance: 1e-6,
          );
        },
      );
    },
  );
}
