import 'dart:math' as math;

class CalculatrixNumericPolicy {
  const CalculatrixNumericPolicy._();

  static const double defaultRelativeTolerance = 1e-10;
  static const double defaultAbsoluteTolerance = 1e-12;

  /// Double-precision unit roundoff, `u = 2^-52` (~2.220446e-16): the gap
  /// between 1.0 and the next representable double, divided by 2. Scale-
  /// relative tolerances throughout the eigenvalue/kind-classification
  /// pipeline are expressed as a small integer multiple of this constant
  /// times the relevant magnitude (a matrix norm, or the larger of two
  /// compared entries), rather than as a fixed absolute floor — a fixed
  /// floor is wrong by construction at any scale other than the one it was
  /// tuned for (see [eigenvalueRoundingNoiseTolerance] and the doc comments
  /// on `Matrix.isComplexForm` and `Matrix.log` for the specific formulas).
  static const double machineEpsilon = 2.220446049250313e-16;

  /// Rounding-noise floor used specifically to decide whether a 2x2 block's
  /// discriminant is genuinely zero (a repeated real root) rather than a
  /// small negative value from a real complex-conjugate pair.
  ///
  /// This is deliberately much tighter than [defaultAbsoluteTolerance]
  /// (1e-12), which is calibrated for Hessenberg/QR convergence residuals,
  /// not for "is this discriminant effectively zero". It is used as the
  /// `eps` in `|discriminant| <= eps * (trace^2 + |det|)`, i.e. already
  /// scaled to the block's own magnitude by the caller, so this constant
  /// only needs to cover the handful of arithmetic operations in the
  /// eigenvalue pipeline above double's own relative precision (~2.22e-16,
  /// see [machineEpsilon]).
  ///
  /// Not used to gate eigenvalue non-positivity for `Matrix.log`/`power`
  /// (see that method's own doc comment for why a fixed floor is wrong
  /// there too, regardless of how tight).
  static const double eigenvalueRoundingNoiseTolerance = 1e-14;

  /// Practically-reachable relative-residual acceptance floor for
  /// `Matrix.sqrt`'s Denman-Beavers Newton iteration on a genuinely
  /// ill-conditioned (but real, positive-definite-in-the-relevant-sense)
  /// matrix.
  ///
  /// Newton's iteration for `X <- 0.5*(X + X^-1*A)` amplifies double's own
  /// rounding error by roughly the input matrix's condition number, so the
  /// best relative accuracy actually achievable in `‖S*S - A‖ / ‖A‖` is
  /// bounded below by `condition(A) * machineEpsilon`, not by
  /// [defaultRelativeTolerance] (1e-10). A symmetric positive-definite
  /// matrix with condition number ~2.5e7 (e.g. eigenvalues ~5 and ~2e-7)
  /// already limits achievable accuracy to roughly
  /// `2.5e7 * 2.22e-16 =~ 5.5e-9`, above 1e-10 — demanding 1e-10 there
  /// would reject a numerically correct principal square root because no
  /// double-precision computation of it can ever be that precise. 1e-8
  /// gives headroom above that bound for condition numbers up into the
  /// low 1e8s while still enforcing a materially tight residual, and is
  /// only ever used as a floor: it never loosens what a well-conditioned
  /// input already achieves, since those converge far tighter than either
  /// this or the caller's own `relativeTolerance` regardless.
  static const double sqrtResidualAcceptanceTolerance = 1e-8;

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
