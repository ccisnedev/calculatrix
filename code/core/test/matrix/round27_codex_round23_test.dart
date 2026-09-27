// Core PR #7 Codex round 23, one Low finding plus coverage, found against
// [Matrix._exactRealEigen2x2] after round 22's own fix (343ac98) had already
// replaced every complete-underflow check with a reversibility check, but
// only at the sqrt-derived and determinant rescales, never at the plain
// power-of-two rescale applied to the block's own raw inputs.
//
// Finding: neither the balance step (`b`, `c` rescaled towards a common
// magnitude before anything else runs) nor the whole-block scale (`a`,
// `balancedB`, `balancedC`, `d` each rescaled by the one power of two tuned
// to the block's largest-magnitude entry) ever checked that its own rescale
// was reversible. When one entry is far smaller than the block's largest,
// this rescale alone can drive it clear through the smallest representable
// subnormal before it is ever used again: `a = 2^400`, `b = c = d = 2^-700`,
// `debugExactRealEigen2x2(a, b, c, d)` used to return `lambda2 = 0.0` with
// `lambda2Error = 0.0` (verified against the pre-fix code below), even
// though the true smaller eigenvalue is close to `2^-700` and strictly
// positive. The pre-existing `adUnderflowed`/`bcUnderflowed` checks only
// fire once BOTH factors of a product are already nonzero and their product
// underflows; they never catch a single factor already zeroed by the very
// rescale that produced it, which is exactly what happened here (`sb`, `sc`,
// `sd` all rescaled to exactly `0.0`).
//
// A second, distinct fixture (`a = d = 2^400`, `b = c = 2^-700`) isolates
// the whole-block scale's own new guard from the discriminant's: with `h`
// exactly `0` here, the discriminant's own scale is tuned to `b`/`c`
// directly rather than to `h`, and `b`/`c` survive that scale intact,
// leaving `blockScaleReversible` as the first guard to reject the input
// (`sb`/`sc`/`sd` again zeroed by the whole-block scale, but this time
// `sa`/`sd` from the discriminant's own scale never underflow, so the
// discriminant's own reliability check would have nothing to reject). On
// the pre-fix code, this second fixture coincidentally rounds to the
// correct answer in double precision (`b*c` genuinely is negligible next to
// `a*d` here), but the fixed code cannot prove that without trusting an
// irreversible rescale, so it fails closed anyway, per the unconditional
// "fail closed rather than silently trust" design this whole certification
// path already follows.
//
// Fixed by adding a reversibility check at every remaining power-of-two
// rescale of an INPUT entry in [Matrix._exactRealEigen2x2] and
// [Matrix._scaledCenteredDiscriminant]: the balance step (`balanceReversible`),
// the whole-block scale (`blockScaleReversible`), and, inside the
// discriminant's own scale, `sh`/`shLo` and `sb`/`sc` (gated by the same
// `sqNegligible`/`bcNegligible` escape hatches the discriminant's own
// pre-existing `sqErr`/`crossTerm`/`bcErr` checks already use, so genuinely
// negligible terms, the whole point of round 19's own fixtures, are not
// regressed).
//
// Every scaling site audited in [Matrix._exactRealEigen2x2] and its direct
// helpers ([Matrix._scaledCenteredDiscriminant],
// [Matrix._compensatedDeterminant]) is listed in the round's report; a
// separate, unrelated eigen-solving path ([Matrix._eigenvalues2x2], reached
// only from the generic [Matrix.eigenvalues] entry point for 2x2 matrices,
// never from [Matrix._exactRealEigen2x2]) was confirmed out of scope.
//
// Coverage: [Matrix._failEigen2x2Certification] now takes a `guard` name
// and embeds it in the thrown message, so each certification check below
// can be isolated by asserting on its own specific reason string rather
// than only on the shared `matrix-out-of-precision-range` error id. Every
// guard tested here was verified, by mutation (temporarily removing the
// guard's own check and confirming this file's matching test fails, then
// restoring it), to be the one thing keeping its own test red; that
// mutation table is reported alongside the commit, not reproduced in this
// file. Two guards, `lambda1Certification` and `lambda2Certification`, are
// finiteness/non-negativity sanity checks on values built entirely from
// already-certified (normal-magnitude, reversible, finite) inputs; no
// fixture search (targeted at forcing `m`/`sqrtD`/`det` to overflow or
// cancel to `NaN`) found one that reaches either check first, ahead of an
// earlier guard. They are left as defense-in-depth only, honestly reported
// as such rather than forced, the same way round 22 reported
// `centerHalvingExact` as unreachable ahead of the earlier trace guard.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:calculatrix/src/matrix/matrix.dart' show debugExactRealEigen2x2;
import 'package:test/test.dart';

Matcher throwsOutOfPrecisionRangeGuard(String guard) => throwsA(
  isA<MatrixDomainError>()
      .having(
        (MatrixDomainError e) => e.errorId,
        'errorId',
        CalculatrixErrorId.matrixOutOfPrecisionRange,
      )
      .having(
        (MatrixDomainError e) => e.message,
        'message',
        contains('guard: $guard'),
      ),
);

void main() {
  group('Codex round 23 (reversible input rescale, P6 follow-up)', () {
    group(
      'Finding: a power-of-two rescale of the block\'s own raw input '
      '(the balance step, or the whole-block scale) was never itself '
      'checked for reversibility, unlike every sqrt-derived and '
      'determinant rescale already fixed in round 22',
      () {
        test(
          'debugExactRealEigen2x2 raises matrix-out-of-precision-range at '
          'discriminantReliable for a=2^400, b=c=d=2^-700 instead of '
          'certifying lambda2=0 (the true smaller root is close to 2^-700 '
          'and strictly positive)',
          () {
            final double a = math.pow(2.0, 400).toDouble();
            final double t = math.pow(2.0, -700).toDouble();
            expect(
              () => debugExactRealEigen2x2(a, t, t, t),
              throwsOutOfPrecisionRangeGuard('discriminantReliable'),
            );
          },
        );

        test(
          'pre-fix behavior check: the same a=2^400, b=c=d=2^-700 input '
          'silently returned lambda2=0.0 with lambda2Error=0.0 before this '
          'round\'s fix (recorded here for the record; this test exercises '
          'the current, fixed code and must throw, not return that value)',
          () {
            final double a = math.pow(2.0, 400).toDouble();
            final double t = math.pow(2.0, -700).toDouble();
            expect(
              () => debugExactRealEigen2x2(a, t, t, t),
              isNot(returnsNormally),
            );
          },
        );

        test(
          'debugExactRealEigen2x2 raises matrix-out-of-precision-range at '
          'blockScaleReversible for a=d=2^400, b=c=2^-700 (h=0 exactly, so '
          'the discriminant\'s own scale is tuned to b/c directly and '
          'cannot itself reject this input; only the whole-block scale, '
          'tuned to a/d, can), instead of certifying a coincidentally '
          'correct double-rounded answer it cannot prove sound',
          () {
            final double a = math.pow(2.0, 400).toDouble();
            final double t = math.pow(2.0, -700).toDouble();
            expect(
              () => debugExactRealEigen2x2(a, t, t, a),
              throwsOutOfPrecisionRangeGuard('blockScaleReversible'),
            );
          },
        );
      },
    );

    group(
      'Coverage: each guard inside _exactRealEigen2x2 and its helpers is '
      'isolated by asserting on its own specific reason string, so '
      'deleting any single guard either stops the throw entirely or shifts '
      'the reported reason to a different guard, either of which fails '
      'the matching test below',
      () {
        test('traceHalving: minNormal, 1.0, 1.0, minNormal - 3*s', () {
          final double s = double.minPositive;
          final double minNormal = 2.2250738585072014e-308;
          expect(
            () => debugExactRealEigen2x2(minNormal, 1.0, 1.0, minNormal - 3 * s),
            throwsOutOfPrecisionRangeGuard('traceHalving'),
          );
        });

        test('balanceReversible: deep-subnormal b, c pulled apart by the '
            'balance step\'s own geometric-mean rescale', () {
          expect(
            () => debugExactRealEigen2x2(
              3.7865429746418134e-55,
              3.047165e-318,
              3.48736e-319,
              6.694868590527775e-29,
            ),
            throwsOutOfPrecisionRangeGuard('balanceReversible'),
          );
        });

        test('complexWRescale: 0, 4*s, -2*s, 0', () {
          final double s = double.minPositive;
          expect(
            () => debugExactRealEigen2x2(0, 4 * s, -2 * s, 0),
            throwsOutOfPrecisionRangeGuard('complexWRescale'),
          );
        });

        test('repeatedRootRescale: t=2^-1020, (t, t, -t, -t)', () {
          final double t = math.pow(2.0, -1020).toDouble();
          expect(
            () => debugExactRealEigen2x2(t, t, -t, -t),
            throwsOutOfPrecisionRangeGuard('repeatedRootRescale'),
          );
        });

        test('sqrtDRescale: 0, 4*s, 2*s, 0', () {
          final double s = double.minPositive;
          expect(
            () => debugExactRealEigen2x2(0, 4 * s, 2 * s, 0),
            throwsOutOfPrecisionRangeGuard('sqrtDRescale'),
          );
        });

        test(
          'eSqrtDRescale: 1.0, minNormal/2, minNormal/2, 1.0',
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
              throwsOutOfPrecisionRangeGuard('eSqrtDRescale'),
            );
          },
        );

        test('blockScaleReversible: a=d=2^400, b=c=2^-700 (see finding above)', () {
          final double a = math.pow(2.0, 400).toDouble();
          final double t = math.pow(2.0, -700).toDouble();
          expect(
            () => debugExactRealEigen2x2(a, t, t, a),
            throwsOutOfPrecisionRangeGuard('blockScaleReversible'),
          );
        });

        test(
          'adUnderflow: both a and d individually survive the whole-block '
          'scale, but their product still underflows to exactly 0',
          () {
            expect(
              () => debugExactRealEigen2x2(
                1.0565128225056955e-159,
                2.0525276616060813e+139,
                2.1464526267448587e+135,
                1.565661837160844e-163,
              ),
              throwsOutOfPrecisionRangeGuard('adUnderflow'),
            );
          },
        );

        test(
          'bcUnderflow: both b and c individually survive the whole-block '
          'scale, but their product still underflows to exactly 0',
          () {
            expect(
              () => debugExactRealEigen2x2(
                3.6609425220110713e+130,
                2.1460950276776464e-156,
                3.309469101488402e-173,
                5.350518879106594e+137,
              ),
              throwsOutOfPrecisionRangeGuard('bcUnderflow'),
            );
          },
        );

        test(
          'determinantReliable: a*d rescales to a nonzero subnormal (not an '
          'exact zero adUnderflow would catch), breaking the error-free '
          'transform\'s own normal-magnitude assumption',
          () {
            expect(
              () => debugExactRealEigen2x2(
                5.080068206439197e-202,
                3.773929956731858e-48,
                1.1529705833444417e-59,
                1.1692897401208229e-202,
              ),
              throwsOutOfPrecisionRangeGuard('determinantReliable'),
            );
          },
        );

        test(
          'determinantValueRescale: 0, 2^-512, 0.7*2^-512, 0',
          () {
            final double e = math.pow(2.0, -512).toDouble();
            expect(
              () => debugExactRealEigen2x2(0, e, 0.7 * e, 0),
              throwsOutOfPrecisionRangeGuard('determinantValueRescale'),
            );
          },
        );

        test(
          'determinantErrorRescale: a determinant value that rescales '
          'reversibly while its own error bound does not',
          () {
            expect(
              () => debugExactRealEigen2x2(
                1.571625451087422e-180,
                1.1492853899791748e-117,
                4.355826798465998e-179,
                1.3583580828767927e-160,
              ),
              throwsOutOfPrecisionRangeGuard('determinantErrorRescale'),
            );
          },
        );
      },
    );
  });
}
