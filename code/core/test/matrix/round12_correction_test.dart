// Round 12 correction: seven findings from an independent review of PR #7
// (feat/core-power-and-error-ids), each covered here by a test that fails
// before its paired fix and asserts a concrete numeric value or behavior,
// checked against an independently derived reference (Python mpmath at
// 200-1200 decimal digits, or an analytically stated closed form), never
// against this implementation's own prior output.
import 'dart:math' as math;

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
      test('log() does not throw for the true positive real eigenvalues', () {
        final Matrix value = Matrix(<List<double>>[
          <double>[1e-200, 1e-200],
          <double>[2e-200, 4e-200],
        ]);

        final Matrix result = value.log();

        // Reference (mpmath, dps=1200):
        expectRelativelyClose(result.at(0, 0), -461.02253778330164);
        expectRelativelyClose(result.at(0, 1), 0.56806184984831558);
        expectRelativelyClose(result.at(1, 0), 1.1361236996966312);
        expectRelativelyClose(result.at(1, 1), -459.31835223375669);
      });

      test(
        'power(-0.5) matches the mpmath reference, not a false zero '
        'eigenvalue rejection or a garbage finite value',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e-200, 1e-200],
            <double>[2e-200, 4e-200],
          ]);

          final Matrix result = value.power(Matrix.scalar(-0.5));

          // Reference (mpmath, dps=1200):
          expectRelativelyClose(result.at(0, 0), 1.3683056745854404e+100);
          expectRelativelyClose(result.at(0, 1), -2.5272473256221178e+99);
          expectRelativelyClose(result.at(1, 0), -5.0544946512442356e+99);
          expectRelativelyClose(result.at(1, 1), 6.1013147689880504e+99);
        },
      );

      test(
        'sqrt() recovers the true small eigenvalue-weighted (0,0) entry, '
        'not the value produced by trusting the underflowed direct '
        'determinant',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e-200, 1e-200],
            <double>[2e-200, 4e-200],
          ]);

          final Matrix result = value.sqrt();

          // Reference (mpmath, dps=1200): the bug produces 4.68213...e-101
          // here (using lambda2 = 0 from the false directDet=0 reading);
          // the true value is 8.6285620946101682e-101.
          expectRelativelyClose(result.at(0, 0), 8.6285620946101682e-101);
          expectRelativelyClose(result.at(0, 1), 3.5740674433659326e-101);
          expectRelativelyClose(result.at(1, 0), 7.1481348867318651e-101);
          expectRelativelyClose(result.at(1, 1), 1.9350764424707966e-100);
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
      test('exp() equals cos(1)*I + sin(1)*A, not the identity', () {
        final Matrix value = Matrix(<List<double>>[
          <double>[0, 1e200],
          <double>[-1e-200, 0],
        ]);

        final Matrix result = value.exp();

        expectRelativelyClose(result.at(0, 0), math.cos(1));
        expectRelativelyClose(result.at(1, 1), math.cos(1));
        expectRelativelyClose(result.at(0, 1), math.sin(1) * 1e200);
        expectRelativelyClose(result.at(1, 0), math.sin(1) * -1e-200);
      });

      test('log() does not throw (genuine complex pair, never undefined)', () {
        final Matrix value = Matrix(<List<double>>[
          <double>[0, 1e200],
          <double>[-1e-200, 0],
        ]);

        expect(() => value.log(), returnsNormally);
        expect(value.log().at(0, 0).isFinite, isTrue);
      });

      test('sqrt() does not throw (genuine complex pair, never undefined)', () {
        final Matrix value = Matrix(<List<double>>[
          <double>[0, 1e200],
          <double>[-1e-200, 0],
        ]);

        expect(() => value.sqrt(), returnsNormally);
        expect(value.sqrt().at(0, 0).isFinite, isTrue);
      });

      test(
        'power(0.5) does not throw (genuine complex pair, never undefined)',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[0, 1e200],
            <double>[-1e-200, 0],
          ]);

          expect(() => value.power(Matrix.scalar(0.5)), returnsNormally);
          expect(
            value.power(Matrix.scalar(0.5)).at(0, 0).isFinite,
            isTrue,
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
      test('s=1e-200: does not throw, matches the mpmath reference', () {
        const double s = 1e-200;
        final Matrix value = Matrix(<List<double>>[
          <double>[0, s],
          <double>[-2 * s, 0],
        ]);

        final Matrix result = value.power(Matrix.scalar(-1.5));

        expectRelativelyClose(result.at(0, 0), -4.2044820762685727e+299);
        expectRelativelyClose(result.at(0, 1), -2.9730177875068027e+299);
        expectRelativelyClose(result.at(1, 0), 5.9460355750136053e+299);
        expectRelativelyClose(result.at(1, 1), -4.2044820762685727e+299);
      });

      test(
        's=1e200: recovers the true nonzero off-diagonal entries, not '
        'an underflowed 0',
        () {
          const double s = 1e200;
          final Matrix value = Matrix(<List<double>>[
            <double>[0, s],
            <double>[-2 * s, 0],
          ]);

          final Matrix result = value.power(Matrix.scalar(-1.5));

          expectRelativelyClose(result.at(0, 0), -4.2044820762685727e-301);
          expectRelativelyClose(result.at(0, 1), -2.9730177875068027e-301);
          expectRelativelyClose(result.at(1, 0), 5.9460355750136053e-301);
          expectRelativelyClose(result.at(1, 1), -4.2044820762685727e-301);
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
      test(
        'power(1e-20) on [[1e200,1],[0,1e-200]] recovers the true nonzero '
        '(0,1) entry, not a false 0 from the log1p fallback\'s own '
        'degenerate argument',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e200, 1],
            <double>[0, 1e-200],
          ]);

          final Matrix result = value.power(Matrix.scalar(1e-20));

          expectRelativelyClose(result.at(0, 0), 1.0000000000000000046);
          expectRelativelyClose(result.at(0, 1), 9.2103403719761827361e-218);
          expect(result.at(1, 0), equals(0));
          expectRelativelyClose(result.at(1, 1), 0.99999999999999999539);
        },
      );

      // Negative-y variant of the same counterexample: y=-1e-20. Reference
      // (mpmath, dps=100): fa = 0.99999999999999999539,
      // fd = 1.0000000000000000046,
      // entry01 = -9.2103403719761827361e-218.
      test(
        'power(-1e-20) on [[1e200,1],[0,1e-200]] recovers the true nonzero '
        '(0,1) entry with the correct sign',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e200, 1],
            <double>[0, 1e-200],
          ]);

          final Matrix result = value.power(Matrix.scalar(-1e-20));

          expectRelativelyClose(result.at(0, 0), 0.99999999999999999539);
          expectRelativelyClose(
            result.at(0, 1),
            -9.2103403719761827361e-218,
          );
          expect(result.at(1, 0), equals(0));
          expectRelativelyClose(result.at(1, 1), 1.0000000000000000046);
        },
      );

      // Forward-looking regression, not a currently-failing case: guards
      // the new unconditional far-branch formula against reintroducing an
      // overflow of its own. A naive, unconditional implementation of
      // lyBig - lySmall = lySmall * expm1(y * (ln lBig - ln lSmall)) would
      // itself overflow here, because y * (ln lBig - ln lSmall) ~ 1409.18
      // is far past the point where exp() (and therefore expm1()) itself
      // overflows (~709), even though lySmall is finite and the true
      // product is representable; the sign-of-y-conditioned form this fix
      // uses instead always keeps expm1's own argument non-positive.
      // Reference (mpmath, dps=100): fa = 1.0e+306, fd = 1.0e-306,
      // entry01 = 1000000.0.
      test(
        'power(1.02) on [[1e300,1],[0,1e-300]] does not overflow the way '
        'an unconditional expm1(y * logDiff) form would',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e300, 1],
            <double>[0, 1e-300],
          ]);

          final Matrix result = value.power(Matrix.scalar(1.02));

          expectRelativelyClose(result.at(0, 0), 1.0e+306);
          expectRelativelyClose(result.at(0, 1), 1000000.0);
          expect(result.at(1, 0), equals(0));
          expectRelativelyClose(result.at(1, 1), 1.0e-306);
        },
      );

      // Negative-y counterpart of the regression above, confirming the
      // sign-of-y branch selection is correct in both directions.
      // Reference (mpmath, dps=100): fa = 1.0e-306, fd = 1.0e+306,
      // entry01 = -1000000.0.
      test(
        'power(-1.02) on [[1e300,1],[0,1e-300]] does not overflow either',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e300, 1],
            <double>[0, 1e-300],
          ]);

          final Matrix result = value.power(Matrix.scalar(-1.02));

          expectRelativelyClose(result.at(0, 0), 1.0e-306);
          expectRelativelyClose(result.at(0, 1), -1000000.0);
          expect(result.at(1, 0), equals(0));
          expectRelativelyClose(result.at(1, 1), 1.0e+306);
        },
      );
    },
  );

  group(
    'Round 12, finding 8: general 2x2 power\'s repeated-eigenvalue branch '
    'c0 = pow(l,y) - c1*l overflows even though every entry it feeds '
    'stays finite',
    () {
      // A=[[1150,1],[0,1150]] has a repeated eigenvalue l=1150 (Jordan
      // block). With y=100.25, pow(l,y) ~ 6.84e+306 and c1 = y*l^(y-1)
      // ~ 5.96e+305 are each individually finite, but c0 = pow(l,y) -
      // c1*l overflows: c1*l ~ 6.86e+308, past double's max (~1.8e+308).
      // The true entries (c0*I + c1*A collapsed algebraically) are all
      // finite. Reference (mpmath, dps=150), independent of this
      // implementation: fl = 6.8384629050092065369e+306,
      // fprime (c1) = 5.9613557063232430898e+305, entry00 = entry11 = fl
      // (since a - l = d - l = 0), entry01 = fprime * b =
      // 5.9613557063232430898e+305.
      test(
        'power(100.25) on [[1150,1],[0,1150]] returns a finite result '
        'instead of throwing MatrixDomainError from an overflowed c0',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1150, 1],
            <double>[0, 1150],
          ]);

          final Matrix result = value.power(Matrix.scalar(100.25));

          expectRelativelyClose(result.at(0, 0), 6.8384629050092065369e+306);
          expectRelativelyClose(result.at(0, 1), 5.9613557063232430898e+305);
          expect(result.at(1, 0), equals(0));
          expectRelativelyClose(result.at(1, 1), 6.8384629050092065369e+306);
        },
      );
    },
  );

  group(
    'Round 12, finding 6: general 2x2 exp\'s repeated-eigenvalue branch '
    'must not materialize c0 = f(l) - c1*l as a standalone value when '
    'c1*l overflows, even though every entry c0 actually feeds into '
    '(c0 + c1*a, c0 + c1*d) is itself finite',
    () {
      // A=[[709,1],[0,709]]: triangular with equal diagonal entries, so
      // the eigenvalue is repeated exactly at l=709. el = exp(709) is
      // close to double's max (~1.7977e308), so c1*l = el*709 overflows
      // to Infinity even though the true result (mpmath, dps=60) is
      // finite: every entry is exp(709) except the exact-zero (1,0).
      test('exp([[709,1],[0,709]]) does not throw, matches exp(709)', () {
        final Matrix value = Matrix(<List<double>>[
          <double>[709, 1],
          <double>[0, 709],
        ]);

        final Matrix result = value.exp();

        final double expected = 8.2184074615549721892e+307;
        expectRelativelyClose(result.at(0, 0), expected);
        expectRelativelyClose(result.at(0, 1), expected);
        expect(result.at(1, 0), equals(0));
        expectRelativelyClose(result.at(1, 1), expected);
      });
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
      test(
        'log() recovers the true (0,1) entry to near machine precision, '
        'not a value with a 1e-6-scale relative error from cancellation',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e200, 1e200],
            <double>[0, 9.999999850839375e199],
          ]);

          final Matrix result = value.log();

          expectRelativelyClose(result.at(0, 0), 460.5170185988091368);
          expectRelativelyClose(result.at(0, 1), 1.0000000074580313242);
          expect(result.at(1, 0), equals(0));
          expectRelativelyClose(result.at(1, 1), 460.51701858389307419);
        },
      );
    },
  );
}
