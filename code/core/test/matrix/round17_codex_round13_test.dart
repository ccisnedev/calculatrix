// Core PR #7 Codex round 13 (reviewed at commit 06eee0f), 5 medium
// findings, addressed as three principles rather than five ad hoc patches:
//
//   P1 (findings 1 and 4): one classification, applied BEFORE any D38
//      magnitude gate, used by every operation (sqrt, log, non-integer
//      power): a computed eigenvalue with |lambda| <= its own block-local
//      backward-error bound (the same per-block Weyl bound
//      [Matrix._cyclicJacobiEigendecomposition] already computes) is
//      NUMERICALLY ZERO. sqrt maps a numerically-zero eigenvalue to exactly
//      0; log and non-integer power raise log-undefined for one (D34:
//      cannot certify positive), the same as a true zero eigenvalue.
//      Finding 1 regression: round 12 made log/power ignore the
//      block-local tolerance entirely, so a tiny nonzero Jacobi residual
//      for a true zero eigenvalue silently produced a wrong finite
//      logarithm/power instead of raising log-undefined. Finding 4
//      regression: classification happens before the D38 magnitude gate,
//      not after, so a genuinely tiny (but classified nonzero) eigenvalue
//      still passes through the gate on its own terms, and a
//      classified-zero eigenvalue never reaches the gate at all, even when
//      its raw magnitude alone would have failed it.
//   P2 (findings 2 and 3): D38's declared-precision-range gates apply only
//      to a public operation's own operands and its final result, never to
//      an intermediate of an internal chain (`_powerByMatrixExponent`'s
//      `_internalExp`/`_internalLog`), including inside the symmetric and
//      general 2x2 branches. [Matrix._symmetricRealFunction],
//      [Matrix._general2x2Exp] and [Matrix._general2x2Log] now take a
//      caller-decided `checkOperandRange` flag instead of always applying
//      their embedded operand gate; the result-side
//      "before-exponentiating, in log space" check
//      ([Matrix._requireResultLogMagnitudeInRange]) stays unconditional
//      everywhere, including three places [Matrix._internalExp] was
//      missing it entirely (its scalar, complex-form and diagonal
//      branches), which is finding 2's regression: an internal chain could
//      silently underflow to exactly 0 instead of raising
//      matrix-out-of-precision-range.
//   P3 (finding 5): `cos(y*pi)`/`sin(y*pi)` are replaced by `_cosPi`/`_sinPi`
//      helpers using exact argument reduction
//      (`r = y - 2*round(y/2)`, exact in binary floating point for
//      representable `y`), returning exact 0/+-1 at half-integers instead
//      of a residual a few ULPs away from it.
//
// Every numeric reference value below not already exactly representable was
// either independently derived by hand from each case's own closed form, or
// probed directly from the sub-expression the fix leaves untouched (the
// magnitude `exp(y*log(-b))`, entirely unaffected by the cosPi/sinPi
// argument-reduction fix itself), not copied from this implementation's own
// end-to-end output.
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

Matcher throwsOutOfPrecisionRange() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.matrixOutOfPrecisionRange,
  ),
);

void main() {
  group(
    'Codex round 13, finding 1 (P1: classification, not raw sign, decides '
    'zero for log/power, the same as sqrt)',
    () {
      // A = [[1,0,1],[0,1,1],[1,1,2]]: row 2 is exactly row 0 + row 1, so A
      // is rank-deficient with true eigenvalues exactly 0, 1, 3 (trace
      // 1+1+2=4=0+1+3). Cyclic Jacobi computes the true-zero eigenvalue as
      // a tiny nonzero residual (either sign), well within its block-local
      // backward-error bound, since every index here ends up in one block
      // spanning the whole matrix. Before this fix, [Matrix.log] and
      // non-integer [Matrix.power] applied no zero-tolerance at all (only
      // [Matrix.sqrt] did), so this residual was treated as a genuine
      // eigenvalue and silently produced a finite (wrong) result instead of
      // raising log-undefined.
      final Matrix a = Matrix(<List<double>>[
        <double>[1, 0, 1],
        <double>[0, 1, 1],
        <double>[1, 1, 2],
      ]);

      test(
        'log([[1,0,1],[0,1,1],[1,1,2]]) raises log-undefined for the '
        'classified-zero eigenvalue instead of silently returning a finite '
        'result',
        () {
          expect(a.log, throwsLogUndefined());
        },
      );

      test(
        '[[1,0,1],[0,1,1],[1,1,2]].power(scalar(0.5)) raises log-undefined '
        'for the same reason',
        () {
          expect(() => a.power(Matrix.scalar(0.5)), throwsLogUndefined());
        },
      );
    },
  );

  group(
    'Codex round 13, finding 4 (P1: classification runs before the D38 '
    'magnitude gate, not after)',
    () {
      // A = [[1,2,4],[2,4,8],[4,8,16]] is rank 1 (the outer product of
      // v=[1,2,4]), true eigenvalues exactly |v|^2=21, 0, 0. Scaling by
      // s = 3.4395525670743494e-136 (2^-450) gives true eigenvalues
      // 21s, 0, 0; 21s is comfortably inside the declared precision range,
      // but the two zero eigenvalues are computed by Jacobi as tiny
      // nonzero residuals whose RAW magnitude alone sits below
      // matrixFunctionMinMagnitude (1e-150). Classifying them as zero
      // before the D38 gate (rather than after) means the gate never even
      // sees them; only the genuine, in-range 21s eigenvalue is checked.
      final double s = 3.4395525670743494e-136;
      final Matrix a = Matrix(<List<double>>[
        <double>[1, 2, 4],
        <double>[2, 4, 8],
        <double>[4, 8, 16],
      ]).scale(s);

      test(
        'sqrt([[1,2,4],[2,4,8],[4,8,16]].scale(2^-450)) succeeds instead of '
        'raising matrix-out-of-precision-range on a residual belonging to '
        'a classified-zero eigenvalue',
        () {
          expect(a.sqrt, returnsNormally);
        },
      );

      test(
        'the successful sqrt above recovers sqrt(21s) at the (0,0) entry: '
        'A = s*v*v^T for v=[1,2,4], |v|^2=21, so sqrt(A) = '
        'sqrt(s/21)*v*v^T, whose (0,0) entry is sqrt(s/21)*1*1',
        () {
          final Matrix result = a.sqrt();
          final double expected = math.sqrt(s / 21);
          expect(result.at(0, 0), closeTo(expected, expected * 1e-9));
        },
      );
    },
  );

  group(
    'Codex round 13, docs review #9 extra regression (P1: an eigenvalue '
    'within its block-local bound is numerically zero for sqrt/log/power '
    'regardless of its own computed sign)',
    () {
      // A = [[s,s,0],[s,s*(1+d),0],[0,0,s]], s=1e-140, d=2^-50. The
      // top-left 2x2 block is s*[[1,1],[1,1]] + s*d*[[0,0],[0,1]]: the
      // unperturbed block s*[[1,1],[1,1]] is rank 1 with eigenvalues 0 and
      // 2s, and the perturbation shifts the true-zero eigenvalue to
      // approximately s*d/2 (first-order perturbation along the zero
      // eigenvector [1,-1]/sqrt(2)), about 4.66e-156 for d=2^-50, well
      // within that block's own backward-error bound (about 4.44e-155).
      // Index 2 is isolated (no rotation ever touches it, off-diagonal
      // entries already exactly 0), so its own eigenvalue is exactly s,
      // unaffected by this finding.
      final double s = 1e-140;
      final double d = math.pow(2, -50).toDouble();

      Matrix buildWithSign(double signedD) => Matrix(<List<double>>[
        <double>[s, s, 0],
        <double>[s, s * (1 + signedD), 0],
        <double>[0, 0, s],
      ]);

      test(
        'positive-sign within-bound eigenvalue: sqrt succeeds (classifies '
        'it as zero)',
        () {
          expect(buildWithSign(d).sqrt, returnsNormally);
        },
      );

      test(
        'positive-sign within-bound eigenvalue: log raises log-undefined, '
        'not matrix-out-of-precision-range',
        () {
          expect(buildWithSign(d).log, throwsLogUndefined());
        },
      );

      test(
        'positive-sign within-bound eigenvalue: power(scalar(0.5)) raises '
        'log-undefined, not matrix-out-of-precision-range',
        () {
          expect(
            () => buildWithSign(d).power(Matrix.scalar(0.5)),
            throwsLogUndefined(),
          );
        },
      );

      test(
        'negative-sign within-bound eigenvalue: sqrt still succeeds '
        '(classification depends on magnitude vs. the block bound, not '
        'sign)',
        () {
          expect(buildWithSign(-d).sqrt, returnsNormally);
        },
      );

      test(
        'negative-sign within-bound eigenvalue: log raises log-undefined',
        () {
          expect(buildWithSign(-d).log, throwsLogUndefined());
        },
      );
    },
  );

  group(
    'Codex round 13, findings 2 and 3 (P2: D38 gates apply only to a '
    'public operation\'s own operands and final result, never to an '
    'internal chain\'s intermediate; the always-on, before-exponentiating '
    'log-space check must still run in every branch of the internal chain)',
    () {
      test(
        'scalar(2).power(complex(-2000,0)) raises '
        'matrix-out-of-precision-range instead of silently underflowing to '
        'zero: the internal chain computes exp(log(2)*(-2000)), whose '
        'log-magnitude (about -1386.29) is far below '
        '-ln(matrixFunctionMaxMagnitude) (about -345.39), a check '
        '[Matrix._internalExp]\'s complex-form branch used to skip '
        'entirely',
        () {
          expect(
            () => Matrix.scalar(2).power(Matrix.complex(-2000, 0)),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        'scalar(2).power([[-2000,0],[0,-2100]]) raises '
        'matrix-out-of-precision-range for the same reason, via '
        '[Matrix._internalExp]\'s diagonal branch, which used to skip the '
        'same before-exponentiating check entirely',
        () {
          expect(
            () => Matrix.scalar(2).power(
              Matrix(<List<double>>[
                <double>[-2000, 0],
                <double>[0, -2100],
              ]),
            ),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        'scalar(2).power([[1e-150,1],[0,2e-150]]) succeeds instead of '
        'wrongly raising matrix-out-of-precision-range on the internal '
        'chain\'s intermediate exponent*ln(2) eigenvalues (about '
        '6.93e-151 and 1.39e-150), which are internal-chain intermediates, '
        'not raw operands or the final result: reference is '
        'exp(exponent*ln(2)) = [[1,ln(2)],[0,1]] (an upper-triangular '
        'closed form, since the exponent\'s own (1,0) entry is 0)',
        () {
          final Matrix result = Matrix.scalar(2).power(
            Matrix(<List<double>>[
              <double>[1e-150, 1],
              <double>[0, 2e-150],
            ]),
          );
          expect(result.at(0, 0), closeTo(1.0, 1e-12));
          expect(result.at(0, 1), closeTo(math.log(2), 1e-12));
          expect(result.at(1, 0), 0.0);
          expect(result.at(1, 1), closeTo(1.0, 1e-12));
        },
      );

      test(
        'scalar(2).power([[1e-150,0,0],[0,2,1],[0,1,2]]) succeeds instead '
        'of wrongly raising matrix-out-of-precision-range on the internal '
        'chain\'s intermediate symmetric-branch eigenvalue (about '
        '6.93e-151), via [Matrix._internalExp]\'s symmetric branch, which '
        'used to apply its embedded operand gate unconditionally: '
        'reference is exp(exponent*ln(2)); the (2,2) 2x2 sub-block '
        '[[2,1],[1,2]] has eigenvalues 1 and 3, so exp of its scaled '
        'sub-block (eigenvalues ln2 and 3*ln2) reconstructs to '
        '[[5,3],[3,5]] (0.5*(2+2^3)=5, 0.5*(2^3-2)=3)',
        () {
          final Matrix result = Matrix.scalar(2).power(
            Matrix(<List<double>>[
              <double>[1e-150, 0, 0],
              <double>[0, 2, 1],
              <double>[0, 1, 2],
            ]),
          );
          expect(result.at(0, 0), closeTo(1.0, 1e-12));
          expect(result.at(0, 1), 0.0);
          expect(result.at(0, 2), 0.0);
          expect(result.at(1, 0), 0.0);
          expect(result.at(1, 1), closeTo(5.0, 1e-9));
          expect(result.at(1, 2), closeTo(3.0, 1e-9));
          expect(result.at(2, 0), 0.0);
          expect(result.at(2, 1), closeTo(3.0, 1e-9));
          expect(result.at(2, 2), closeTo(5.0, 1e-9));
        },
      );
    },
  );

  group(
    'Codex round 13, finding 5 (P3: exact half-integer argument reduction '
    'for y*pi trig, cosPi/sinPi instead of cos(y*pi)/sin(y*pi))',
    () {
      // scalar(-1e100).power(scalar(-1.5)): B^Y = exp(Y*log(B)), where
      // log(B) = ln(1e100) + pi*i for the negative base. The result is
      // magnitude*(cos(angle) + i*sin(angle)) for angle = Y*pi = -1.5*pi.
      // The true mathematical cos(-1.5*pi) is exactly 0 (a quarter-turn
      // axis-aligned angle), but the old naive `math.cos(y * math.pi)`
      // computes a residual a few ULPs away from 0 instead, since
      // `math.pi` itself is not exactly representable: that residual,
      // multiplied by the large `magnitude`, produced a spurious nonzero
      // real part. Exact argument reduction (`_cosPi`/`_sinPi`) recognizes
      // -1.5 as an exact half-integer and returns exactly 0/-1, so the
      // real part becomes exactly 0.0 and the imaginary part is unaffected
      // (magnitude * (-1) is exact whenever magnitude itself is finite).
      // magnitude = exp(-1.5 * ln(1e100)) probed directly at
      // 9.99999999999955e-151, entirely unaffected by this fix (it comes
      // from the unrelated `exp(y*log(-b))` sub-expression).
      test(
        'scalar(-1e100).power(scalar(-1.5)) has an exactly zero real part '
        '(cosPi(-1.5) == 0 exactly)',
        () {
          final Matrix result = Matrix.scalar(
            -1e100,
          ).power(Matrix.scalar(-1.5));
          expect(result.realPart, 0.0);
          expect(
            result.imagPart,
            closeTo(9.99999999999955e-151, 1e-163),
          );
        },
      );

      // Lower-boundary mirror (the case round 12's finding 3 explicitly
      // left unfixed, since round 12 was not asked to fix this residual):
      // scalar(-1e100).power(scalar(1.5)), angle = 1.5*pi, whose exact
      // cosPi(1.5) is also 0 and whose exact sinPi(1.5) is -1. magnitude
      // = exp(1.5*ln(1e100)) probed directly at 1.000000000000045e+150.
      test(
        'scalar(-1e100).power(scalar(1.5)) (the lower-boundary mirror) '
        'also has an exactly zero real part (cosPi(1.5) == 0 exactly)',
        () {
          final Matrix result = Matrix.scalar(
            -1e100,
          ).power(Matrix.scalar(1.5));
          expect(result.realPart, 0.0);
          expect(
            result.imagPart,
            closeTo(-1.000000000000045e150, 1e138),
          );
        },
      );
    },
  );
}
