// Core PR #7 Codex round 14, 3 medium findings:
//
//   Finding 1: [Matrix._powerByMatrixExponent] validated only each
//      operand's raw ENTRIES ([Matrix._requireEntriesInPrecisionRange])
//      before chaining its internal `log`/`exp` helpers, never the
//      operand's own eigenvalue SPECTRUM. A complex-form operand's
//      eigenvalue magnitude is `hypot(realPart, imagPart)`, which can
//      exceed the declared precision range even when `realPart` and
//      `imagPart` individually do not (the same gap round 9, finding 5
//      already closed for standalone [Matrix.exp]/[Matrix.log]/
//      [Matrix.power] with a real exponent, but never extended to the
//      matrix-exponent path). Fixed by
//      [Matrix._requireSpectrumInPrecisionRange], which validates the
//      full spectrum (dispatching across all five supported
//      matrix-function classes) instead of merely the entries, applied to
//      both the base and the exponent before either is used.
//   Finding 2: two power paths formed an angle that is provably an EXACT
//      multiple of pi (a negative real base's principal log angle) via
//      generic floating point multiplication, then called ordinary
//      `cos`/`sin` on the resulting radians value, losing the exactness
//      [Matrix._cosPi]/[Matrix._sinPi] exist to preserve (the same
//      antipattern round 13, finding 5 (P3) fixed for the real
//      scalar-exponent closed form). Site A:
//      [Matrix._complexFormRealPower] (a complex-form base with zero
//      imaginary part, raised to a real [Matrix.scalar] exponent). Site
//      B: [Matrix._powerByMatrixExponent]'s two `_internalLog() *
//      exponent` branches (a negative scalar, or a complex-form base with
//      zero imaginary part, raised to a complex-form exponent whose own
//      imaginary part is zero, i.e. the same real exponent wearing
//      complex-form clothing instead of being a [Matrix.scalar]). Both
//      sites now go through [Matrix._cosPi]/[Matrix._sinPi] on the exact
//      "turns" value directly.
//   Finding 3: [Matrix._powerByScalarExponent] validated only the BASE's
//      raw entries before dispatch, never the non-integer exponent itself,
//      which is just as much a raw public operand. Fixed by validating a
//      non-integer exponent's own magnitude against the declared precision
//      range before dispatching on the base, keeping the existing integer
//      exponent exemption (and exact zero, always integer, is unaffected).
//
// Every numeric reference value below not already exactly representable
// was either independently derived by hand from each case's own closed
// form, or probed directly from a sub-expression the fix leaves untouched
// (e.g. the magnitude `exp(y*log(-b))`, unaffected by the cosPi/sinPi
// argument-reduction fix itself), not copied from this implementation's
// own end-to-end output.
import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

Matcher throwsOutOfPrecisionRange() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.matrixOutOfPrecisionRange,
  ),
);

void main() {
  group(
    'Codex round 14, finding 1 (public operand SPECTRA, not merely '
    'entries, must satisfy D38 before _powerByMatrixExponent chains its '
    'internal helpers)',
    () {
      test(
        'complex(1e150,1e150).power(complex(0,1)) raises '
        'matrix-out-of-precision-range: the base\'s own entries (1e150 '
        'and 1e150) each individually pass the old entry-only check, but '
        'its eigenvalue magnitude hypot(1e150,1e150) (about '
        '1.4142e150) exceeds matrixFunctionMaxMagnitude (1e150)',
        () {
          expect(
            () => Matrix.complex(
              1e150,
              1e150,
            ).power(Matrix.complex(0, 1)),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        'scalar(1).power(complex(1e150,1e150)) raises '
        'matrix-out-of-precision-range: the base (scalar 1) is trivially '
        'in range, but the EXPONENT\'s own spectrum magnitude '
        'hypot(1e150,1e150) is the one that is out of range, previously '
        'unchecked entirely on the exponent side of this path',
        () {
          expect(
            () => Matrix.scalar(1).power(Matrix.complex(1e150, 1e150)),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        'a general 2x2 (non-complex-form) exponent whose entries '
        'individually pass but whose real eigenvalue does not: '
        '[[0.6e150,0.6e150],[0.6e150,0.6e150]] is rank 1 (both rows '
        'identical), with exact eigenvalues 0 and 1.2e150 (trace); every '
        'entry is 0.6e150, in range, but the nonzero eigenvalue 1.2e150 '
        'exceeds matrixFunctionMaxMagnitude. Codex round 15 test note: a '
        'scalar(1) base, not scalar(2), isolates the operand-spectrum gate '
        'itself, since log(1) is exactly 0, so the scaled exponent and its '
        'exponential are the identity, trivially within every range, '
        'unless the operand-spectrum check independently rejects the '
        'exponent\'s own out-of-range eigenvalue first; scalar(2) instead '
        'lets the RESULT-range check (exp(1.2e150 * ln 2) overflowing) '
        'independently catch this case even if the operand-spectrum gate '
        'itself were removed entirely, so it never isolated the gate it '
        'was meant to test',
        () {
          final Matrix exponent = Matrix(<List<double>>[
            <double>[0.6e150, 0.6e150],
            <double>[0.6e150, 0.6e150],
          ]);
          expect(
            () => Matrix.scalar(1).power(exponent),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        'the same exponent-spectrum gap is consistent with what finding 3 '
        'already expects of a complex-form exponent: '
        'scalar(2).power(complex(1e-200,0)) raises '
        'matrix-out-of-precision-range (hypot(1e-200,0)=1e-200 is below '
        'matrixFunctionMinMagnitude, 1e-150)',
        () {
          expect(
            () => Matrix.scalar(2).power(Matrix.complex(1e-200, 0)),
            throwsOutOfPrecisionRange(),
          );
        },
      );
    },
  );

  group(
    'Codex round 14, finding 2 (exact multiples of pi must be preserved '
    'through every power path that provably produces one, not merely '
    "_complexFormRealPower's own real-scalar-exponent closed form)",
    () {
      // Reference: complex(-1e100,0)^(-1.5) = exp(-1.5*(ln(1e100)+pi*i))
      // = magnitude*(cos(-1.5*pi)+i*sin(-1.5*pi)), magnitude =
      // exp(-1.5*ln(1e100)), probed directly at 9.99999999999955e-151,
      // entirely unaffected by this fix. cosPi(-1.5) is exactly 0 and
      // sinPi(-1.5) is exactly 1 (round 13, finding 5's own reference
      // scalar-exponent case, scalar(-1e100).power(scalar(-1.5)), already
      // established these exact values for the identical angle).
      const double expectedMagnitude = 9.99999999999955e-151;

      test(
        'site A: complex(-1e100,0).power(scalar(-1.5)) has an exactly '
        'zero real part instead of a spurious residual around 1.8e-166',
        () {
          final Matrix result = Matrix.complex(
            -1e100,
            0,
          ).power(Matrix.scalar(-1.5));
          expect(result.realPart, 0.0);
          expect(
            result.imagPart,
            closeTo(expectedMagnitude, expectedMagnitude * 1e-9),
          );
        },
      );

      test(
        'site B, negative scalar base: scalar(-1e100).power(complex(-1.5,'
        '0)) (the same real exponent, wearing complex-form clothing '
        'instead of being a Matrix.scalar) has the identical exactly zero '
        'real part',
        () {
          final Matrix result = Matrix.scalar(
            -1e100,
          ).power(Matrix.complex(-1.5, 0));
          expect(result.realPart, 0.0);
          expect(
            result.imagPart,
            closeTo(expectedMagnitude, expectedMagnitude * 1e-9),
          );
        },
      );

      test(
        'site B, complex-form base with zero imaginary part: '
        'complex(-1e100,0).power(complex(-1.5,0)) also has the identical '
        'exactly zero real part',
        () {
          final Matrix result = Matrix.complex(
            -1e100,
            0,
          ).power(Matrix.complex(-1.5, 0));
          expect(result.realPart, 0.0);
          expect(
            result.imagPart,
            closeTo(expectedMagnitude, expectedMagnitude * 1e-9),
          );
        },
      );
    },
  );

  group(
    'Codex round 14, finding 3 (a non-integer exponent is a raw public '
    'operand and must satisfy D38 before dispatch, the same as the base)',
    () {
      test(
        'scalar(2).power(scalar(1e-200)) raises '
        'matrix-out-of-precision-range instead of silently returning 1: '
        'the exponent magnitude 1e-200 is below matrixFunctionMinMagnitude '
        '(1e-150), the public exponent Matrix.complex(1e-200,0) already '
        'correctly raises for the same magnitude, showing the previous '
        'inconsistency',
        () {
          expect(
            () => Matrix.scalar(2).power(Matrix.scalar(1e-200)),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        'a matrix (non-scalar) base with the same out-of-range scalar '
        'exponent also raises matrix-out-of-precision-range: '
        '[[2,0],[0,3]].power(scalar(1e-200))',
        () {
          final Matrix base = Matrix(<List<double>>[
            <double>[2, 0],
            <double>[0, 3],
          ]);
          expect(
            () => base.power(Matrix.scalar(1e-200)),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        'the integer-exponent exemption still holds: '
        'scalar(2).power(scalar(3)) (an integer exponent) still succeeds '
        'normally, unaffected by the new non-integer-only check',
        () {
          final Matrix result = Matrix.scalar(2).power(Matrix.scalar(3));
          expect(result.scalarValue, 8.0);
        },
      );

      test(
        'exact zero exponent (always integer) still succeeds normally: '
        'scalar(2).power(scalar(0)) is 1',
        () {
          final Matrix result = Matrix.scalar(2).power(Matrix.scalar(0));
          expect(result.scalarValue, 1.0);
        },
      );
    },
  );
}
