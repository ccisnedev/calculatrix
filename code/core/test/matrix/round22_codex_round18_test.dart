// Core PR #7 Codex round 18, 3 medium findings on
// [Matrix._exactRealEigen2x2]'s general 2x2 closed form (all traced to the
// error-bound machinery built in round 17):
//
//   1. Mixed error models silently accepted an invalid sqrt. Round 17 fixed
//      the discriminant to recover a genuine sign split for
//      `A = [[1.0000000000000002, 1], [-1, -1]]`, but
//      [Matrix._compensatedDeterminant] still carried a first-order
//      input-uncertainty floor in its own error bound that
//      [Matrix._compensatedDiscriminant] never had. That floor made
//      `lambda2Error` (derived from `det / lambda1`) about 7.45e-7, roughly
//      50 times larger than `lambda2` itself (about -1.49e-8), so
//      classification reported the smaller, genuinely negative eigenvalue
//      as zero/positive instead of negative, and `sqrt()` returned a
//      matrix scaled by about 8192x the original, a silent invalid result
//      instead of a rejection. Fixed by removing that floor: both
//      compensated helpers now share exactly one error model, pure forward
//      error on the stored binary64 entries treated as exact inputs, never
//      any claim about how those entries were themselves produced.
//
//   2. `lambda1Error` omitted the rounding of
//      `q = effectiveM + sign(effectiveM)*sqrt(D)` itself. For
//      `[[2.2, 1], [-1.21, 0]]`, both eigenvalues have an actual error of
//      about 9.197e-17 against a high-precision reference, but the old
//      `lambda1Error` was about 1.50e-22, an understatement of about six
//      orders of magnitude, because the single addition that forms `q`
//      from two already-rounded operands rounds again, by up to
//      `unitRoundoff * |q|`, and nothing accounted for that. Fixed by
//      adding that term to `lambda1Error` in both the direct (natural-unit)
//      and scaled-unit computations.
//
//   3. Underflow could break the error-free-transform (EFT) guarantees
//      inside [Matrix._compensatedDiscriminant]/[Matrix._compensatedDeterminant]
//      in two different ways. `[[2*s, s*(1+t)], [-s*(1-t), 0]]` at
//      `s = 2^-498`, `t = 2^-52` has exact discriminant `D = s^2*t^2`,
//      about 7.36e-332, and true roots `s +/- s*t`. The direct (natural
//      unit) computation returns `D = 0` with `E_D = 0` exactly: every
//      individual twoSum/twoProduct term involved is itself either exactly
//      zero or a normal double (so the existing per-term subnormal check
//      alone does not catch it), yet the true correction the discriminant
//      needs lives near `2^-1100`, below even the smallest subnormal
//      double (`2^-1074`), so it silently rounds to exactly 0 instead of
//      surviving as a representable residual. Fixed by adding a second
//      reliability check: whenever the dominant cancelling term itself is
//      small enough that a correction at double-double's own resolving
//      power (about `unitRoundoff^2`, `~2^-106` relative) would underflow
//      below `double.minPositive`, the direct computation is marked
//      unreliable and the whole-block-scaled recomputation (immune to this
//      absolute-underflow floor, since it rebases every entry near unit
//      magnitude first) is used instead.
//
//   [debugExactRealEigen2x2] is the same `@visibleForTesting` seam used by
//   the round 17 regression file, exposing [Matrix._exactRealEigen2x2]'s
//   return record directly.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:calculatrix/src/matrix/matrix.dart' show debugExactRealEigen2x2;
import 'package:test/test.dart';

import 'support/exact_quadratic.dart';

Matcher throwsLogUndefined() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.logUndefined,
  ),
);

void main() {
  group('Codex round 18', () {
    group(
      'Finding 1: the determinant input-uncertainty floor no longer hides '
      'a negative eigenvalue behind an oversized lambda2Error',
      () {
        final Matrix a = Matrix(<List<double>>[
          <double>[1.0000000000000002, 1.0],
          <double>[-1.0, -1.0],
        ]);

        test(
          'debugExactRealEigen2x2 classifies the smaller root as negative, '
          'not zero or positive',
          () {
            final eigen = debugExactRealEigen2x2(
              1.0000000000000002,
              1.0,
              -1.0,
              -1.0,
            );
            expect(eigen.isComplex, isFalse);
            final bool firstIsSmaller =
                eigen.lambda1.abs() <= eigen.lambda2.abs();
            final double smaller =
                firstIsSmaller ? eigen.lambda1 : eigen.lambda2;
            final double smallerError =
                firstIsSmaller ? eigen.lambda1Error : eigen.lambda2Error;
            expect(smaller, lessThan(0));
            expect(smaller, lessThan(-smallerError));
          },
        );

        test('sqrt() rejects the matrix instead of returning a scaled '
            'invalid result', () {
          expect(() => a.sqrt(), throwsLogUndefined());
        });
      },
    );

    group(
      'Finding 2: lambda1Error accounts for the rounding of q itself, '
      'bounding BOTH roots against high-precision enclosures',
      () {
        test(
          'debugExactRealEigen2x2 bounds both eigenvalues of '
          '[[2.2, 1], [-1.21, 0]] against arbitrary-precision references',
          () {
            final eigen = debugExactRealEigen2x2(2.2, 1.0, -1.21, 0.0);
            expect(eigen.isComplex, isFalse);
            final bool firstIsLarger =
                eigen.lambda1.abs() >= eigen.lambda2.abs();
            final double larger = firstIsLarger ? eigen.lambda1 : eigen.lambda2;
            final double largerError =
                firstIsLarger ? eigen.lambda1Error : eigen.lambda2Error;
            final double smaller =
                firstIsLarger ? eigen.lambda2 : eigen.lambda1;
            final double smallerError =
                firstIsLarger ? eigen.lambda2Error : eigen.lambda1Error;
            // Codex round 18, finding 2: a plain rounded-double reference
            // is not good enough here (round 17's own regression test made
            // exactly this mistake for the smaller root alone), because a
            // double this close to the true answer rounds right back to
            // the same double whether or not the bound under test is
            // correct. [trueQuadraticErrors] instead decomposes the exact
            // binary64 inputs and solves the characteristic polynomial
            // with BigInt arithmetic, then subtracts two exact dyadic
            // values, never two already-rounded doubles.
            final errors = trueQuadraticErrors(
              a: 2.2,
              b: 1.0,
              c: -1.21,
              d: 0.0,
              computedLarger: larger,
              computedSmaller: smaller,
            );
            expect(largerError, greaterThanOrEqualTo(errors.largerActualError));
            expect(
              smallerError,
              greaterThanOrEqualTo(errors.smallerActualError),
            );
            // The old, uncompensated-addition bound understated the larger
            // root's own error by about six orders of magnitude (Codex
            // round 18, finding 2): the true error here is about 9.2e-17,
            // so a bound anywhere near that confirms the fix, not just a
            // vacuously large one.
            expect(errors.largerActualError, lessThan(2e-16));
            expect(largerError, lessThan(1e-13));
          },
        );
      },
    );

    group(
      'Finding 3: a discriminant correction that underflows below the '
      'smallest subnormal double is no longer trusted as an exact zero',
      () {
        test(
          'debugExactRealEigen2x2 reports an error bound covering the true '
          's*t separation for [[2*s, s*(1+t)], [-s*(1-t), 0]]',
          () {
            final double s = math.pow(2.0, -498).toDouble();
            final double t = math.pow(2.0, -52).toDouble();
            final double a = 2 * s;
            final double b = s * (1 + t);
            final double c = -s * (1 - t);
            const double d = 0.0;
            final eigen = debugExactRealEigen2x2(a, b, c, d);
            expect(eigen.isComplex, isFalse);
            final double trueSplit = s * t;
            // Codex round 18, finding 3: the old, unreliability-blind direct
            // computation returned a bit-exact repeated root with a
            // zero error bound here, even though the true roots are split
            // by `s*t` (about 2.71e-166). The fixed computation must cover
            // that true split, whichever root the record reports as
            // lambda1/lambda2.
            expect(eigen.lambda1Error, greaterThanOrEqualTo(trueSplit));
            expect(eigen.lambda2Error, greaterThanOrEqualTo(trueSplit));
            // The bound must still be a genuine, non-vacuous bound: not
            // many orders of magnitude looser than the true split, and not
            // larger than the eigenvalues themselves.
            expect(eigen.lambda1Error, lessThan(s));
          },
        );
      },
    );
  });
}
