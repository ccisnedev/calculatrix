import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Matrix.i — imaginary unit properties', () {
    final Matrix i = Matrix.i;
    final Matrix identity = Matrix.identity(2);
    final Matrix negIdentity = Matrix(<List<double>>[
      <double>[-1, 0],
      <double>[0, -1],
    ]);
    final Matrix negI = i.scale(-1);

    test('i is 2×2', () {
      expect(i.rowCount, 2);
      expect(i.columnCount, 2);
    });

    test('i equals [[0, -1], [1, 0]] (standard convention)', () {
      expect(
        i,
        Matrix(<List<double>>[
          <double>[0, -1],
          <double>[1, 0],
        ]),
      );
    });

    test('i² = -I (fundamental property)', () {
      expect(i * i, negIdentity);
    });

    test('i³ = -i', () {
      expect(i * i * i, negI);
    });

    test('i⁴ = I (periodicity)', () {
      expect(i * i * i * i, identity);
    });

    test('i⁸ = I (double period)', () {
      final i4 = i * i * i * i;
      expect(i4 * i4, identity);
    });

    test('det(i) = 1 (unit norm)', () {
      expect(i.determinant(), Matrix.scalar(1));
    });

    test('i⁻¹ = -i (multiplicative inverse)', () {
      expect(i.inverse(), negI);
    });

    test('iᵀ = -i (transpose equals negation)', () {
      expect(i.transpose(), negI);
    });

    test('i + (-i) = zero matrix', () {
      expect(i + negI, Matrix.zeros(2, 2));
    });

    test('complex multiplication: (2I + 3i)(4I + 5i) = -7I + 22i', () {
      // (2 + 3i)(4 + 5i) = 8 + 10i + 12i + 15i² = 8 + 22i - 15 = -7 + 22i
      final a = identity.scale(2) + i.scale(3);
      final b = identity.scale(4) + i.scale(5);
      final expected = identity.scale(-7) + i.scale(22);
      expect(a * b, expected);
    });

    test('complex multiplication is commutative', () {
      final a = identity.scale(3) + i.scale(7);
      final b = identity.scale(-2) + i.scale(4);
      expect(a * b, b * a);
    });

    test('complex conjugate via transpose: (aI + bJ)ᵀ = aI - bJ', () {
      final z = identity.scale(3) + i.scale(5);
      final conjugate = identity.scale(3) - i.scale(5);
      expect(z.transpose(), conjugate);
    });

    test('|z|² = z · z* = (a² + b²)I', () {
      // z = 3I + 4i => |z|² = 9 + 16 = 25
      final z = identity.scale(3) + i.scale(4);
      final zStar = z.transpose();
      final normSquared = z * zStar;
      expect(normSquared, identity.scale(25));
    });

    test('complex division: z / z = I', () {
      final z = identity.scale(3) + i.scale(4);
      expect(z * z.inverse(), identity);
    });

    test('Euler-like identity: i² + I = zero matrix', () {
      expect((i * i) + identity, Matrix.zeros(2, 2));
    });

    test('distributivity: i(a + b) = ia + ib', () {
      final a = identity.scale(2) + i.scale(3);
      final b = identity.scale(-1) + i.scale(7);
      expect(i * (a + b), (i * a) + (i * b));
    });

    test('eigenvalues of i are ±i (trace=0, det=1)', () {
      expect(i.trace(), Matrix.scalar(0));
      expect(i.determinant(), Matrix.scalar(1));
    });

    test('aI + bJ has form [[a, -b], [b, a]]', () {
      final z = identity.scale(3) + i.scale(5);
      expect(
        z,
        Matrix(<List<double>>[
          <double>[3, -5],
          <double>[5, 3],
        ]),
      );
    });

    test('det(aI + bJ) = a² + b² (squared modulus)', () {
      final z = identity.scale(3) + i.scale(4);
      expect(z.determinant(), Matrix.scalar(25));
    });
  });

  group('Matrix.complex — factory and recognition', () {
    test('Matrix.complex(a, b) produces [[a, -b], [b, a]]', () {
      expect(
        Matrix.complex(3, 5),
        Matrix(<List<double>>[
          <double>[3, -5],
          <double>[5, 3],
        ]),
      );
    });

    test('Matrix.complex(1, 0) is identity I₂', () {
      expect(Matrix.complex(1, 0), Matrix.identity(2));
    });

    test('Matrix.complex(0, 1) is Matrix.i', () {
      expect(Matrix.complex(0, 1), Matrix.i);
    });

    test('Matrix.complex(0, -1) is -Matrix.i', () {
      expect(Matrix.complex(0, -1), Matrix.i.scale(-1));
    });

    test('Matrix.complex(2, 3) * Matrix.complex(-1, 7) = Matrix.complex(-23, 11)', () {
      // (2+3i)(-1+7i) = -2+14i - 3i + 21i² = -2+11i - 21 = -23+11i
      expect(Matrix.complex(2, 3) * Matrix.complex(-1, 7), Matrix.complex(-23, 11));
    });

    test('isComplexForm is true for Matrix.complex(a, b)', () {
      expect(Matrix.complex(3, 5).isComplexForm, isTrue);
      expect(Matrix.complex(0, 0).isComplexForm, isTrue);
      expect(Matrix.complex(-2, 7).isComplexForm, isTrue);
    });

    test('isComplexForm is true for Matrix.i', () {
      expect(Matrix.i.isComplexForm, isTrue);
    });

    test('isComplexForm is true for identity I₂', () {
      expect(Matrix.identity(2).isComplexForm, isTrue);
    });

    test('isComplexForm is false for non-2×2 matrix', () {
      expect(Matrix.identity(3).isComplexForm, isFalse);
      expect(Matrix.scalar(5).isComplexForm, isFalse);
    });

    test('isComplexForm is false for generic 2×2 matrix', () {
      final m = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);
      expect(m.isComplexForm, isFalse);
    });

    test('realPart returns a from Matrix.complex(a, b)', () {
      expect(Matrix.complex(3, 5).realPart, 3.0);
      expect(Matrix.complex(-7, 0).realPart, -7.0);
    });

    test('imagPart returns b from Matrix.complex(a, b)', () {
      expect(Matrix.complex(3, 5).imagPart, 5.0);
      expect(Matrix.complex(0, -2).imagPart, -2.0);
    });

    test('realPart of Matrix.i is 0', () {
      expect(Matrix.i.realPart, 0.0);
    });

    test('imagPart of Matrix.i is 1', () {
      expect(Matrix.i.imagPart, 1.0);
    });

    test('realPart throws for non-complex-form matrix', () {
      expect(
        () => Matrix.identity(3).realPart,
        throwsA(isA<MatrixDomainError>()),
      );
    });

    test('imagPart throws for non-complex-form matrix', () {
      expect(
        () => Matrix.scalar(5).imagPart,
        throwsA(isA<MatrixDomainError>()),
      );
    });
  });
}
