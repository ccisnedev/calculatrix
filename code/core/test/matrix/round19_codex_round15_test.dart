// Core PR #7 Codex round 15, 3 medium findings plus one test-isolation
// note:
//
//   Finding 1: [Matrix._requireSpectrumInPrecisionRange]'s general 2x2
//      real-eigenvalue-pair branch (and, since a 2x2 exactly-symmetric
//      operand also falls through to this same branch, that case too)
//      supplied a hardcoded zero tolerance of 0 for both eigenvalues,
//      instead of the same block-local backward-error bound
//      [Matrix._cyclicJacobiEigendecomposition] already computes for its
//      own iterative branch. A closed-form 2x2 eigenvalue solve has its
//      own backward error from the same source (subtraction, sqrt,
//      division, all in finite precision), not "no rotation noise at all"
//      as if it were exact, so a genuinely negligible eigenvalue (an
//      artifact of catastrophic cancellation in a nearly-singular 2x2, not
//      a meaningful nonzero result) was wrongly rejected as out of the
//      declared range instead of being classified zero and skipped, the
//      same as the Jacobi branch already does. Fixed by
//      [Matrix._blockZeroTolerance], the same scaled-Frobenius-norm
//      backward-error bound computed directly from the 2x2's own four
//      entries, supplied to [Matrix._requireEigenvaluesInPrecisionRange]
//      instead of a hardcoded 0.
//   Finding 2: [Matrix._cosPi]/[Matrix._sinPi]'s exact argument reduction,
//      `r = y - 2*round(y/2)`, called `.round()` on a `double`, which
//      returns a native `int`; on the native VM, `int` is a wrapping
//      64-bit signed type. For `y` at or beyond 2^63, `(y / 2).round()`
//      either overflows outright (2^64: `y/2` = 2^63, itself outside the
//      representable int64 range) or multiplying an in-range rounded
//      value by 2 wraps to a negative int (2^63: `y/2` rounds to the
//      in-range 2^62, but `2 * 2^62` overflows int64 and wraps to
//      -2^63), silently corrupting the reduced argument instead of
//      preserving the exact identity an even huge exponent is entitled
//      to. Fixed by replacing `.round()` with `.roundToDouble()`, which
//      keeps the whole computation in floating point (no `int` involved
//      at any point, so no wraparound at any magnitude).
//   Finding 3: [Matrix._powerByMatrixExponent] called
//      [Matrix._requireSpectrumInPrecisionRange] on both operands
//      unconditionally, before deciding whether the base/exponent pairing
//      is even one of the three pairings [Matrix.power]'s kind dispatch
//      supports (D25/D34). A pairing outside all three (e.g. two general,
//      non-scalar, non-complex-form operands) must fall through to
//      ambiguous-power regardless of either operand's magnitude, the same
//      way it would if both operands were comfortably in range; the
//      premature spectrum check instead intercepted it first with
//      matrix-out-of-precision-range whenever an operand's own eigenvalue
//      happened to be out of range, reversing D25/D34's kind-before-
//      magnitude precedence. Fixed by moving each spectrum check into the
//      specific branch it actually gates, after that branch has already
//      established the pairing is one of the three permitted ones.
//   Test note: round 14's general-2x2-exponent regression test (see
//      round18_codex_round14_test.dart) used a scalar(2) base, whose
//      RESULT-range check (`exp(1.2e150 * ln 2)` overflowing) would have
//      independently caught the bad exponent even if the operand-spectrum
//      gate it meant to test were removed entirely. Reworked there to use
//      scalar(1) instead (log(1) = 0, so the scaled-and-exponentiated
//      result is the identity, trivially in range, unless the
//      operand-spectrum gate itself rejects the exponent's own
//      out-of-range eigenvalue first), which genuinely isolates the gate.
//
// Every numeric reference value below not already exactly representable was
// either independently derived by hand from each case's own closed form, or
// probed directly from a sub-expression the fix leaves untouched, not
// copied from this implementation's own end-to-end output.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

Matcher throwsOutOfPrecisionRange() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.matrixOutOfPrecisionRange,
  ),
);

Matcher throwsAmbiguousPower() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.ambiguousPower,
  ),
);

void main() {
  group('Codex round 15', () {
    group('finding 1: numerical-zero eigenvalues in a 2x2 spectrum', () {
      test(
        'a nearly-singular 2x2 operand whose true eigenvalues are '
        'approximately 2s and a tiny numerical-zero residual: s = 1e-140, '
        'Y = [[s,s],[s,s*(1+2^-50)]] has true eigenvalues approximately 2s '
        'and -s*2^-50/2 (about -4.89e-156), well within this 2x2 block\'s '
        'own backward-error bound (10 * 2 * unitRoundoff * '
        'frobeniusNorm(block), about 4.44e-155, since the block\'s '
        'Frobenius norm is about 2s). scalar(1).power(Y) must classify '
        'that residual eigenvalue zero before the D38 range check ever '
        'sees it, and log(1) = 0 makes the scaled-and-exponentiated result '
        'the identity',
        () {
          final double s = 1e-140;
          final double d = math.pow(2.0, -50) as double;
          final Matrix y = Matrix(<List<double>>[
            <double>[s, s],
            <double>[s, s * (1 + d)],
          ]);

          final Matrix result = Matrix.scalar(1).power(y);

          expect(result.at(0, 0), 1.0);
          expect(result.at(0, 1), 0.0);
          expect(result.at(1, 0), 0.0);
          expect(result.at(1, 1), 1.0);
        },
      );

      test(
        'the same numerical-zero classification also applies to a general '
        '(non-symmetric) 2x2 operand, not only a symmetric one: '
        'Y2 = [[s,s*(1+2^-50)],[s,s]] has off-diagonal entries s*(1+2^-50) '
        'and s that differ, so Y2 is not exactly symmetric, yet its true '
        'eigenvalues are the same order of magnitude as the symmetric case '
        'above (approximately 2s and -s*2^-50/2), and both route through '
        'the identical general-2x2 branch of '
        '[Matrix._requireSpectrumInPrecisionRange]',
        () {
          final double s = 1e-140;
          final double d = math.pow(2.0, -50) as double;
          final Matrix y2 = Matrix(<List<double>>[
            <double>[s, s * (1 + d)],
            <double>[s, s],
          ]);

          final Matrix result = Matrix.scalar(1).power(y2);

          expect(result.at(0, 0), 1.0);
          expect(result.at(0, 1), 0.0);
          expect(result.at(1, 0), 0.0);
          expect(result.at(1, 1), 1.0);
        },
      );
    });

    group(
      'finding 2: exact-turn reduction must not overflow native ints',
      () {
        test(
          'a scalar(-1) base raised to a complex-form exponent whose real '
          'part is exactly 2^63 (an even integer): the true result is '
          '(-1)^(2^63) = 1, since 2^63 is even; the reduction bug wraps '
          'the argument to 2^64 instead of the correct 0',
          () {
            final Matrix result = Matrix.scalar(
              -1,
            ).power(Matrix.complex(9223372036854775808.0, 0));

            expect(result.at(0, 0), 1.0);
            expect(result.at(0, 1), 0.0);
            expect(result.at(1, 0), 0.0);
            expect(result.at(1, 1), 1.0);
          },
        );

        test(
          'a scalar(-1) base raised to a complex-form exponent whose real '
          'part is exactly 2^64 (an even integer, and itself already '
          'outside the representable int64 range, so the old '
          '.round()-based reduction could not even complete): the true '
          'result is (-1)^(2^64) = 1',
          () {
            final Matrix result = Matrix.scalar(
              -1,
            ).power(Matrix.complex(18446744073709551616.0, 0));

            expect(result.at(0, 0), 1.0);
            expect(result.at(0, 1), 0.0);
            expect(result.at(1, 0), 0.0);
            expect(result.at(1, 1), 1.0);
          },
        );

        test(
          'a scalar(-1) base raised to a complex-form exponent whose real '
          'part is 1e149 (far beyond 2^63, still within the D38 declared '
          'operand range so this exercises the reduction itself rather '
          'than the entry range check, and already integer-valued as a '
          'double, having no fractional bits left at that magnitude): the '
          'exact-turn reduction must still complete without throwing and '
          'without a wrapped, wrong reduced argument',
          () {
            final Matrix result = Matrix.scalar(
              -1,
            ).power(Matrix.complex(1e149, 0));

            expect(result.at(0, 0), 1.0);
            expect(result.at(0, 1), 0.0);
            expect(result.at(1, 0), 0.0);
            expect(result.at(1, 1), 1.0);
          },
        );

        test(
          'the complex-form-base counterpart of the same site: '
          'complex(-1,0).power(complex(2^63,0)) reaches the OTHER '
          '_exactRealExponentComplexPower call site in '
          '_powerByMatrixExponent (a complex-form base whose own imaginary '
          'part is exactly zero, raised to a complex-form exponent whose '
          'own imaginary part is exactly zero), with the same true result, '
          '(-1)^(2^63) = 1',
          () {
            final Matrix result = Matrix.complex(
              -1,
              0,
            ).power(Matrix.complex(9223372036854775808.0, 0));

            expect(result.at(0, 0), 1.0);
            expect(result.at(0, 1), 0.0);
            expect(result.at(1, 0), 0.0);
            expect(result.at(1, 1), 1.0);
          },
        );
      },
    );

    group(
      'finding 3: kind dispatch must precede spectrum validation',
      () {
        test(
          'a fundamentally ambiguous pairing (a general, non-scalar, '
          'non-complex-form base and a non-scalar exponent) must raise '
          'ambiguous-power even when the base\'s own spectrum is also out '
          'of the D38 declared range, since D25/D34\'s kind-based '
          'precedence decides the pairing is unsupported before any '
          'magnitude concern is even considered: '
          'B = [[6e149,6e149],[6e149,6e149]] has exact eigenvalues 0 and '
          '1.2e150 (both entries in range individually, but the nonzero '
          'eigenvalue exceeds matrixFunctionMaxMagnitude); B is not '
          'complex-form (its off-diagonal entries are equal, not negated), '
          'so B.power(identity(2)) can never reach a permitted branch and '
          'must raise ambiguous-power, not matrix-out-of-precision-range',
          () {
            final Matrix b = Matrix(<List<double>>[
              <double>[6e149, 6e149],
              <double>[6e149, 6e149],
            ]);

            expect(
              () => b.power(Matrix.identity(2)),
              throwsAmbiguousPower(),
            );
          },
        );

        test(
          'the previously-existing behavior for a genuinely permitted '
          'pairing is unaffected by moving the spectrum checks: a positive '
          'scalar base with an out-of-range exponent spectrum still raises '
          'matrix-out-of-precision-range (unchanged from round 14), not '
          'ambiguous-power, since scalar(1) IS a permitted base kind',
          () {
            final Matrix exponent = Matrix(<List<double>>[
              <double>[0.6e150, 0.6e150],
              <double>[0.6e150, 0.6e150],
            ]);

            expect(
              () => Matrix.scalar(1).power(exponent),
              throwsOutOfPrecisionRange(),
            );
          },
        );
      },
    );
  });
}
