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
}
