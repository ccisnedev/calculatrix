// Core PR #7 Codex round 19: one medium finding on
// [Matrix._exactRealEigen2x2]'s general 2x2 closed form, traced to round
// 18's own finding-3 fix.
//
// Round 18 added a `reliable` flag to [Matrix._compensatedDiscriminant], so
// the direct (natural-unit) discriminant is correctly rejected whenever its
// own error-free-transform terms cannot be certified sound. But the
// fallback used whenever that happens was the discriminant recomputed on
// the WHOLE-BLOCK-scaled entries, scaled by the one power of two nearest
// `max(|a|,|b|,|c|,|d|)`. That scale keeps `a`/`d` representable, but for a
// block where `a`/`d` are far larger than `b`/`c` (exactly the shape that
// makes the direct discriminant unreliable in the first place), the same
// scale crushes the already-small `b`/`c` down far enough that their
// scaled product underflows to exactly 0, even though `b`, `c` and the true
// `b*c` are each individually representable in natural units:
//
//   - `[[-1e20, 1e-150], [-2e-150, -1e20]]`: the whole-block scale (tuned
//     to `a`/`d` around `1e20`) shrinks `b`/`c` to about `1e-170` each,
//     whose product `~-3.67e-340` underflows to exactly 0, spuriously
//     reporting a repeated real root at `-1e20` instead of the true
//     complex pair `-1e20 +/- i*sqrt(2)*1e-150`. `log()` and
//     `power(0.25)` wrongly raised log-undefined instead of succeeding.
//
//   - `[[1e20, 1e-150], [4e-150, 1e20]]`: the same underflow reports both
//     roots as bit-identical `1e20` with a zero error bound, but the true
//     roots are the distinct real pair `1e20 +/- 2e-150`.
//
// Fixed by [Matrix._scaledCenteredDiscriminant]: the discriminant
// `D = h^2 + b*c` (`h = (a-d)/2`) is a property of the CENTERED block
// alone, never of `m = (a+d)/2` or the raw magnitude of `a`/`d` beyond
// their difference, so it is scaled by its own power of two chosen from
// `max(|h|, |b|, |c|)` instead, independent of whatever scale `a`/`d`
// alone might need.
//
// Codex round 20 (P6, fail closed) removed the whole-block-scaled
// discriminant fallback entirely, along with the rest of the multi-tier
// cascade this file's own second fixture used to fall through to. For
// `[[1e20, 1e-150], [4e-150, 1e20]]`, the discriminant itself now certifies
// cleanly (its own centered scale keeps every term normal), but resolving
// which root is which still requires the determinant `a*d - b*c`, computed
// on the whole-block scale tuned to `max(|a|,|b|,|c|,|d|)` (about `1e20`):
// that scale drives the already-tiny `b*c` (`~4e-300`) down far enough that
// the scaled product underflows to exactly `0`, and round 20's explicit
// underflow check now names that and fails closed instead of silently
// trusting a zeroed product. The correct D38 outcome for this fixture is
// therefore `matrix-out-of-precision-range`, not a resolved bound: a clean
// rejection is preferable to the old fallback's own, differently broken,
// zero-bound misclassification, per round 20's "a shorter certified path is
// better than a clever uncertified one".
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:calculatrix/src/matrix/matrix.dart' show debugExactRealEigen2x2;
import 'package:test/test.dart';

void main() {
  group('Codex round 19', () {
    group(
      'Finding: the whole-block-scaled discriminant fallback can itself '
      'underflow a genuine complex pair into a spurious repeated real root',
      () {
        test(
          'debugExactRealEigen2x2 reports the true complex pair for '
          '[[-1e20, 1e-150], [-2e-150, -1e20]], not a repeated real root',
          () {
            final eigen = debugExactRealEigen2x2(
              -1e20,
              1e-150,
              -2e-150,
              -1e20,
            );
            expect(eigen.isComplex, isTrue);
            expect(eigen.m, -1e20);
            final double trueW = math.sqrt(2) * 1e-150;
            // A genuine, non-vacuous bound on the rotation frequency: it
            // must be close to the true value, not zero (the old,
            // underflow-blind fallback reported this whole block as a
            // repeated real root, i.e. `w = 0`) and not wildly larger.
            expect(eigen.w, greaterThan(0));
            expect(
              (eigen.w - trueW).abs(),
              lessThan(trueW * 1e-6),
            );
          },
        );

        test(
          'log() succeeds on [[-1e20, 1e-150], [-2e-150, -1e20]] instead of '
          'wrongly raising log-undefined for a spurious negative real '
          'repeated eigenvalue',
          () {
            final Matrix m = Matrix(<List<double>>[
              <double>[-1e20, 1e-150],
              <double>[-2e-150, -1e20],
            ]);
            final Matrix result = m.log();
            expect(result.at(0, 0).isFinite, isTrue);
            expect(result.at(1, 1).isFinite, isTrue);
            // The dominant real part of every eigenvalue's log is
            // ln(1e20); the trace of the log is the sum of the two
            // eigenvalues' logs, so each diagonal entry's real part sits
            // near that magnitude.
            expect(result.at(0, 0), closeTo(math.log(1e20), 1e-6));
          },
        );

        test(
          'power(0.25) succeeds on [[-1e20, 1e-150], [-2e-150, -1e20]] '
          'instead of wrongly raising log-undefined',
          () {
            final Matrix m = Matrix(<List<double>>[
              <double>[-1e20, 1e-150],
              <double>[-2e-150, -1e20],
            ]);
            final Matrix result = m.power(Matrix.scalar(0.25));
            expect(result.at(0, 0).isFinite, isTrue);
            expect(result.at(1, 1).isFinite, isTrue);
          },
        );
      },
    );

    group(
      'Finding: the same underflow can also erase a genuine tiny real '
      'separation, reporting a zero bound instead of one covering it',
      () {
        // Codex round 20 (P6, fail closed): this fixture's discriminant now
        // certifies cleanly, but the whole-block scale tuned to `a`/`d`
        // (around `1e20`) still underflows the determinant's `b*c`
        // (`~4e-300`) to exactly `0`; round 20's explicit underflow check
        // now names that and fails closed instead of the old fallback's own
        // zero-bound misclassification. See this file's header comment for
        // the full explanation.
        test(
          'debugExactRealEigen2x2 raises matrix-out-of-precision-range for '
          '[[1e20, 1e-150], [4e-150, 1e20]] instead of reporting a zero '
          'bound over the true 2e-150 separation',
          () {
            expect(
              () => debugExactRealEigen2x2(1e20, 1e-150, 4e-150, 1e20),
              throwsA(
                isA<MatrixDomainError>().having(
                  (MatrixDomainError e) => e.errorId,
                  'errorId',
                  CalculatrixErrorId.matrixOutOfPrecisionRange,
                ),
              ),
            );
          },
        );
      },
    );
  });
}
