// Core PR #7 Codex round 17, 2 medium findings on
// [Matrix._exactRealEigen2x2]'s general 2x2 closed form:
//
//   1. Rounded-zero discriminant hides a negative eigenvalue. For
//      `A = [[1.0000000000000002, 1], [-1, -1]]`, the exact eigenvalues of
//      these exact double inputs are approximately +1.49011613e-8 and
//      -1.49011611e-8, but naive floating point arithmetic computes
//      `(a-d)/2` as exactly `1` (the true value's low-order bit, `2^-52`,
//      is lost to rounding once `a-d` is added as a single double), so the
//      discriminant `halfDiff^2 + b*c` computes as exactly `1 - 1 = 0`,
//      spuriously classifying this genuine sign split as a repeated
//      positive eigenvalue at `2^-53`. [Matrix.log] and a non-integer
//      [Matrix.power] must instead see the true negative eigenvalue and
//      raise logUndefined.
//
//   2. The round 16 `zeroTolerance` is not a genuine error bound for the
//      smaller eigenvalue `det / lambda1`. For `[[2.2, 1], [-1.21, 0]]`,
//      cancellation in the discriminant amplifies through the square root
//      into `lambda1`, and from there into `lambda2 = det / lambda1`: the
//      naive implementation's computed smaller eigenvalue was off by about
//      2.95e-10 from a high-precision reference, while the returned
//      tolerance was only about 1.22e-15, an underestimate by five orders
//      of magnitude.
//
//   Fixed at the root (P4): every real eigenvalue from the 2x2 closed form
//   now carries its own computed error bound, never a shared, single
//   tolerance for both roots, and classification is always
//   `|lambda| <= e => zero`, `lambda > e => positive`, `lambda < -e =>
//   negative`, never an exact-equality or exact-zero check on a raw
//   floating point value.
//
//   The discriminant `D = ((a-d)/2)^2 + b*c` and the determinant
//   `det = a*d - b*c` are now computed with Dekker/Veltkamp error-free
//   transforms (twoSum, twoProduct; dart:math has no native fma), which
//   both correct the cancellation-prone subtraction (fixing finding 1, by
//   actually recovering the lost precision instead of just widening a
//   tolerance around the wrong answer) and produce a rigorous first-order
//   bound on their own residual error, `E_D` and `E_det`. Three regimes:
//     - `D > E_D`: two distinct real roots. `lambda1` is the
//       larger-magnitude root (`m + sign(m)*sqrt(D)`, safe from
//       cancellation by construction), `lambda2 = det / lambda1`. Each
//       root's own error bound propagates every term that can move it:
//       `E_D`'s contribution through the square root
//       (`E_D / (2*sqrt(D))`), the square root's own rounding
//       (`unitRoundoff * sqrt(D)`), `m`'s own twoSum residual, `E_det`
//       propagated through the division, the denominator term
//       `|lambda2| * E_lambda1 / |lambda1|` (how `lambda1`'s own
//       uncertainty moves the quotient), and division rounding, all
//       wrapped in the existing Jacobi backward-error safety factor.
//     - `D < -E_D`: complex conjugate pair, unchanged from before.
//     - `|D| <= E_D` (unresolved): the true roots lie within
//       `r = sqrt(E_D + |D|)` of `m`. If `|m| > r + err(m)`, both roots
//       share `m`'s sign well outside the noise floor: treated as a
//       (near-)repeated root at `m`, with error bound `r + err(m)` (this
//       is also what an exactly repeated, non-triangular eigenvalue now
//       resolves through, replacing the old bit-exact
//       `discriminant == 0` check). Otherwise the sign genuinely cannot be
//       resolved from these inputs, and `m`'s own magnitude is within its
//       error bound, so classification correctly reports zero.
//   The exactly triangular fast path keeps a `0` error bound for both
//   eigenvalues (raw diagonal entries, no arithmetic between them).
//
//   [debugExactRealEigen2x2] is a `@visibleForTesting` seam (matching the
//   existing `debugCyclicJacobiSqrtWithSweepBudget` pattern) exposing
//   [Matrix._exactRealEigen2x2]'s return record directly, since several
//   assertions below need the raw per-eigenvalue error bound, not just an
//   end-to-end success/failure through the public API.
import 'package:calculatrix/calculatrix.dart';
import 'package:calculatrix/src/matrix/matrix.dart' show debugExactRealEigen2x2;
import 'package:test/test.dart';

Matcher throwsLogUndefined() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.logUndefined,
  ),
);

Matcher throwsOutOfPrecisionRange() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.matrixOutOfPrecisionRange,
  ),
);

void main() {
  group('Codex round 17', () {
    group(
      'Finding 1: a rounded-zero discriminant no longer hides a negative '
      'eigenvalue',
      () {
        final Matrix a = Matrix(<List<double>>[
          <double>[1.0000000000000002, 1.0],
          <double>[-1.0, -1.0],
        ]);

        test('log raises log-undefined instead of succeeding', () {
          expect(() => a.log(), throwsLogUndefined());
        });

        test(
          'power(scalar(0.5)) raises log-undefined instead of succeeding',
          () {
            expect(
              () => a.power(Matrix.scalar(0.5)),
              throwsLogUndefined(),
            );
          },
        );

        test(
          'debugExactRealEigen2x2 resolves one positive and one negative '
          'eigenvalue, not a repeated positive pair',
          () {
            final eigen = debugExactRealEigen2x2(
              1.0000000000000002,
              1.0,
              -1.0,
              -1.0,
            );
            expect(eigen.isComplex, isFalse);
            final bool firstIsLarger =
                eigen.lambda1.abs() >= eigen.lambda2.abs();
            final double larger = firstIsLarger ? eigen.lambda1 : eigen.lambda2;
            final double smaller = firstIsLarger ? eigen.lambda2 : eigen.lambda1;
            expect(larger, closeTo(1.49011613e-8, 1e-14));
            expect(smaller, closeTo(-1.49011611e-8, 1e-14));
          },
        );
      },
    );

    group(
      'Finding 2: the returned error bound is a genuine bound on '
      'det / lambda1, not an underestimate',
      () {
        test(
          'debugExactRealEigen2x2 bounds the actual error against a '
          'high-precision reference',
          () {
            final eigen = debugExactRealEigen2x2(2.2, 1.0, -1.21, 0.0);
            expect(eigen.isComplex, isFalse);
            final bool firstIsSmaller =
                eigen.lambda1.abs() <= eigen.lambda2.abs();
            final double smaller =
                firstIsSmaller ? eigen.lambda1 : eigen.lambda2;
            final double smallerError =
                firstIsSmaller ? eigen.lambda1Error : eigen.lambda2Error;
            // High-precision reference for the smaller eigenvalue (Codex
            // round 17, finding 2), from an arbitrary-precision solve of
            // this exact 2x2's characteristic polynomial.
            const double reference = 1.099999984803737748;
            final double actualError = (smaller - reference).abs();
            expect(smallerError, greaterThanOrEqualTo(actualError));
            // The naive, uncompensated implementation's own error was
            // about 2.95e-10 (Codex round 17, finding 2); this fix must
            // make the computed value itself far more accurate, not just
            // widen the bound to hide that same error.
            expect(actualError, lessThan(2.95e-10));
          },
        );
      },
    );

    group(
      'Regression: the s=1e-140 fixtures (Codex round 16) now resolve their '
      'residual eigenvalue as genuinely nonzero and below '
      'matrixFunctionMinMagnitude, both signs (superseded by Codex round '
      '18\'s removal of the general 2x2 closed form\'s mixed error model; '
      'see round22_codex_round18_test.dart and round20_codex_round16_test.'
      'dart)',
      () {
        const double s = 1e-140;
        const double delta = 8.881784197001252e-16;

        test('positive residual', () {
          final Matrix m = Matrix(<List<double>>[
            <double>[s, s],
            <double>[s, s * (1 + delta)],
          ]);
          expect(() => m.sqrt(), throwsOutOfPrecisionRange());
          expect(() => m.log(), throwsOutOfPrecisionRange());
          expect(
            () => m.power(Matrix.scalar(0.5)),
            throwsOutOfPrecisionRange(),
          );
        });

        test('negative residual', () {
          final Matrix m = Matrix(<List<double>>[
            <double>[s, s],
            <double>[s, s * (1 - delta)],
          ]);
          expect(() => m.sqrt(), throwsOutOfPrecisionRange());
          expect(() => m.log(), throwsOutOfPrecisionRange());
          expect(
            () => m.power(Matrix.scalar(0.5)),
            throwsOutOfPrecisionRange(),
          );
        });
      },
    );

    test(
      'Regression: a wide-spectrum matrix ([[4,1],[1e-30,1e-18]]) keeps its '
      'genuinely resolvable ~1e-18 eigenvalue, not classified as zero',
      () {
        final eigen = debugExactRealEigen2x2(4.0, 1.0, 1e-30, 1e-18);
        expect(eigen.isComplex, isFalse);
        final bool firstIsSmaller = eigen.lambda1.abs() <= eigen.lambda2.abs();
        final double smaller = firstIsSmaller ? eigen.lambda1 : eigen.lambda2;
        final double smallerError =
            firstIsSmaller ? eigen.lambda1Error : eigen.lambda2Error;
        expect(smaller.abs(), closeTo(1e-18, 1e-25));
        expect(smaller.abs() > smallerError, isTrue);
        final Matrix m = Matrix(<List<double>>[
          <double>[4.0, 1.0],
          <double>[1e-30, 1e-18],
        ]);
        expect(() => m.log(), returnsNormally);
      },
    );

    test(
      'Regression: a symmetric 2x2 with a near-repeated but genuinely '
      'distinct eigenvalue pair resolves as distinct',
      () {
        final Matrix m = Matrix(<List<double>>[
          <double>[5.0, 1e-9],
          <double>[1e-9, 5.0],
        ]);
        final eigen = debugExactRealEigen2x2(5.0, 1e-9, 1e-9, 5.0);
        expect(eigen.isComplex, isFalse);
        expect((eigen.lambda1 - eigen.lambda2).abs(), closeTo(2e-9, 1e-12));
        final Matrix root = m.sqrt();
        final Matrix squared = root * root;
        expect(squared.at(0, 0), closeTo(5.0, 1e-12));
        expect(squared.at(0, 1), closeTo(1e-9, 1e-14));
        expect(squared.at(1, 0), closeTo(1e-9, 1e-14));
        expect(squared.at(1, 1), closeTo(5.0, 1e-12));
        expect(() => m.log(), returnsNormally);
      },
    );

    test(
      'Regression: an exactly repeated, non-triangular eigenvalue is still '
      'resolved as repeated through the unresolved-discriminant branch, not '
      'a bit-exact discriminant equality check',
      () {
        // a=2, b=1, c=-1, d=0: exact discriminant is 0 (halfDiff=1,
        // b*c=-1), repeated eigenvalue at m=1.
        final eigen = debugExactRealEigen2x2(2.0, 1.0, -1.0, 0.0);
        expect(eigen.isComplex, isFalse);
        expect(eigen.lambda1, 1.0);
        expect(eigen.lambda2, 1.0);
      },
    );
  });
}
