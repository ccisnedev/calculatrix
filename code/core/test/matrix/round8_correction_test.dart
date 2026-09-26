// Round 8 correction: twelve findings from an independent review of
// lib/src/matrix/matrix.dart, each covered here by a test that fails
// before its paired fix and asserts a concrete numeric value or error id.
import 'dart:math' as math;

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

    // Converted from a finite-result regression check to a rule A
    // rejection: every raw entry (-1000, 1, 0, -500) sits well inside
    // [1e-150, 1e150], so this passes the argument-side D38 check, but
    // rule A also requires each RESULT eigenvalue (exp(-1000) and
    // exp(-500), whose log-magnitudes are the eigenvalues themselves) to
    // be in the same declared range. Both -1000 and -500 exceed
    // ln(1e150)~=345.39 in magnitude (most severely -1000), so this now
    // raises matrix-out-of-precision-range before ever computing
    // exp(-1000) or exp(-500), superseding the previous expectation that
    // this returns a finite result close to exp(-500) with a
    // vanishingly small (0, 0) entry.
    test(
      'exp([[-1000,1],[0,-500]]) raises matrix-out-of-precision-range',
      () {
        final Matrix value = Matrix(<List<double>>[
          <double>[-1000, 1],
          <double>[0, -500],
        ]);

        expect(value.exp, throwsOutOfPrecisionRange());
      },
    );
  });

  group('Round 8, finding 2: general 2x2 complex-pair closed forms must use '
      'the centered discriminant halfDiff^2 + b*c, not trace^2 - 4*det, to '
      'find the rotation frequency w', () {
    test('exp(A) matches the centered-discriminant closed form for a '
        'complex pair whose uncentered discriminant loses precision', () {
      // a=1e8, d=-99999999, b=1e8, c=-99999999.00000004: chosen so the
      // true (centered) discriminant halfDiff^2 + b*c is -4 (m=0.5, w=2),
      // but trace^2 - 4*det evaluates to -15 instead of -16, a large
      // relative error from subtracting two ~1e16-magnitude terms. Both
      // formulas agree the pair is complex, so this is not a
      // classification flip: it is the recomputed discriminant itself
      // (used for the rotation frequency w in the c0*I + c1*A closed
      // form) losing precision, which changes exp(A) by several percent.
      final double a = 100000000.0;
      final double b = 100000000.0;
      final double c = -99999999.00000004;
      final double d = -99999999.0;
      final Matrix matrix = Matrix(<List<double>>[
        <double>[a, b],
        <double>[c, d],
      ]);

      final Matrix result = matrix.exp();

      // True closed form: m = (a+d)/2 = 0.5, w = sqrt(-(halfDiff^2+b*c))
      // = 2 exactly (by construction), em = exp(0.5),
      // c1 = em * sin(w) / w, c0 = em * cos(w) - c1 * m.
      final double m = 0.5;
      final double w = 2.0;
      final double em = math.exp(m);
      final double c1 = em * math.sin(w) / w;
      final double c0 = em * math.cos(w) - c1 * m;
      final double expected00 = c0 + c1 * a;
      final double expected01 = c1 * b;
      final double expected10 = c1 * c;
      final double expected11 = c0 + c1 * d;

      expect(result.at(0, 0), closeTo(expected00, expected00.abs() * 1e-6));
      expect(result.at(0, 1), closeTo(expected01, expected01.abs() * 1e-6));
      expect(result.at(1, 0), closeTo(expected10, expected10.abs() * 1e-6));
      expect(result.at(1, 1), closeTo(expected11, expected11.abs() * 1e-6));
    });
  });

  group('Round 8, finding 3: Frobenius norm must scale before squaring to '
      'avoid spurious overflow', () {
    test('sqrt() raises matrix-out-of-precision-range (D38 declared '
        'precision contract: entries of magnitude 1e200 sit above '
        'matrixFunctionMaxMagnitude=1e150, so this is rejected outright '
        'before the scale-before-squaring Frobenius-norm fix this test '
        'used to regression-check is ever reached)', () {
      final Matrix matrix = Matrix(<List<double>>[
        <double>[1e200, 5],
        <double>[5, 1e200],
      ]);

      expect(
        matrix.sqrt,
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.matrixOutOfPrecisionRange,
          ),
        ),
      );
    });
  });

  group('Round 8, finding 4: sqrt()/power() must dispatch to the complex '
      'form closed form before the general 2x2 closed form', () {
    test('sqrt() of a complex-form matrix with a negative real part and a '
        'tiny imaginary part raises matrix-out-of-precision-range (D38 '
        'declared precision contract: the off-diagonal entries have '
        'magnitude 1e-170, below matrixFunctionMinMagnitude=1e-150, so '
        'this is rejected outright before the complex-form-dispatch-order '
        'fix this test used to regression-check is ever reached)', () {
      // a=-1, b=1e-170: b*b underflows to exactly 0 in double precision
      // (1e-340 is below the smallest subnormal double, about 4.9e-324),
      // so the general 2x2 eigenvalue classification (which squares b as
      // part of its discriminant) sees a discriminant of exactly 0 and
      // misclassifies this as a repeated real eigenvalue of -1, a genuine
      // negative real eigenvalue that non-integer real powers reject.
      final Matrix matrix = Matrix(<List<double>>[
        <double>[-1, -1e-170],
        <double>[1e-170, -1],
      ]);
      expect(matrix.isComplexForm, isTrue);

      expect(
        matrix.sqrt,
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.matrixOutOfPrecisionRange,
          ),
        ),
      );
    });
  });

  group('Round 8, finding 5: isComplexForm must use exact equality, not a '
      'scale-relative tolerance', () {
    test('a large Jordan block is not misclassified as complex form', () {
      // Diagonal entries equal (-1e20 == -1e20), but the off-diagonal pair
      // is 1 and 0, genuinely not negatives of each other. The current
      // scale-relative tolerance (4 * machineEpsilon * the matrix's own
      // largest entry, about 8.88e4 at this scale) is far larger than the
      // true off-diagonal gap of 1, so it wrongly calls this complex form.
      // This is a genuine Jordan block for the repeated eigenvalue -1e20
      // (b=1, c=0: not diagonalizable), which has no real or complex-form
      // square root in this package's supported closed forms.
      final Matrix matrix = Matrix(<List<double>>[
        <double>[-1e20, 1],
        <double>[0, -1e20],
      ]);

      expect(matrix.isComplexForm, isFalse);
    });
  });

  group('Round 8, finding 6: real Schur deflation must use the '
      'Ahues-Tisseur two-stage criterion, not the single-stage basic test '
      'alone', () {
    test('eigenvalues() of a 3x3 upper Hessenberg matrix does not collapse '
        'a genuinely separated near-defective 2x2 block into a repeated '
        'root', () {
      // Rows/columns 0-1 form a 2x2 block A = [[1, 1e10],[1e-16, 1]] whose
      // true eigenvalues (trace 2, det 1 - 1e-6 = 0.999999) are 1.001 and
      // 0.999, not a repeated 1. The subdiagonal entry h[1][0] = 1e-16 is
      // tiny enough that the single-stage basic test
      // |h[1][0]| <= eps*(|h[0][0]|+|h[1][1]|) = eps*2 =~ 4.44e-16 passes
      // and wrongly deflates row 0 off as an isolated eigenvalue of
      // exactly 1, even though the huge superdiagonal entry h[0][1] = 1e10
      // means row 0 and row 1 are still genuinely, significantly coupled.
      // The Ahues-Tisseur refinement also weighs h[0][1] (via
      // AB = max(|h10|,|h01|)) and the equal-diagonal gap (via
      // BB = min(|h11|, |h00-h11|) = 0 here), which correctly rejects this
      // deflation and forces real QR iteration on the full 3x3, recovering
      // the true 1.001/0.999 pair. Row/column 2 (h[2][1] = 5, h[2][2] =
      // 100) is a well-separated third eigenvalue whose own subdiagonal is
      // nowhere near negligible, so the search reaches h[1][0] at all.
      //
      // This matrix is block lower triangular (h[0][2] = h[1][2] = 0), so
      // its true spectrum is exactly the union of A's eigenvalues and
      // {100}, independent of h[2][1], by the determinant of a block
      // triangular matrix factoring along the block diagonal.
      final Matrix matrix = Matrix(<List<double>>[
        <double>[1, 1e10, 0],
        <double>[1e-16, 1, 0],
        <double>[0, 5, 100],
      ]);

      final Matrix eigen = matrix.eigenvalues();
      final List<double> values = List<double>.generate(
        eigen.rowCount,
        (int i) => eigen.at(i, 0),
      )..sort();

      expect(values.length, equals(3));
      expect(values[0], closeTo(0.999, 1e-9));
      expect(values[1], closeTo(1.001, 1e-9));
      expect(values[2], closeTo(100, 1e-9));
    });
  });

  group('Round 8, finding 7: the 2x2 eigenvalue path must not run the '
      'whole-matrix power-of-two normalization before balancing b and c '
      'individually', () {
    test('eigenvalues() of [[0,1e200],[1e-200,0]] recovers +-1, not a '
        'spurious {0,0} from b or c underflowing under a single shared '
        'scale factor', () {
      // True eigenvalues: trace 0, det = 0*0 - 1e200*1e-200 = -1, so
      // lambda = +-sqrt(-det) = +-1 exactly. The whole-matrix power-of-two
      // normalization picks one k from the matrix's infinity norm (1e200),
      // dividing every entry by ~2^664: b (1e200) lands near 0.53, fine,
      // but c (1e-200) lands near 5e-401, far below the smallest
      // representable subnormal double (~4.9e-324), so it underflows to
      // exactly 0 before the eigenvalue solver ever sees it, making
      // det = 0 and the eigenvalues a wrongly repeated 0.
      final Matrix matrix = Matrix(<List<double>>[
        <double>[0, 1e200],
        <double>[1e-200, 0],
      ]);

      final Matrix eigen = matrix.eigenvalues();
      final List<double> values = List<double>.generate(
        eigen.rowCount,
        (int i) => eigen.at(i, 0),
      )..sort();

      expect(values.length, equals(2));
      expect(values[0], closeTo(-1.0, 1e-9));
      expect(values[1], closeTo(1.0, 1e-9));
    });
  });

  group('Round 8, finding 8: general 2x2 real-power divided difference must '
      'anchor at the larger-magnitude eigenvalue, not always lambda2', () {
    test('power(1.5) of a general 2x2 with a huge eigenvalue ratio raises '
        'matrix-out-of-precision-range, not nonFinite (D38 declared '
        'precision contract: entries of magnitude 1e-160, 2e-160 and '
        '1e-300 all sit below matrixFunctionMinMagnitude=1e-150, so this '
        'is rejected outright before the anchor-at-larger-eigenvalue fix '
        'this test used to regression-check is ever reached)',
        () {
      final Matrix matrix = Matrix(<List<double>>[
        <double>[1, 1e-160],
        <double>[2e-160, 1e-300],
      ]);

      expect(
        () => matrix.power(Matrix.scalar(1.5)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.matrixOutOfPrecisionRange,
          ),
        ),
      );
    });
  });

  group('Round 8, finding 9: inverse() must use genuine LU decomposition '
      'with partial pivoting plus forward/back substitution, not '
      'Gauss-Jordan elimination on an augmented matrix', () {
    test('inverse() of a 10x10 Hilbert matrix has a residual close to what '
        'LU with partial pivoting achieves, not the looser residual '
        'Gauss-Jordan elimination leaves on this ill-conditioned input',
        () {
      // A Hilbert matrix (H[i][j] = 1/(i+j+1)) is a classic ill-conditioned
      // test case (condition number grows roughly like 1.5e13 at n=10).
      // Gauss-Jordan elimination on the augmented [A | I] matrix keeps
      // updating the whole augmented row, including the columns already
      // reduced toward the identity, at every pivot step, which
      // accumulates materially more rounding error on an ill-conditioned
      // input than genuine LU decomposition (eliminate once, below the
      // pivot only) followed by a single forward and back substitution
      // per right-hand side. A reference LU implementation checked
      // against this same matrix during investigation leaves a maximum
      // residual around 7.6e-5, while the current Gauss-Jordan
      // implementation leaves one around 2.8e-3, almost forty times
      // looser.
      final int n = 10;
      final Matrix hilbert = Matrix(
        List<List<double>>.generate(
          n,
          (int i) => List<double>.generate(n, (int j) => 1 / (i + j + 1)),
        ),
      );

      final Matrix inverse = hilbert.inverse();
      final Matrix product = hilbert * inverse;

      double maxResidual = 0;
      for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
          final double expected = i == j ? 1.0 : 0.0;
          final double residual = (product.at(i, j) - expected).abs();
          if (residual > maxResidual) {
            maxResidual = residual;
          }
        }
      }

      expect(maxResidual, lessThan(1e-4));
    });
  });

  group('Round 8, finding 10: a positive scalar base raised to a matrix '
      'exponent must classify the exponent\'s own supported '
      'matrix-function class before scaling it by log(base)', () {
    test('base^exponent raises matrix-out-of-precision-range (D38 declared '
        'precision contract: this test\'s exponent entries of magnitude '
        '1e-310 sit below matrixFunctionMinMagnitude=1e-150, so this is '
        'rejected outright before the classify-before-scaling fix this '
        'test used to regression-check is ever reached; see below for why '
        'that original scenario is now provably unreachable, not merely '
        'untested, for any exponent within the declared range)', () {
      // base = 1 + 2^-52 (the smallest double strictly greater than 1),
      // so log(base) is about 2.22e-16, the smallest nonzero magnitude a
      // scaling factor derived this way can have. exponent's off-diagonal
      // entries are 1e-310, 2e-310, and so on: genuinely nonzero, valid
      // subnormal doubles, making exponent a genuine 3x3 non-diagonal,
      // non-symmetric matrix, which is not one of the five supported
      // matrix-function classes (scalar, complex-form, diagonal, exactly
      // symmetric, general 2x2). entry * log(base) (about 1e-310 *
      // 2.22e-16 =~ 2.22e-326) is below the smallest representable
      // subnormal double (about 4.9e-324), so every off-diagonal entry of
      // the scaled copy used to underflow to exactly 0, making the scaled
      // copy look exactly diagonal even though exponent itself never was.
      //
      // Codex round 9, finding 4 added a D38 raw-entry precision-range
      // gate ([_requireEntriesInPrecisionRange]) that now runs on both
      // operands before this scenario's classify-before-scale check
      // ([_isSupportedMatrixFunctionClass]) is ever reached, so this
      // specific 1e-310-magnitude exponent is now rejected earlier, for a
      // different reason, than the one this test originally targeted.
      // This is not just a coincidence of this particular fixture: the
      // smallest nonzero |log(base)| a positive double base distinct
      // from 1 can produce is about 2.22e-16 (base = 1 +/- one ulp of 1,
      // the closest a double can sit to 1 without being 1), so an
      // exponent entry would need magnitude below roughly
      // 4.9e-324 / 2.22e-16 =~ 2.2e-308 to underflow to exactly 0 once
      // scaled. matrixFunctionMinMagnitude is 1e-150, twenty orders of
      // magnitude above that floor, so no exponent entry within the D38
      // declared range can ever underflow to exactly 0 under this
      // scaling. The classify-before-scale fix (still present, and still
      // correct as a defense-in-depth measure) is therefore unreachable
      // for any input the D38 gate now admits; this test is kept, with
      // its expectation updated, to document that finding and to keep
      // regression-checking the D38 gate firing first on this code path.
      final double base = 1.0000000000000002;
      final Matrix exponent = Matrix(<List<double>>[
        <double>[1, 1e-310, 3e-310],
        <double>[2e-310, 2, 4e-310],
        <double>[5e-310, 6e-310, 3],
      ]);

      expect(
        () => Matrix.scalar(base).power(exponent),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.matrixOutOfPrecisionRange,
          ),
        ),
      );
    });
  });

  group('Round 8, finding 12: a zero eigenvalue raised to a negative real '
      'power in the general 2x2 closed form must be logUndefined, not '
      'nonFinite', () {
    test('power(-1.5) of a general 2x2 matrix with eigenvalues 0 and 3 '
        'throws logUndefined', () {
      // [[0,1],[0,3]] has trace 3 and determinant 0, so its exact
      // eigenvalues are 0 and 3: distinct, real, one of them exactly zero.
      // It is not diagonal (the [0][1] entry is nonzero), not exactly
      // symmetric (the [0][1] and [1][0] entries differ), and not the
      // complex form a*I+b*J (the diagonal entries differ), so power()
      // reaches the general 2x2 closed form. A zero eigenvalue raised to a
      // negative power is genuinely undefined in the real domain the same
      // way log(0) is (it is not that the result overflows to a finite-but-
      // unrepresentable magnitude; there is no real value at all), so the
      // typed error must be logUndefined, matching every other "no real
      // value exists" case in this file (the repeated-zero-eigenvalue case
      // just above already uses logUndefined for exactly this reason).
      final Matrix matrix = Matrix(<List<double>>[
        <double>[0, 1],
        <double>[0, 3],
      ]);

      expect(
        () => matrix.power(Matrix.scalar(-1.5)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.logUndefined,
          ),
        ),
      );
    });
  });
}
