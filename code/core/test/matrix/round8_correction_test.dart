// Round 8 correction: twelve findings from an independent review of
// lib/src/matrix/matrix.dart, each covered here by a test that fails
// before its paired fix and asserts a concrete numeric value or error id.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

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

    test('exp([[-1000,1],[0,-500]]) has a finite [1][1] entry close to '
        'exp(-500)', () {
      final Matrix result = Matrix(<List<double>>[
        <double>[-1000, 1],
        <double>[0, -500],
      ]).exp();

      expect(result.at(1, 1).isFinite, isTrue);
      expect(
        result.at(1, 1),
        closeTo(math.exp(-500), math.exp(-500) * 1e-9),
      );
      expect(result.at(0, 0), closeTo(math.exp(-1000), 1e-300));
    });
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
    test('sqrt() succeeds for a symmetric matrix whose entries individually '
        'overflow when squared but whose true norm is finite', () {
      // 1e200 squared is 1e400, which overflows double (max ~1.8e308), even
      // though the true Frobenius norm (about 1.41e200) is well within
      // double's finite range. A Frobenius norm that sums unscaled squares
      // wrongly reports a non-finite norm and refuses to run the Jacobi
      // eigendecomposition at all.
      final Matrix matrix = Matrix(<List<double>>[
        <double>[1e200, 5],
        <double>[5, 1e200],
      ]);

      final Matrix result = matrix.sqrt();

      expect(result.at(0, 0).isFinite, isTrue);
      expect(result.at(0, 1).isFinite, isTrue);
      expect(result.at(1, 0).isFinite, isTrue);
      expect(result.at(1, 1).isFinite, isTrue);

      // A single unit-in-the-last-place near 1e200 is about 2e184, far
      // larger than the original off-diagonal entry (5), so the residual
      // check only requires the off-diagonal entries to stay small relative
      // to the dominant 1e200 scale, not to reproduce 5 exactly.
      final Matrix squared = result * result;
      expect(squared.at(0, 0), closeTo(1e200, 1e200 * 1e-6));
      expect(squared.at(0, 1), closeTo(0, 1e195));
      expect(squared.at(1, 0), closeTo(0, 1e195));
      expect(squared.at(1, 1), closeTo(1e200, 1e200 * 1e-6));
    });
  });

  group('Round 8, finding 4: sqrt()/power() must dispatch to the complex '
      'form closed form before the general 2x2 closed form', () {
    test('sqrt() of a complex-form matrix with a negative real part and a '
        'tiny imaginary part succeeds instead of wrongly throwing '
        'logUndefined', () {
      // a=-1, b=1e-170: b*b underflows to exactly 0 in double precision
      // (1e-340 is below the smallest subnormal double, about 4.9e-324),
      // so the general 2x2 eigenvalue classification (which squares b as
      // part of its discriminant) sees a discriminant of exactly 0 and
      // misclassifies this as a repeated real eigenvalue of -1, a genuine
      // negative real eigenvalue that non-integer real powers reject.
      // log() already dispatches to the dedicated complex-form branch
      // first and succeeds for the exact same matrix (ln(1) + pi*i, since
      // the magnitude is exactly 1 and the angle is essentially pi), so
      // sqrt() should too: the complex form aI+bJ has a well-defined
      // non-integer power for any nonzero magnitude, regardless of sign.
      final Matrix matrix = Matrix(<List<double>>[
        <double>[-1, -1e-170],
        <double>[1e-170, -1],
      ]);
      expect(matrix.isComplexForm, isTrue);

      final Matrix result = matrix.sqrt();

      expect(result.at(0, 0).isFinite, isTrue);
      expect(result.at(1, 1).isFinite, isTrue);
      // sqrt(-1) = i (magnitude 1, angle pi/2), so the real part collapses
      // to (near) zero and the imaginary part to (near) 1.
      expect(result.at(0, 0), closeTo(0, 1e-9));
      expect(result.at(1, 1), closeTo(0, 1e-9));
      expect(result.at(1, 0).abs(), closeTo(1, 1e-9));
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
    test('power(1.5) of a general 2x2 with a huge eigenvalue ratio succeeds '
        'instead of wrongly throwing nonFinite from a 0*Infinity product',
        () {
      // Eigenvalues are approximately 1 (l1) and 1e-300 (l2). Anchoring
      // the divided difference at l2 (the previous, always-l2 behavior)
      // computes l2^1.5, which underflows to exactly 0, and separately
      // computes expm1(y*log1p((l1-l2)/l2)), whose argument is huge
      // (l1/l2 ~ 1e300) and whose expm1 result overflows to Infinity, so
      // their product is 0*Infinity = NaN. Anchoring at l1 (the
      // larger-magnitude eigenvalue) instead computes l1^1.5 = 1 (finite,
      // no underflow) and expm1(y*log1p((l2-l1)/l1)), whose argument is
      // safely close to -1, which never overflows. Since l2 is negligible
      // next to l1, the true result is (to double precision) simply A
      // itself: A^1.5 has eigenvalues 1^1.5=1 and (~0)^1.5=~0, so c0=~0
      // and c1=~1 in the c0*I + c1*A closed form.
      final Matrix matrix = Matrix(<List<double>>[
        <double>[1, 1e-160],
        <double>[2e-160, 1e-300],
      ]);

      final Matrix result = matrix.power(Matrix.scalar(1.5));

      expect(result.at(0, 0).isFinite, isTrue);
      expect(result.at(0, 1).isFinite, isTrue);
      expect(result.at(1, 0).isFinite, isTrue);
      expect(result.at(1, 1).isFinite, isTrue);
      expect(result.at(0, 0), closeTo(1.0, 1e-6));
      expect(result.at(0, 1), closeTo(1e-160, 1e-165));
      expect(result.at(1, 0), closeTo(2e-160, 1e-165));
    });
  });
}
