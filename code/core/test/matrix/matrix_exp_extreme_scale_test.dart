import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// The exact shifted-nilpotent path of `exp()` scales a finite sum by e^mu.
/// When e^mu alone underflows a double while the scaled entries do not,
/// scaling by e^mu in one step flushes them to zero.
void main() {
  // Smallest positive subnormal double: the spacing of the subnormal range.
  const double subnormalSpacing = 4.9406564584124654e-324;

  test('[[-746 1000] [0 -746]] keeps the subnormal (0,1) entry '
      '(Giac: 1000 e^-746 = 1.03828480951582823942500912128e-321)', () {
    final result = Matrix(<List<double>>[
      <double>[-746, 1000],
      <double>[0, -746],
    ]).exp();

    const double reference = 1.03828480951582823942500912128e-321;
    expect(result.at(0, 1), closeTo(reference, subnormalSpacing));
    // e^-746 is below half the smallest subnormal: it rounds to zero.
    expect(result.at(0, 0), 0);
    expect(result.at(1, 1), 0);
    expect(result.at(1, 0), 0);
  });

  test('[[-800 1e300] [0 -800]]: e^-800 underflows to 0 alone, but '
      '1e300 e^-800 (Giac: 3.6679e-48) is a normal double', () {
    final result = Matrix(<List<double>>[
      <double>[-800, 1e300],
      <double>[0, -800],
    ]).exp();

    // Giac: evalf(1e300*exp(-800), 30) with exact 10^300.
    const double reference = 3.66787458417768721345549565426e-48;
    expect(result.at(0, 1), closeTo(reference, reference * 1e-13));
    expect(result.at(0, 0), 0);
  });
}
