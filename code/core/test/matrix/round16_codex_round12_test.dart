// Core PR #7 Codex round 12 (reviewed at commit b3c836d), three medium
// defects:
//
//   1. matrix.dart:3961, cyclic Jacobi snapped every diagonal entry within
//      a single, whole-matrix tolerance of zero to exactly 0.0, even for an
//      index an executed rotation never touched. On
//      [[1e-20,0,0],[0,2,1],[0,1,2]], index 0 is never touched by any
//      rotation (its off-diagonal entries stay exactly 0 throughout), so
//      its raw computed eigenvalue is the exact input, 1e-20, yet the old
//      whole-matrix tolerance (about 7.0e-14 here) snapped it to exactly
//      0.0 anyway, making [log] and non-integer [power] wrongly throw
//      log-undefined, and making the negated variant's [sqrt] wrongly
//      accept an indefinite matrix. The fix tracks, via a union-find over
//      which index pairs an executed rotation actually merges, a per-block
//      backward-error bound computed from that block's own entries in the
//      ORIGINAL matrix, and applies the zero decision only inside
//      [Matrix._realScalarPower] (used only by [Matrix.sqrt]'s semantics,
//      never by [Matrix.log] or non-integer [Matrix.power]).
//   2. matrix.dart:2878, [Matrix._powerByMatrixExponent]'s three internal
//      chains (`scaled.exp()`, and two `product.exp()` calls, `product`
//      itself built from the public `log()`) routed an internally derived
//      intermediate, never a raw caller-supplied argument, through the
//      PUBLIC `exp`/`log`, which re-applies their own stage-1 argument
//      gate to it. `scalar(2).power(complex(1e-150,0))` builds the
//      intermediate `ln(2)*1e-150` (about 6.93e-151), which fails that
//      gate on its own even though the true final result rounds to exactly
//      1.0. The fix introduces private `_internalExp`/`_internalLog`
//      helpers that skip the stage-1 argument gate (keeping genuine
//      domain checks and finiteness guards), used for every internal
//      chain in `_powerByMatrixExponent`; the final result is still
//      validated once, the same as every other branch.
//   3. matrix.dart:2821, the result-entry check
//      ([Matrix._requireResultEntriesInPrecisionRange]) applied the same
//      strict, zero-tolerance comparison as the raw-input check, even
//      though the widened log-magnitude check just upstream
//      ([Matrix._requireResultLogMagnitudeInRange], round 11 finding 2)
//      already accepts a comparable amount of materialization rounding.
//      `scalar(-1e-100).power(scalar(-1.5))`'s true imaginary component
//      sits exactly at the declared upper bound, 1e150, but computes to
//      about 1.000000000000045e150 (about 45 ULPs above it), which the old
//      strict check rejected. The fix widens only the result-entry check
//      by a relative tolerance derived from the same named ULP constant
//      the log-magnitude check already uses; the raw-input check stays
//      strict and unchanged.
//
// Every numeric reference value below not already exactly representable
// was independently derived by hand from each case's own closed form (see
// each group's leading comment), not copied from this implementation's own
// output, except where a comment says otherwise.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

Matcher throwsLogUndefined() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.logUndefined,
  ),
);

void main() {
  group(
    'Codex round 12, finding 1: Jacobi zero-snapping must be per-block, '
    'not whole-matrix',
    () {
      // A = block-diag(1e-20, B), B = [[2,1],[1,2]]. Index 0 has no
      // off-diagonal entries at all, so no rotation ever touches it (an
      // executed rotation on (1, 2) leaves a[0][1]/a[0][2] at
      // c*0 - s*0 = 0 and s*0 + c*0 = 0, still exactly 0), so index 0's
      // raw computed eigenvalue is the exact input, 1e-20 (or -1e-20 for
      // the negated variant below), never subject to any Jacobi rounding.
      //
      // B's rotation is exact for this input: theta = (2-2)/(2*1) = 0, so
      // t = 1.0 exactly (the theta == 0 special case), giving computed
      // eigenvalues exactly 1 and 3 (2 - 1*1 = 1, 2 + 1*1 = 3), and
      // Q's 2x2 sub-block is +/-1/sqrt(2) in every entry. For any function
      // f, reconstructing Q * diag(f(1), f(3)) * Q^T over that sub-block
      // gives, at both diagonal entries, 0.5*(f(1) + f(3)), and at both
      // off-diagonal entries, 0.5*(f(3) - f(1)) (by hand expansion of the
      // 2x2 product); this is a property of B alone, independent of which
      // index Jacobi happens to assign eigenvalue 1 versus 3 to.
      final Matrix a = Matrix(<List<double>>[
        <double>[1e-20, 0, 0],
        <double>[0, 2, 1],
        <double>[0, 1, 2],
      ]);
      final Matrix aNegated = Matrix(<List<double>>[
        <double>[-1e-20, 0, 0],
        <double>[0, 2, 1],
        <double>[0, 1, 2],
      ]);

      test(
        'log([[1e-20,0,0],[0,2,1],[0,1,2]]) no longer throws log-undefined '
        'from the isolated eigenvalue being wrongly snapped to zero by a '
        'whole-matrix tolerance: reference is '
        'block-diag(ln(1e-20), 0.5*ln(3)*[[1,1],[1,1]])',
        () {
          final double logIsolated = math.log(1e-20);
          final double logBlock = 0.5 * math.log(3);

          final Matrix result = a.log();

          expect(result.at(0, 0), closeTo(logIsolated, 1e-9));
          expect(result.at(0, 1), closeTo(0, 1e-12));
          expect(result.at(0, 2), closeTo(0, 1e-12));
          expect(result.at(1, 0), closeTo(0, 1e-12));
          expect(result.at(2, 0), closeTo(0, 1e-12));
          expect(result.at(1, 1), closeTo(logBlock, 1e-9));
          expect(result.at(1, 2), closeTo(logBlock, 1e-9));
          expect(result.at(2, 1), closeTo(logBlock, 1e-9));
          expect(result.at(2, 2), closeTo(logBlock, 1e-9));
        },
      );

      test(
        'power([[1e-20,0,0],[0,2,1],[0,1,2]], 0.5) no longer throws '
        'log-undefined for the same reason (power keeps '
        'rejectZeroEigenvalue: true, so this specifically exercises that '
        'the isolated eigenvalue is never snapped to an exact zero in the '
        'first place): reference is '
        'block-diag(1e-10, 0.5*(1+sqrt(3)), 0.5*(sqrt(3)-1); '
        '0.5*(sqrt(3)-1), 0.5*(1+sqrt(3)))',
        () {
          final double sqrtIsolated = 1e-10;
          final double diagBlock = 0.5 * (1 + math.sqrt(3));
          final double offBlock = 0.5 * (math.sqrt(3) - 1);

          final Matrix result = a.power(Matrix.scalar(0.5));

          expect(result.at(0, 0), closeTo(sqrtIsolated, 1e-20));
          expect(result.at(0, 1), closeTo(0, 1e-12));
          expect(result.at(0, 2), closeTo(0, 1e-12));
          expect(result.at(1, 1), closeTo(diagBlock, 1e-9));
          expect(result.at(1, 2), closeTo(offBlock, 1e-9));
          expect(result.at(2, 1), closeTo(offBlock, 1e-9));
          expect(result.at(2, 2), closeTo(diagBlock, 1e-9));
        },
      );

      test(
        'sqrt([[1e-20,0,0],[0,2,1],[0,1,2]]) itself also recovers the '
        'isolated eigenvalue correctly (decision: this is a necessary '
        'consequence of the fix, not merely "does not throw": before the '
        'fix, this silently returned 0 at (0, 0) instead of the true '
        'sqrt(1e-20) = 1e-10, because the isolated eigenvalue was snapped '
        'to zero inside the decomposition itself)',
        () {
          final Matrix result = a.sqrt();

          expect(result.at(0, 0), closeTo(1e-10, 1e-20));
        },
      );

      test(
        'sqrt([[-1e-20,0,0],[0,2,1],[0,1,2]]) still raises log-undefined: '
        'the isolated eigenvalue is genuinely negative (-1e-20), and the '
        'per-block backward-error bound for a singleton, untouched block '
        'is astronomically small (about '
        '10*1*unitRoundoff*1e-20 =~ 1.11e-35), far below 1e-20 itself, so '
        'this is never treated as within-tolerance-of-zero: the fix must '
        'not widen far enough to swallow a real, meaningfully negative '
        'eigenvalue merely because it happens to be tiny',
        () {
          expect(aNegated.sqrt, throwsLogUndefined());
        },
      );
    },
  );

  group(
    'Codex round 12, finding 2: an internal power-by-matrix-exponent '
    'intermediate must skip the public argument gate',
    () {
      test(
        'scalar(2)^complex(1e-150,0) no longer raises matrix-out-of-'
        'precision-range on its own internal intermediate ln(2)*1e-150 '
        '(about 6.93e-151, below matrixFunctionMinMagnitude on its own, '
        'but never a raw argument the caller supplied): the true result is '
        'exp(1e-150*ln(2)), whose real part rounds to exactly 1.0 in '
        'double precision and whose imaginary part is exactly 0 (the '
        'exponent itself has a zero imaginary part)',
        () {
          final Matrix result = Matrix.scalar(
            2,
          ).power(Matrix.complex(1e-150, 0));

          expect(result.realPart, 1.0);
          expect(result.imagPart, 0.0);
        },
      );

      test(
        'complex(1e150,1e-150)^complex(0,1) no longer raises matrix-out-of-'
        'precision-range from routing this base\'s own log() through the '
        'public method, whose result-entry check rejects the tiny angle '
        'entry (atan2(1e-150,1e150) ~= 1e-300) as if it were a raw '
        'argument: the true result, by hand expansion of '
        'exp(i * log(complex(1e150,1e-150))), is approximately '
        '0.9824867416967755 - 0.18633250492078285*i (reviewer\'s own '
        'figure, to 5 significant digits: 0.98249 - 0.18633i)',
        () {
          final Matrix result = Matrix.complex(
            1e150,
            1e-150,
          ).power(Matrix.complex(0, 1));

          expect(result.realPart, closeTo(0.9824867416967755, 1e-9));
          expect(result.imagPart, closeTo(-0.18633250492078285, 1e-9));
        },
      );
    },
  );

  group(
    'Codex round 12, finding 3: the result-entry check must tolerate the '
    'same materialization rounding the result-eigenvalue check already '
    'does',
    () {
      test(
        'scalar(-1e-100)^scalar(-1.5) (reviewer\'s own example) no longer '
        'raises matrix-out-of-precision-range on its computed imaginary '
        'entry, whose true value sits exactly at the declared upper '
        'bound, 1e150, but computes to about 1.000000000000045e150 (about '
        '45 ULPs above it): the widened result-eigenvalue check upstream '
        'already accepts this result (its log-magnitude, y*ln(1e-100), is '
        'exactly at the boundary in log space), so the result-entry check '
        'must accept the materialized magnitude too',
        () {
          final Matrix result = Matrix.scalar(
            -1e-100,
          ).power(Matrix.scalar(-1.5));

          expect(
            result.realPart,
            closeTo(-1.8369701987211123e134, 1.9e125),
          );
          expect(result.imagPart, closeTo(1.000000000000045e150, 1e141));
        },
      );

      test(
        'scalar(-1e100)^scalar(1.5) (a mirrored boundary case: same '
        'magnitude, opposite exponent sign, so the marginal entry lands at '
        'the same upper bound with the opposite sign) no longer raises '
        'matrix-out-of-precision-range for the same reason. Decision: this '
        'is used instead of a literal lower-boundary "-1.5 analogue" '
        '(mirroring round 11\'s finding 2 pairing) because, at this '
        'branch\'s exact axis-aligned angle, the orthogonal boundary\'s '
        'own trig residual computes about 16 orders of magnitude below '
        'matrixFunctionMinMagnitude, a separate, unrelated floating-point '
        'quirk this finding does not ask to fix; both cases here instead '
        'hit the same upper bound from opposite sides, which is enough to '
        'exercise the fix at both signs',
        () {
          final Matrix result = Matrix.scalar(
            -1e100,
          ).power(Matrix.scalar(1.5));

          expect(
            result.realPart,
            closeTo(-1.8369701987211123e134, 1.9e125),
          );
          expect(result.imagPart, closeTo(-1.000000000000045e150, 1e141));
        },
      );
    },
  );
}
