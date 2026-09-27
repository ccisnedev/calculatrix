// Core PR #7 Codex round 21: one Low finding on
// [Matrix._exactRealEigen2x2], found after round 20's fail-closed rewrite
// (e54e463) was itself judged sound against 17,057 high-precision
// comparisons.
//
// Finding: underflowed uncertainty becomes a certified zero bound.
// `s = double.minPositive`, `debugExactRealEigen2x2(5*s, 2*s, -2*s, 0)`
// returned both eigenvalues as `2*s` with both error bounds exactly `0`,
// but the exact eigenvalues (the characteristic polynomial factors as
// `(lambda - 4*s)*(lambda - s)`) are `4*s` and `s`, a genuinely distinct
// pair, not a repeated root at `2*s`.
//
// Root cause: `double.minPositive` is the smallest representable
// subnormal, so it has no bit of precision left to spare. Halving the
// trace `(a+d)/2` and the centered half-difference `(a-d)/2` both divide
// an odd multiple of `double.minPositive` (`5*s`) by 2; the true half,
// `2.5*s`, sits exactly between the two nearest representable subnormals
// (`2*s` and `3*s`), so it rounds (to even) to `2*s`, silently losing the
// `0.5*s` remainder with no residual left anywhere to record it. Neither
// halving was ever checked for exactness. The corrupted half then feeds a
// discriminant that comes out exactly `0` in its own scaled units, and
// rescaling that scaled discriminant's uncertainty radius back to natural
// units (multiplying by `2^scale`, with `scale` around `-1073` here)
// underflows a genuinely nonzero radius to exactly `0.0`, which looked
// like a valid, fully-resolved zero bound instead of the sign that the
// computation had already lost the answer before the discriminant was
// ever formed.
//
// Fixed by verifying the halvings of `m` (the trace's half) and `h` (the
// centered block's half-difference) are exact, checking that doubling the
// computed half exactly recovers the original sum, and by verifying every
// power-of-two rescale of an uncertainty quantity back to natural units
// never turns a nonzero scaled value into an exact `0`. Either failure now
// fails closed (`matrix-out-of-precision-range`) instead of silently
// trusting an under-resolved bound.
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
  group('Codex round 21 (P6 follow-up)', () {
    group(
      'Finding: halving the trace or the centered half-difference can lose '
      'a bit at the smallest subnormal scale, and rescaling a '
      'repeated-root radius back to natural units can underflow a '
      'genuinely nonzero radius to an exactly-zero bound',
      () {
        test(
          'debugExactRealEigen2x2 raises matrix-out-of-precision-range for '
          '5*s, 2*s, -2*s, 0 (s = double.minPositive) instead of reporting '
          'a certified zero bound around a wrong repeated root, when the '
          'true eigenvalues are the distinct 4*s and s',
          () {
            final double s = double.minPositive;
            expect(
              () => debugExactRealEigen2x2(5 * s, 2 * s, -2 * s, 0),
              throwsOutOfPrecisionRange(),
            );
          },
        );

        test(
          'the mirrored negative-entries block also raises '
          'matrix-out-of-precision-range instead of a certified zero bound '
          'around a wrong repeated root, when the true eigenvalues are the '
          'distinct -4*s and -s',
          () {
            final double s = double.minPositive;
            expect(
              () => debugExactRealEigen2x2(-5 * s, -2 * s, 2 * s, 0),
              throwsOutOfPrecisionRange(),
            );
          },
        );
      },
    );
  });
}
