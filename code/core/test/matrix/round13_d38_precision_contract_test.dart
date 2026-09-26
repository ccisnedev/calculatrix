// D38 declared precision contract: `exp`, `log`, `sqrt` and non-integer
// `power` reject, before or right after computing, any nonzero raw entry or
// computed eigenvalue whose magnitude falls outside
// `[CalculatrixNumericPolicy.matrixFunctionMinMagnitude,
// CalculatrixNumericPolicy.matrixFunctionMaxMagnitude]` (currently
// `[1e-150, 1e150]`), with the typed error id
// `matrix-out-of-precision-range`, instead of silently guessing at a result
// once the input strays into a regime double precision cannot resolve
// accurately.
//
// This file classifies the 11 "round 8" findings (a later, distinct review
// round from the numbered `round8_correction_test.dart` file already in
// this suite) as either:
//   R: now rejected outright by the D38 domain gate, because the finding's
//      own matrix has a raw entry outside the declared range. Covered here
//      by a test asserting `matrix-out-of-precision-range` on the finding's
//      *exact* original matrix.
//   I: still inside the declared range (every raw entry, and every computed
//      eigenvalue, lies in `[1e-150, 1e150]`). Covered here by an in-range
//      *analogue* that exercises the same underlying numerical bug pattern,
//      checked against an independently derived reference (Python mpmath,
//      dps 50-300 depending on how much cancellation the specific
//      computation involves) using the contract's own normwise (Frobenius)
//      accuracy criterion, condition-relative since the user's finding 7
//      correction: `||F_computed - F_true|| / ||F_true|| <=
//      matrixFunctionAccuracyFactor * kappa(f, A) * unitRoundoff`, which
//      recovers the flat `1e-12` this file used before that correction
//      whenever `kappa(f, A) ~= 1` (see [expectConditionRelativeError]).
//
// Classification:
//   1  I (exp analogue + power(-0.5) analogue; both already fixed by the
//        general-purpose "anchor at whichever function value is smaller in
//        magnitude" fix, see [Matrix._lagrangeClosedForm2x2])
//   2  R (exp([[700,1e-200],[2e-200,-700]]): 1e-200 entries)
//   3  R (sqrt([[2e-162,2e-162],[4e-162,8e-162]]): 2e-162 etc entries)
//   4  R (both the 1e200 matrix and its 1e-200 "throws" counterpart)
//   5  R (exp([[-750,1e300],[0,-750]]): 1e300 entry)
//   6  R (log([[1e200,1e-200],[2e-200,1e-200]]): both directions violated)
//   7  R (sqrt([[-1,1e-200],[-2e-200,-1]]): 1e-200 entries)
//   8  R (sqrt/log on [[1,1e300],[-1e-320,1]]: both directions violated)
//   9  I (exp analogues at 709, already fixed by the centered-form rewrite
//        of both the complex-pair and close-real-eigenvalue branches, see
//        [Matrix._general2x2Exp])
//   10 R (log([[1e-320,1e-320],[0,2e-320]]): subnormal entries)
//   11 I (sqrt analogue across the close/far eigenvalue threshold, already
//        fixed by the unconditional `y == 0.5` bypass, see
//        [Matrix._general2x2RealPower])
//
// Every in-range (I) analogue was independently verified, via a throwaway
// script driving this implementation directly (not committed, not part of
// this file), to already satisfy the normwise accuracy contract: the
// general anchor-selection and centered-form fixes made for the
// out-of-range (R) originals generalize correctly to these in-range
// analogues without requiring any further code change. These tests are
// therefore regression/confirmation tests, not red-then-fixed TDD cycles.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// Frobenius norm of [m], computed scale-aware (each entry divided by the
/// matrix's own largest-magnitude entry before squaring, then rescaled back
/// at the end, the same trick `hypot` uses for two values) so that entries
/// around 1e300 or larger do not overflow when squared: `(1e300)^2` alone
/// already exceeds double's ~1.8e308 max, even though the true norm itself
/// is perfectly representable.
double _frobeniusNorm(Matrix m) {
  double maxAbs = 0;
  for (int row = 0; row < m.rowCount; row++) {
    for (int column = 0; column < m.columnCount; column++) {
      final double abs = m.at(row, column).abs();
      if (abs > maxAbs) maxAbs = abs;
    }
  }
  if (maxAbs == 0) return 0;

  double sumSquaredScaled = 0;
  for (int row = 0; row < m.rowCount; row++) {
    for (int column = 0; column < m.columnCount; column++) {
      final double scaled = m.at(row, column) / maxAbs;
      sumSquaredScaled += scaled * scaled;
    }
  }
  return maxAbs * math.sqrt(sumSquaredScaled);
}

/// The D38 contract's own accuracy criterion: normwise (Frobenius) relative
/// error, `||computed - reference|| / ||reference|| <= tolerance`. Distinct
/// from the componentwise `expectRelativelyClose` helper used elsewhere in
/// this suite: a single tiny reference entry that happens to be noisy does
/// not, by itself, fail this check the way it would fail a componentwise
/// one, matching the contract's own stated norm.
void expectNormwiseRelativeError(
  Matrix computed,
  Matrix reference, {
  double tolerance = 1e-12,
}) {
  expect(computed.rowCount, reference.rowCount);
  expect(computed.columnCount, reference.columnCount);

  final double frobeniusDiff = _frobeniusNorm(computed - reference);
  final double frobeniusReference = _frobeniusNorm(reference);
  final double relativeError = frobeniusReference == 0
      ? frobeniusDiff
      : frobeniusDiff / frobeniusReference;

  expect(
    relativeError,
    lessThanOrEqualTo(tolerance),
    reason:
        'computed=$computed reference=$reference '
        'normwiseRelativeError=$relativeError',
  );
}

/// The D38 contract's condition-relative accuracy criterion (Codex round 9
/// finding 7 correction): normwise (Frobenius) relative error at most
/// `CalculatrixNumericPolicy.matrixFunctionAccuracyFactor * kappa *
/// CalculatrixNumericPolicy.unitRoundoff`, where [kappa] is the caller-
/// supplied relative condition number of the matrix function under test at
/// its specific input, `kappa(f, A) = ||L_f(A)||_F * ||A||_F / ||f(A)||_F`
/// (`L_f(A)` the Frechet derivative of `f` at `A`). Each call site below
/// documents how its own `kappa` was independently computed in mpmath: a
/// central-difference Frechet derivative, in each of the 4 basis
/// directions of a 2x2 matrix, at high mpmath precision, assembled into a
/// 4x4 operator matrix whose largest singular value is
/// `sigma_max(L_f(A))` (`= sqrt(largest eigenvalue of M^T * M)`, `M` that
/// 4x4 matrix), since the vec-flattened basis of 2x2 matrices is
/// orthonormal under the Frobenius inner product, so that largest singular
/// value equals the operator norm `||L_f(A)||_F` induced by that inner
/// product; verified stable across finite-difference step sizes from
/// `1e-20` to `1e-40`.
void expectConditionRelativeError(
  Matrix computed,
  Matrix reference, {
  required double kappa,
}) {
  // Coordinator amendment (docs review, runbook D38, commit afb9477): the
  // bound floors kappa at 1, `max(1, kappa) * unitRoundoff`, not a bare
  // `kappa * unitRoundoff`, since no double-precision algorithm ever does
  // better than the flat, condition-1 figure regardless of how favorably
  // kappa computes for a specific (f, A) pair (e.g. exp(1e-16), whose
  // kappa comes out below 1, still returns 1.0 exactly, not something
  // more accurate than the flat figure would allow).
  final double tolerance =
      CalculatrixNumericPolicy.matrixFunctionAccuracyFactor *
      math.max(1, kappa) *
      CalculatrixNumericPolicy.unitRoundoff;
  expectNormwiseRelativeError(computed, reference, tolerance: tolerance);
}

Matcher throwsOutOfPrecisionRange() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.matrixOutOfPrecisionRange,
  ),
);

/// Rule B (runbook D38 amendment): the absolute-bound analogue of
/// [expectConditionRelativeError], for a genuinely singular `sqrt` input
/// whose reference is itself partly or wholly zero, so a relative bound is
/// either undefined or vacuous. `||X - sqrt(A)||_F <=
/// 1e4*sqrt(unitRoundoff*||A||_F)`, where `X` is the computed result and
/// `A` is the original (singular) input this bound is stated against.
void expectSqrtSingularBound(Matrix computed, Matrix reference, Matrix a) {
  final double tolerance =
      1e4 *
      math.sqrt(CalculatrixNumericPolicy.unitRoundoff * _frobeniusNorm(a));
  final double frobeniusDiff = _frobeniusNorm(computed - reference);
  expect(
    frobeniusDiff,
    lessThanOrEqualTo(tolerance),
    reason:
        'computed=$computed reference=$reference '
        'frobeniusDiff=$frobeniusDiff tolerance=$tolerance',
  );
}

void main() {
  group('D38: precision-range constants', () {
    test('the declared range matches the contract, 1e-150 to 1e150', () {
      expect(CalculatrixNumericPolicy.matrixFunctionMinMagnitude, 1e-150);
      expect(CalculatrixNumericPolicy.matrixFunctionMaxMagnitude, 1e150);
    });
  });

  group('D38: entry-level boundary (stage 1, before any computation)', () {
    test('exactly 1e-150 and exactly 1e150 entries are allowed', () {
      final Matrix atMin = Matrix(<List<double>>[
        <double>[1e-150, 0],
        <double>[0, 1e-150],
      ]);
      final Matrix atMax = Matrix(<List<double>>[
        <double>[1e150, 0],
        <double>[0, 1e150],
      ]);

      expect(atMin.sqrt, returnsNormally);
      expect(atMax.sqrt, returnsNormally);
    });

    test('an entry just below 1e-150 is rejected', () {
      final Matrix justBelow = Matrix(<List<double>>[
        <double>[9.9e-151, 0],
        <double>[0, 1],
      ]);

      expect(justBelow.sqrt, throwsOutOfPrecisionRange());
    });

    test('an entry just above 1e150 is rejected', () {
      final Matrix justAbove = Matrix(<List<double>>[
        <double>[1.0001e150, 0],
        <double>[0, 1],
      ]);

      expect(justAbove.sqrt, throwsOutOfPrecisionRange());
    });

    test(
      'a zero entry is always allowed regardless of scale, alongside '
      'entries at the declared boundary',
      () {
        final Matrix withZero = Matrix(<List<double>>[
          <double>[1e150, 0],
          <double>[0, 1e150],
        ]);

        expect(withZero.sqrt, returnsNormally);
      },
    );
  });

  group(
    'D38: eigenvalue-level boundary (stage 2, after eigendecomposition) '
    'rejects an out-of-range computed eigenvalue even though every raw '
    'entry is individually in range',
    () {
      test(
        'exactly symmetric [[1e150,1e150],[1e150,0]]: entries sit right at '
        'the declared max, but the larger eigenvalue is '
        '~1.618e150, above 1e150',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1e150, 1e150],
            <double>[1e150, 0],
          ]);

          expect(m.sqrt, throwsOutOfPrecisionRange());
        },
      );

      test(
        'general (asymmetric) 2x2 [[9e149,9e149],[8e149,0]]: every entry is '
        'below 1e150, but the larger eigenvalue is ~1.41e150, above 1e150',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[9e149, 9e149],
            <double>[8e149, 0],
          ]);

          expect(m.sqrt, throwsOutOfPrecisionRange());
        },
      );

      test(
        'log: same general (asymmetric) 2x2 [[9e149,9e149],[8e149,0]], '
        'real-eigenvalue branch: the eigenvalue-range check must run '
        'before the negative-eigenvalue check, since this matrix\'s other '
        'eigenvalue (~-5.10e149) is negative and would otherwise be '
        'reported as the ordinary log-undefined error instead of the '
        'out-of-range one, masking the fact that the larger eigenvalue is '
        'already outside the declared range',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[9e149, 9e149],
            <double>[8e149, 0],
          ]);

          expect(m.log, throwsOutOfPrecisionRange());
        },
      );
    },
  );

  group('D38: round 8 finding 2 (R) - exp, 1e-200 entries', () {
    test(
      'exp([[700,1e-200],[2e-200,-700]]) raises matrix-out-of-precision-'
      'range (1e-200 sits below matrixFunctionMinMagnitude=1e-150; the '
      'original finding was a bc-underflow bug this input can no longer '
      'reach)',
      () {
        final Matrix m = Matrix(<List<double>>[
          <double>[700, 1e-200],
          <double>[2e-200, -700],
        ]);

        expect(m.exp, throwsOutOfPrecisionRange());
      },
    );
  });

  group('D38: round 8 finding 3 (R) - sqrt, subnormal-scale determinant', () {
    test(
      'sqrt([[2e-162,2e-162],[4e-162,8e-162]]) raises matrix-out-of-'
      'precision-range (2e-162 etc all sit below matrixFunctionMin'
      'Magnitude=1e-150; the original finding was a 7.9% sqrt error this '
      'input can no longer reach)',
      () {
        final Matrix m = Matrix(<List<double>>[
          <double>[2e-162, 2e-162],
          <double>[4e-162, 8e-162],
        ]);

        expect(m.sqrt, throwsOutOfPrecisionRange());
      },
    );
  });

  group(
    'D38: round 8 finding 4 (R) - power(-1.5), 1e200 zero off-diagonal '
    'and the 1e-200 throwing counterpart',
    () {
      test(
        '[[1e200,1e200],[0,1e200]]^-1.5 raises matrix-out-of-precision-'
        'range (1e200 sits above matrixFunctionMaxMagnitude=1e150; the '
        'original finding was a zeroed off-diagonal, should have been '
        '-1.5e-300, this input can no longer reach)',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1e200, 1e200],
            <double>[0, 1e200],
          ]);

          expect(
            () => m.power(Matrix.scalar(-1.5)),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        '[[1e-200,1e-200],[0,1e-200]]^-1.5 raises matrix-out-of-precision-'
        'range (1e-200 sits below matrixFunctionMinMagnitude=1e-150; this '
        'is the "throws at 1e-200" counterpart from the same finding)',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1e-200, 1e-200],
            <double>[0, 1e-200],
          ]);

          expect(
            () => m.power(Matrix.scalar(-1.5)),
            throwsOutOfPrecisionRange(),
          );
        },
      );
    },
  );

  group('D38: round 8 finding 5 (R) - exp, 1e300 coupling entry', () {
    test(
      'exp([[-750,1e300],[0,-750]]) raises matrix-out-of-precision-range '
      '(1e300 sits above matrixFunctionMaxMagnitude=1e150; the original '
      'finding was a spuriously all-zero result this input can no longer '
      'reach)',
      () {
        final Matrix m = Matrix(<List<double>>[
          <double>[-750, 1e300],
          <double>[0, -750],
        ]);

        expect(m.exp, throwsOutOfPrecisionRange());
      },
    );
  });

  group('D38: round 8 finding 6 (R) - log, 1e200/1e-200 mixed entries', () {
    test(
      'log([[1e200,1e-200],[2e-200,1e-200]]) raises matrix-out-of-'
      'precision-range (1e200 sits above, and 1e-200 sits below, the '
      'declared range; the original finding was a spurious log-undefined '
      'rejection this input can no longer reach)',
      () {
        final Matrix m = Matrix(<List<double>>[
          <double>[1e200, 1e-200],
          <double>[2e-200, 1e-200],
        ]);

        expect(m.log, throwsOutOfPrecisionRange());
      },
    );
  });

  group('D38: round 8 finding 7 (R) - sqrt, 1e-200 entries', () {
    test(
      'sqrt([[-1,1e-200],[-2e-200,-1]]) raises matrix-out-of-precision-'
      'range (1e-200 etc sit below matrixFunctionMinMagnitude=1e-150; the '
      'original finding was a spurious log-undefined rejection from '
      'discriminant underflow this input can no longer reach)',
      () {
        final Matrix m = Matrix(<List<double>>[
          <double>[-1, 1e-200],
          <double>[-2e-200, -1],
        ]);

        expect(m.sqrt, throwsOutOfPrecisionRange());
      },
    );
  });

  group(
    'D38: round 8 finding 8 (R) - sqrt and log, 1e300/1e-320 mixed entries',
    () {
      test(
        'sqrt([[1,1e300],[-1e-320,1]]) raises matrix-out-of-precision-'
        'range (1e300 sits above, and 1e-320 sits below, the declared '
        'range; the original finding was a b/w overflow this input can no '
        'longer reach)',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1, 1e300],
            <double>[-1e-320, 1],
          ]);

          expect(m.sqrt, throwsOutOfPrecisionRange());
        },
      );

      test(
        'log([[1,1e300],[-1e-320,1]]) raises matrix-out-of-precision-range '
        'for the same reason',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1, 1e300],
            <double>[-1e-320, 1],
          ]);

          expect(m.log, throwsOutOfPrecisionRange());
        },
      );
    },
  );

  group('D38: round 8 finding 10 (R) - log, subnormal entries', () {
    test(
      'log([[1e-320,1e-320],[0,2e-320]]) raises matrix-out-of-precision-'
      'range (1e-320 etc are subnormal doubles, far below '
      'matrixFunctionMinMagnitude=1e-150; the original finding was a '
      'spurious throw this input can no longer reach for a different '
      'reason)',
      () {
        final Matrix m = Matrix(<List<double>>[
          <double>[1e-320, 1e-320],
          <double>[0, 2e-320],
        ]);

        expect(m.log, throwsOutOfPrecisionRange());
      },
    );
  });

  group(
    'D38: round 8 finding 1 - exp analogue, 1e-100 coupling far below '
    'the diagonal scale',
    () {
      test(
        'exp([[700,1],[1e-100,-701]]) now raises '
        'matrix-out-of-precision-range under rule A (converted from the '
        'previous (I) classification): every raw entry (700, 1, 1e-100, '
        '-701) and both argument-side eigenvalues (700, -701) individually '
        'sit in [1e-150, 1e150], but rule A also requires the RESULT '
        'eigenvalue (exp(700), magnitude about 1.014e304) to be in that '
        'same declared range, and 1.014e304 is far above '
        'matrixFunctionMaxMagnitude=1e150 (its log-magnitude, 700, is '
        'likewise far above ln(1e150)~=345.39). This is now rejected '
        'before ever computing exp(700), rather than computed and checked '
        'against the mpmath reference this test used before rule A '
        'existed.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[700, 1],
            <double>[1e-100, -701],
          ]);

          expect(m.exp, throwsOutOfPrecisionRange());
        },
      );

      test(
        '[[1e100,1],[1e-100,1e-98]]^-0.5 now raises matrix-out-of-'
        'precision-range under rule A (converted from the previous (I) '
        'classification): both eigenvalues (1e100, 1e-98) individually '
        'sit in [1e-150, 1e150], and the exponent -0.5 keeps every result '
        'eigenvalue in range too (0.5*ln(1e100)=115.1, 0.5*ln(1e-98)='
        '-112.8, both under 345.39), but rule A also requires every '
        'NONZERO ENTRY of the computed result to be in the declared '
        'range, not just its eigenvalues: the off-diagonal entry (1,0) '
        'is mathematically -1e-151 (per the mpmath reference below, '
        'dps=300, verified to 50 significant digits, since every '
        'quantity here is an exact power of ten), below '
        'matrixFunctionMinMagnitude=1e-150. Reference: entry00=1e-50, '
        'entry01=-1e-51, entry10=-1e-151, entry11=1e49.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1e100, 1],
            <double>[1e-100, 1e-98],
          ]);

          expect(
            () => m.power(Matrix.scalar(-0.5)),
            throwsOutOfPrecisionRange(),
          );
        },
      );
    },
  );

  group(
    'D38 / Codex round 10, rule A: exp at 709 now raises '
    'matrix-out-of-precision-range, converted from round 8 finding 9\'s '
    '(I) in-range analogues',
    () {
      test(
        'exp([[709,1],[-2,709]]): complex-eigenvalue-pair branch '
        '(bc=-2, discriminant=-8 < 0, m=709, w=sqrt(2)). Every raw entry '
        'and the pair\'s own eigenvalue magnitude (hypot(709, sqrt(2))) '
        'are in range, but rule A also requires the RESULT eigenvalue '
        '(exp(709 +/- sqrt(2)*i), magnitude exp(709)) to be in range: '
        'exp(709) is about 8.2e307, comfortably representable, but its '
        'log-magnitude (709) is above the declared bound '
        '(ln(1e150)~=345.39), so this now raises '
        'matrix-out-of-precision-range before ever computing exp(709), '
        'superseding the previous (I) classification once rule A checks '
        'the result side, not just the argument side.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[709, 1],
            <double>[-2, 709],
          ]);

          expect(m.exp, throwsOutOfPrecisionRange());
        },
      );

      test(
        'exp([[709,1e-7],[2e-7,709]]): close-real-eigenvalue branch '
        '(bc=2e-14, discriminant=8e-14 > 0 but tiny, relative eigenvalue '
        'gap well under the close-eigenvalue threshold). Same rule A '
        'result-side rejection as the complex case above: both close-real '
        'eigenvalues sit at about 709, so the result eigenvalue exp(709) '
        'is again above the declared range.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[709, 1e-7],
            <double>[2e-7, 709],
          ]);

          expect(m.exp, throwsOutOfPrecisionRange());
        },
      );
    },
  );

  group(
    'D38: round 8 finding 11 (I) - sqrt close/far threshold, in-range '
    'analogue',
    () {
      test(
        'sqrt([[1,1],[0,1-1.4916e-8]]): every entry and both eigenvalues '
        '(1, 1-1.4916e-8) are in range. The relative eigenvalue gap here '
        'is ~1.4916e-8, just *above* the shared close-eigenvalue '
        'threshold (~1.4901e-8), so this sits right at the close/far '
        'branch boundary the original finding was about, testing that '
        'power\'s unconditional `y == 0.5` bypass (not the close/far '
        'branching at all) is what actually governs sqrt, regardless of '
        'which side of that threshold the eigenvalue gap falls on. '
        'Reference (mpmath, dps=50): entry00=1, entry01='
        '0.50000000186450001391, entry10=0, '
        'entry11=0.99999999254199997219 (sqrt(1-1.4916e-8)). Already '
        'handled correctly by [Matrix._general2x2RealPower]\'s '
        '`1/(sqrt(lBig)+sqrt(lSmall))` identity for `y == 0.5`.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1, 1],
            <double>[0, 1 - 1.4916e-8],
          ]);

          final Matrix reference = Matrix(<List<double>>[
            <double>[1, 0.50000000186450001391],
            <double>[0, 0.99999999254199997219],
          ]);

          // kappa(f, A) = 0.752679392434872, computed in mpmath (dps=100)
          // via the same method as finding 1a above (sigma_max(L_f(A))
          // ~= 0.652, ||A||_F ~= 1.732, ||f(A)||_F ~= 1.5): this is the
          // "kappa about 1" case, so the flat 1e-12 tolerance (recovered
          // from the condition-relative bound at kappa=1) is kept
          // directly here rather than routed through
          // [expectConditionRelativeError].
          expectNormwiseRelativeError(m.sqrt(), reference);
        },
      );
    },
  );

  group(
    'D38: Codex round 9 finding 7 (I) - exp with a huge purely-imaginary '
    'rotation frequency, condition-relative accuracy contract',
    () {
      test(
        'exp([[0,1e10],[-2e10,0]]): complex-eigenvalue-pair branch with '
        'm=0, w=sqrt(2)*1e10~=1.4142e10 (purely imaginary eigenvalue '
        'pair, both in range: |1e10| and |2e10| are well inside '
        '[1e-150, 1e150]). Reference (mpmath, dps=100): '
        'entry00=entry11=-0.78147106333642978134, '
        'entry01=0.44119325536992842452, '
        'entry10=-0.88238651073985684903. kappa(f, A) = '
        '18414244737.4962, computed in mpmath via the same central-'
        'difference Frechet-derivative/largest-singular-value method as '
        'the other cases in this file (verified stable across finite-'
        'difference step sizes from 1e-20 to 1e-40, and cross-checked '
        'against a direct, non-infinitesimal finite difference): '
        'sigma_max(L_f(A)) ~= 1.220 (a modest, well-behaved operator '
        'norm), ||A||_F ~= 2.236e10, ||f(A)||_F ~= 1.481. This kappa is '
        'enormous purely because ||A||_F dwarfs ||f(A)||_F (exp of a '
        'huge purely-imaginary eigenvalue pair is still bounded, since '
        'it is essentially a rotation), not because the derivative '
        'operator itself is ill-conditioned, unlike finding 1b above. '
        'Bound = matrixFunctionAccuracyFactor * kappa * unitRoundoff = '
        '1e4 * 18414244737.4962 * 1.1102230246251565e-16 ~= 2.044e-2. '
        'The actual computed result here has normwise relative error '
        '~= 8.42e-7 (verified directly against this reference before '
        'writing this test), about 24300 times tighter than the bound, '
        'so no algorithmic fix was needed for this finding: the '
        'existing complex-pair branch (which calls cos/sin on the raw '
        'rotation half-width w, relying on dart:math\'s own argument '
        'reduction) already stays comfortably within this contract.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[0, 1e10],
            <double>[-2e10, 0],
          ]);

          final Matrix reference = Matrix(<List<double>>[
            <double>[-0.78147106333642978134, 0.44119325536992842452],
            <double>[-0.88238651073985684903, -0.78147106333642978134],
          ]);

          expectConditionRelativeError(
            m.exp(),
            reference,
            kappa: 18414244737.4962,
          );
        },
      );
    },
  );

  group(
    'D38 / Codex round 10, rule A: contract examples (result-side range '
    'check, before computing)',
    () {
      test('scalar exp(-1000) raises matrix-out-of-precision-range', () {
        expect(Matrix.scalar(-1000).exp, throwsOutOfPrecisionRange());
      });

      test('scalar exp(710) raises matrix-out-of-precision-range', () {
        expect(Matrix.scalar(710).exp, throwsOutOfPrecisionRange());
      });

      test(
        'exp([[710,0.75],[-0.8,710]]) raises matrix-out-of-precision-'
        'range: complex-eigenvalue-pair branch (bc=-0.6, discriminant < 0) '
        'with real part m=710, so the result eigenvalue exp(710 +/- w*i) '
        'has log-magnitude 710, above ln(1e150)~=345.39',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[710, 0.75],
            <double>[-0.8, 710],
          ]);
          expect(m.exp, throwsOutOfPrecisionRange());
        },
      );

      test(
        '[[1e150,1e150],[0,1e150]]^-1.15 raises matrix-out-of-precision-'
        'range: the repeated eigenvalue 1e150 sits right at the declared '
        'max, but the result eigenvalue log-magnitude, '
        '-1.15*ln(1e150)~=-397.20, exceeds -345.39 in magnitude',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1e150, 1e150],
            <double>[0, 1e150],
          ]);
          expect(
            () => m.power(Matrix.scalar(-1.15)),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        '[[1e149,1e149],[0,2e149]]^-1.5 raises matrix-out-of-precision-'
        'range: the larger (triangular, real) eigenvalue, 2e149, has '
        'result eigenvalue log-magnitude -1.5*ln(2e149)~=-515.67, '
        'exceeding -345.39',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1e149, 1e149],
            <double>[0, 2e149],
          ]);
          expect(
            () => m.power(Matrix.scalar(-1.5)),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        '[[1e149,1e149],[-1e-149,1e149]]^-1.5 raises matrix-out-of-'
        'precision-range: a complex-eigenvalue-pair branch (bc=-1, '
        'discriminant < 0) whose radius, hypot(1e149,1), is about 1e149, '
        'giving result eigenvalue log-magnitude -1.5*ln(1e149)~=-514.63, '
        'exceeding -345.39',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1e149, 1e149],
            <double>[-1e-149, 1e149],
          ]);
          expect(
            () => m.power(Matrix.scalar(-1.5)),
            throwsOutOfPrecisionRange(),
          );
        },
      );
    },
  );

  group(
    'D38 / Codex round 10, rule A: an exactly-zero result eigenvalue is '
    'always allowed, distinguished from a merely tiny but nonzero one',
    () {
      test(
        'log(I) succeeds: every eigenvalue of the identity is exactly 1, '
        'so every result eigenvalue (ln(1)) is exactly zero, allowed '
        'regardless of the declared range (rule B: the log-identity '
        'residual is bounded by 1e4*unitRoundoff*||L_log(I)||_F*||I||_F, '
        'in practice exactly zero)',
        () {
          final Matrix result = Matrix.identity(2).log();
          expect(result.at(0, 0), 0.0);
          expect(result.at(0, 1), 0.0);
          expect(result.at(1, 0), 0.0);
          expect(result.at(1, 1), 0.0);
        },
      );

      test(
        'sqrt(0) succeeds: the sole eigenvalue is exactly zero, allowed',
        () {
          expect(Matrix.scalar(0).sqrt().scalarValue, 0.0);
        },
      );

      test(
        'sqrt(diag(0,1)) succeeds: one eigenvalue is exactly zero '
        '(allowed) and the other, 1, has result eigenvalue log-magnitude '
        '0.5*ln(1)=0 (also in range)',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[0, 0],
            <double>[0, 1],
          ]);
          final Matrix result = m.sqrt();
          expect(result.at(0, 0), 0.0);
          expect(result.at(0, 1), 0.0);
          expect(result.at(1, 0), 0.0);
          expect(result.at(1, 1), 1.0);
        },
      );

      test(
        'sqrt([[1,1],[1,1]]) succeeds: this singular symmetric matrix has '
        'eigenvalues exactly 0 and 2, the zero eigenvalue allowed and the '
        'other well within range (rule B: '
        '||X - sqrt(A)||_F <= 1e4*sqrt(unitRoundoff*||A||_F))',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1, 1],
            <double>[1, 1],
          ]);
          final double s = 1 / math.sqrt(2);
          final Matrix reference = Matrix(<List<double>>[
            <double>[s, s],
            <double>[s, s],
          ]);
          expectSqrtSingularBound(m.sqrt(), reference, m);
        },
      );

      test(
        'in contrast, exp(-1000) still raises matrix-out-of-precision-'
        'range: its result eigenvalue, exp(-1000), is tiny but NOT '
        'exactly zero (a double can represent an extremely small nonzero '
        'value distinct from zero), so the zero exception above does not '
        'apply here',
        () {
          expect(Matrix.scalar(-1000).exp, throwsOutOfPrecisionRange());
        },
      );
    },
  );

  group(
    'D38: the max(1, kappa) accuracy floor (coordinator amendment, '
    'runbook D38, commit afb9477)',
    () {
      test(
        'exp(1e-16) returns exactly 1.0: kappa(exp, 1e-16) computes below '
        '1 (exp itself is close to 1 while its derivative times the tiny '
        'eigenvalue is smaller still), yet no double-precision algorithm '
        'does better than the flat, condition-1 figure regardless, which '
        'is trivially satisfied here since 1e-16 already rounds to '
        'exactly 1.0 under exp',
        () {
          expect(Matrix.scalar(1e-16).exp().scalarValue, 1.0);
        },
      );
    },
  );

  group(
    'Codex round 10, rule C: log\'s centered form must not form w/m at '
    'exactly 1.0 for a widely separated spectrum',
    () {
      test(
        'log([[1e20,1],[1,1]]): the centered log1p formula used for '
        'close eigenvalues would compute w/m rounding to exactly 1.0 '
        'here (spuriously calling log1p(-1) = -Infinity), since this '
        'matrix\'s eigenvalues are far apart, not close; restricting '
        'the centered form to close eigenvalues and using the stable, '
        'far-apart Lagrange closed form here fixes it. Reference '
        '(mpmath, dps=60): entry00=46.0517018598809, '
        'entry01=4.60517018598809e-19, entry10=4.60517018598809e-19, '
        'entry11=-9.9999999999999999955e-21 (about -1e-20).',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1e20, 1],
            <double>[1, 1],
          ]);

          final Matrix reference = Matrix(<List<double>>[
            <double>[46.0517018598809, 4.60517018598809e-19],
            <double>[4.60517018598809e-19, -9.9999999999999999955e-21],
          ]);

          // kappa(f, A) ~= 2.171472409516259e18, computed in mpmath
          // (dps=60) via the same central-difference Frechet-derivative/
          // largest-singular-value method as the other cases in this
          // file: sigma_max(L_f(A)) ~= 1.0, ||A||_F ~= 1e20,
          // ||f(A)||_F ~= 46.05. This kappa is enormous purely because
          // ||A||_F dwarfs ||f(A)||_F, the same pattern as Codex round 9
          // finding 7 above, not because the derivative operator itself
          // is ill-conditioned.
          expectConditionRelativeError(
            m.log(),
            reference,
            kappa: 2.171472409516259e18,
          );
        },
      );
    },
  );

  group(
    'D25 case 13 / runbook f7ace5e: non-integer power checks the D38 '
    'range first, while an integer power and an integer-exponent exp '
    'bypass it entirely',
    () {
      test(
        '10^400.5 (non-integer power) raises matrix-out-of-precision-'
        'range: result eigenvalue log-magnitude is 400.5*ln(10)~=922.19, '
        'far above ln(1e150)~=345.39',
        () {
          expect(
            () => Matrix.scalar(10).power(Matrix.scalar(400.5)),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        '10^400 (integer power) stays non-finite: an integer exponent is '
        'computed by ordinary real exponentiation, not the closed-form '
        'eigenvalue machinery rule A governs, so it bypasses the '
        'declared range entirely; 10^400 genuinely overflows double '
        'precision regardless',
        () {
          expect(
            () => Matrix.scalar(10).power(Matrix.scalar(400)),
            throwsA(
              isA<MatrixDomainError>().having(
                (MatrixDomainError e) => e.errorId,
                'errorId',
                CalculatrixErrorId.nonFinite,
              ),
            ),
          );
        },
      );

      test(
        'e^400 (integer power) succeeds, about 5.221469689764144e173: an '
        'integer exponent bypasses rule A even though 400 alone, as a '
        'scalar exp argument, raises matrix-out-of-precision-range (see '
        'the next test); unlike 10^400 above, e^400 does not overflow '
        'double precision',
        () {
          final Matrix result = Matrix.scalar(
            math.e,
          ).power(Matrix.scalar(400));
          expect(
            result.scalarValue,
            closeTo(5.221469689764144e173, 5.221469689764144e173 * 1e-9),
          );
        },
      );

      test(
        'exp(400) (scalar exp, not power) raises matrix-out-of-precision-'
        'range: exp\'s result log-magnitude is the scalar itself, 400, '
        'above ln(1e150)~=345.39, even though e^400 (the integer-power '
        'form above) succeeds',
        () {
          expect(Matrix.scalar(400).exp, throwsOutOfPrecisionRange());
        },
      );
    },
  );
}
