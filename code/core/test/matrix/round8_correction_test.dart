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
}
