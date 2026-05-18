import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Matrix construction', () {
    test('creates scalar matrix', () {
      final Matrix scalar = Matrix.scalar(2);

      expect(scalar.isScalar, isTrue);
      expect(scalar.scalarValue, 2);
      expect(scalar.rowCount, 1);
      expect(scalar.columnCount, 1);
    });

    test('creates zero and one matrices with explicit shape', () {
      expect(
        Matrix.zeros(2, 3),
        Matrix(<List<double>>[
          <double>[0, 0, 0],
          <double>[0, 0, 0],
        ]),
      );

      expect(
        Matrix.ones(2, 2),
        Matrix(<List<double>>[
          <double>[1, 1],
          <double>[1, 1],
        ]),
      );
    });

    test('creates identity matrix', () {
      expect(
        Matrix.identity(3),
        Matrix(<List<double>>[
          <double>[1, 0, 0],
          <double>[0, 1, 0],
          <double>[0, 0, 1],
        ]),
      );
    });

    test('throws for empty matrix', () {
      expect(() => Matrix(<List<double>>[]), throwsA(isA<MatrixShapeError>()));
    });

    test('throws for ragged matrix', () {
      expect(
        () => Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3],
        ]),
        throwsA(isA<MatrixShapeError>()),
      );
    });

    test('throws for invalid explicit constructor shapes', () {
      expect(() => Matrix.zeros(0, 1), throwsA(isA<MatrixShapeError>()));
      expect(() => Matrix.ones(1, 0), throwsA(isA<MatrixShapeError>()));
      expect(() => Matrix.identity(0), throwsA(isA<MatrixShapeError>()));
    });
  });

  group('Matrix operations', () {
    test('adds matrices with same dimensions', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);
      final Matrix b = Matrix(<List<double>>[
        <double>[5, 6],
        <double>[7, 8],
      ]);

      expect(
        a + b,
        Matrix(<List<double>>[
          <double>[6, 8],
          <double>[10, 12],
        ]),
      );
    });

    test('multiplies matrix by scalar represented as 1x1 matrix', () {
      final Matrix matrix = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);

      expect(
        matrix * Matrix.scalar(3),
        Matrix(<List<double>>[
          <double>[3, 6],
          <double>[9, 12],
        ]),
      );

      expect(
        Matrix.scalar(3) * matrix,
        Matrix(<List<double>>[
          <double>[3, 6],
          <double>[9, 12],
        ]),
      );
    });

    test('throws typed shape error when adding incompatible matrices', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[1, 2],
      ]);
      final Matrix b = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);

      expect(() => a + b, throwsA(isA<MatrixShapeError>()));
    });

    test('multiplies two compatible matrices', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[1, 2, 3],
        <double>[4, 5, 6],
      ]);
      final Matrix b = Matrix(<List<double>>[
        <double>[7, 8],
        <double>[9, 10],
        <double>[11, 12],
      ]);

      expect(
        a * b,
        Matrix(<List<double>>[
          <double>[58, 64],
          <double>[139, 154],
        ]),
      );
    });

    test('rejects division by a non-scalar matrix denominator', () {
      final Matrix left = Matrix(<List<double>>[
        <double>[3, 1],
        <double>[7, 3],
      ]);
      final Matrix right = Matrix(<List<double>>[
        <double>[2, 1],
        <double>[1, 1],
      ]);

      expect(
        () => left / right,
        throwsA(isA<UnsupportedCalculatrixOperationError>()),
      );
    });

    test('computes the principal square root of a square matrix', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[5, 4],
        <double>[4, 5],
      ]);

      expect(
        value.sqrt().almostEquals(
          Matrix(<List<double>>[
            <double>[2, 1],
            <double>[1, 2],
          ]),
        ),
        isTrue,
      );
    });

    test('transposes non-square matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 2, 3],
        <double>[4, 5, 6],
      ]);

      expect(
        value.transpose(),
        Matrix(<List<double>>[
          <double>[1, 4],
          <double>[2, 5],
          <double>[3, 6],
        ]),
      );
    });

    test('inverts supported square matrices through the public API', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[4, 7],
        <double>[2, 6],
      ]);

      expect(
        value.inverse().almostEquals(
          Matrix(<List<double>>[
            <double>[0.6, -0.7],
            <double>[-0.2, 0.4],
          ]),
        ),
        isTrue,
      );
    });

    test('computes determinant as a scalar matrix through the public API', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[4, 7],
        <double>[2, 6],
      ]);

      expect(value.determinant(), Matrix.scalar(10));
    });

    test('rejects determinant for non-square matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 2, 3],
        <double>[4, 5, 6],
      ]);

      expect(() => value.determinant(), throwsA(isA<MatrixShapeError>()));
    });

    test('computes real eigenvalues for 2x2 matrices as a column matrix', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[2, 0],
        <double>[0, 3],
      ]);

      expect(
        value.eigenvalues(),
        Matrix(<List<double>>[
          <double>[3],
          <double>[2],
        ]),
      );
    });

    test('rejects eigenvalues for non-square matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 2, 3],
        <double>[4, 5, 6],
      ]);

      expect(() => value.eigenvalues(), throwsA(isA<MatrixShapeError>()));
    });

    test('computes real eigenvalues for 3x3 diagonal matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[5, 0, 0],
        <double>[0, 3, 0],
        <double>[0, 0, 1],
      ]);

      expect(
        value.eigenvalues(),
        Matrix(<List<double>>[
          <double>[5],
          <double>[3],
          <double>[1],
        ]),
      );
    });

    test('computes real eigenvalues for 3x3 symmetric matrices', () {
      // Eigenvalues of [[2,1,0],[1,3,1],[0,1,2]] are 4, 2, 1
      final Matrix value = Matrix(<List<double>>[
        <double>[2, 1, 0],
        <double>[1, 3, 1],
        <double>[0, 1, 2],
      ]);

      final Matrix result = value.eigenvalues();
      expect(result.rowCount, 3);
      expect(result.columnCount, 1);
      expect(result.at(0, 0), closeTo(4, 1e-9));
      expect(result.at(1, 0), closeTo(2, 1e-9));
      expect(result.at(2, 0), closeTo(1, 1e-9));
    });

    test('computes real eigenvalues for 4x4 diagonal matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[10, 0, 0, 0],
        <double>[0, 7, 0, 0],
        <double>[0, 0, 3, 0],
        <double>[0, 0, 0, 1],
      ]);

      expect(
        value.eigenvalues(),
        Matrix(<List<double>>[
          <double>[10],
          <double>[7],
          <double>[3],
          <double>[1],
        ]),
      );
    });

    test('computes real eigenvalues for 3x3 general non-symmetric matrices', () {
      // A = [[1,2,0],[0,3,0],[2,-4,2]], eigenvalues are 3, 2, 1
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 2, 0],
        <double>[0, 3, 0],
        <double>[2, -4, 2],
      ]);

      final Matrix result = value.eigenvalues();
      expect(result.rowCount, 3);
      expect(result.columnCount, 1);
      expect(result.at(0, 0), closeTo(3, 1e-9));
      expect(result.at(1, 0), closeTo(2, 1e-9));
      expect(result.at(2, 0), closeTo(1, 1e-9));
    });

    test('computes real eigenvalues for 4x4 symmetric matrices', () {
      // Symmetric: A = [[4,1,0,0],[1,3,1,0],[0,1,2,1],[0,0,1,1]]
      // Known eigenvalues (approximately): 4.7321, 3.0, 1.2679, 1.0
      final Matrix value = Matrix(<List<double>>[
        <double>[4, 1, 0, 0],
        <double>[1, 3, 1, 0],
        <double>[0, 1, 2, 1],
        <double>[0, 0, 1, 1],
      ]);

      final Matrix result = value.eigenvalues();
      expect(result.rowCount, 4);
      expect(result.columnCount, 1);
      // Verify descending order and known sum (trace = 10)
      final double sum = result.at(0, 0) + result.at(1, 0) +
          result.at(2, 0) + result.at(3, 0);
      expect(sum, closeTo(10, 1e-9));
      // Verify descending order
      expect(result.at(0, 0), greaterThan(result.at(1, 0)));
      expect(result.at(1, 0), greaterThan(result.at(2, 0)));
      expect(result.at(2, 0), greaterThan(result.at(3, 0)));
    });

    test('computes repeated eigenvalues correctly', () {
      // Identity 3x3 has eigenvalue 1 with multiplicity 3
      final Matrix value = Matrix.identity(3);

      final Matrix result = value.eigenvalues();
      expect(result.rowCount, 3);
      expect(result.columnCount, 1);
      expect(result.at(0, 0), closeTo(1, 1e-9));
      expect(result.at(1, 0), closeTo(1, 1e-9));
      expect(result.at(2, 0), closeTo(1, 1e-9));
    });

    test('rejects eigenvalues when NxN spectrum is complex', () {
      // 3x3 rotation-like matrix with complex eigenvalues
      final Matrix value = Matrix(<List<double>>[
        <double>[0, -1, 0],
        <double>[1, 0, 0],
        <double>[0, 0, 1],
      ]);

      expect(() => value.eigenvalues(), throwsA(isA<MatrixDomainError>()));
    });

    test('rejects eigenvalues when the 2x2 spectrum is complex', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[0, -1],
        <double>[1, 0],
      ]);

      expect(() => value.eigenvalues(), throwsA(isA<MatrixDomainError>()));
    });

    test('computes eigenvectors for 2x2 diagonal matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[3, 0],
        <double>[0, 5],
      ]);

      final Diagonalization result = value.diagonalization();
      // D should contain eigenvalues on diagonal (sorted descending)
      expect(result.d.at(0, 0), closeTo(5, 1e-9));
      expect(result.d.at(1, 1), closeTo(3, 1e-9));
      expect(result.d.at(0, 1), closeTo(0, 1e-9));
      expect(result.d.at(1, 0), closeTo(0, 1e-9));
      // P columns are eigenvectors: A*P ≈ P*D
      final Matrix ap = value * result.p;
      final Matrix pd = result.p * result.d;
      for (int r = 0; r < 2; r++) {
        for (int c = 0; c < 2; c++) {
          expect(ap.at(r, c), closeTo(pd.at(r, c), 1e-9));
        }
      }
    });

    test('computes eigenvectors for 3x3 diagonal matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[5, 0, 0],
        <double>[0, 3, 0],
        <double>[0, 0, 1],
      ]);

      final Diagonalization result = value.diagonalization();
      expect(result.d.at(0, 0), closeTo(5, 1e-9));
      expect(result.d.at(1, 1), closeTo(3, 1e-9));
      expect(result.d.at(2, 2), closeTo(1, 1e-9));
      // Verify A*P = P*D
      final Matrix ap = value * result.p;
      final Matrix pd = result.p * result.d;
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          expect(ap.at(r, c), closeTo(pd.at(r, c), 1e-9));
        }
      }
    });

    test('computes eigenvectors for 3x3 symmetric matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[2, 1, 0],
        <double>[1, 3, 1],
        <double>[0, 1, 2],
      ]);

      final Diagonalization result = value.diagonalization();
      // Eigenvalues are 4, 2, 1 (descending)
      expect(result.d.at(0, 0), closeTo(4, 1e-9));
      expect(result.d.at(1, 1), closeTo(2, 1e-9));
      expect(result.d.at(2, 2), closeTo(1, 1e-9));
      // Verify A*P = P*D
      final Matrix ap = value * result.p;
      final Matrix pd = result.p * result.d;
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          expect(ap.at(r, c), closeTo(pd.at(r, c), 1e-9));
        }
      }
    });

    test('computes eigenvectors for 2x2 non-diagonal matrices', () {
      // A = [[2, 1], [0, 3]], eigenvalues 3, 2
      final Matrix value = Matrix(<List<double>>[
        <double>[2, 1],
        <double>[0, 3],
      ]);

      final Diagonalization result = value.diagonalization();
      expect(result.d.at(0, 0), closeTo(3, 1e-9));
      expect(result.d.at(1, 1), closeTo(2, 1e-9));
      // Verify A*P = P*D
      final Matrix ap = value * result.p;
      final Matrix pd = result.p * result.d;
      for (int r = 0; r < 2; r++) {
        for (int c = 0; c < 2; c++) {
          expect(ap.at(r, c), closeTo(pd.at(r, c), 1e-9));
        }
      }
    });

    test('rejects diagonalization for non-square matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 2, 3],
        <double>[4, 5, 6],
      ]);

      expect(
        () => value.diagonalization(),
        throwsA(isA<MatrixShapeError>()),
      );
    });

    test('rejects diagonalization when spectrum is complex', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[0, -1],
        <double>[1, 0],
      ]);

      expect(
        () => value.diagonalization(),
        throwsA(isA<MatrixDomainError>()),
      );
    });

    test('computes PLU decomposition for square matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[2, 1, 1],
        <double>[4, -6, 0],
        <double>[-2, 7, 2],
      ]);

      final LuDecomposition decomposition = value.luDecomposition();

      expect(
        (decomposition.permutation * value).almostEquals(
          decomposition.lower * decomposition.upper,
        ),
        isTrue,
      );
      expect(decomposition.lower.at(0, 0), 1);
      expect(decomposition.lower.at(1, 1), 1);
      expect(decomposition.lower.at(2, 2), 1);
    });

    test('rejects LU decomposition for non-square matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 2, 3],
        <double>[4, 5, 6],
      ]);

      expect(() => value.luDecomposition(), throwsA(isA<MatrixShapeError>()));
    });

    test('LU decomposition pivots when the leading entry is zero', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[0, 2],
        <double>[3, 4],
      ]);

      final LuDecomposition decomposition = value.luDecomposition();

      expect(
        (decomposition.permutation * value).almostEquals(
          decomposition.lower * decomposition.upper,
        ),
        isTrue,
      );
      expect(
        decomposition.permutation,
        Matrix(<List<double>>[
          <double>[0, 1],
          <double>[1, 0],
        ]),
      );
    });

    test('LU decomposition preserves reconstruction for singular matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[2, 4],
      ]);

      final LuDecomposition decomposition = value.luDecomposition();

      expect(
        (decomposition.permutation * value).almostEquals(
          decomposition.lower * decomposition.upper,
        ),
        isTrue,
      );
      expect(decomposition.upper.at(1, 1), 0);
    });

    test('computes QR decomposition for full-rank matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 1, 0],
        <double>[1, 0, 1],
        <double>[0, 1, 1],
      ]);

      final QrDecomposition decomposition = value.qrDecomposition();

      expect((decomposition.q * decomposition.r).almostEquals(value), isTrue);
      expect(
        (decomposition.q.transpose() * decomposition.q).almostEquals(
          Matrix.identity(3),
        ),
        isTrue,
      );
    });

    test('computes QR decomposition for tall full-rank matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 0],
        <double>[0, 2],
        <double>[0, 0],
      ]);

      final QrDecomposition decomposition = value.qrDecomposition();

      expect((decomposition.q * decomposition.r).almostEquals(value), isTrue);
      expect(
        (decomposition.q.transpose() * decomposition.q).almostEquals(
          Matrix.identity(2),
        ),
        isTrue,
      );
    });

    test('QR decomposition preserves reconstruction for dependent columns', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[2, 4],
        <double>[3, 6],
      ]);

      final QrDecomposition decomposition = value.qrDecomposition();

      expect((decomposition.q * decomposition.r).almostEquals(value), isTrue);
      expect(decomposition.r.at(1, 1), 0);
    });

    test('rejects QR decomposition for wide matrices', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 2, 3],
        <double>[4, 5, 6],
      ]);

      expect(() => value.qrDecomposition(), throwsA(isA<MatrixShapeError>()));
    });

    test('appends compatible row and column operands', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);

      expect(
        base.appendRow(Matrix(<List<double>>[<double>[5, 6]])),
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
          <double>[5, 6],
        ]),
      );

      expect(
        base.appendColumn(Matrix(<List<double>>[
          <double>[5],
          <double>[6],
        ])),
        Matrix(<List<double>>[
          <double>[1, 2, 5],
          <double>[3, 4, 6],
        ]),
      );
    });

    test('deletes duplicates and moves rows immutably', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
        <double>[5, 6],
      ]);

      expect(
        base.deleteRow(1),
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[5, 6],
        ]),
      );

      expect(
        base.duplicateRow(1),
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
          <double>[3, 4],
          <double>[5, 6],
        ]),
      );

      expect(
        base.moveRow(0, 2),
        Matrix(<List<double>>[
          <double>[3, 4],
          <double>[5, 6],
          <double>[1, 2],
        ]),
      );
    });

    test('deletes duplicates and moves columns immutably', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2, 3],
        <double>[4, 5, 6],
      ]);

      expect(
        base.deleteColumn(1),
        Matrix(<List<double>>[
          <double>[1, 3],
          <double>[4, 6],
        ]),
      );

      expect(
        base.duplicateColumn(1),
        Matrix(<List<double>>[
          <double>[1, 2, 2, 3],
          <double>[4, 5, 5, 6],
        ]),
      );

      expect(
        base.moveColumn(2, 0),
        Matrix(<List<double>>[
          <double>[3, 1, 2],
          <double>[6, 4, 5],
        ]),
      );
    });

    test('throws typed structural errors for invalid shapes and indices', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);

      expect(
        () => base.appendRow(
          Matrix(<List<double>>[
            <double>[5],
            <double>[6],
          ]),
        ),
        throwsA(isA<MatrixShapeError>()),
      );
      expect(
        () => base.appendColumn(Matrix(<List<double>>[<double>[5, 6]])),
        throwsA(isA<MatrixShapeError>()),
      );
      expect(() => base.deleteRow(2), throwsA(isA<MatrixIndexError>()));
      expect(() => base.deleteColumn(2), throwsA(isA<MatrixIndexError>()));
      expect(
        () => Matrix(<List<double>>[<double>[1, 2]]).deleteRow(0),
        throwsA(isA<MatrixShapeError>()),
      );
      expect(
        () => Matrix(<List<double>>[
          <double>[1],
          <double>[2],
        ]).deleteColumn(0),
        throwsA(isA<MatrixShapeError>()),
      );
    });
  });

  group('Numeric policy', () {
    test('exact equality remains strict for floating-point values', () {
      expect(Matrix.scalar(0.1 + 0.2) == Matrix.scalar(0.3), isFalse);
    });

    test('almostEquals accepts values within default tolerance', () {
      final Matrix a = Matrix.scalar(0.1 + 0.2);
      final Matrix b = Matrix.scalar(0.3);

      expect(a.almostEquals(b), isTrue);
    });

    test('almostEquals rejects values outside tolerance', () {
      final Matrix a = Matrix.scalar(1.0);
      final Matrix b = Matrix.scalar(1.01);

      expect(a.almostEquals(b), isFalse);
    });

    test('almostEquals works for non-square matrices', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[1.0, 2.0],
        <double>[3.0, 4.000000000001],
      ]);
      final Matrix b = Matrix(<List<double>>[
        <double>[1.0, 2.0],
        <double>[3.0, 4.0],
      ]);

      expect(a.almostEquals(b), isTrue);
    });

    test('almostEquals returns false for mismatched shapes', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[1.0],
      ]);
      final Matrix b = Matrix(<List<double>>[
        <double>[1.0, 2.0],
      ]);

      expect(a.almostEquals(b), isFalse);
    });

    test('numeric policy exposes default tolerances', () {
      expect(CalculatrixNumericPolicy.defaultRelativeTolerance, greaterThan(0));
      expect(CalculatrixNumericPolicy.defaultAbsoluteTolerance, greaterThan(0));
    });
  });
}
