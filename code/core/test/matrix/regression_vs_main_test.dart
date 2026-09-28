// Differential regression check against `origin/main` (PR #7,
// feat/core-power-and-error-ids): a corpus of 6440 deterministic matrices
// was evaluated against every public Matrix API present on both branches.
// Three distinct classes of regression (PR worse than main, main's own
// value verified against a Julia 1.12.7 bare stdlib (Base/LinearAlgebra
// only, no packages installed) reference) were found. Each is reproduced
// here with a minimal case pulled directly from the differential corpus.
//
// This is a straight port from commit 55c21da of the archived
// feat/core-power-and-error-ids branch. This minimal rebuild does not
// touch exp(), eigenvalues() or spectralNorm() at all, so these tests
// exercise main's untouched behavior directly; they are included here as
// the required regression guard from the issue #5 rebuild plan, not
// because this branch fixed any of these three regressions itself (they
// were PR #7 regressions against main, and main never had them).
import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Regression 1: exp() of an exactly-triangular matrix with a constant '
      'diagonal (lambda*I + nilpotent N) must use the exact finite-sum '
      'closed form exp(A) = e^lambda * (I + N + N^2/2! + ... ), not throw '
      'unsupported-matrix-function. Corpus id 5900 (jordan_block, n=3); '
      'main returns [[1,1,0.5],[0,1,1],[0,0,1]].', () {
    test('3x3 Jordan block with a tiny diagonal', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[5.834829942008954e-102, 1.0, 0.0],
        <double>[0.0, 5.834829942008954e-102, 1.0],
        <double>[0.0, 0.0, 5.834829942008954e-102],
      ]);

      final Matrix result = value.exp();

      expect(result.at(0, 0), closeTo(1.0, 1e-9));
      expect(result.at(0, 1), closeTo(1.0, 1e-9));
      expect(result.at(0, 2), closeTo(0.5, 1e-9));
      expect(result.at(1, 0), closeTo(0.0, 1e-9));
      expect(result.at(1, 1), closeTo(1.0, 1e-9));
      expect(result.at(1, 2), closeTo(1.0, 1e-9));
      expect(result.at(2, 0), closeTo(0.0, 1e-9));
      expect(result.at(2, 1), closeTo(0.0, 1e-9));
      expect(result.at(2, 2), closeTo(1.0, 1e-9));
    });
  });

  group('Regression 2: eigenvalues()/diagonalization() never route exactly '
      'symmetric input through the globally-convergent cyclic Jacobi path '
      '(only exp/log/sqrt/power internal dispatch does), always using the '
      'general Francis QR-on-Hessenberg algorithm regardless of symmetry, '
      'which can fail to converge or misclassify a real eigenvalue as '
      'complex on an ill-separated or extreme-dynamic-range symmetric '
      'spectrum. This also affects spectralNorm()/svd(), which build an '
      'exactly-symmetric A^T*A and call the same public eigenvalues()/ '
      'diagonalization() on it.', () {
    test('spectralNorm() on a Jordan-block-derived case (corpus id 5937, '
        'n=3) must not throw no-convergence; main returns 17731206141.17', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[-17731206141.16566, 1.0, 0.0],
        <double>[0.0, -17731206141.16566, 1.0],
        <double>[0.0, 0.0, -17731206141.16566],
      ]);

      final Matrix result = value.spectralNorm();

      expect(
        result.at(0, 0),
        closeTo(17731206141.16566, 17731206141.16566 * 1e-6),
      );
    });

    test('eigenvalues() on an exactly-symmetric 5x5 extreme-dynamic-range '
        'matrix (corpus id 4931) must not throw "undefined in the real '
        'domain"; main returns real eigenvalues '
        '[0, 0, 0, -5.419372890208981e79, -2.8324661847271987e103]', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[
          -2.8324661847271987e103,
          1.1633936529184828e46,
          -2.251518523195926e-36,
          -9.089242342269679e86,
          6.203955642914341e39,
        ],
        <double>[
          1.1633936529184828e46,
          -6.3668376636396e-61,
          -4.561075302313692e-105,
          -7.81957474880885e-77,
          -1.8895839848345216e-90,
        ],
        <double>[
          -2.251518523195926e-36,
          -4.561075302313692e-105,
          -5.419372890208981e79,
          1.370177163500177e-88,
          3.6664801732058995e-107,
        ],
        <double>[
          -9.089242342269679e86,
          -7.81957474880885e-77,
          1.370177163500177e-88,
          -5.66016793923999e-135,
          -4.237293357428657e-67,
        ],
        <double>[
          6.203955642914341e39,
          -1.8895839848345216e-90,
          3.6664801732058995e-107,
          -4.237293357428657e-67,
          0.0,
        ],
      ]);

      final Matrix result = value.eigenvalues();

      expect(result.rowCount, 5);
      // Sorted descending, matching every other eigenvalues() case.
      expect(
        result.at(3, 0),
        closeTo(-5.419372890208981e79, 5.419372890208981e79 * 1e-6),
      );
      expect(
        result.at(4, 0),
        closeTo(-2.8324661847271987e103, 2.8324661847271987e103 * 1e-6),
      );
    });
  });

  group('Regression 3: exp() has no operand-lower-bound concern (exp of a '
      'tiny eigenvalue is always representable, ~1), unlike log()/sqrt(). '
      "_general2x2Exp's operand-eigenvalue range guard wrongly rejects a "
      'near-zero eigenvalue with matrix-out-of-precision-range even though '
      "the RESULT-side check (_requireResultLogMagnitudeInRange) already "
      'and correctly guards representability on its own. Corpus id 1144 '
      '(random, n=2); main returns [[1, -2.713968953737917e-147], '
      '[1.0796716403716762e-81, 1]].', () {
    test('2x2 with a near-zero eigenvalue must not be rejected', () {
      final Matrix value = Matrix(<List<double>>[
        <double>[0.0, -2.713968953737917e-147],
        <double>[1.0796716403716762e-81, 4.4302627596520196e-26],
      ]);

      final Matrix result = value.exp();

      expect(result.at(0, 0), closeTo(1.0, 1e-9));
      expect(result.at(0, 1), closeTo(-2.713968953737917e-147, 1e-9));
      expect(result.at(1, 0), closeTo(1.0796716403716762e-81, 1e-9));
      expect(result.at(1, 1), closeTo(1.0, 1e-9));
    });
  });
}
