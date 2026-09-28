// Differential test for issue #13 (acceptance 4): for matrices with
// infinity norm up to 10, where the pre-fix Taylor series (capped at 50
// terms, no scaling) is already correct, the new scaling-and-squaring
// implementation must give the same result to 1e-12 relative.
//
// `_oldExp` below is a private, verbatim copy of Matrix.exp() as it stood
// on `main` before this fix (a plain Taylor series, no scaling, capped at
// 50 terms). It is kept only as a reference for this test; production code
// never calls it. The corpus is a deterministic set of random matrices
// (fixed seed, sizes 2 to 4, entries bounded so the infinity norm never
// exceeds 10), plus a complex-form matrix and a Jordan block, both also
// within that norm bound.

import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Matrix.exp - differential vs the pre-fix algorithm (issue #13, '
      'acceptance 4)', () {
    final List<Matrix> corpus = _buildCorpus();

    test(
      'corpus has matrices of size 2, 3 and 4, plus the two named forms',
      () {
        expect(corpus.length, greaterThanOrEqualTo(17));
        expect(corpus.any((Matrix m) => m.rowCount == 2), isTrue);
        expect(corpus.any((Matrix m) => m.rowCount == 3), isTrue);
        expect(corpus.any((Matrix m) => m.rowCount == 4), isTrue);
      },
    );

    test('every corpus matrix has infinity norm <= 10', () {
      for (final Matrix matrix in corpus) {
        expect(_infinityNormOf(matrix), lessThanOrEqualTo(10.0 + 1e-9));
      }
    });

    test('new exp() matches the old truncated-series algorithm to 1e-12 '
        'relative (infinity norm) on the whole corpus', () {
      for (int index = 0; index < corpus.length; index++) {
        final Matrix matrix = corpus[index];
        final Matrix expected = _oldExp(matrix);
        final Matrix actual = matrix.exp();

        final double relativeError = _relativeInfinityNormError(
          actual,
          expected,
        );
        expect(
          relativeError,
          lessThanOrEqualTo(1e-12),
          reason:
              'corpus[$index] (size ${matrix.rowCount}) differs: '
              'relative error $relativeError',
        );
      }
    });
  });
}

List<Matrix> _buildCorpus() {
  final List<Matrix> corpus = <Matrix>[];
  final math.Random random = math.Random(20260928);

  for (final int size in <int>[2, 3, 4]) {
    for (int sample = 0; sample < 5; sample++) {
      corpus.add(_randomMatrixWithBoundedNorm(random, size));
    }
  }

  // Complex-form matrix, infinity norm = |3| + |-4| = 7 <= 10.
  corpus.add(Matrix.complex(3, 4));

  // Jordan block (unscaled), infinity norm = 3 <= 10.
  corpus.add(
    Matrix(<List<double>>[
      <double>[2, 1, 0],
      <double>[0, 2, 1],
      <double>[0, 0, 2],
    ]),
  );

  return corpus;
}

// Entries bounded to +/- (10 / size) so every row sum of absolute values is
// at most size * (10 / size) = 10, guaranteeing infinity norm <= 10 without
// rejection sampling.
Matrix _randomMatrixWithBoundedNorm(math.Random random, int size) {
  final double bound = 10 / size;
  return Matrix(
    List<List<double>>.generate(
      size,
      (_) => List<double>.generate(
        size,
        (_) => (random.nextDouble() * 2 - 1) * bound,
      ),
    ),
  );
}

double _infinityNormOf(Matrix matrix) {
  double maxRowSum = 0;
  for (int row = 0; row < matrix.rowCount; row++) {
    double rowSum = 0;
    for (int column = 0; column < matrix.columnCount; column++) {
      rowSum += matrix.at(row, column).abs();
    }
    if (rowSum > maxRowSum) {
      maxRowSum = rowSum;
    }
  }
  return maxRowSum;
}

double _relativeInfinityNormError(Matrix actual, Matrix expected) {
  final Matrix difference = actual - expected;
  final double diffNorm = _infinityNormOf(difference);
  final double referenceNorm = _infinityNormOf(expected);
  if (referenceNorm == 0) {
    return diffNorm == 0 ? 0 : diffNorm;
  }
  return diffNorm / referenceNorm;
}

// Verbatim copy of Matrix.exp() as it stood on main before issue #13's fix:
// a Taylor series with no scaling, capped at 50 terms. Correct for the small
// norms this test restricts itself to; this is exactly what makes it a valid
// reference here.
Matrix _oldExp(Matrix matrix) {
  if (matrix.rowCount == 1 && matrix.columnCount == 1) {
    return Matrix.scalar(math.exp(matrix.scalarValue));
  }

  Matrix result = Matrix.identity(matrix.rowCount);
  Matrix term = Matrix.identity(matrix.rowCount);
  double factorial = 1;

  for (int n = 1; n <= 50; n++) {
    factorial *= n;
    term = term * matrix;
    result = result + term.scale(1 / factorial);

    if (_infinityNormOf(term) / factorial < 1e-12) {
      break;
    }
  }

  return result;
}
