import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Matrix.log', () {
    test('log of positive scalar is natural logarithm', () {
      final Matrix value = Matrix.scalar(math.e * math.e);
      final Matrix result = value.log();

      expect(result.isScalar, isTrue);
      expect(result.scalarValue, closeTo(2, 1e-10));
    });

    test('log of negative scalar returns complex principal value', () {
      final Matrix value = Matrix.scalar(-1);
      final Matrix result = value.log();

      expect(result.isComplexForm, isTrue);
      expect(result.realPart, closeTo(0, 1e-10));
      expect(result.imagPart, closeTo(math.pi, 1e-10));
    });

    test('log for complex-form matrix matches principal branch', () {
      final Matrix value = Matrix.complex(0, 1); // i
      final Matrix result = value.log();

      expect(result.isComplexForm, isTrue);
      expect(result.realPart, closeTo(0, 1e-10));
      expect(result.imagPart, closeTo(math.pi / 2, 1e-10));
    });

    test('log and exp are inverse on positive diagonal matrix', () {
      final Matrix diagonal = Matrix(<List<double>>[
        <double>[math.e, 0],
        <double>[0, math.e * math.e],
      ]);

      final Matrix roundTrip = diagonal.log().exp();
      expect(roundTrip.almostEquals(diagonal, absoluteTolerance: 1e-8), isTrue);
    });

    test('rejects log for non-square matrix', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 2, 3],
      ]);

      expect(() => value.log(), throwsA(isA<MatrixShapeError>()));
    });

    test('rejects log for scalar zero', () {
      expect(
        () => Matrix.scalar(0).log(),
        throwsA(isA<MatrixDomainError>()),
      );
    });
  });

  group('Matrix.svd', () {
    test('svd reconstructs square matrix', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[3, 1],
        <double>[0, 2],
      ]);

      final SvdDecomposition svd = value.svd();
      final Matrix reconstructed = svd.u * svd.s * svd.vT;

      expect(reconstructed.almostEquals(value, absoluteTolerance: 1e-8), isTrue);
    });

    test('svd reconstructs rectangular matrix', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[1, 0, 2],
        <double>[0, 1, 0],
      ]);

      final SvdDecomposition svd = value.svd();
      final Matrix reconstructed = svd.u * svd.s * svd.vT;

      expect(reconstructed.almostEquals(value, absoluteTolerance: 1e-8), isTrue);
      expect(svd.u.rowCount, value.rowCount);
      expect(svd.vT.columnCount, value.columnCount);
    });

    test('singular values are non-negative and sorted descending', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[2, 0],
        <double>[0, 1],
      ]);

      final SvdDecomposition svd = value.svd();
      final double sigma1 = svd.s.at(0, 0);
      final double sigma2 = svd.s.at(1, 1);

      expect(sigma1, greaterThanOrEqualTo(0));
      expect(sigma2, greaterThanOrEqualTo(0));
      expect(sigma1, greaterThanOrEqualTo(sigma2));
    });

    test('svd of zero matrix yields zero singular values', () {
      final Matrix value = Matrix.zeros(2, 3);

      final SvdDecomposition svd = value.svd();
      final Matrix reconstructed = svd.u * svd.s * svd.vT;

      expect(reconstructed.almostEquals(value, absoluteTolerance: 1e-10), isTrue);
      expect(svd.s.at(0, 0), closeTo(0, 1e-10));
      expect(svd.s.at(1, 1), closeTo(0, 1e-10));
    });
  });
}
