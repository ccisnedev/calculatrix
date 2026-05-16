import 'dart:math' as math;

class CalculatrixNumericPolicy {
  const CalculatrixNumericPolicy._();

  static const double defaultRelativeTolerance = 1e-10;
  static const double defaultAbsoluteTolerance = 1e-12;

  static bool nearlyEqual(
    double a,
    double b, {
    double relativeTolerance = defaultRelativeTolerance,
    double absoluteTolerance = defaultAbsoluteTolerance,
  }) {
    if (a == b) {
      return true;
    }

    final double diff = (a - b).abs();
    if (diff <= absoluteTolerance) {
      return true;
    }

    final double scale = math.max(a.abs(), b.abs());
    if (scale == 0) {
      return diff <= absoluteTolerance;
    }

    return diff <= relativeTolerance * scale;
  }
}
