// Core PR #7 Codex round 20, 3 medium findings, all inside the fallback
// paths [Matrix._exactRealEigen2x2] had accumulated across rounds 9 through
// 19 (up to three discriminant recomputations, up to three determinant
// recomputations, each tried only when an earlier one failed to certify):
//
//   1. `s = 2^-490`, `A = s*[[2,1],[1-2^-52,0.5]]` (and the `+2^-52`
//      variant): the smaller eigenvalue is approximately `2.77845e-164`,
//      below `matrixFunctionMinMagnitude=1e-150`, but the whole-block-scaled
//      fallback's own error bound was inflated enough to hide that a
//      genuinely nonzero, out-of-range eigenvalue was being reported instead
//      of raising `matrix-out-of-precision-range`.
//
//   2. `[[2e-160,1e-160],[3e-160,4e-160]]`: the returned determinant bound
//      was `1.11e-175` against an actual error of about `1.11e-165`, ten
//      orders of magnitude too tight. `[[1e150,1e-85],[2e-85,0]]`: the
//      second root's bound was exactly `0`, a vacuous bound.
//
//   3. `1.0000000000000002 ^ [[1.8e17,1e-150],[4e-150,1.8e17]]`: the smaller
//      eigenvalue's error bound resolved as `NaN`, and the operation still
//      succeeded instead of rejecting an uncertifiable result.
//
// Fixed by removing the cascade entirely (P6, fail closed):
// [Matrix._exactRealEigen2x2] now computes the discriminant exactly once
// (on the power-of-two scale [Matrix._scaledCenteredDiscriminant] chooses
// from `max(|h|,|b|,|c|)`) and the determinant exactly once (on the
// whole-block scale tuned to `max(|a|,|b|,|c|,|d|)`, since `det` genuinely
// depends on `a`/`d`'s raw magnitude, unlike the discriminant). Every
// error-free-transform term feeding either computation must certify as a
// normal double or an exact zero from a zero operand, every error bound
// must be finite and non-negative, and rescaling either result back to
// natural units must be exact; whenever any of that fails, the whole
// operation raises `matrix-out-of-precision-range` instead of trying
// another path. A shorter certified path is better than a clever
// uncertified one.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:calculatrix/src/matrix/matrix.dart' show debugExactRealEigen2x2;
import 'package:test/test.dart';

import 'support/exact_quadratic.dart';

Matcher throwsOutOfPrecisionRange() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.matrixOutOfPrecisionRange,
  ),
);

/// Runs [debugExactRealEigen2x2] on one fixture and asserts the P6
/// invariant: either it raises `matrix-out-of-precision-range` (an
/// acceptable, honest rejection), or every returned field is finite, no
/// error bound is negative or NaN, and, for the real branch, both bounds
/// cover the exact-dyadic reference error [exact_quadratic.dart] computes
/// from the stored binary64 entries themselves.
void expectCertifiedOrRejected(double a, double b, double c, double d) {
  final ({
    bool isComplex,
    double lambda1,
    double lambda2,
    double m,
    double w,
    double lambda1Error,
    double lambda2Error,
  })
  eigen;
  try {
    eigen = debugExactRealEigen2x2(a, b, c, d);
  } on MatrixDomainError catch (e) {
    expect(
      e.errorId,
      CalculatrixErrorId.matrixOutOfPrecisionRange,
      reason:
          'a=$a b=$b c=$c d=$d: only matrix-out-of-precision-range is an '
          'acceptable rejection',
    );
    return;
  }

  expect(eigen.m.isFinite, isTrue, reason: 'a=$a b=$b c=$c d=$d: m');
  expect(eigen.w.isFinite, isTrue, reason: 'a=$a b=$b c=$c d=$d: w');
  expect(
    eigen.w,
    greaterThanOrEqualTo(0),
    reason: 'a=$a b=$b c=$c d=$d: w must never be negative',
  );
  expect(
    eigen.lambda1Error.isNaN,
    isFalse,
    reason: 'a=$a b=$b c=$c d=$d: lambda1Error must never be NaN',
  );
  expect(
    eigen.lambda2Error.isNaN,
    isFalse,
    reason: 'a=$a b=$b c=$c d=$d: lambda2Error must never be NaN',
  );
  expect(eigen.lambda1Error.isFinite, isTrue, reason: 'a=$a b=$b c=$c d=$d');
  expect(eigen.lambda2Error.isFinite, isTrue, reason: 'a=$a b=$b c=$c d=$d');
  expect(
    eigen.lambda1Error,
    greaterThanOrEqualTo(0),
    reason: 'a=$a b=$b c=$c d=$d',
  );
  expect(
    eigen.lambda2Error,
    greaterThanOrEqualTo(0),
    reason: 'a=$a b=$b c=$c d=$d',
  );

  if (eigen.isComplex) {
    return;
  }

  // [trueQuadraticErrors] pairs `computedLarger`/`computedSmaller` against
  // `(trace +/- sqrtDiscriminant) / 2`, the algebraically greater/smaller
  // root, never the larger-magnitude one: for two roots sharing a sign
  // (for example the triangular `[[-2000,0],[0,-2100]]`, both negative),
  // the larger-MAGNITUDE root is the algebraically SMALLER one, so an
  // abs()-based comparator would pair the wrong reference against each
  // computed value.
  final bool firstIsLarger = eigen.lambda1 >= eigen.lambda2;
  final double larger = firstIsLarger ? eigen.lambda1 : eigen.lambda2;
  final double largerError = firstIsLarger
      ? eigen.lambda1Error
      : eigen.lambda2Error;
  final double smaller = firstIsLarger ? eigen.lambda2 : eigen.lambda1;
  final double smallerError = firstIsLarger
      ? eigen.lambda2Error
      : eigen.lambda1Error;
  final errors = trueQuadraticErrors(
    a: a,
    b: b,
    c: c,
    d: d,
    computedLarger: larger,
    computedSmaller: smaller,
  );
  expect(
    largerError,
    greaterThanOrEqualTo(errors.largerActualError),
    reason: 'a=$a b=$b c=$c d=$d: larger root bound must cover actual error',
  );
  expect(
    smallerError,
    greaterThanOrEqualTo(errors.smallerActualError),
    reason: 'a=$a b=$b c=$c d=$d: smaller root bound must cover actual error',
  );
}

void main() {
  group('Codex round 20 (P6, fail closed)', () {
    group(
      'Regressions: round 20\'s own three findings must resolve correctly '
      'or fail closed, never a wrong classification, an understated bound '
      'or NaN',
      () {
        test(
          'finding 1: s=2^-490, A=s*[[2,1],[1-2^-52,0.5]] must raise '
          'matrix-out-of-precision-range from sqrt(), not report an '
          'inflated bound around the true ~2.77845e-164 eigenvalue',
          () {
            final double s = math.pow(2.0, -490).toDouble();
            final double eps = math.pow(2.0, -52).toDouble();
            final Matrix minusEps = Matrix(<List<double>>[
              <double>[2 * s, 1 * s],
              <double>[(1 - eps) * s, 0.5 * s],
            ]);
            expect(() => minusEps.sqrt(), throwsOutOfPrecisionRange());
          },
        );

        test(
          'finding 1 variant: the +2^-52 perturbation (a negative smaller '
          'eigenvalue) must also raise matrix-out-of-precision-range, not '
          'let sqrt() succeed on a negative real eigenvalue',
          () {
            final double s = math.pow(2.0, -490).toDouble();
            final double eps = math.pow(2.0, -52).toDouble();
            final Matrix plusEps = Matrix(<List<double>>[
              <double>[2 * s, 1 * s],
              <double>[(1 + eps) * s, 0.5 * s],
            ]);
            expect(() => plusEps.sqrt(), throwsOutOfPrecisionRange());
          },
        );

        test(
          'finding 2: [[2e-160,1e-160],[3e-160,4e-160]] must either return '
          'a valid bound covering the true determinant error or raise '
          'matrix-out-of-precision-range, never the ten-orders-too-tight '
          'bound round 20 found',
          () {
            expectCertifiedOrRejected(2e-160, 1e-160, 3e-160, 4e-160);
          },
        );

        test(
          'finding 2 companion: [[1e150,1e-85],[2e-85,0]] must either '
          'return a valid nonzero bound for the second root or raise '
          'matrix-out-of-precision-range, never a vacuous zero bound',
          () {
            expectCertifiedOrRejected(1e150, 1e-85, 2e-85, 0);
          },
        );

        test(
          'finding 3: 1.0000000000000002 ^ [[1.8e17,1e-150],[4e-150,1.8e17]] '
          'must be certified or cleanly rejected, never resolve a NaN '
          'lambda2Error while still succeeding',
          () {
            final Matrix base = Matrix(<List<double>>[
              <double>[1.8e17, 1e-150],
              <double>[4e-150, 1.8e17],
            ]);
            try {
              final Matrix result = base.power(
                Matrix.scalar(1.0000000000000002),
              );
              expect(result.at(0, 0).isNaN, isFalse);
              expect(result.at(1, 1).isNaN, isFalse);
            } on MatrixDomainError catch (e) {
              expect(e.errorId, CalculatrixErrorId.matrixOutOfPrecisionRange);
            }
            expectCertifiedOrRejected(1.8e17, 1e-150, 4e-150, 1.8e17);
          },
        );
      },
    );

    group(
      'Invariant: every 2x2 fixture from the round 17 to 23 test files '
      'either fails closed with matrix-out-of-precision-range or returns '
      'finite, non-NaN bounds covering the exact-dyadic reference error',
      () {
        test('round 17 through round 23 fixtures', () {
          final double t50 = math.pow(2.0, -50).toDouble();
          final double s498 = math.pow(2.0, -498).toDouble();
          final double t52 = math.pow(2.0, -52).toDouble();
          final double s498a = 2 * s498;
          final double s498b = s498 * (1 + t52);
          final double s498c = -s498 * (1 - t52);

          final List<List<double>> fixtures = <List<double>>[
            // round17_codex_round13_test.dart
            <double>[1e-150, 1, 0, 2e-150],
            <double>[-2000, 0, 0, -2100],
            // round18_codex_round14_test.dart
            <double>[2, 0, 0, 3],
            <double>[0.6e150, 0.6e150, 0.6e150, 0.6e150],
            // round19_codex_round15_test.dart
            <double>[1e-140, 1e-140, 1e-140, 1e-140 * (1 + t50)],
            <double>[1e-140, 1e-140 * (1 + t50), 1e-140, 1e-140],
            <double>[6e149, 6e149, 6e149, 6e149],
            // round20_codex_round16_test.dart
            <double>[1e-140, 1e-140, 1e-140, 1e-140 * (1 - t50)],
            // round21_codex_round17_test.dart
            <double>[1.0000000000000002, 1.0, -1.0, -1.0],
            <double>[2.2, 1.0, -1.21, 0.0],
            <double>[s498a, s498b, s498c, 0.0],
            <double>[4.0, 1.0, 1e-30, 1e-18],
            <double>[5.0, 1e-9, 1e-9, 5.0],
            <double>[2.0, 1.0, -1.0, 0.0],
            // round22_codex_round18_test.dart repeats the
            // 1.0000000000000002 and 2.2 fixtures above and the s498
            // fixture with the same values, already covered.
            // round23_codex_round19_test.dart
            <double>[-1e20, 1e-150, -2e-150, -1e20],
            <double>[1e20, 1e-150, 4e-150, 1e20],
          ];

          for (final List<double> f in fixtures) {
            expectCertifiedOrRejected(f[0], f[1], f[2], f[3]);
          }
        });
      },
    );
  });
}
