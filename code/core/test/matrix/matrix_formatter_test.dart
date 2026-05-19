import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('MatrixDisplayFormatter', () {
    final Matrix matrix = Matrix(<List<double>>[
      <double>[1, 2],
      <double>[30, 400],
    ]);

    test('renders compact one-line matrix output', () {
      expect(
        MatrixDisplayFormatter.compact(matrix),
        '[[1, 2], [30, 400]]',
      );
    });

    test('renders expanded aligned matrix output', () {
      expect(
        MatrixDisplayFormatter.expanded(matrix),
        '[ 1   2]\n[30 400]',
      );
    });
  });

  group('MatrixDisplayFormatter.complex', () {
    test('2 + 3i', () {
      expect(MatrixDisplayFormatter.complex(Matrix.complex(2, 3)), '2 + 3i');
    });

    test('2 - 3i (negative imaginary)', () {
      expect(MatrixDisplayFormatter.complex(Matrix.complex(2, -3)), '2 - 3i');
    });

    test('pure imaginary: i', () {
      expect(MatrixDisplayFormatter.complex(Matrix.i), 'i');
    });

    test('pure imaginary: -i', () {
      expect(MatrixDisplayFormatter.complex(Matrix.complex(0, -1)), '-i');
    });

    test('pure imaginary: 3i', () {
      expect(MatrixDisplayFormatter.complex(Matrix.complex(0, 3)), '3i');
    });

    test('pure real: 5', () {
      expect(MatrixDisplayFormatter.complex(Matrix.complex(5, 0)), '5');
    });

    test('pure real: -7', () {
      expect(MatrixDisplayFormatter.complex(Matrix.complex(-7, 0)), '-7');
    });

    test('zero: 0', () {
      expect(MatrixDisplayFormatter.complex(Matrix.complex(0, 0)), '0');
    });

    test('identity is 1 (no imaginary part)', () {
      expect(MatrixDisplayFormatter.complex(Matrix.identity(2)), '1');
    });

    test('coefficient 1 rendered as i not 1i', () {
      expect(MatrixDisplayFormatter.complex(Matrix.complex(2, 1)), '2 + i');
    });

    test('coefficient -1 rendered as -i not -1i', () {
      expect(MatrixDisplayFormatter.complex(Matrix.complex(2, -1)), '2 - i');
    });

    test('decimal complex: 1.5 + 2.5i', () {
      expect(MatrixDisplayFormatter.complex(Matrix.complex(1.5, 2.5)), '1.5 + 2.5i');
    });
  });
}