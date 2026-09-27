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
//
// Codex round 18 superseded this file's own zero classification for both
// fixtures below: removing the general 2x2 closed form's mixed error model
// (a determinant input-uncertainty floor no longer matching the
// discriminant's own pure-forward-error bound; see
// round22_codex_round18_test.dart) resolves each fixture's residual
// eigenvalue as genuinely nonzero, 4.661462957000128e-156
// (positive-residual) / -4.66146295700013e-156 (negative-residual), rather
// than as a numerical zero within [Matrix._blockZeroTolerance]. Both
// magnitudes are below matrixFunctionMinMagnitude=1e-150, so the correct
// D38 outcome for every operation below is matrix-out-of-precision-range,
// not the classified-zero outcome this file originally exercised.
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

    group(
      'sqrt now raises matrix-out-of-precision-range: Codex round 18 '
      'resolves the residual eigenvalue as genuinely nonzero and below '
      'matrixFunctionMinMagnitude, not as a numerical zero',
      () {
        test('positive-residual fixture', () {
          expect(() => positiveResidual.sqrt(), throwsOutOfPrecisionRange());
        });

        test('negative-residual fixture', () {
          expect(() => negativeResidual.sqrt(), throwsOutOfPrecisionRange());
        });
      },
    );

    group(
      'log now raises matrix-out-of-precision-range, not log-undefined: '
      'Codex round 18 resolves the residual eigenvalue as genuinely nonzero '
      'and below matrixFunctionMinMagnitude, so the D38 range check rejects '
      'it before log-undefined\'s own zero-eigenvalue domain decision is '
      'ever reached',
      () {
        test('positive-residual fixture', () {
          expect(() => positiveResidual.log(), throwsOutOfPrecisionRange());
          expect(() => positiveResidual.log(), isNot(throwsLogUndefined()));
        });

        test('negative-residual fixture', () {
          expect(() => negativeResidual.log(), throwsOutOfPrecisionRange());
          expect(() => negativeResidual.log(), isNot(throwsLogUndefined()));
        });
      },
    );

    group(
      'a non-integer power (power(scalar(0.5))) now raises '
      'matrix-out-of-precision-range, not log-undefined: Codex round 18 '
      'resolves the residual eigenvalue as genuinely nonzero and below '
      'matrixFunctionMinMagnitude, so the D38 range check rejects it before '
      "power's own zero-eigenvalue domain decision is ever reached",
      () {
        test('positive-residual fixture', () {
          expect(
            () => positiveResidual.power(Matrix.scalar(0.5)),
            throwsOutOfPrecisionRange(),
          );
        });

        test('negative-residual fixture', () {
          expect(
            () => negativeResidual.power(Matrix.scalar(0.5)),
            throwsOutOfPrecisionRange(),
          );
        });
      },
    );

    group(
      'exp now raises matrix-out-of-precision-range: Codex round 18 '
      'resolves the residual eigenvalue as genuinely nonzero and below '
      'matrixFunctionMinMagnitude, not as a numerical zero contributing '
      'nothing distinguishable from 0',
      () {
        test('positive-residual fixture', () {
          expect(() => positiveResidual.exp(), throwsOutOfPrecisionRange());
        });

        test('negative-residual fixture', () {
          expect(() => negativeResidual.exp(), throwsOutOfPrecisionRange());
        });
      },
    );

    group(
      'the round 15, finding 1 operand-spectrum gate already covered the '
      'positive-residual sign (round19_codex_round15_test.dart); this '
      'confirms the negative-residual sign too, now updated for Codex '
      'round 18: the residual eigenvalue resolves as genuinely nonzero and '
      'below matrixFunctionMinMagnitude, so scalar(1).power(negativeResidual) '
      'must raise matrix-out-of-precision-range instead of returning the '
      'identity',
      () {
        test(
          'scalar(1).power(negativeResidual) raises '
          'matrix-out-of-precision-range',
          () {
            expect(
              () => Matrix.scalar(1).power(negativeResidual),
              throwsOutOfPrecisionRange(),
            );
          },
        );
      },
    );
  });
}
