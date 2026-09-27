// Core PR #7 Codex round 16, 1 medium finding:
//
//   Numerical-zero eigenvalue classification (round 15, finding 1) was
//   applied only to [Matrix._requireSpectrumInPrecisionRange]'s general 2x2
//   branch, never to the general 2x2 closed forms [sqrt]/[log]/[exp]/
//   [power] actually compute through
//   ([Matrix._general2x2RealPower]/[Matrix._general2x2Log]/
//   [Matrix._general2x2Exp]). Each of those three still passed a hardcoded
//   `[0, 0]` zero-tolerance pair to [Matrix._requireEigenvaluesInPrecisionRange]
//   (`_general2x2Exp` around the old line 5353, `_general2x2Log` around the
//   old line 5547, `_general2x2RealPower` around the old line 5967), and
//   [_general2x2Log]/[_general2x2RealPower]'s own domain decisions (negative
//   eigenvalue, zero eigenvalue) compared the raw computed eigenvalue
//   against a literal `0`/`< 0` instead of classifying it first. A
//   nearly-singular 2x2 whose true small eigenvalue is a numerically-zero
//   residual (from the same subtraction/sqrt/division backward error
//   [Matrix._blockZeroTolerance] already bounds for the operand-spectrum
//   gate) was therefore rejected as out of the declared D38 range instead of
//   being classified zero and handled per-operation: [sqrt] must succeed
//   (the classified-zero eigenvalue taken as exactly 0, `0^0.5 = 0`, the
//   same as [Matrix._realScalarPower] already does for the symmetric,
//   rowCount != 2 Jacobi branch), while [log] and a non-integer [power] must
//   raise log-undefined (the same as a mathematically exact zero
//   eigenvalue), never matrix-out-of-precision-range.
//
//   Fixed at the root: all three general 2x2 branches now compute the same
//   [Matrix._blockZeroTolerance] bound from their own four entries, supply
//   it to [Matrix._requireEigenvaluesInPrecisionRange] instead of a literal
//   `[0, 0]`, and classify each eigenvalue via [Matrix._classifyEigenvalue]
//   BEFORE any sign/zero domain decision, instead of comparing the raw
//   computed value against a literal `0`.
//
//   A second grep across every other public/internal eigenvalue gate,
//   covering all five supported matrix-function classes, found no further
//   site with the same defect:
//     - Scalar (1x1): the "eigenvalue" is the raw scalar entry itself, with
//       no subtraction/sqrt/division computing it, so an exact-zero check
//       is already correct; there is no backward error to bound.
//     - Complex-form (aI + bJ): likewise, realPart/imagPart are raw entries,
//       not computed by any cancellation-prone algorithm, so [log]'s
//       `a == 0 && b == 0` exact check is already correct.
//     - Exactly diagonal: each diagonal entry is a raw entry with no
//       off-diagonal coupling at all (documented explicitly at this
//       branch's own zeroTolerance: 0 already, in [_matrixRealPower]).
//     - Exactly symmetric (rowCount != 2, cyclic Jacobi): already uses the
//       per-block zeroTolerance [Matrix._cyclicJacobiEigendecomposition]
//       computes and [Matrix._realScalarPower]/[Matrix.log]'s own branch
//       already classify before deciding (round 13, finding 1 (P1)); this
//       predates and is unaffected by this finding.
//   No other literal zero-tolerance pair or raw eigenvalue comparison
//   remains outside these three now-fixed sites.
//
// Every numeric reference value below was independently derived by hand
// from the fixture's own closed form (a 2x2 divided-difference eigenvalue
// solve and, for [exp], a first-order Taylor expansion valid because the
// fixture's own norm is far below double's relative precision at 1.0), not
// copied from this implementation's own end-to-end output.
import 'package:calculatrix/calculatrix.dart';
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
  group('Codex round 16', () {
    // s = 1e-140, d = 2^-50. Both fixtures are symmetric 2x2 matrices whose
    // true eigenvalues are approximately 2s (comfortably in the declared
    // D38 range) and a tiny numerical-zero residual, well within this
    // block's own [Matrix._blockZeroTolerance] (hand-derived at about
    // 4.44e-155 for both fixtures below). [positiveResidual] perturbs the
    // (1,1) entry upward (s*(1+d)), which rounds its small eigenvalue to a
    // positive residual (about +4.66e-156, hand-derived from the centered
    // discriminant `m - sqrt(halfDiff^2 + b*c)`); [negativeResidual]
    // perturbs it downward (s*(1-d)) instead, which rounds the identical
    // small eigenvalue to a negative residual (about -4.66e-156), covering
    // both signs the classification must handle identically.
    const double s = 1e-140;
    const double d = 8.881784197001252e-16; // 2^-50

    final Matrix positiveResidual = Matrix(<List<double>>[
      <double>[s, s],
      <double>[s, s * (1 + d)],
    ]);
    final Matrix negativeResidual = Matrix(<List<double>>[
      <double>[s, s],
      <double>[s, s * (1 - d)],
    ]);

    group('sqrt succeeds, the numerically-zero eigenvalue taken as 0', () {
      test('positive-residual fixture: sqrt does not throw, and squaring '
          'the result reconstructs the original matrix', () {
        final Matrix result = positiveResidual.sqrt();
        final Matrix squared = result * result;
        for (int r = 0; r < 2; r++) {
          for (int c = 0; c < 2; c++) {
            expect(
              squared.at(r, c),
              closeTo(positiveResidual.at(r, c), s * 1e-6),
            );
          }
        }
      });

      test('negative-residual fixture: sqrt does not throw, and squaring '
          'the result reconstructs the original matrix', () {
        final Matrix result = negativeResidual.sqrt();
        final Matrix squared = result * result;
        for (int r = 0; r < 2; r++) {
          for (int c = 0; c < 2; c++) {
            expect(
              squared.at(r, c),
              closeTo(negativeResidual.at(r, c), s * 1e-6),
            );
          }
        }
      });
    });

    group(
      'log raises log-undefined for the numerically-zero eigenvalue, not '
      'matrix-out-of-precision-range',
      () {
        test('positive-residual fixture', () {
          expect(() => positiveResidual.log(), throwsLogUndefined());
          expect(
            () => positiveResidual.log(),
            isNot(throwsOutOfPrecisionRange()),
          );
        });

        test('negative-residual fixture', () {
          expect(() => negativeResidual.log(), throwsLogUndefined());
          expect(
            () => negativeResidual.log(),
            isNot(throwsOutOfPrecisionRange()),
          );
        });
      },
    );

    group(
      'a non-integer power (power(scalar(0.5))) raises log-undefined for '
      'the numerically-zero eigenvalue, unlike sqrt: power always rejects a '
      'zero eigenvalue with a non-integer exponent (D25/D34), regardless of '
      "the exponent's own sign",
      () {
        test('positive-residual fixture', () {
          expect(
            () => positiveResidual.power(Matrix.scalar(0.5)),
            throwsLogUndefined(),
          );
        });

        test('negative-residual fixture', () {
          expect(
            () => negativeResidual.power(Matrix.scalar(0.5)),
            throwsLogUndefined(),
          );
        });
      },
    );

    group(
      'exp succeeds, the numerically-zero eigenvalue contributing nothing '
      'distinguishable from 0 to the result (its own true contribution, '
      "order s, is already below 1.0's own double precision, about "
      '2.22e-16, so the diagonal entries round to exactly 1.0)',
      () {
        test('positive-residual fixture', () {
          final Matrix result = positiveResidual.exp();
          expect(result.at(0, 0), closeTo(1.0, 1e-12));
          expect(result.at(0, 1), closeTo(s, s * 1e-6));
          expect(result.at(1, 0), closeTo(s, s * 1e-6));
          expect(result.at(1, 1), closeTo(1.0, 1e-12));
        });

        test('negative-residual fixture', () {
          final Matrix result = negativeResidual.exp();
          expect(result.at(0, 0), closeTo(1.0, 1e-12));
          expect(result.at(0, 1), closeTo(s, s * 1e-6));
          expect(result.at(1, 0), closeTo(s, s * 1e-6));
          expect(result.at(1, 1), closeTo(1.0, 1e-12));
        });
      },
    );

    group(
      'the round 15, finding 1 operand-spectrum gate already covered the '
      'positive-residual sign (round19_codex_round15_test.dart); this '
      'confirms the negative-residual sign too',
      () {
        test('scalar(1).power(negativeResidual) is the identity', () {
          final Matrix result = Matrix.scalar(1).power(negativeResidual);
          expect(result.at(0, 0), 1.0);
          expect(result.at(0, 1), 0.0);
          expect(result.at(1, 0), 0.0);
          expect(result.at(1, 1), 1.0);
        });
      },
    );
  });
}
