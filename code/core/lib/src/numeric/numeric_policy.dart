import 'dart:math' as math;

class CalculatrixNumericPolicy {
  const CalculatrixNumericPolicy._();

  static const double defaultRelativeTolerance = 1e-10;
  static const double defaultAbsoluteTolerance = 1e-12;

  /// Rounding-noise floor used specifically to classify a computed real
  /// eigenvalue as non-positive (for the principal-logarithm/power domain
  /// gate), and to decide whether a 2x2 block's discriminant is genuinely
  /// zero (a repeated real root) rather than a small negative value from a
  /// real complex-conjugate pair.
  ///
  /// This is deliberately much tighter than [defaultAbsoluteTolerance]
  /// (1e-12), which is calibrated for Hessenberg/QR convergence residuals,
  /// not for "is this eigenvalue effectively zero". Eigenvalues computed
  /// via the cancellation-resistant stable quadratic formula are accurate
  /// to within a handful of ULPs of their own magnitude however small —
  /// e.g. 1e-13 is a fully legitimate positive eigenvalue of a matrix whose
  /// other entries are O(1) and must not be treated as rounding noise just
  /// because it is smaller than [defaultAbsoluteTolerance]. 1e-14 sits just
  /// above double's own relative precision (~2.22e-16) with headroom for
  /// the handful of arithmetic operations in the eigenvalue pipeline.
  static const double eigenvalueRoundingNoiseTolerance = 1e-14;

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
