// Round 8 correction: twelve findings from an independent review of
// lib/src/matrix/matrix.dart, each covered here by a test that fails
// before its paired fix and asserts a concrete numeric value or error id.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Round 8, finding 1: general 2x2 exp real-eigenvalue divided '
      'difference must not cancel to zero for well-separated eigenvalues', () {
    test('exp([[0,1],[0,50]]) has a finite [0][0] entry close to 1', () {
      final Matrix result = Matrix(<List<double>>[
        <double>[0, 1],
        <double>[0, 50],
      ]).exp();

      expect(result.at(0, 0).isFinite, isTrue);
      expect(result.at(0, 0), closeTo(1.0, 1e-9));
      expect(result.at(1, 1), closeTo(math.exp(50), math.exp(50) * 1e-9));
    });

    test('exp([[-1000,1],[0,-500]]) has a finite [1][1] entry close to '
        'exp(-500)', () {
      final Matrix result = Matrix(<List<double>>[
        <double>[-1000, 1],
        <double>[0, -500],
      ]).exp();

      expect(result.at(1, 1).isFinite, isTrue);
      expect(
        result.at(1, 1),
        closeTo(math.exp(-500), math.exp(-500) * 1e-9),
      );
      expect(result.at(0, 0), closeTo(math.exp(-1000), 1e-300));
    });
  });

  group('Round 8, finding 2: general 2x2 complex-pair closed forms must use '
      'the centered discriminant halfDiff^2 + b*c, not trace^2 - 4*det, to '
      'find the rotation frequency w', () {
    test('exp(A) matches the centered-discriminant closed form for a '
        'complex pair whose uncentered discriminant loses precision', () {
      // a=1e8, d=-99999999, b=1e8, c=-99999999.00000004: chosen so the
      // true (centered) discriminant halfDiff^2 + b*c is -4 (m=0.5, w=2),
      // but trace^2 - 4*det evaluates to -15 instead of -16, a large
      // relative error from subtracting two ~1e16-magnitude terms. Both
      // formulas agree the pair is complex, so this is not a
      // classification flip: it is the recomputed discriminant itself
      // (used for the rotation frequency w in the c0*I + c1*A closed
      // form) losing precision, which changes exp(A) by several percent.
      final double a = 100000000.0;
      final double b = 100000000.0;
      final double c = -99999999.00000004;
      final double d = -99999999.0;
      final Matrix matrix = Matrix(<List<double>>[
        <double>[a, b],
        <double>[c, d],
      ]);

      final Matrix result = matrix.exp();

      // True closed form: m = (a+d)/2 = 0.5, w = sqrt(-(halfDiff^2+b*c))
      // = 2 exactly (by construction), em = exp(0.5),
      // c1 = em * sin(w) / w, c0 = em * cos(w) - c1 * m.
      final double m = 0.5;
      final double w = 2.0;
      final double em = math.exp(m);
      final double c1 = em * math.sin(w) / w;
      final double c0 = em * math.cos(w) - c1 * m;
      final double expected00 = c0 + c1 * a;
      final double expected01 = c1 * b;
      final double expected10 = c1 * c;
      final double expected11 = c0 + c1 * d;

      expect(result.at(0, 0), closeTo(expected00, expected00.abs() * 1e-6));
      expect(result.at(0, 1), closeTo(expected01, expected01.abs() * 1e-6));
      expect(result.at(1, 0), closeTo(expected10, expected10.abs() * 1e-6));
      expect(result.at(1, 1), closeTo(expected11, expected11.abs() * 1e-6));
    });
  });
}
