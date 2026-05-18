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
