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
        () => matrix * Matrix.scalar(3),
        throwsA(isA<MatrixShapeError>()),
      );

      expect(
        matrix.scale(3),
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

      expect(
        () => a + b,
        throwsA(isA<MatrixShapeError>()),
      );
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
  });
}
