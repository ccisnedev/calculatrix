// Core PR #7 Codex round 22, one Low finding plus coverage, found against
// [Matrix._exactRealEigen2x2] after round 21's own fix (5a89bb2) had
// already resolved the previous round's complete-underflow gap.
//
// Finding: round 21's [Matrix._rescaleUnderflowedToZero] (renamed here to
// [Matrix._rescaleReversible]) only caught a power-of-two rescale that
// underflowed all the way to an exact `0.0`. A rescale that lands in the
// sparse subnormal range while staying nonzero can still lose most of its
// bits, understating the true value without ever tripping that check.
// `s = double.minPositive`, `t = 2^-1020`,
// `debugExactRealEigen2x2(t, t, -t, -t)` hits exactly this: the
// repeated-root radius is `~6.3246*s` in exact math, but rescaling it to
// natural units rounds to `6*s` (only a handful of representable values
// exist down there), quietly understating the certified bound by about
// five percent instead of failing closed.
//
// Fixed by replacing the complete-underflow check with a reversibility
// check: a power-of-two rescale is certified only when scaling the result
// back by the inverse power recovers the original value bit for bit (and a
// nonzero input never becomes zero). Applied at every sqrt-derived rescale
// (`w`, `r`, `sqrtD`, `eSqrtD`) and at the determinant value/error rescale
// checks, which had the same complete-underflow-only gap.
//
// Coverage: while constructing fixtures for each rescale guard, a fixture
// meant to isolate the discriminant's centered-halving guard (`h`, inside
// [Matrix._scaledCenteredDiscriminant]) from the trace-halving guard
// (`m`, checked earlier in [Matrix._exactRealEigen2x2]) turned out not to
// be constructible: for [Matrix._twoSum](a, d) (the trace) and
// [Matrix._twoSum](a, -d) (the centered half-difference), the two
// halving-exactness checks were verified, by random search across several
// million signed double pairs plus a wide structured sweep around the
// subnormal/normal boundary, to always agree for any given `a`, `d`. The
// fixture below reaches and fails the centered-halving guard, but, as that
// search shows, it necessarily also fails the earlier trace guard on the
// same input; both firing together is still a valid regression, just not
// one that isolates the two guards from each other.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:calculatrix/src/matrix/matrix.dart' show debugExactRealEigen2x2;
import 'package:test/test.dart';

Matcher throwsOutOfPrecisionRange() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.matrixOutOfPrecisionRange,
  ),
);

void main() {
  group('Codex round 22 (reversible rescale, P6 follow-up)', () {
    group(
      'Finding: a power-of-two rescale that lands in the subnormal range '
      'while staying nonzero can still lose most of its bits, understating '
      'a certified bound instead of failing closed',
      () {
        test(
          'debugExactRealEigen2x2 raises matrix-out-of-precision-range for '
          't=2^-1020, (t, t, -t, -t) instead of certifying the '
          'repeated-root radius understated from ~6.3246*s to 6*s '
          '(s = double.minPositive)',
          () {
            final double t = 8.900295434028806e-308; // 2^-1020
            expect(
              () => debugExactRealEigen2x2(t, t, -t, -t),
              throwsOutOfPrecisionRange(),
            );
          },
        );
      },
    );

    group(
      'Coverage: each sqrt-derived and determinant rescale site raises '
      'matrix-out-of-precision-range when its own reversibility check '
      'fails, not only on complete underflow to zero',
      () {
        test(
          'w-site (complex branch): (0, 4*s, -2*s, 0) raises '
          'matrix-out-of-precision-range instead of certifying a lossy '
          'nonzero rescale of the imaginary radius',
          () {
            final double s = double.minPositive;
            expect(
              () => debugExactRealEigen2x2(0, 4 * s, -2 * s, 0),
              throwsOutOfPrecisionRange(),
            );
          },
        );

        test(
          'sqrtD-site (distinct real roots): (0, 4*s, 2*s, 0) raises '
          'matrix-out-of-precision-range instead of certifying a lossy '
          'nonzero rescale of the real square root',
          () {
            final double s = double.minPositive;
            expect(
              () => debugExactRealEigen2x2(0, 4 * s, 2 * s, 0),
              throwsOutOfPrecisionRange(),
            );
          },
        );

        test(
          'eSqrtD-site: (1.0, minNormal/2, minNormal/2, 1.0) reaches and '
          'fails the eSqrtD reversibility check before the determinant is '
          'ever computed, raising matrix-out-of-precision-range',
          () {
            final double minNormal = 2.2250738585072014e-308;
            final double halfMinNormal = minNormal / 2;
            expect(
              () => debugExactRealEigen2x2(
                1.0,
                halfMinNormal,
                halfMinNormal,
                1.0,
              ),
              throwsOutOfPrecisionRange(),
            );
          },
        );

        test(
          'determinant value/error rescale: (0, 2^-512, 0.7*2^-512, 0) '
          'raises matrix-out-of-precision-range instead of certifying a '
          'lossy nonzero rescale of the determinant and its error bound',
          () {
            final double e = math.pow(2.0, -512).toDouble();
            expect(
              () => debugExactRealEigen2x2(0, e, 0.7 * e, 0),
              throwsOutOfPrecisionRange(),
            );
          },
        );

        test(
          'centered-halving guard of h: (minNormal, 1.0, 1.0, '
          'minNormal - 3*s) reaches and fails the centered-halving check '
          'inside the discriminant computation (this input also fails the '
          'earlier trace-halving guard on the same a, d, which a wide '
          'search found is always the case; both failing closed together '
          'is the correct, honest outcome)',
          () {
            final double s = double.minPositive;
            final double minNormal = 2.2250738585072014e-308;
            expect(
              () => debugExactRealEigen2x2(
                minNormal,
                1.0,
                1.0,
                minNormal - 3 * s,
              ),
              throwsOutOfPrecisionRange(),
            );
          },
        );
      },
    );
  });
}
