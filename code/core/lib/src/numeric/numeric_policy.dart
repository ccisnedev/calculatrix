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
  /// compared entries), rather than as a fixed absolute floor: a fixed
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
  /// `2.5e7 * 2.22e-16 =~ 5.5e-9`, above 1e-10: demanding 1e-10 there
  /// would reject a numerically correct principal square root because no
  /// double-precision computation of it can ever be that precise. 1e-8
  /// gives headroom above that bound for condition numbers up into the
  /// low 1e8s while still enforcing a materially tight residual, and is
  /// only ever used as a floor: it never loosens what a well-conditioned
  /// input already achieves, since those converge far tighter than either
  /// this or the caller's own `relativeTolerance` regardless.
  static const double sqrtResidualAcceptanceTolerance = 1e-8;

  /// Sweep budget for [Matrix]'s cyclic Jacobi eigendecomposition (Golub
  /// and Van Loan, "Matrix Computations", section 8.5), used by the
  /// exactly-symmetric-matrix branch of `sqrt`, `exp`, `log` and `power`.
  ///
  /// Cyclic Jacobi converges quadratically once off-diagonal entries are
  /// small, so 50 sweeps is far more than any legitimate finite,
  /// well-posed symmetric input needs; exceeding this budget without
  /// converging raises [CalculatrixErrorId.noConvergence] instead of
  /// returning an under-converged result. Not a public parameter on any of
  /// those methods (round 8 correction, finding 11): a caller cannot pick
  /// a smaller budget and get a faster but less accurate answer, since
  /// there is no such tradeoff to make here, only convergence or a typed
  /// error.
  static const int jacobiMaxSweeps = 50;

  /// D38 declared precision contract: the closed range every nonzero raw
  /// entry of a matrix passed to `Matrix.exp`, `Matrix.log`, `Matrix.sqrt`
  /// or a non-integer `Matrix.power` must lie in before anything is
  /// computed, and every nonzero eigenvalue those functions compute (or,
  /// for a general 2x2 complex-conjugate pair, its real part `m` and
  /// rotation half-width `w`) must also lie in once computed. An input or
  /// a computed eigenvalue outside `[matrixFunctionMinMagnitude,
  /// matrixFunctionMaxMagnitude]` is rejected outright
  /// ([CalculatrixErrorId.matrixOutOfPrecisionRange]), never guessed at:
  /// this replaces case-by-case patching of individual overflow/
  /// cancellation bugs discovered outside this range with one declarative
  /// gate. Zero is always allowed, at any of the five supported
  /// matrix-function classes, regardless of this range. Integer matrix
  /// powers (computed by repeated multiplication, [Matrix._integerMatrixPower])
  /// are not affected: this range only bounds the four closed-form
  /// eigenvalue-based functions.
  ///
  /// Inside this range, the accuracy contract is condition-relative, not a
  /// flat or componentwise one: the normwise (Frobenius) relative error
  /// `||F_computed - F_true|| / ||F_true||` is at most
  /// `matrixFunctionAccuracyFactor * max(1, kappa(f, A)) * unitRoundoff`,
  /// the `max(1, ...)` floor covering a well-conditioned pair whose
  /// `kappa(f, A)` computes below 1 purely from how that ratio is defined
  /// (for example `exp` at a tiny eigenvalue, where `kappa(f, A)` can come
  /// out below 1 even though the achievable accuracy is still bounded below
  /// by the flat, condition-1 figure, never better than it), where
  /// `kappa(f, A) = ||L_f(A)||_F * ||A||_F / ||f(A)||_F` is the relative
  /// condition number of `f` at `A` in the Frobenius norm (`L_f(A)` the
  /// Frechet derivative of `f` at `A`, a linear operator on 2x2 matrices;
  /// Higham, "Functions of Matrices", section 3.1; `||L_f(A)||_F` is the
  /// operator norm induced by the Frobenius inner product, i.e. the
  /// largest singular value of the 4x4 matrix representing `L_f(A)` on the
  /// vec-flattened, and therefore orthonormal, basis of 2x2 matrices under
  /// that inner product); see the dartdoc of `Matrix.exp`, `Matrix.log`,
  /// `Matrix.sqrt` and `Matrix.power` for that contract's statement on
  /// each function, and [matrixFunctionAccuracyFactor] and [unitRoundoff]
  /// for the bound's two named factors.
  static const double matrixFunctionMinMagnitude = 1e-150;

  /// See [matrixFunctionMinMagnitude].
  static const double matrixFunctionMaxMagnitude = 1e150;

  /// Double-precision unit roundoff, `u = 2^-53`
  /// (~1.1102230246251565e-16): half of [machineEpsilon] (`2^-52`). This is
  /// the constant conventionally called `u` in backward-error-analysis
  /// bounds of the form `c * kappa * u` (Higham, "Accuracy and Stability of
  /// Numerical Algorithms"), as distinct from [machineEpsilon] (`2^-52`,
  /// "the gap between 1.0 and the next representable double"), which this
  /// codebase uses elsewhere for scale-relative comparison tolerances, not
  /// for stating an error bound's roundoff unit. Used only in the D38
  /// condition-relative accuracy contract on [matrixFunctionMinMagnitude];
  /// see that constant and [matrixFunctionAccuracyFactor].
  static const double unitRoundoff = 1.1102230246251565e-16;

  /// Named constant factor in the D38 condition-relative accuracy contract
  /// on [matrixFunctionMinMagnitude]: the bound on the normwise relative
  /// error of `Matrix.exp`, `Matrix.log`, `Matrix.sqrt` and non-integer
  /// `Matrix.power`, inside the declared magnitude range, is
  /// `matrixFunctionAccuracyFactor * max(1, kappa(f, A)) * unitRoundoff`.
  ///
  /// Chosen so that a well-conditioned problem (`kappa(f, A) ~= 1`, e.g. a
  /// matrix function evaluated away from a repeated or near-repeated
  /// eigenvalue) recovers the flat figure this codebase used before the
  /// contract became condition-relative: `1e4 * 1 * 1.1102230246251565e-16
  /// ~= 1.11e-12 ~= 1e-12`. For an ill-conditioned `(f, A)` pair the bound
  /// scales up with `kappa(f, A)`, since no double-precision algorithm can
  /// do better than roughly `kappa(f, A) * unitRoundoff` regardless of how
  /// it is implemented (this is a property of the problem, not of this
  /// library's algorithms); a large `kappa(f, A)` purely from `||A||_F`
  /// dwarfing `||f(A)||_F` (rather than from a large Frechet-derivative
  /// operator norm) still legitimately widens this bound, since the
  /// definition of `kappa(f, A)` (see [matrixFunctionMinMagnitude]) does
  /// not distinguish the two causes. The `max(1, ...)` floor exists because
  /// `kappa(f, A)` can compute to below 1 for a pair where `||f(A)||_F`
  /// happens to exceed `||L_f(A)||_F * ||A||_F` (for example `exp` at a
  /// tiny eigenvalue, where `exp` itself is close to 1 while its derivative
  /// times the eigenvalue's own tiny magnitude is smaller still): no
  /// double-precision algorithm ever does better than the flat,
  /// condition-1 figure regardless of how favorably `kappa(f, A)` computes,
  /// so the bound never drops below it.
  static const double matrixFunctionAccuracyFactor = 1e4;

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
