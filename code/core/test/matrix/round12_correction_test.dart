// Round 12 correction: seven findings from an independent review of PR #7
// (feat/core-power-and-error-ids), each covered here by a test that fails
// before its paired fix and asserts a concrete numeric value or behavior,
// checked against an independently derived reference (Python mpmath at
// 200-1200 decimal digits, or an analytically stated closed form), never
// against this implementation's own prior output.
import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// Asserts [actual] is within [relativeTolerance] of [expected]. Exactly 0
/// is required when [expected] is exactly 0.
void expectRelativelyClose(
  double actual,
  double expected, {
  double relativeTolerance = 1e-9,
}) {
  if (expected == 0) {
    expect(actual, equals(0));
    return;
  }
  final double relativeError = (actual - expected).abs() / expected.abs();
  expect(
    relativeError,
    lessThan(relativeTolerance),
    reason: 'actual=$actual expected=$expected relativeError=$relativeError',
  );
}

Matcher throwsOutOfPrecisionRange() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.matrixOutOfPrecisionRange,
  ),
);

void main() {
  group(
    'Round 12, finding 2: general 2x2 discriminant solver must not let an '
    'underflowed direct determinant (a*d - b*c both underflow to exactly 0) '
    'masquerade as a reliable finite result',
    () {
      // A=[[1e-200,1e-200],[2e-200,4e-200]]. Reference (mpmath, dps=1200):
      // eigenvalues lambda1 ~= 4.56155281280883e-200,
      // lambda2 ~= 4.38447187092134e-201 (both from the characteristic
      // polynomial trace/det of the *exact* rational entries, not from
      // this implementation). a*d = 4e-400 and b*c = 2e-400 each
      // underflow to exactly 0 in double precision (below the smallest
      // subnormal double, ~4.94e-324), so `directDet = a*d - b*c` is
      // exactly 0 and wrongly looks "finite" even though the true
      // determinant is `4e-400 - 2e-400 = 2e-400`, nonzero.
      // D38 declared precision contract: every entry of this matrix
      // (1e-200, 1e-200, 2e-200, 4e-200) sits below
      // matrixFunctionMinMagnitude=1e-150, so all three operations below
      // are now rejected outright, before the underflowed-determinant fix
      // these tests used to regression-check ever runs.
      test('log() raises matrix-out-of-precision-range', () {
        final Matrix value = Matrix(<List<double>>[
          <double>[1e-200, 1e-200],
          <double>[2e-200, 4e-200],
        ]);

        expect(
          value.log,
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.matrixOutOfPrecisionRange,
            ),
          ),
        );
      });

      test(
        'power(-0.5) raises matrix-out-of-precision-range',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e-200, 1e-200],
            <double>[2e-200, 4e-200],
          ]);

          expect(
            () => value.power(Matrix.scalar(-0.5)),
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

      test(
        'sqrt() raises matrix-out-of-precision-range',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e-200, 1e-200],
            <double>[2e-200, 4e-200],
          ]);

          expect(
            value.sqrt,
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

  group(
    'Round 12, finding 3: general 2x2 eigensolver must balance b and c '
    'against each other before the whole-block magnitude scale, mirroring '
    '[Matrix._eigenvalues2x2]; a single block-wide power-of-two factor '
    'tuned to the larger off-diagonal entry underflows the smaller one to '
    'exactly 0, erasing a genuinely negative (complex-pair) discriminant',
    () {
      // A=[[0,1e200],[-1e-200,0]]: A^2 = -I exactly (b*c = -1 exactly), so
      // the true eigenvalues are the complex pair +-i, never a repeated
      // real 0. Reference for exp: since A^2 = -I, the matrix exponential
      // series collapses to the closed form exp(A) = cos(1)*I + sin(1)*A
      // exactly (an analytically derived identity, not this
      // implementation's own output; math.cos/math.sin are Dart's
      // standard trig functions, independent of the matrix code path
      // under test).
      // D38 declared precision contract: entries 1e200 and -1e-200 both
      // sit outside [1e-150, 1e150], so all four operations below are now
      // rejected outright before the balancing fix these tests used to
      // regression-check ever runs.
      test('exp() raises matrix-out-of-precision-range', () {
        final Matrix value = Matrix(<List<double>>[
          <double>[0, 1e200],
          <double>[-1e-200, 0],
        ]);

        expect(
          value.exp,
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.matrixOutOfPrecisionRange,
            ),
          ),
        );
      });

      test('log() raises matrix-out-of-precision-range', () {
        final Matrix value = Matrix(<List<double>>[
          <double>[0, 1e200],
          <double>[-1e-200, 0],
        ]);

        expect(
          value.log,
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.matrixOutOfPrecisionRange,
            ),
          ),
        );
      });

      test('sqrt() raises matrix-out-of-precision-range', () {
        final Matrix value = Matrix(<List<double>>[
          <double>[0, 1e200],
          <double>[-1e-200, 0],
        ]);

        expect(
          value.sqrt,
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.matrixOutOfPrecisionRange,
            ),
          ),
        );
      });

      test(
        'power(0.5) raises matrix-out-of-precision-range',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[0, 1e200],
            <double>[-1e-200, 0],
          ]);

          expect(
            () => value.power(Matrix.scalar(0.5)),
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

  group(
    'Round 12, finding 4: general 2x2 power\'s complex-eigenvalue-pair '
    'branch must not materialize c1 = rToY*sin(y*angle)/w as a standalone '
    'value when w sits at a far different scale than rToY, since that '
    'division alone can overflow (or underflow to exactly 0) even though '
    'every product c1 actually feeds into (c1*b, c1*c, c1*(a-m)) is '
    'itself finite and correctly scaled',
    () {
      // A=[[0,s],[-2s,0]]: trace 0, det = 0-s*(-2s) = 2*s^2 > 0 but the
      // discriminant (halfDiff^2 - det, halfDiff=0) is -2*s^2 < 0, a
      // genuine complex-conjugate eigenvalue pair +-i*s*sqrt(2), for any
      // s. Reference (mpmath, dps=1200), independent of this
      // implementation, via the exact eigendecomposition closed form.
      // D38 declared precision contract: s=1e-200 and s=1e200 both sit
      // outside [1e-150, 1e150] (as raw entries, since b=s or c=-2s), so
      // both cases below are now rejected outright before the
      // standalone-c1 fix these tests used to regression-check ever runs.
      test('s=1e-200: raises matrix-out-of-precision-range', () {
        const double s = 1e-200;
        final Matrix value = Matrix(<List<double>>[
          <double>[0, s],
          <double>[-2 * s, 0],
        ]);

        expect(
          () => value.power(Matrix.scalar(-1.5)),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.matrixOutOfPrecisionRange,
            ),
          ),
        );
      });

      test(
        's=1e200: raises matrix-out-of-precision-range',
        () {
          const double s = 1e200;
          final Matrix value = Matrix(<List<double>>[
            <double>[0, s],
            <double>[-2 * s, 0],
          ]);

          expect(
            () => value.power(Matrix.scalar(-1.5)),
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

  group(
    'Round 12, finding 5: general 2x2 power\'s far-apart-eigenvalue direct '
    'divided difference (lyBig - lySmall) / (lBig - lSmall) collapses to '
    'exactly 0 when the exponent y is astronomically small, even though '
    'the eigenvalues themselves are nowhere near each other, because '
    'pow(lBig, y) and pow(lSmall, y) both round to exactly 1.0',
    () {
      // A=[[2,1e20],[0,1]] is triangular (c=0), eigenvalues exactly 2 and
      // 1 (relativeGap = 0.5, far above closeEigenvalueThreshold, so this
      // does not take the existing log1p/expm1 "close eigenvalue" branch).
      // With y=1e-20, pow(2,1e-20) and pow(1,1e-20) both round to exactly
      // 1.0 in double precision, so the naive c1 = (lyBig - lySmall) /
      // (lBig - lSmall) = 0 / 1 = 0 loses the true, tiny, nonzero divided
      // difference entirely. Reference (mpmath, dps=60), independent of
      // this implementation: c1 = 0.69314718055994530942 (the true
      // divided difference y * ln(2) to first order, since
      // d/dx[x^y] at y->0 collapses to the logarithmic mean).
      test(
        'power(1e-20) on [[2,1e20],[0,1]] recovers the true nonzero '
        '(0,1) entry, not a false 0 from a collapsed direct subtraction',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[2, 1e20],
            <double>[0, 1],
          ]);

          final Matrix result = value.power(Matrix.scalar(1e-20));

          expectRelativelyClose(result.at(0, 0), 1.0);
          expectRelativelyClose(result.at(0, 1), 0.69314718055994530942);
          expect(result.at(1, 0), equals(0));
          expectRelativelyClose(result.at(1, 1), 1.0);
        },
      );
    },
  );

  group(
    'Round 12, finding 5 (revision): the functionValueCancellationRisk '
    'gate from the first finding-5 fix is itself still a fallback to the '
    'broken direct form whenever its own log1p argument degenerates '
    '(an extreme eigenvalue ratio), which loses the true, tiny, nonzero '
    'divided difference the same way the original bug did',
    () {
      // A=[[1e200,1],[0,1e-200]] is triangular, eigenvalues exactly 1e200
      // and 1e-200. With y=1e-20, pow(1e200,1e-20) and pow(1e-200,1e-20)
      // both round to 1.0 in double precision (functionValueCancellationRisk
      // true), but (lSmall-lBig)/lBig rounds to exactly -1.0 (an extreme
      // eigenvalue ratio), so 1.0 + log1pArg is not > 0 and the first
      // finding-5 fix falls through to the broken direct form, giving
      // c1 = 0 instead of the true, tiny, nonzero divided difference.
      // Reference (mpmath, dps=100), independent of this implementation:
      // fa = 1.0000000000000000046, fd = 0.99999999999999999539,
      // entry01 = b*dd = 9.2103403719761827361e-218 (dd = (fa-fd)/(a-d)).
      // D38 declared precision contract: entries 1e200 and 1e-200 both sit
      // outside [1e-150, 1e150], so this and the negative-y variant below
      // are now rejected outright before the log1p-fallback fix these
      // tests used to regression-check ever runs.
      test(
        'power(1e-20) on [[1e200,1],[0,1e-200]] raises '
        'matrix-out-of-precision-range',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e200, 1],
            <double>[0, 1e-200],
          ]);

          expect(
            () => value.power(Matrix.scalar(1e-20)),
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

      test(
        'power(-1e-20) on [[1e200,1],[0,1e-200]] raises '
        'matrix-out-of-precision-range',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e200, 1],
            <double>[0, 1e-200],
          ]);

          expect(
            () => value.power(Matrix.scalar(-1e-20)),
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

      // D38 declared precision contract: entries 1e300 and 1e-300 both sit
      // outside [1e-150, 1e150], so this forward-looking overflow
      // regression and its negative-y counterpart below are now rejected
      // outright before the sign-of-y-conditioned expm1 form these tests
      // used to guard is even reached.
      test(
        'power(1.02) on [[1e300,1],[0,1e-300]] raises '
        'matrix-out-of-precision-range',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e300, 1],
            <double>[0, 1e-300],
          ]);

          expect(
            () => value.power(Matrix.scalar(1.02)),
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

      test(
        'power(-1.02) on [[1e300,1],[0,1e-300]] raises '
        'matrix-out-of-precision-range',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e300, 1],
            <double>[0, 1e-300],
          ]);

          expect(
            () => value.power(Matrix.scalar(-1.02)),
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

  group(
    'Round 12, finding 8: general 2x2 power\'s repeated-eigenvalue branch '
    'converted from an overflowed-c0 finding to a rule A rejection: '
    'power(100.25) on [[1150,1],[0,1150]] now raises '
    'matrix-out-of-precision-range',
    () {
      // A=[[1150,1],[0,1150]] has a repeated eigenvalue l=1150 (Jordan
      // block), and every raw entry (1150, 1, 0) sits well inside
      // [1e-150, 1e150], so this passes the argument-side D38 check. But
      // rule A also requires the RESULT eigenvalue (l^y = 1150^100.25,
      // whose log-magnitude is y*ln(l)) to be in the same declared range:
      // y*ln(l) = 100.25 * ln(1150) is about 706.51, far above
      // ln(1e150)~=345.39. This now raises matrix-out-of-precision-range
      // before ever computing pow(1150, 100.25), superseding this
      // finding's previous overflowed-c0 regression check, which asserted
      // a finite result matching an independently derived mpmath
      // reference (fl ~= 6.8384629050092065369e+306) before rule A
      // existed.
      test(
        'power(100.25) on [[1150,1],[0,1150]] raises '
        'matrix-out-of-precision-range',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1150, 1],
            <double>[0, 1150],
          ]);

          expect(
            () => value.power(Matrix.scalar(100.25)),
            throwsOutOfPrecisionRange(),
          );
        },
      );
    },
  );

  group(
    'Round 12, finding 6: general 2x2 exp\'s repeated-eigenvalue branch '
    'converted from an overflowed-c0 finding to a rule A rejection: '
    'exp([[709,1],[0,709]]) now raises matrix-out-of-precision-range',
    () {
      // A=[[709,1],[0,709]]: triangular with equal diagonal entries, so
      // the eigenvalue is repeated exactly at l=709, and every raw entry
      // (709, 1, 0) sits well inside [1e-150, 1e150], so this passes the
      // argument-side D38 check. But rule A also requires the RESULT
      // eigenvalue (exp(l), whose log-magnitude is l itself) to be in the
      // same declared range: l=709 is far above ln(1e150)~=345.39. This
      // now raises matrix-out-of-precision-range before ever computing
      // exp(709), superseding this finding's previous overflowed-c0
      // regression check, which asserted a finite result (every entry
      // exp(709) except the exact-zero (1,0)) before rule A existed.
      test(
        'exp([[709,1],[0,709]]) raises matrix-out-of-precision-range',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[709, 1],
            <double>[0, 709],
          ]);

          expect(value.exp, throwsOutOfPrecisionRange());
        },
      );
    },
  );

  group(
    'Round 12, finding 7: general 2x2 log\'s "far apart" relativeGap '
    'threshold sits too close to sqrt(machine epsilon), so a pair of '
    'eigenvalues whose relative gap is just barely above that threshold '
    'still suffers meaningful cancellation in the direct '
    '(log(lBig) - log(lSmall)) / (lBig - lSmall) divided difference',
    () {
      // A=[[1e200,1e200],[0,9.999999850839375e199]]: triangular,
      // eigenvalues lBig=1e200, lSmall=9.999999850839375e199.
      // relativeGap = (lBig-lSmall)/lBig ~= 1.4916062468187247e-08, just
      // above closeEigenvalueThreshold (sqrt(machine epsilon) ~=
      // 1.4901161193847656e-08), so this takes the direct branch, whose
      // absolute rounding error (~machine epsilon * |log(lBig)|, since
      // log(lBig) and log(lSmall) are each independently rounded to
      // ~0.5ulp) is comparable to the true difference
      // log(lBig)-log(lSmall) (~1.4916e-08 in this case), losing most of
      // c1's significant digits. Reference (mpmath, dps=60), independent
      // of this implementation.
      // D38 declared precision contract: entries 1e200 and
      // 9.999999850839375e199 both sit above matrixFunctionMaxMagnitude=
      // 1e150, so this is now rejected outright before the
      // relativeGap-threshold fix this test used to regression-check ever
      // runs.
      test('log() raises matrix-out-of-precision-range', () {
        final Matrix value = Matrix(<List<double>>[
          <double>[1e200, 1e200],
          <double>[0, 9.999999850839375e199],
        ]);

        expect(
          value.log,
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.matrixOutOfPrecisionRange,
            ),
          ),
        );
      });
    },
  );

  group(
    'Round 12, finding 9: general 2x2 log\'s repeated-eigenvalue branch '
    'c1 = 1/l overflows for a subnormal-scale repeated eigenvalue, even '
    'when it only ever feeds into a genuinely finite entry',
    () {
      // A=[[2l,l],[-l,0]] with l=1e-320 (subnormal) is a genuine Jordan
      // coupling (a != d, but the discriminant is still exactly 0:
      // (a-d)/2 = l and bc = -l^2, so (a-d)^2+4bc = 4l^2-4l^2 = 0,
      // repeated eigenvalue l1=l2=(a+d)/2=l). c1 = 1/l = 1e320
      // overflows past double's max (~1.7977e308), even though the true
      // centered-form entries (log(l)*I + (1/l)*(A-l*I), where each
      // (A-l*I) entry is itself O(l), so (1/l)*(A-l*I) entry is O(1)) are
      // all finite. Reference (mpmath, dps=60), independent of this
      // implementation: log(l) = -736.8272408909739061509869,
      // entry00 = log(l)+1 = -735.8272408909739061509869,
      // entry11 = log(l)-1 = -737.8272408909739061509869,
      // entry01 = b/l = 1.0, entry10 = c/l = -1.0.
      // D38 declared precision contract: l=1e-320 is a subnormal double,
      // far below matrixFunctionMinMagnitude=1e-150, so this is now
      // rejected outright before the overflowed-c1 fix this test used to
      // regression-check ever runs.
      test('log() on [[2e-320,1e-320],[-1e-320,0]] raises '
          'matrix-out-of-precision-range', () {
        const double l = 1e-320;
        final Matrix value = Matrix(<List<double>>[
          <double>[2 * l, l],
          <double>[-l, 0],
        ]);

        expect(
          value.log,
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.matrixOutOfPrecisionRange,
            ),
          ),
        );
      });
    },
  );

  group(
    'Round 12, finding 10: general 2x2 log\'s complex-eigenvalue-pair '
    'branch c1 = angle/w overflows for a subnormal-scale eigenvalue '
    'pair, even when it only ever feeds into genuinely finite entries',
    () {
      // A=[[w,w],[-2w,-w]] with w=1e-309 (subnormal): m=(a+d)/2=0,
      // discriminant (a-d)^2+4bc = 4w^2 - 8w^2 = -4w^2, complex pair with
      // eigenvalue-pair half-width w_eigen = w, angle = atan2(w,0) =
      // pi/2. c1 = angle/w_eigen = (pi/2)/1e-309 overflows past double's
      // max, even though the true centered-form entries (log(w)*I +
      // (angle/w_eigen)*A, where every entry of A is O(w), so
      // (angle/w_eigen)*entry is O(1)) are all finite. Reference (mpmath,
      // dps=60), independent of this implementation:
      // log(w) = -711.4987937351601144759702,
      // entry00 = log(w)+pi/2 = -709.9279974083652178567388,
      // entry11 = log(w)-pi/2 = -713.0695900619550110952015,
      // entry01 = pi/2 = 1.570796326794896619231322,
      // entry10 = -pi = -3.141592653589793238462643.
      // D38 declared precision contract: w=1e-309 is a subnormal double,
      // far below matrixFunctionMinMagnitude=1e-150, so this is now
      // rejected outright before the overflowed-c1 fix this test used to
      // regression-check ever runs.
      test('log() on [[1e-309,1e-309],[-2e-309,-1e-309]] raises '
          'matrix-out-of-precision-range', () {
        const double w = 1e-309;
        final Matrix value = Matrix(<List<double>>[
          <double>[w, w],
          <double>[-2 * w, -w],
        ]);

        expect(
          value.log,
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.matrixOutOfPrecisionRange,
            ),
          ),
        );
      });
    },
  );
}
