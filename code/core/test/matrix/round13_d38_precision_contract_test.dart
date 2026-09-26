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
//      accuracy criterion: `||F_computed - F_true|| / ||F_true|| <= 1e-12`.
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

Matcher throwsOutOfPrecisionRange() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.matrixOutOfPrecisionRange,
  ),
);

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
    'D38: round 8 finding 1 (I) - exp analogue, 1e-100 coupling far below '
    'the diagonal scale',
    () {
      test(
        'exp([[700,1],[1e-100,-701]]): every entry (700, 1, 1e-100, -701) '
        'and both eigenvalues (700, -701) are in range. Reference '
        '(mpmath, dps=200, needed because entry11 is the result of '
        'catastrophic cancellation between two ~5e303-magnitude '
        'quantities down to a ~5e197-magnitude result, about 106 decimal '
        'orders of magnitude, unresolvable at a default dps=60): '
        'entry00=1.01423205473500450945532959523e304, '
        'entry01=7.23934371688083161638350888816e300, '
        'entry10=7.23934371688083161638350888816e200, '
        'entry11=5.16726889142100757771842176171e197. This exercises the '
        'same "small coupling relative to the diagonal scale" pattern as '
        'the original (out-of-range) finding, and is already handled '
        'correctly by [Matrix._lagrangeClosedForm2x2]\'s anchor-at-'
        'whichever-function-value-is-smaller fix, plus its bc-identity '
        'cancellation recovery for the near-zero offset.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[700, 1],
            <double>[1e-100, -701],
          ]);

          final Matrix reference = Matrix(<List<double>>[
            <double>[1.01423205473500450945532959523e304, 7.23934371688083161638350888816e300],
            <double>[7.23934371688083161638350888816e200, 5.16726889142100757771842176171e197],
          ]);

          expectNormwiseRelativeError(m.exp(), reference);
        },
      );

      test(
        '[[1e100,1],[1e-100,1e-98]]^-0.5: every entry and both eigenvalues '
        '(1e100, 1e-98) are in range. This exercises the negative-'
        'exponent anchor inversion the original finding named directly '
        '("anchoring at fSmall when it exceeds fBig"): raising the '
        'larger-magnitude eigenvalue to a negative power makes it the '
        'smaller function value (1e100^-0.5 = 1e-50) while the smaller-'
        'magnitude eigenvalue becomes the larger function value '
        '(1e-98^-0.5 = 1e49). Reference (mpmath, dps=300; the eigenvalues '
        'here are each exact powers of ten with even exponents, so every '
        'downstream quantity is an exact power of ten, verified to 50 '
        'significant digits): entry00=1e-50, entry01=-1e-51, '
        'entry10=-1e-151, entry11=1e49. Already handled correctly by the '
        'same anchor-selection fix as the exp case above.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1e100, 1],
            <double>[1e-100, 1e-98],
          ]);

          final Matrix reference = Matrix(<List<double>>[
            <double>[1e-50, -1e-51],
            <double>[-1e-151, 1e49],
          ]);

          expectNormwiseRelativeError(
            m.power(Matrix.scalar(-0.5)),
            reference,
          );
        },
      );
    },
  );

  group(
    'D38: round 8 finding 9 (I) - exp at 709 with normal-magnitude '
    'entries, complex and close-real branches',
    () {
      test(
        'exp([[709,1],[-2,709]]): complex-eigenvalue-pair branch '
        '(bc=-2, discriminant=-8 < 0, m=709, w=sqrt(2)). Reference '
        '(mpmath, dps=60): entry00=entry11=1.28160882464220463078095'
        '360971e307, entry01=5.74019599076293162691749707998e307, '
        'entry10=-1.148039198152586325383499416e308. This is a '
        'representable result (well below double\'s ~1.8e308 max) that '
        'the previous, non-centered `c0 = em*cos(w) - c1*m` form could '
        'overflow even when every entry itself stays finite, since '
        '`c1*m` is not one of the matrix\'s own bounded quantities. '
        'Already handled correctly by [Matrix._general2x2Exp]\'s centered '
        'form.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[709, 1],
            <double>[-2, 709],
          ]);

          final Matrix reference = Matrix(<List<double>>[
            <double>[1.28160882464220463078095360971e307, 5.74019599076293162691749707998e307],
            <double>[-1.148039198152586325383499416e308, 1.28160882464220463078095360971e307],
          ]);

          expectNormwiseRelativeError(m.exp(), reference);
        },
      );

      test(
        'exp([[709,1e-7],[2e-7,709]]): close-real-eigenvalue branch '
        '(bc=2e-14, discriminant=8e-14 > 0 but tiny, relative eigenvalue '
        'gap well under the close-eigenvalue threshold). Reference '
        '(mpmath, dps=60): entry00=entry11=8.21840746155505437331598'
        '793646e307, entry01=8.2184074615549995839329109032e300, '
        'entry10=1.64368149231099991678658218064e301. Same overflow-'
        'prone standalone-c0 pattern as the complex case above, for the '
        'close-real-eigenvalue branch; already handled correctly by the '
        'same centered-form fix.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[709, 1e-7],
            <double>[2e-7, 709],
          ]);

          final Matrix reference = Matrix(<List<double>>[
            <double>[8.21840746155505437331598793646e307, 8.2184074615549995839329109032e300],
            <double>[1.64368149231099991678658218064e301, 8.21840746155505437331598793646e307],
          ]);

          expectNormwiseRelativeError(m.exp(), reference);
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

          expectNormwiseRelativeError(m.sqrt(), reference);
        },
      );
    },
  );
}
