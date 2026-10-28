// The 2x2 logarithm classifies its eigenvalues with (a - d)^2 + 4bc, which
// does not cancel for large nearly equal eigenvalues.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  test('large, nearly equal real eigenvalues', () {
    final Matrix a = Matrix(<List<double>>[
      <double>[1e8, 1],
      <double>[0, 1e8 + 0.2],
    ]);
    final Matrix log = a.log();
    final double l1 = 18.420680743952367; // ln 1e8
    final double l2 = 18.420680745952364; // ln (1e8 + 0.2)
    expect(log.at(0, 0), closeTo(l1, 1e-12));
    expect(log.at(1, 1), closeTo(l2, 1e-12));
    expect(log.at(1, 0), 0);
    // (ln d - ln a) / (d - a) for the off-diagonal entry.
    expect(log.at(0, 1), closeTo(1e-8, 1e-17));
    final Matrix back = log.exp();
    expect(back.at(0, 1), closeTo(1, 1e-6));
  });

  test('a repeated eigenvalue far from zero is real, not complex', () {
    final Matrix log = Matrix(<List<double>>[
      <double>[1e8, 1],
      <double>[0, 1e8],
    ]).log();
    expect(log.at(0, 0), closeTo(18.420680743952367, 1e-12));
    expect(log.at(0, 1), closeTo(1e-8, 1e-17));
    expect(log.at(1, 0), 0);
  });
}
