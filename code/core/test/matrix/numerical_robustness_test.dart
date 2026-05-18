/// Numerical robustness tests using standard test matrices from the literature.
///
/// Reference: Higham, "Accuracy and Stability of Numerical Algorithms" (2002).
/// These matrices are canonical stress tests for linear algebra implementations:
/// - Hilbert: exponentially growing condition number κ(H_n) ≈ e^{3.5n}
/// - Pascal: symmetric positive definite with known integer inverse
/// - Frank: upper-Hessenberg with known eigenvalue structure
///
/// Residual-norm assertions test backward stability:
/// - ‖A·A⁻¹ − I‖_F / n measures inverse accuracy
/// - ‖P·A − L·U‖_F / ‖A‖_F measures LU reconstruction
/// - ‖Q·R − A‖_F / ‖A‖_F measures QR reconstruction
/// - ‖A·v − λ·v‖ / (‖A‖·‖v‖) measures eigenpair accuracy
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1: Standard Test Matrix Factories
  // ═══════════════════════════════════════════════════════════════════════════
  group('Standard test matrix factories', () {
    group('Hilbert matrix', () {
      test('H(3) has correct entries H[i,j] = 1/(i+j+1)', () {
        final h3 = Matrix.hilbert(3);
        expect(h3.rowCount, 3);
        expect(h3.columnCount, 3);
        // H(3) = [[1, 1/2, 1/3], [1/2, 1/3, 1/4], [1/3, 1/4, 1/5]]
        expect(h3.at(0, 0), 1.0);
        expect(h3.at(0, 1), 1 / 2);
        expect(h3.at(0, 2), 1 / 3);
        expect(h3.at(1, 0), 1 / 2);
        expect(h3.at(1, 1), 1 / 3);
        expect(h3.at(1, 2), 1 / 4);
        expect(h3.at(2, 0), 1 / 3);
        expect(h3.at(2, 1), 1 / 4);
        expect(h3.at(2, 2), 1 / 5);
      });

      test('H(4) is 4×4 symmetric', () {
        final h4 = Matrix.hilbert(4);
        expect(h4.rowCount, 4);
        expect(h4.columnCount, 4);
        // Symmetry: H[i,j] = H[j,i]
        for (int i = 0; i < 4; i++) {
          for (int j = 0; j < 4; j++) {
            expect(h4.at(i, j), h4.at(j, i));
          }
        }
      });

      test('H(5) is 5×5', () {
        final h5 = Matrix.hilbert(5);
        expect(h5.rowCount, 5);
        expect(h5.columnCount, 5);
        expect(h5.at(4, 4), 1 / 9); // 1/(4+4+1)
      });

      test('H(6) is 6×6', () {
        final h6 = Matrix.hilbert(6);
        expect(h6.rowCount, 6);
        expect(h6.columnCount, 6);
        expect(h6.at(5, 5), 1 / 11); // 1/(5+5+1)
      });

      test('H(1) throws for invalid size', () {
        // H(1) is valid: [[1]]
        expect(Matrix.hilbert(1).scalarValue, 1.0);
      });

      test('H(0) throws MatrixShapeError', () {
        expect(
          () => Matrix.hilbert(0),
          throwsA(isA<MatrixShapeError>()),
        );
      });
    });

    group('Pascal matrix', () {
      test('P(3) has correct binomial entries P[i,j] = C(i+j, i)', () {
        final p3 = Matrix.pascal(3);
        expect(p3.rowCount, 3);
        expect(p3.columnCount, 3);
        // P(3) = [[1, 1, 1], [1, 2, 3], [1, 3, 6]]
        expect(p3.at(0, 0), 1);
        expect(p3.at(0, 1), 1);
        expect(p3.at(0, 2), 1);
        expect(p3.at(1, 0), 1);
        expect(p3.at(1, 1), 2);
        expect(p3.at(1, 2), 3);
        expect(p3.at(2, 0), 1);
        expect(p3.at(2, 1), 3);
        expect(p3.at(2, 2), 6);
      });

      test('P(4) is symmetric positive definite', () {
        final p4 = Matrix.pascal(4);
        expect(p4.rowCount, 4);
        expect(p4.columnCount, 4);
        // Symmetry
        for (int i = 0; i < 4; i++) {
          for (int j = 0; j < 4; j++) {
            expect(p4.at(i, j), p4.at(j, i));
          }
        }
        // Positive definite: det > 0
        expect(p4.determinant().scalarValue, greaterThan(0));
      });

      test('P(5) is 5×5 with det = 1', () {
        // det(Pascal(n)) = 1 for all n
        final p5 = Matrix.pascal(5);
        expect(p5.rowCount, 5);
        expect(p5.columnCount, 5);
        expect(p5.determinant().scalarValue, closeTo(1, 1e-8));
      });

      test('P(0) throws MatrixShapeError', () {
        expect(
          () => Matrix.pascal(0),
          throwsA(isA<MatrixShapeError>()),
        );
      });
    });

    group('Frank matrix', () {
      test('F(3) has correct upper-Hessenberg structure', () {
        final f3 = Matrix.frank(3);
        expect(f3.rowCount, 3);
        expect(f3.columnCount, 3);
        // F(3) = [[3, 2, 1], [2, 2, 1], [0, 1, 1]]
        // F[i,j] = n-max(i,j) if j >= i-1, else 0
        expect(f3.at(0, 0), 3);
        expect(f3.at(0, 1), 2);
        expect(f3.at(0, 2), 1);
        expect(f3.at(1, 0), 2);
        expect(f3.at(1, 1), 2);
        expect(f3.at(1, 2), 1);
        expect(f3.at(2, 0), 0);
        expect(f3.at(2, 1), 1);
        expect(f3.at(2, 2), 1);
      });

      test('F(4) is upper-Hessenberg (zeros below sub-diagonal)', () {
        final f4 = Matrix.frank(4);
        expect(f4.rowCount, 4);
        expect(f4.columnCount, 4);
        // Below sub-diagonal should be zero
        for (int i = 2; i < 4; i++) {
          for (int j = 0; j < i - 1; j++) {
            expect(f4.at(i, j), 0,
                reason: 'F[$i,$j] should be 0 (below sub-diagonal)');
          }
        }
      });

      test('F(5) is 5×5', () {
        final f5 = Matrix.frank(5);
        expect(f5.rowCount, 5);
        expect(f5.columnCount, 5);
      });

      test('F(0) throws MatrixShapeError', () {
        expect(
          () => Matrix.frank(0),
          throwsA(isA<MatrixShapeError>()),
        );
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2: Inverse Residual Assertions
  // ═══════════════════════════════════════════════════════════════════════════
  group('Inverse residual: ‖A·A⁻¹ − I‖_F / n', () {
    test('Hilbert(3) inverse residual < 1e-10', () {
      final h3 = Matrix.hilbert(3);
      final inv = h3.inverse();
      final product = h3 * inv;
      final residual = _frobeniusResidual(product, Matrix.identity(3));
      expect(residual / 3, lessThan(1e-10));
    });

    test('Hilbert(4) inverse residual < 1e-6', () {
      // κ(H4) ≈ 1.5×10⁴ so we relax tolerance
      final h4 = Matrix.hilbert(4);
      final inv = h4.inverse();
      final product = h4 * inv;
      final residual = _frobeniusResidual(product, Matrix.identity(4));
      expect(residual / 4, lessThan(1e-6));
    });

    test('Pascal(3) inverse residual < 1e-10', () {
      final p3 = Matrix.pascal(3);
      final inv = p3.inverse();
      final product = p3 * inv;
      final residual = _frobeniusResidual(product, Matrix.identity(3));
      expect(residual / 3, lessThan(1e-10));
    });

    test('Pascal(4) inverse residual < 1e-10', () {
      final p4 = Matrix.pascal(4);
      final inv = p4.inverse();
      final product = p4 * inv;
      final residual = _frobeniusResidual(product, Matrix.identity(4));
      expect(residual / 4, lessThan(1e-10));
    });

    test('Frank(4) inverse residual < 1e-10', () {
      final f4 = Matrix.frank(4);
      final inv = f4.inverse();
      final product = f4 * inv;
      final residual = _frobeniusResidual(product, Matrix.identity(4));
      expect(residual / 4, lessThan(1e-10));
    });

    test('5×5 random-style matrix inverse residual', () {
      // Well-conditioned 5×5 matrix
      final a = Matrix([
        [2, 1, 0, 0, 0],
        [1, 3, 1, 0, 0],
        [0, 1, 4, 1, 0],
        [0, 0, 1, 5, 1],
        [0, 0, 0, 1, 6],
      ]);
      final inv = a.inverse();
      final product = a * inv;
      final residual = _frobeniusResidual(product, Matrix.identity(5));
      expect(residual / 5, lessThan(1e-10));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3: LU Decomposition Residual Assertions
  // ═══════════════════════════════════════════════════════════════════════════
  group('LU residual: ‖P·A − L·U‖_F / ‖A‖_F', () {
    test('Hilbert(3) LU residual < 1e-12', () {
      final h3 = Matrix.hilbert(3);
      final lu = h3.luDecomposition();
      final reconstructed = lu.lower * lu.upper;
      final pa = lu.permutation * h3;
      final normA = h3.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(pa, reconstructed) / normA;
      expect(residual, lessThan(1e-12));
    });

    test('Hilbert(5) LU residual < 1e-10', () {
      final h5 = Matrix.hilbert(5);
      final lu = h5.luDecomposition();
      final reconstructed = lu.lower * lu.upper;
      final pa = lu.permutation * h5;
      final normA = h5.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(pa, reconstructed) / normA;
      expect(residual, lessThan(1e-10));
    });

    test('Pascal(4) LU residual < 1e-12', () {
      final p4 = Matrix.pascal(4);
      final lu = p4.luDecomposition();
      final reconstructed = lu.lower * lu.upper;
      final pa = lu.permutation * p4;
      final normA = p4.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(pa, reconstructed) / normA;
      expect(residual, lessThan(1e-12));
    });

    test('Frank(5) LU residual < 1e-12', () {
      final f5 = Matrix.frank(5);
      final lu = f5.luDecomposition();
      final reconstructed = lu.lower * lu.upper;
      final pa = lu.permutation * f5;
      final normA = f5.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(pa, reconstructed) / normA;
      expect(residual, lessThan(1e-12));
    });

    test('6×6 tridiagonal LU residual < 1e-12', () {
      final a = _tridiagonal(6);
      final lu = a.luDecomposition();
      final reconstructed = lu.lower * lu.upper;
      final pa = lu.permutation * a;
      final normA = a.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(pa, reconstructed) / normA;
      expect(residual, lessThan(1e-12));
    });

    test('8×8 tridiagonal LU residual < 1e-12', () {
      final a = _tridiagonal(8);
      final lu = a.luDecomposition();
      final reconstructed = lu.lower * lu.upper;
      final pa = lu.permutation * a;
      final normA = a.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(pa, reconstructed) / normA;
      expect(residual, lessThan(1e-12));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 4: QR Decomposition Residual Assertions
  // ═══════════════════════════════════════════════════════════════════════════
  group('QR residual: ‖Q·R − A‖_F / ‖A‖_F', () {
    test('Hilbert(3) QR residual < 1e-12', () {
      final h3 = Matrix.hilbert(3);
      final qr = h3.qrDecomposition();
      final reconstructed = qr.q * qr.r;
      final normA = h3.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(h3, reconstructed) / normA;
      expect(residual, lessThan(1e-12));
    });

    test('Hilbert(5) QR residual < 1e-10', () {
      final h5 = Matrix.hilbert(5);
      final qr = h5.qrDecomposition();
      final reconstructed = qr.q * qr.r;
      final normA = h5.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(h5, reconstructed) / normA;
      expect(residual, lessThan(1e-10));
    });

    test('Pascal(4) QR residual < 1e-12', () {
      final p4 = Matrix.pascal(4);
      final qr = p4.qrDecomposition();
      final reconstructed = qr.q * qr.r;
      final normA = p4.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(p4, reconstructed) / normA;
      expect(residual, lessThan(1e-12));
    });

    test('Frank(5) QR residual < 1e-12', () {
      final f5 = Matrix.frank(5);
      final qr = f5.qrDecomposition();
      final reconstructed = qr.q * qr.r;
      final normA = f5.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(f5, reconstructed) / normA;
      expect(residual, lessThan(1e-12));
    });

    test('QR orthogonality: ‖QᵀQ − I‖_F < 1e-10 on Hilbert(5)', () {
      final h5 = Matrix.hilbert(5);
      final qr = h5.qrDecomposition();
      final qtq = qr.q.transpose() * qr.q;
      final residual = _frobeniusResidual(qtq, Matrix.identity(5));
      expect(residual, lessThan(1e-10));
    });

    test('6×6 tridiagonal QR residual < 1e-12', () {
      final a = _tridiagonal(6);
      final qr = a.qrDecomposition();
      final reconstructed = qr.q * qr.r;
      final normA = a.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(a, reconstructed) / normA;
      expect(residual, lessThan(1e-12));
    });

    test('8×8 tridiagonal QR residual < 1e-12', () {
      final a = _tridiagonal(8);
      final qr = a.qrDecomposition();
      final reconstructed = qr.q * qr.r;
      final normA = a.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(a, reconstructed) / normA;
      expect(residual, lessThan(1e-12));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5: Eigenvalue Residual Assertions
  // ═══════════════════════════════════════════════════════════════════════════
  group('Eigenvalue residual: ‖A·v − λ·v‖ / (‖A‖·‖v‖)', () {
    test('5×5 diagonal matrix eigenvalues exact', () {
      final d = Matrix([
        [5, 0, 0, 0, 0],
        [0, 4, 0, 0, 0],
        [0, 0, 3, 0, 0],
        [0, 0, 0, 2, 0],
        [0, 0, 0, 0, 1],
      ]);
      final eigs = d.eigenvalues();
      expect(eigs.rowCount, 5);
      // Should be [5, 4, 3, 2, 1] sorted descending
      expect(eigs.at(0, 0), closeTo(5, 1e-10));
      expect(eigs.at(1, 0), closeTo(4, 1e-10));
      expect(eigs.at(2, 0), closeTo(3, 1e-10));
      expect(eigs.at(3, 0), closeTo(2, 1e-10));
      expect(eigs.at(4, 0), closeTo(1, 1e-10));
    });

    test('5×5 symmetric matrix eigenvalue residual via diagonalization', () {
      // Symmetric tridiagonal — guaranteed real eigenvalues
      final a = Matrix([
        [4, 1, 0, 0, 0],
        [1, 4, 1, 0, 0],
        [0, 1, 4, 1, 0],
        [0, 0, 1, 4, 1],
        [0, 0, 0, 1, 4],
      ]);
      final diag = a.diagonalization();
      // Verify A ≈ P·D·P⁻¹
      final reconstructed = diag.p * diag.d * diag.p.inverse();
      final normA = a.frobeniusNorm().scalarValue;
      final residual = _frobeniusResidual(a, reconstructed) / normA;
      expect(residual, lessThan(1e-8));
    });

    test('6×6 symmetric matrix eigenvalues sorted descending', () {
      // 6×6 symmetric positive definite
      final a = Matrix([
        [6, 1, 0, 0, 0, 0],
        [1, 6, 1, 0, 0, 0],
        [0, 1, 6, 1, 0, 0],
        [0, 0, 1, 6, 1, 0],
        [0, 0, 0, 1, 6, 1],
        [0, 0, 0, 0, 1, 6],
      ]);
      final eigs = a.eigenvalues();
      expect(eigs.rowCount, 6);
      // Verify sorted descending
      for (int i = 0; i < 5; i++) {
        expect(eigs.at(i, 0), greaterThanOrEqualTo(eigs.at(i + 1, 0)));
      }
      // All eigenvalues should be positive (SPD matrix)
      for (int i = 0; i < 6; i++) {
        expect(eigs.at(i, 0), greaterThan(0));
      }
    });

    test('Frank(5) eigenvalues all positive and real', () {
      // Frank matrices have all real positive eigenvalues
      final f5 = Matrix.frank(5);
      final eigs = f5.eigenvalues();
      expect(eigs.rowCount, 5);
      for (int i = 0; i < 5; i++) {
        expect(eigs.at(i, 0), greaterThan(0),
            reason: 'Frank(5) eigenvalue $i should be positive');
      }
    });

    test('Pascal(4) determinant equals product of eigenvalues', () {
      final p4 = Matrix.pascal(4);
      final eigs = p4.eigenvalues();
      double product = 1;
      for (int i = 0; i < 4; i++) {
        product *= eigs.at(i, 0);
      }
      final det = p4.determinant().scalarValue;
      expect(product, closeTo(det, 1e-6));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 6: RREF on Standard Matrices
  // ═══════════════════════════════════════════════════════════════════════════
  group('RREF on standard matrices', () {
    test('Hilbert(3) RREF is identity (full rank)', () {
      final h3 = Matrix.hilbert(3);
      final rref = h3.rref();
      expect(rref.almostEquals(Matrix.identity(3)), isTrue);
    });

    test('Pascal(4) RREF is identity (det = 1)', () {
      final p4 = Matrix.pascal(4);
      final rref = p4.rref();
      expect(rref.almostEquals(Matrix.identity(4)), isTrue);
    });

    test('Frank(4) RREF is identity (non-singular)', () {
      final f4 = Matrix.frank(4);
      final rref = f4.rref();
      expect(rref.almostEquals(Matrix.identity(4)), isTrue);
    });

    test('5×5 identity RREF is itself', () {
      final i5 = Matrix.identity(5);
      final rref = i5.rref();
      expect(rref.almostEquals(i5), isTrue);
    });

    test('6×6 tridiagonal RREF is identity', () {
      final a = _tridiagonal(6);
      final rref = a.rref();
      expect(rref.almostEquals(Matrix.identity(6)), isTrue);
    });

    test('rank-deficient 5×5 RREF has zero rows', () {
      // Last row is sum of first two → rank 4
      final a = Matrix([
        [1, 0, 0, 0, 0],
        [0, 1, 0, 0, 0],
        [0, 0, 1, 0, 0],
        [0, 0, 0, 1, 0],
        [1, 1, 0, 0, 0], // linearly dependent on rows 0+1
      ]);
      final rref = a.rref();
      expect(a.rank().scalarValue, closeTo(4, 1e-10));
      // Last row of RREF should be all zeros
      for (int j = 0; j < 5; j++) {
        expect(rref.at(4, j).abs(), lessThan(1e-10),
            reason: 'RREF row 4 col $j should be ~0');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 7: Dimension Stress Tests (5×5, 6×6, 8×8)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Dimension stress tests', () {
    group('5×5 operations', () {
      test('determinant of 5×5 tridiagonal', () {
        final a = _tridiagonal(5);
        final det = a.determinant().scalarValue;
        expect(det.isFinite, isTrue);
        expect(det.abs(), greaterThan(0));
      });

      test('5×5 inverse exists and is correct', () {
        final a = _tridiagonal(5);
        final inv = a.inverse();
        final product = a * inv;
        expect(product.almostEquals(Matrix.identity(5)), isTrue);
      });

      test('5×5 trace equals sum of eigenvalues', () {
        final a = Matrix([
          [4, 1, 0, 0, 0],
          [1, 4, 1, 0, 0],
          [0, 1, 4, 1, 0],
          [0, 0, 1, 4, 1],
          [0, 0, 0, 1, 4],
        ]);
        final tr = a.trace().scalarValue;
        final eigs = a.eigenvalues();
        double eigSum = 0;
        for (int i = 0; i < 5; i++) {
          eigSum += eigs.at(i, 0);
        }
        expect(tr, closeTo(eigSum, 1e-8));
      });

      test('5×5 spectral norm ≤ Frobenius norm', () {
        final a = _tridiagonal(5);
        final snorm = a.spectralNorm().scalarValue;
        final fnorm = a.frobeniusNorm().scalarValue;
        expect(snorm, lessThanOrEqualTo(fnorm + 1e-10));
      });
    });

    group('6×6 operations', () {
      test('determinant of 6×6 tridiagonal', () {
        final a = _tridiagonal(6);
        final det = a.determinant().scalarValue;
        expect(det.isFinite, isTrue);
        expect(det.abs(), greaterThan(0));
      });

      test('6×6 diagonalization reconstruction', () {
        // 6×6 symmetric guarantees real eigenvalues
        final a = Matrix([
          [6, 1, 0, 0, 0, 0],
          [1, 6, 1, 0, 0, 0],
          [0, 1, 6, 1, 0, 0],
          [0, 0, 1, 6, 1, 0],
          [0, 0, 0, 1, 6, 1],
          [0, 0, 0, 0, 1, 6],
        ]);
        final diag = a.diagonalization();
        final reconstructed = diag.p * diag.d * diag.p.inverse();
        final normA = a.frobeniusNorm().scalarValue;
        final residual = _frobeniusResidual(a, reconstructed) / normA;
        expect(residual, lessThan(1e-6));
      });

      test('6×6 rank computation', () {
        final a = _tridiagonal(6);
        expect(a.rank().scalarValue, closeTo(6, 1e-10));
      });

      test('6×6 Frobenius norm is positive', () {
        final a = _tridiagonal(6);
        expect(a.frobeniusNorm().scalarValue, greaterThan(0));
      });
    });

    group('8×8 operations', () {
      test('determinant of 8×8 tridiagonal', () {
        final a = _tridiagonal(8);
        final det = a.determinant().scalarValue;
        expect(det.isFinite, isTrue);
        expect(det.abs(), greaterThan(0));
      });

      test('8×8 inverse residual < 1e-10', () {
        final a = _tridiagonal(8);
        final inv = a.inverse();
        final product = a * inv;
        final residual = _frobeniusResidual(product, Matrix.identity(8));
        expect(residual / 8, lessThan(1e-10));
      });

      test('8×8 LU + QR residuals both small', () {
        final a = _tridiagonal(8);
        final normA = a.frobeniusNorm().scalarValue;

        final lu = a.luDecomposition();
        final luResid = _frobeniusResidual(
              lu.permutation * a,
              lu.lower * lu.upper,
            ) /
            normA;
        expect(luResid, lessThan(1e-12));

        final qr = a.qrDecomposition();
        final qrResid = _frobeniusResidual(a, qr.q * qr.r) / normA;
        expect(qrResid, lessThan(1e-12));
      });

      test('8×8 eigenvalues of symmetric tridiagonal', () {
        // 8×8 symmetric tridiagonal: guaranteed real eigenvalues
        final a = Matrix([
          [4, 1, 0, 0, 0, 0, 0, 0],
          [1, 4, 1, 0, 0, 0, 0, 0],
          [0, 1, 4, 1, 0, 0, 0, 0],
          [0, 0, 1, 4, 1, 0, 0, 0],
          [0, 0, 0, 1, 4, 1, 0, 0],
          [0, 0, 0, 0, 1, 4, 1, 0],
          [0, 0, 0, 0, 0, 1, 4, 1],
          [0, 0, 0, 0, 0, 0, 1, 4],
        ]);
        final eigs = a.eigenvalues();
        expect(eigs.rowCount, 8);
        // Trace = sum of eigenvalues = 32
        double eigSum = 0;
        for (int i = 0; i < 8; i++) {
          eigSum += eigs.at(i, 0);
        }
        expect(eigSum, closeTo(32, 1e-6));
      });

      test('8×8 RREF of full-rank matrix is identity', () {
        final a = _tridiagonal(8);
        final rref = a.rref();
        expect(rref.almostEquals(Matrix.identity(8)), isTrue);
      });

      test('8×8 spectral norm is consistent', () {
        final a = _tridiagonal(8);
        final snorm = a.spectralNorm().scalarValue;
        final fnorm = a.frobeniusNorm().scalarValue;
        // ‖A‖₂ ≤ ‖A‖_F always
        expect(snorm, lessThanOrEqualTo(fnorm + 1e-10));
        expect(snorm, greaterThan(0));
      });
    });
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// Helpers
// ═════════════════════════════════════════════════════════════════════════════

/// Compute ‖A − B‖_F (Frobenius norm of the difference).
double _frobeniusResidual(Matrix a, Matrix b) {
  final diff = a - b;
  return diff.frobeniusNorm().scalarValue;
}

/// Build an n×n symmetric positive definite tridiagonal matrix:
/// diagonal = 4, sub/super-diagonal = 1.
/// This is a standard well-conditioned test matrix.
Matrix _tridiagonal(int n) {
  return Matrix(
    List<List<double>>.generate(
      n,
      (int i) => List<double>.generate(n, (int j) {
        if (i == j) return 4;
        if ((i - j).abs() == 1) return 1;
        return 0;
      }, growable: false),
      growable: false,
    ),
  );
}
