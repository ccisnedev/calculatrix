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
