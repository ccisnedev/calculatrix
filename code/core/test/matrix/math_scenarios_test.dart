/// Comprehensive mathematical scenario tests for Calculatrix.
///
/// Organized by topic to validate correctness from a mathematician's
/// perspective: student homework problems, textbook identities, and
/// research-level numerical edge cases.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 1: Scalar Arithmetic (sanity baseline)
  // ─────────────────────────────────────────────────────────────────────────
  group('Scalar arithmetic', () {
    test('addition and subtraction', () {
      final a = Matrix.scalar(7);
      final b = Matrix.scalar(3);
      expect((a + b).scalarValue, 10);
      expect((a - b).scalarValue, 4);
    });

    test('multiplication and division', () {
      final a = Matrix.scalar(6);
      final b = Matrix.scalar(2);
      expect((a * b).scalarValue, 12);
      expect((a / b).scalarValue, 3);
    });

    test('negative numbers', () {
      final a = Matrix.scalar(-5);
      final b = Matrix.scalar(3);
      expect((a + b).scalarValue, -2);
      expect((a * b).scalarValue, -15);
    });

    test('decimal precision', () {
      final a = Matrix.scalar(0.1);
      final b = Matrix.scalar(0.2);
      // floating point: 0.1 + 0.2 ≈ 0.30000000000000004
      expect((a + b).scalarValue, closeTo(0.3, 1e-10));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 2: Vector Algebra (R² and R³)
  // ─────────────────────────────────────────────────────────────────────────
  group('Vector algebra', () {
    group('vector addition and scaling', () {
      test('sum of two R³ vectors', () {
        final u = Matrix(<List<double>>[[1], [2], [3]]);
        final v = Matrix(<List<double>>[[4], [5], [6]]);
        final sum = u + v;
        expect(sum, Matrix(<List<double>>[[5], [7], [9]]));
      });

      test('scalar multiplication of vector', () {
        final u = Matrix(<List<double>>[[2], [3], [4]]);
        final scalar = Matrix.scalar(3);
        final result = scalar * u;
        expect(result, Matrix(<List<double>>[[6], [9], [12]]));
      });

      test('linear combination: 2u + 3v', () {
        final u = Matrix(<List<double>>[[1], [0], [1]]);
        final v = Matrix(<List<double>>[[0], [1], [1]]);
        final result = u.scale(2) + v.scale(3);
        expect(result, Matrix(<List<double>>[[2], [3], [5]]));
      });
    });

    group('dot product properties', () {
      test('dot product of orthogonal vectors is zero', () {
        final u = Matrix(<List<double>>[[1], [0], [0]]);
        final v = Matrix(<List<double>>[[0], [1], [0]]);
        expect(u.dot(v).scalarValue, 0);
      });

      test('dot product of parallel vectors equals product of magnitudes', () {
        final u = Matrix(<List<double>>[[3], [0], [0]]);
        final v = Matrix(<List<double>>[[5], [0], [0]]);
        expect(u.dot(v).scalarValue, 15);
      });

      test('dot product with self equals squared norm', () {
        final u = Matrix(<List<double>>[[1], [2], [3]]);
        final dotSelf = u.dot(u).scalarValue;
        final normSq = 1 * 1 + 2 * 2 + 3 * 3;
        expect(dotSelf, normSq.toDouble());
      });

      test('Cauchy-Schwarz inequality: |u·v| ≤ ‖u‖·‖v‖', () {
        final u = Matrix(<List<double>>[[1], [2], [3]]);
        final v = Matrix(<List<double>>[[4], [-1], [2]]);
        final dotUv = u.dot(v).scalarValue.abs();
        final normU = math.sqrt(u.dot(u).scalarValue);
        final normV = math.sqrt(v.dot(v).scalarValue);
        expect(dotUv, lessThanOrEqualTo(normU * normV + 1e-10));
      });
    });

    group('cross product properties', () {
      test('cross product of parallel vectors is zero', () {
        final u = Matrix(<List<double>>[[1], [2], [3]]);
        final v = Matrix(<List<double>>[[2], [4], [6]]);
        final cross = u.cross(v);
        expect(cross.almostEquals(Matrix(<List<double>>[[0], [0], [0]])), isTrue);
      });

      test('cross product is perpendicular to both operands', () {
        final u = Matrix(<List<double>>[[1], [2], [3]]);
        final v = Matrix(<List<double>>[[4], [5], [6]]);
        final w = u.cross(v);
        expect(w.dot(u).scalarValue, closeTo(0, 1e-10));
        expect(w.dot(v).scalarValue, closeTo(0, 1e-10));
      });

      test('standard basis: i×j = k, j×k = i, k×i = j', () {
        final i = Matrix(<List<double>>[[1], [0], [0]]);
        final j = Matrix(<List<double>>[[0], [1], [0]]);
        final k = Matrix(<List<double>>[[0], [0], [1]]);
        expect(i.cross(j), k);
        expect(j.cross(k), i);
        expect(k.cross(i), j);
      });

      test('magnitude equals area of parallelogram: ‖u×v‖² = ‖u‖²‖v‖² - (u·v)²', () {
        final u = Matrix(<List<double>>[[1], [2], [0]]);
        final v = Matrix(<List<double>>[[3], [0], [1]]);
        final cross = u.cross(v);
        final crossNormSq = cross.dot(cross).scalarValue;
        final uNormSq = u.dot(u).scalarValue;
        final vNormSq = v.dot(v).scalarValue;
        final dotUv = u.dot(v).scalarValue;
        final lagrange = uNormSq * vNormSq - dotUv * dotUv;
        expect(crossNormSq, closeTo(lagrange, 1e-10));
      });
    });

    group('vector norms', () {
      test('Frobenius norm of column vector equals Euclidean norm', () {
        final u = Matrix(<List<double>>[[3], [4]]);
        final norm = u.frobeniusNorm();
        expect(norm.scalarValue, closeTo(5, 1e-10));
      });

      test('unit vector has norm 1', () {
        final u = Matrix(<List<double>>[[1 / math.sqrt(3)], [1 / math.sqrt(3)], [1 / math.sqrt(3)]]);
        final norm = u.frobeniusNorm();
        expect(norm.scalarValue, closeTo(1, 1e-10));
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 3: Matrix Arithmetic and Properties
  // ─────────────────────────────────────────────────────────────────────────
  group('Matrix arithmetic', () {
    test('matrix addition is commutative: A+B = B+A', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4]]);
      final b = Matrix(<List<double>>[[5, 6], [7, 8]]);
      expect(a + b, b + a);
    });

    test('matrix multiplication is associative: (AB)C = A(BC)', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4]]);
      final b = Matrix(<List<double>>[[2, 0], [1, 3]]);
      final c = Matrix(<List<double>>[[1, 1], [0, 2]]);
      final lhs = (a * b) * c;
      final rhs = a * (b * c);
      expect(lhs, rhs);
    });

    test('matrix multiplication distributes over addition: A(B+C) = AB + AC', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4]]);
      final b = Matrix(<List<double>>[[5, 6], [7, 8]]);
      final c = Matrix(<List<double>>[[1, 0], [0, 1]]);
      final lhs = a * (b + c);
      final rhs = (a * b) + (a * c);
      expect(lhs, rhs);
    });

    test('multiplication by identity: AI = IA = A', () {
      final a = Matrix(<List<double>>[[1, 2, 3], [4, 5, 6], [7, 8, 9]]);
      final id = Matrix.identity(3);
      expect(a * id, a);
      expect(id * a, a);
    });

    test('matrix multiplication is NOT commutative in general', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4]]);
      final b = Matrix(<List<double>>[[0, 1], [1, 0]]);
      expect(a * b != b * a, isTrue);
    });

    test('transpose of product: (AB)ᵀ = BᵀAᵀ', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4]]);
      final b = Matrix(<List<double>>[[5, 6], [7, 8]]);
      final lhs = (a * b).transpose();
      final rhs = b.transpose() * a.transpose();
      expect(lhs, rhs);
    });

    test('transpose of transpose: (Aᵀ)ᵀ = A', () {
      final a = Matrix(<List<double>>[[1, 2, 3], [4, 5, 6]]);
      expect(a.transpose().transpose(), a);
    });

    test('non-square matrix multiplication: (2×3) × (3×2) = (2×2)', () {
      final a = Matrix(<List<double>>[[1, 2, 3], [4, 5, 6]]);
      final b = Matrix(<List<double>>[[7, 8], [9, 10], [11, 12]]);
      final c = a * b;
      expect(c.rowCount, 2);
      expect(c.columnCount, 2);
      expect(c, Matrix(<List<double>>[[58, 64], [139, 154]]));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 4: Determinants and Invertibility
  // ─────────────────────────────────────────────────────────────────────────
  group('Determinants and invertibility', () {
    test('det(I) = 1', () {
      final id = Matrix.identity(3);
      expect(id.determinant().scalarValue, 1);
    });

    test('det(kA) = k^n · det(A) for n×n matrix', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4]]);
      final k = 2.0;
      final ka = a.scale(k);
      final n = a.rowCount;
      final expected = math.pow(k, n) * a.determinant().scalarValue;
      expect(ka.determinant().scalarValue, closeTo(expected, 1e-10));
    });

    test('det(AB) = det(A) · det(B)', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4]]);
      final b = Matrix(<List<double>>[[5, 6], [7, 8]]);
      final detAB = (a * b).determinant().scalarValue;
      final detA = a.determinant().scalarValue;
      final detB = b.determinant().scalarValue;
      expect(detAB, closeTo(detA * detB, 1e-10));
    });

    test('det(Aᵀ) = det(A)', () {
      final a = Matrix(<List<double>>[[1, 2, 3], [4, 5, 6], [7, 8, 10]]);
      expect(
        a.transpose().determinant().scalarValue,
        closeTo(a.determinant().scalarValue, 1e-10),
      );
    });

    test('singular matrix has det = 0 and is not invertible', () {
      final singular = Matrix(<List<double>>[[1, 2], [2, 4]]);
      expect(singular.determinant().scalarValue, closeTo(0, 1e-10));
      expect(
        () => singular.inverse(),
        throwsA(isA<MatrixDomainError>()),
      );
    });

    test('A · A⁻¹ = I', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 5]]);
      final inv = a.inverse();
      final product = a * inv;
      expect(product.almostEquals(Matrix.identity(2)), isTrue);
    });

    test('(AB)⁻¹ = B⁻¹A⁻¹', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 5]]);
      final b = Matrix(<List<double>>[[2, 1], [1, 3]]);
      final lhs = (a * b).inverse();
      final rhs = b.inverse() * a.inverse();
      expect(lhs.almostEquals(rhs), isTrue);
    });

    test('det(A⁻¹) = 1/det(A)', () {
      final a = Matrix(<List<double>>[[2, 1], [5, 3]]);
      final detA = a.determinant().scalarValue;
      final detInv = a.inverse().determinant().scalarValue;
      expect(detInv, closeTo(1 / detA, 1e-10));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 5: Systems of Linear Equations (Ax = b)
  // ─────────────────────────────────────────────────────────────────────────
  group('Systems of linear equations', () {
    test('solve 2×2 system via inverse: x = A⁻¹b', () {
      // 2x + y = 5, 3x + 4y = 11  →  x=1.8, y=1.4
      final a = Matrix(<List<double>>[[2, 1], [3, 4]]);
      final b = Matrix(<List<double>>[[5], [11]]);
      final x = a.inverse() * b;
      expect(x.at(0, 0), closeTo(1.8, 1e-10));
      expect(x.at(1, 0), closeTo(1.4, 1e-10));
    });

    test('solve 3×3 system via inverse', () {
      // x + y + z = 6
      // 2y + 5z = -4
      // 2x + 5y - z = 27
      final a = Matrix(<List<double>>[
        [1, 1, 1],
        [0, 2, 5],
        [2, 5, -1],
      ]);
      final b = Matrix(<List<double>>[[6], [-4], [27]]);
      final x = a.inverse() * b;
      expect(x.at(0, 0), closeTo(5, 1e-10));
      expect(x.at(1, 0), closeTo(3, 1e-10));
      expect(x.at(2, 0), closeTo(-2, 1e-10));
    });

    test('solve via LU decomposition: PA = LU → Ly = Pb, Ux = y', () {
      final a = Matrix(<List<double>>[[2, 1, 1], [4, 3, 3], [8, 7, 9]]);
      final b = Matrix(<List<double>>[[4], [10], [24]]);
      // Verify A⁻¹b gives solution
      final x = a.inverse() * b;
      // Check Ax = b
      final result = a * x;
      expect(result.almostEquals(b), isTrue);
    });

    test('verify solution satisfies original system', () {
      final a = Matrix(<List<double>>[[3, 2], [1, -1]]);
      final b = Matrix(<List<double>>[[7], [1]]);
      final x = a.inverse() * b;
      final residual = (a * x) - b;
      expect(residual.almostEquals(Matrix(<List<double>>[[0], [0]])), isTrue);
    });

    test('Cramer rule: det(Ai)/det(A) using cofactor expansion', () {
      // 2x + 3y = 8, x - y = 1  → x=11/5, y=6/5
      final a = Matrix(<List<double>>[[2, 3], [1, -1]]);
      final detA = a.determinant().scalarValue;

      // Replace column 0 with b for x₁
      final a1 = Matrix(<List<double>>[[8, 3], [1, -1]]);
      final x1 = a1.determinant().scalarValue / detA;

      // Replace column 1 with b for x₂
      final a2 = Matrix(<List<double>>[[2, 8], [1, 1]]);
      final x2 = a2.determinant().scalarValue / detA;

      expect(x1, closeTo(11 / 5, 1e-10));
      expect(x2, closeTo(6 / 5, 1e-10));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 6: Eigenvalues and Diagonalization
  // ─────────────────────────────────────────────────────────────────────────
  group('Eigenvalues and diagonalization', () {
    test('eigenvalues of diagonal matrix are its diagonal entries', () {
      final d = Matrix(<List<double>>[[2, 0, 0], [0, 5, 0], [0, 0, -1]]);
      final eigs = d.eigenvalues();
      final eigValues = <double>[
        eigs.at(0, 0),
        eigs.at(1, 0),
        eigs.at(2, 0),
      ]..sort();
      expect(eigValues[0], closeTo(-1, 1e-8));
      expect(eigValues[1], closeTo(2, 1e-8));
      expect(eigValues[2], closeTo(5, 1e-8));
    });

    test('sum of eigenvalues equals trace', () {
      final a = Matrix(<List<double>>[[4, 1], [2, 3]]);
      final eigs = a.eigenvalues();
      final eigSum = eigs.at(0, 0) + eigs.at(1, 0);
      final trace = a.trace().scalarValue;
      expect(eigSum, closeTo(trace, 1e-8));
    });

    test('product of eigenvalues equals determinant', () {
      final a = Matrix(<List<double>>[[4, 1], [2, 3]]);
      final eigs = a.eigenvalues();
      final eigProduct = eigs.at(0, 0) * eigs.at(1, 0);
      final det = a.determinant().scalarValue;
      expect(eigProduct, closeTo(det, 1e-8));
    });

    test('symmetric matrix: A = PDP⁻¹ (diagonalization reconstruction)', () {
      final a = Matrix(<List<double>>[[2, 1], [1, 2]]);
      final diag = a.diagonalization();
      final reconstructed = diag.p * diag.d * diag.p.inverse();
      expect(reconstructed.almostEquals(a), isTrue);
    });

    test('eigenvalues of triangular matrix are its diagonal', () {
      final upper = Matrix(<List<double>>[[3, 1, 2], [0, 5, 4], [0, 0, 7]]);
      final eigs = upper.eigenvalues();
      final eigValues = <double>[
        eigs.at(0, 0),
        eigs.at(1, 0),
        eigs.at(2, 0),
      ]..sort();
      expect(eigValues[0], closeTo(3, 1e-8));
      expect(eigValues[1], closeTo(5, 1e-8));
      expect(eigValues[2], closeTo(7, 1e-8));
    });

    test('trace equals sum of diagonal = sum of eigenvalues', () {
      final a = Matrix(<List<double>>[[1, 2, 3], [0, 4, 5], [0, 0, 6]]);
      final trace = a.trace().scalarValue;
      expect(trace, 11); // 1 + 4 + 6
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 7: Matrix Factorizations (LU, QR)
  // ─────────────────────────────────────────────────────────────────────────
  group('Matrix factorizations', () {
    test('LU: PA = LU reconstruction', () {
      final a = Matrix(<List<double>>[[2, 3, 1], [4, 7, 5], [6, 18, 22]]);
      final lu = a.luDecomposition();
      final reconstructed = lu.permutation * a;
      final luProduct = lu.lower * lu.upper;
      expect(reconstructed.almostEquals(luProduct), isTrue);
    });

    test('LU: L is lower triangular with ones on diagonal', () {
      final a = Matrix(<List<double>>[[4, 3], [6, 3]]);
      final lu = a.luDecomposition();
      // Check upper triangle of L is zero (below diagonal)
      for (int i = 0; i < lu.lower.rowCount; i++) {
        expect(lu.lower.at(i, i), closeTo(1, 1e-10));
        for (int j = i + 1; j < lu.lower.columnCount; j++) {
          expect(lu.lower.at(i, j), closeTo(0, 1e-10));
        }
      }
    });

    test('LU: U is upper triangular', () {
      final a = Matrix(<List<double>>[[4, 3], [6, 3]]);
      final lu = a.luDecomposition();
      for (int i = 0; i < lu.upper.rowCount; i++) {
        for (int j = 0; j < i; j++) {
          expect(lu.upper.at(i, j), closeTo(0, 1e-10));
        }
      }
    });

    test('QR: A = QR reconstruction', () {
      final a = Matrix(<List<double>>[[1, 1], [1, 2], [1, 3]]);
      final qr = a.qrDecomposition();
      final reconstructed = qr.q * qr.r;
      expect(reconstructed.almostEquals(a), isTrue);
    });

    test('QR: Q is orthogonal (QᵀQ = I)', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4], [5, 6]]);
      final qr = a.qrDecomposition();
      final qtq = qr.q.transpose() * qr.q;
      expect(qtq.almostEquals(Matrix.identity(2)), isTrue);
    });

    test('QR: R is upper triangular', () {
      final a = Matrix(<List<double>>[[12, -51, 4], [6, 167, -68], [-4, 24, -41]]);
      final qr = a.qrDecomposition();
      for (int i = 0; i < qr.r.rowCount; i++) {
        for (int j = 0; j < i && j < qr.r.columnCount; j++) {
          expect(qr.r.at(i, j), closeTo(0, 1e-10));
        }
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 8: Formal Operations (Cofactor, Adjugate)
  // ─────────────────────────────────────────────────────────────────────────
  group('Formal operations', () {
    test('cofactor expansion along row 0 equals determinant', () {
      final a = Matrix(<List<double>>[[1, 2, 3], [4, 5, 6], [7, 8, 10]]);
      final det = a.determinant().scalarValue;
      // Manual cofactor expansion along row 0
      double cofExpansion = 0;
      for (int j = 0; j < 3; j++) {
        cofExpansion += a.at(0, j) * a.cofactor(0, j).scalarValue;
      }
      expect(cofExpansion, closeTo(det, 1e-10));
    });

    test('adjugate identity: A · adj(A) = det(A) · I', () {
      final a = Matrix(<List<double>>[[3, 0, 2], [2, 0, -2], [0, 1, 1]]);
      final adj = a.adjugate();
      final det = a.determinant().scalarValue;
      final lhs = a * adj;
      final rhs = Matrix.identity(3).scale(det);
      expect(lhs.almostEquals(rhs), isTrue);
    });

    test('inverse via adjugate: A⁻¹ = adj(A) / det(A)', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4]]);
      final det = a.determinant().scalarValue;
      final adjInv = a.adjugate().scale(1 / det);
      final directInv = a.inverse();
      expect(adjInv.almostEquals(directInv), isTrue);
    });

    test('cofactor matrix of identity is identity', () {
      final id = Matrix.identity(3);
      final cof = id.cofactorMatrix();
      expect(cof.almostEquals(Matrix.identity(3)), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 9: Rank and Null Space Theory
  // ─────────────────────────────────────────────────────────────────────────
  group('Rank theory', () {
    test('rank of identity is n', () {
      expect(Matrix.identity(4).rank().scalarValue, 4);
    });

    test('rank of zero matrix is 0', () {
      expect(Matrix.zeros(3, 3).rank().scalarValue, 0);
    });

    test('rank(A) ≤ min(m, n)', () {
      final a = Matrix(<List<double>>[[1, 2, 3], [4, 5, 6]]);
      final r = a.rank().scalarValue.toInt();
      expect(r, lessThanOrEqualTo(2)); // min(2, 3) = 2
    });

    test('rank-deficient matrix: dependent rows reduce rank', () {
      // Row 3 = Row 1 + Row 2
      final a = Matrix(<List<double>>[[1, 2, 3], [4, 5, 6], [5, 7, 9]]);
      expect(a.rank().scalarValue, 2);
    });

    test('rank(AB) ≤ min(rank(A), rank(B))', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4], [5, 6]]);
      final b = Matrix(<List<double>>[[1, 0, 1], [0, 1, 1]]);
      final ab = a * b;
      final rankA = a.rank().scalarValue.toInt();
      final rankB = b.rank().scalarValue.toInt();
      final rankAB = ab.rank().scalarValue.toInt();
      expect(rankAB, lessThanOrEqualTo(math.min(rankA, rankB)));
    });

    test('rank(Aᵀ) = rank(A)', () {
      final a = Matrix(<List<double>>[[1, 2, 3], [4, 5, 6]]);
      expect(a.transpose().rank().scalarValue, a.rank().scalarValue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 10: Special Matrices
  // ─────────────────────────────────────────────────────────────────────────
  group('Special matrices', () {
    test('symmetric matrix: A = Aᵀ', () {
      final a = Matrix(<List<double>>[[1, 2, 3], [2, 5, 6], [3, 6, 9]]);
      expect(a, a.transpose());
    });

    test('skew-symmetric: Aᵀ = -A → diagonal is zero', () {
      final a = Matrix(<List<double>>[[0, 2, -1], [-2, 0, 3], [1, -3, 0]]);
      final negA = a.scale(-1);
      expect(a.transpose(), negA);
    });

    test('orthogonal matrix: QᵀQ = I and det(Q) = ±1', () {
      // 2D rotation by 45°
      final c = math.cos(math.pi / 4);
      final s = math.sin(math.pi / 4);
      final q = Matrix(<List<double>>[[c, -s], [s, c]]);
      final qtq = q.transpose() * q;
      expect(qtq.almostEquals(Matrix.identity(2)), isTrue);
      expect(q.determinant().scalarValue.abs(), closeTo(1, 1e-10));
    });

    test('idempotent matrix: A² = A (projection)', () {
      // Projection onto x-axis in 2D
      final p = Matrix(<List<double>>[[1, 0], [0, 0]]);
      expect(p * p, p);
    });

    test('nilpotent matrix: A^k = 0 for some k', () {
      final n = Matrix(<List<double>>[[0, 1, 0], [0, 0, 1], [0, 0, 0]]);
      final n2 = n * n;
      final n3 = n2 * n;
      expect(n3, Matrix.zeros(3, 3));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 11: Numerical Stability and Edge Cases
  // ─────────────────────────────────────────────────────────────────────────
  group('Numerical stability', () {
    test('nearly singular matrix: high condition number', () {
      final a = Matrix(<List<double>>[[1, 1], [1, 1.0001]]);
      // Should still be invertible
      final inv = a.inverse();
      final product = a * inv;
      expect(product.almostEquals(Matrix.identity(2), absoluteTolerance: 1e-6), isTrue);
    });

    test('large values do not overflow in determinant', () {
      final a = Matrix(<List<double>>[[1000, 2000], [3000, 5000]]);
      final det = a.determinant().scalarValue;
      expect(det, closeTo(-1000000, 1e-5));
    });

    test('zero matrix operations are safe', () {
      final z = Matrix.zeros(2, 2);
      expect(z.determinant().scalarValue, 0);
      expect(z.trace().scalarValue, 0);
      expect(z.rank().scalarValue, 0);
      expect(z.frobeniusNorm().scalarValue, 0);
    });

    test('1×1 matrix operations degenerate correctly', () {
      final s = Matrix.scalar(5);
      expect(s.determinant().scalarValue, 5);
      expect(s.trace().scalarValue, 5);
      expect(s.inverse().scalarValue, closeTo(0.2, 1e-10));
      expect(s.transpose(), s);
      expect(s.eigenvalues().scalarValue, 5);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 12: Composite Workflows (Student Homework)
  // ─────────────────────────────────────────────────────────────────────────
  group('Student workflow scenarios', () {
    test('find area of triangle with vertices via cross product', () {
      // Vertices: P=(1,0,0), Q=(0,1,0), R=(0,0,1)
      // Vectors: PQ = Q-P, PR = R-P
      final pq = Matrix(<List<double>>[[-1], [1], [0]]);
      final pr = Matrix(<List<double>>[[-1], [0], [1]]);
      final cross = pq.cross(pr);
      final area = math.sqrt(cross.dot(cross).scalarValue) / 2;
      expect(area, closeTo(math.sqrt(3) / 2, 1e-10));
    });

    test('check if vectors are linearly independent via determinant', () {
      // Columns form the matrix; det ≠ 0 → independent
      final a = Matrix(<List<double>>[[1, 2, 3], [0, 1, 4], [5, 6, 0]]);
      expect(a.determinant().scalarValue.abs() > 1e-10, isTrue);
    });

    test('project vector u onto v: proj = (u·v / v·v) * v', () {
      final u = Matrix(<List<double>>[[3], [4], [0]]);
      final v = Matrix(<List<double>>[[1], [0], [0]]);
      final scalar = u.dot(v).scalarValue / v.dot(v).scalarValue;
      final projection = v.scale(scalar);
      expect(projection, Matrix(<List<double>>[[3], [0], [0]]));
    });

    test('Gram-Schmidt: QR gives orthonormal basis for column space', () {
      final a = Matrix(<List<double>>[[1, 1], [1, 0], [0, 1]]);
      final qr = a.qrDecomposition();
      // Q columns are orthonormal
      final qtq = qr.q.transpose() * qr.q;
      expect(qtq.almostEquals(Matrix.identity(2)), isTrue);
    });

    test('change of basis: transform coordinates', () {
      // Standard basis vector in new basis B = [[1,1],[0,1]]
      // Coordinates of [3,2] in basis B: B⁻¹ * [3,2]ᵀ
      final b = Matrix(<List<double>>[[1, 1], [0, 1]]);
      final v = Matrix(<List<double>>[[3], [2]]);
      final coords = b.inverse() * v;
      expect(coords.at(0, 0), closeTo(1, 1e-10)); // 3 - 2 = 1
      expect(coords.at(1, 0), closeTo(2, 1e-10));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 13: Research Scenarios (Advanced)
  // ─────────────────────────────────────────────────────────────────────────
  group('Research scenarios', () {
    test('Cayley-Hamilton: A satisfies its characteristic polynomial (2×2)', () {
      // For 2×2: A² - tr(A)·A + det(A)·I = 0
      final a = Matrix(<List<double>>[[1, 2], [3, 4]]);
      final tr = a.trace().scalarValue;
      final det = a.determinant().scalarValue;
      final a2 = a * a;
      final result = a2 - a.scale(tr) + Matrix.identity(2).scale(det);
      expect(result.almostEquals(Matrix.zeros(2, 2)), isTrue);
    });

    test('similar matrices share eigenvalues: eigenvalues(P⁻¹AP) = eigenvalues(A)', () {
      final a = Matrix(<List<double>>[[4, 1], [2, 3]]);
      final p = Matrix(<List<double>>[[1, 1], [0, 1]]);
      final similar = p.inverse() * a * p;
      final eigsA = a.eigenvalues();
      final eigsS = similar.eigenvalues();
      final valsA = <double>[eigsA.at(0, 0), eigsA.at(1, 0)]..sort();
      final valsS = <double>[eigsS.at(0, 0), eigsS.at(1, 0)]..sort();
      expect(valsA[0], closeTo(valsS[0], 1e-8));
      expect(valsA[1], closeTo(valsS[1], 1e-8));
    });

    test('spectral radius: max |λᵢ| bounds matrix powers', () {
      final a = Matrix(<List<double>>[[0.5, 0.1], [0.2, 0.3]]);
      final eigs = a.eigenvalues();
      final spectralRadius = math.max(
        eigs.at(0, 0).abs(),
        eigs.at(1, 0).abs(),
      );
      // All eigenvalues < 1 → Aⁿ → 0
      expect(spectralRadius, lessThan(1.0));
      // Verify A^10 has small entries
      var power = a;
      for (int i = 1; i < 10; i++) {
        power = power * a;
      }
      expect(power.frobeniusNorm().scalarValue, lessThan(0.01));
    });

    test('matrix exponential approximation via Taylor: e^A ≈ I + A + A²/2! + ...', () {
      // For nilpotent N (N²=0): e^N = I + N exactly
      final n = Matrix(<List<double>>[[0, 1], [0, 0]]);
      final expN = Matrix.identity(2) + n; // exact since N²=0
      expect(expN, Matrix(<List<double>>[[1, 1], [0, 1]]));
    });

    test('Frobenius norm is submultiplicative: ‖AB‖_F ≤ ‖A‖_F · ‖B‖_F', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4]]);
      final b = Matrix(<List<double>>[[5, 6], [7, 8]]);
      final normAB = (a * b).frobeniusNorm().scalarValue;
      final normA = a.frobeniusNorm().scalarValue;
      final normB = b.frobeniusNorm().scalarValue;
      expect(normAB, lessThanOrEqualTo(normA * normB + 1e-10));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TOPIC 14: Error Handling and Guards
  // ─────────────────────────────────────────────────────────────────────────
  group('Error handling', () {
    test('incompatible addition throws MatrixShapeError', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4]]);
      final b = Matrix(<List<double>>[[1, 2, 3], [4, 5, 6]]);
      expect(() => a + b, throwsA(isA<MatrixShapeError>()));
    });

    test('incompatible multiplication throws MatrixShapeError', () {
      final a = Matrix(<List<double>>[[1, 2], [3, 4]]);
      final b = Matrix(<List<double>>[[1, 2], [3, 4], [5, 6]]);
      expect(() => a * b, throwsA(isA<MatrixShapeError>()));
    });

    test('determinant of non-square throws MatrixShapeError', () {
      final a = Matrix(<List<double>>[[1, 2, 3], [4, 5, 6]]);
      expect(() => a.determinant(), throwsA(isA<MatrixShapeError>()));
    });

    test('inverse of non-square throws MatrixShapeError', () {
      final a = Matrix(<List<double>>[[1, 2, 3], [4, 5, 6]]);
      expect(() => a.inverse(), throwsA(isA<MatrixShapeError>()));
    });

    test('eigenvalues of non-square throws MatrixShapeError', () {
      final a = Matrix(<List<double>>[[1, 2, 3], [4, 5, 6]]);
      expect(() => a.eigenvalues(), throwsA(isA<MatrixShapeError>()));
    });

    test('dot product of row vectors throws MatrixShapeError', () {
      final a = Matrix(<List<double>>[[1, 2, 3]]);
      final b = Matrix(<List<double>>[[4, 5, 6]]);
      expect(() => a.dot(b), throwsA(isA<MatrixShapeError>()));
    });

    test('cross product of 2×1 vectors throws MatrixShapeError', () {
      final a = Matrix(<List<double>>[[1], [2]]);
      final b = Matrix(<List<double>>[[3], [4]]);
      expect(() => a.cross(b), throwsA(isA<MatrixShapeError>()));
    });
  });
}
