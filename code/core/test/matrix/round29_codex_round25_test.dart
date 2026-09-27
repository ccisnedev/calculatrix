// Core PR #7 Codex round 25, two public eigenvalues() regressions found
// against origin/main, both inside the declared [1e-150, 1e150] magnitude
// range.
//
// 1. Hessenberg reduction (Matrix._hessenbergWithSchurVectors, near
//    matrix.dart:1354) silently deletes a significant sub-diagonal coupling.
//    [Matrix.eigenvalues] rescales the whole matrix first
//    ([Matrix._normalizedByPowerOfTwo]) so its infinity norm is O(1); a
//    genuinely nonzero Householder-vector entry can survive that rescale as
//    a perfectly representable double yet still square to something below
//    the smallest representable subnormal double. The naive
//    `sum += x[i] * x[i]` norm then underflows to exactly zero even though
//    the entry itself is nonzero, the code reads that false zero as "this
//    column has no sub-diagonal coupling to eliminate" and skips the
//    reflection outright, and the unconditional "structurally exact zero"
//    cleanup that runs after the whole loop still zeroes that entry,
//    discarding real data instead of eliminating it through an actual
//    transform. origin/main never normalizes the whole matrix before
//    Hessenberg reduction, so its own naive norm never underflows on this
//    fixture and it returns the correct spectrum.
//
// 2. The 2x2 real-eigenvalue solver (Matrix._stableRealEigen2x2, matrix.dart
//    :1855) classifies a discriminant as "zero" (a repeated real root)
//    whenever `|discriminant| <= eps * (trace^2 + |det|)`. `trace^2` is
//    dominated by the diagonal entries and has nothing to do with how
//    sensitive the discriminant itself is once `a` and `d` are both large
//    but nearly equal: `trace*trace - 4*det` then subtracts two quantities
//    of size `trace^2` to recover a discriminant many orders of magnitude
//    smaller, so the tolerance, scaled to that huge `trace^2`, swallows a
//    discriminant that is genuinely, unambiguously negative.
//    `[[1e5, 0.01], [-0.01, 1e5]]` has true eigenvalues `1e5 +/- 0.01i`, a
//    complex-conjugate pair the real-only [Matrix.eigenvalues] contract must
//    reject (as origin/main does), not silently collapse to a repeated real
//    `1e5`.
import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Codex round 25 (public eigenvalues() regressions vs origin/main)', () {
    test(
      'Hessenberg reduction preserves a coupling entry that would '
      'underflow to zero if squared directly after whole-matrix '
      'normalization: [[0,0,1e150],[0,2,0],[1.1e-12,0,0]] has eigenvalues '
      'approximately +/-1.0488088481701516e69 and 2, not [2, 0, 0]',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[0, 0, 1e150],
          <double>[0, 2, 0],
          <double>[1.1e-12, 0, 0],
        ]).eigenvalues();

        final List<double> values = <double>[
          result.at(0, 0),
          result.at(1, 0),
          result.at(2, 0),
        ]..sort((double a, double b) => b.compareTo(a));

        const double magnitude = 1.0488088481701516e69;
        expect(values[0], closeTo(magnitude, magnitude * 1e-9));
        expect(values[1], closeTo(2, 1e-6));
        expect(values[2], closeTo(-magnitude, magnitude * 1e-9));
      },
    );

    test(
      'a genuinely complex-conjugate 2x2 block, [[1e5, 0.01], [-0.01, 1e5]] '
      '(true eigenvalues 1e5 +/- 0.01i), throws instead of being reported '
      'as a repeated real 1e5: the trace-dominated tolerance must not hide '
      'this negative discriminant',
      () {
        final Matrix matrix = Matrix(<List<double>>[
          <double>[1e5, 0.01],
          <double>[-0.01, 1e5],
        ]);

        expect(
          () => matrix.eigenvalues(),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.message,
              'message',
              'Eigenvalues are undefined in the real domain for this '
                  'matrix.',
            ),
          ),
        );
      },
    );

    test(
      'a smaller-magnitude genuinely complex-conjugate 2x2 block, '
      '[[1e5, 1e-3], [-1e-3, 1e5]] (true eigenvalues 1e5 +/- 1e-3 i), also '
      'throws',
      () {
        final Matrix matrix = Matrix(<List<double>>[
          <double>[1e5, 1e-3],
          <double>[-1e-3, 1e5],
        ]);

        expect(
          () => matrix.eigenvalues(),
          throwsA(isA<MatrixDomainError>()),
        );
      },
    );

    test(
      'a true repeated real root, [[1e5,0],[0,1e5]], still reports two '
      'real eigenvalues equal to 1e5, not a spurious throw',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[1e5, 0],
          <double>[0, 1e5],
        ]).eigenvalues();

        expect(result.at(0, 0), closeTo(1e5, 1e-3));
        expect(result.at(1, 0), closeTo(1e5, 1e-3));
      },
    );

    test(
      'a real, near-repeated 2x2 block with a tiny POSITIVE discriminant, '
      '[[1e5,0.01],[0.01,1e5]] (true eigenvalues 100000.01 and 99999.99), '
      'reports two distinct real eigenvalues rather than throwing or '
      'collapsing them to one value',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[1e5, 0.01],
          <double>[0.01, 1e5],
        ]).eigenvalues();

        final List<double> values = <double>[
          result.at(0, 0),
          result.at(1, 0),
        ]..sort((double a, double b) => b.compareTo(a));

        expect(values[0], closeTo(100000.01, 1e-6));
        expect(values[1], closeTo(99999.99, 1e-6));
      },
    );
  });
}
