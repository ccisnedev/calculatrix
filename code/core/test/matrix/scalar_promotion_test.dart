import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// Scalar promotion: when one operand of +/- is a 1×1 matrix (scalar)
/// and the other is n×n square (n > 1), the scalar k is promoted to k·Iₙ
/// before the operation. This enables natural complex arithmetic because
/// 3 + 2i = Matrix.scalar(3) + Matrix.scalar(2) * Matrix.i.
void main() {
  group('Scalar promotion — addition', () {
    test('scalar(k) + square(n×n) promotes k to k·Iₙ', () {
      // 3 + I₂ = 3·I₂ + I₂ = 4·I₂
      expect(
        Matrix.scalar(3) + Matrix.identity(2),
        Matrix.identity(2).scale(4),
      );
    });

    test('square(n×n) + scalar(k) promotes k to k·Iₙ (commutativity)', () {
      expect(
        Matrix.identity(2) + Matrix.scalar(3),
        Matrix.identity(2).scale(4),
      );
    });

    test('scalar(3) + Matrix.i = Matrix.complex(3, 1) = [[3,-1],[1,3]]', () {
      expect(
        Matrix.scalar(3) + Matrix.i,
        Matrix.complex(3, 1),
      );
    });

    test('Matrix.i + scalar(3) = Matrix.complex(3, 1)', () {
      expect(
        Matrix.i + Matrix.scalar(3),
        Matrix.complex(3, 1),
      );
    });

    test('scalar(0) + Matrix.i = Matrix.i', () {
      expect(Matrix.scalar(0) + Matrix.i, Matrix.i);
    });

    test('scalar(3) + Matrix.complex(2, 5) = Matrix.complex(5, 5)', () {
      expect(
        Matrix.scalar(3) + Matrix.complex(2, 5),
        Matrix.complex(5, 5),
      );
    });

    test('scalar(k) + identity(3×3) promotes to k·I₃ + I₃', () {
      expect(
        Matrix.scalar(2) + Matrix.identity(3),
        Matrix.identity(3).scale(3),
      );
    });

    test('scalar + non-square matrix still throws MatrixShapeError', () {
      final Matrix nonsquare = Matrix(<List<double>>[
        <double>[1, 2, 3],
        <double>[4, 5, 6],
      ]);
      expect(
        () => Matrix.scalar(1) + nonsquare,
        throwsA(isA<MatrixShapeError>()),
      );
    });

    test('mismatched non-scalar sizes still throw MatrixShapeError', () {
      expect(
        () => Matrix.identity(2) + Matrix.identity(3),
        throwsA(isA<MatrixShapeError>()),
      );
    });
  });

  group('Scalar promotion — subtraction', () {
    test('scalar(3) - Matrix.i = Matrix.complex(3, -1) = [[3,1],[-1,3]]', () {
      expect(
        Matrix.scalar(3) - Matrix.i,
        Matrix.complex(3, -1),
      );
    });

    test('Matrix.i - scalar(1) = Matrix.complex(-1, 1) = [[-1,-1],[1,-1]]', () {
      expect(
        Matrix.i - Matrix.scalar(1),
        Matrix.complex(-1, 1),
      );
    });

    test('scalar(5) - Matrix.identity(2) = 4·I₂', () {
      expect(
        Matrix.scalar(5) - Matrix.identity(2),
        Matrix.identity(2).scale(4),
      );
    });

    test('scalar - non-square matrix throws MatrixShapeError', () {
      final Matrix nonsquare = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
        <double>[5, 6],
      ]);
      expect(
        () => Matrix.scalar(1) - nonsquare,
        throwsA(isA<MatrixShapeError>()),
      );
    });
  });

  group('Scalar promotion — complex arithmetic end-to-end', () {
    test('(2 + 3i) + (4 + 5i) = 6 + 8i via scalar promotion', () {
      // Simulate: 2 + 3*i then 4 + 5*i then add
      final Matrix z1 = Matrix.scalar(2) + Matrix.scalar(3) * Matrix.i;
      final Matrix z2 = Matrix.scalar(4) + Matrix.scalar(5) * Matrix.i;
      expect(z1, Matrix.complex(2, 3));
      expect(z2, Matrix.complex(4, 5));
      expect(z1 + z2, Matrix.complex(6, 8));
    });

    test('(3 + 2i) * (1 + i) = 1 + 5i via matrix multiplication', () {
      final Matrix z1 = Matrix.complex(3, 2);
      final Matrix z2 = Matrix.complex(1, 1);
      expect(z1 * z2, Matrix.complex(1, 5));
    });

    test('scalar(2) + scalar(3)*i displays as complex form', () {
      final Matrix result = Matrix.scalar(2) + Matrix.scalar(3) * Matrix.i;
      expect(result.isComplexForm, isTrue);
      expect(result.realPart, 2.0);
      expect(result.imagPart, 3.0);
    });

    test('building 3+2i step by step: scalar(3) + scalar(2)*Matrix.i', () {
      final Matrix twoI = Matrix.scalar(2) * Matrix.i;
      final Matrix result = Matrix.scalar(3) + twoI;
      expect(result, Matrix.complex(3, 2));
    });
  });
}
