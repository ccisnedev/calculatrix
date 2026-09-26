// Round 7 correction (#5 continued): exp, log, sqrt and the real
// non-integer matrix power are restricted to five supported input classes
// (scalar, complex form a*I+b*J, diagonal, exact-equality symmetric via
// cyclic Jacobi (Golub & Van Loan 8.5) and general 2x2 via a stable
// divided-difference closed form (Higham, "Functions of Matrices" (2008),
// section 1.2)). Any other square input raises `unsupported-matrix-function`
// instead of falling back to a general iterative algorithm. Integer powers,
// `inverse()` and `eigenvalues()` are unaffected and keep working for every
// square matrix.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
// debugCyclicJacobiSqrtWithSweepBudget is a @visibleForTesting seam (round
// 9 correction, finding 5) hidden from the public calculatrix.dart barrel,
// so it is imported directly from its src path instead.
import 'package:calculatrix/src/matrix/matrix.dart' show debugCyclicJacobiSqrtWithSweepBudget;
import 'package:test/test.dart';

void main() {
  group('Round 7, diagonal class: entrywise, 1e-14 relative', () {
    test('exp of a diagonal matrix is entrywise exp within 1e-14 relative', () {
      final Matrix result = Matrix(<List<double>>[
        <double>[1, 0, 0],
        <double>[0, 2, 0],
        <double>[0, 0, 3],
      ]).exp();

      final List<double> expected = <double>[math.exp(1), math.exp(2), math.exp(3)];
      for (int i = 0; i < 3; i++) {
        expect(
          (result.at(i, i) - expected[i]).abs() / expected[i],
          lessThanOrEqualTo(1e-14),
        );
      }
      expect(result.at(0, 1), 0);
      expect(result.at(1, 2), 0);
    });

    test('log of a diagonal matrix is entrywise log within 1e-14 relative', () {
      final Matrix result = Matrix(<List<double>>[
        <double>[1, 0, 0],
        <double>[0, 2, 0],
        <double>[0, 0, 4],
      ]).log();

      expect(result.at(0, 0), 0);
      expect(
        (result.at(1, 1) - math.log(2)).abs() / math.log(2),
        lessThanOrEqualTo(1e-14),
      );
      expect(
        (result.at(2, 2) - math.log(4)).abs() / math.log(4),
        lessThanOrEqualTo(1e-14),
      );
    });

    test(
      'sqrt of a diagonal matrix is entrywise sqrt within 1e-14 relative',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[4, 0, 0],
          <double>[0, 9, 0],
          <double>[0, 0, 16],
        ]).sqrt();

        final List<double> expected = <double>[2, 3, 4];
        for (int i = 0; i < 3; i++) {
          expect(
            (result.at(i, i) - expected[i]).abs() / expected[i],
            lessThanOrEqualTo(1e-14),
          );
        }
      },
    );

    test(
      // Round 9 correction, finding 4: restores runbook D25 case 5 / issue
      // #5 amendment D34. power() must reject a zero eigenvalue with a
      // non-integer exponent as log-undefined, unlike sqrt() (which still
      // accepts 0^0.5 = 0 through this same diagonal class).
      'a diagonal zero entry with a positive power raises log-undefined',
      () {
        expect(
          () => Matrix(<List<double>>[
            <double>[0, 0],
            <double>[0, 9],
          ]).power(Matrix.scalar(0.5)),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.logUndefined,
            ),
          ),
        );
      },
    );
  });

  group(
    'Round 7, symmetric class (exact equality): cyclic Jacobi eigen'
    'decomposition (Golub & Van Loan 8.5), 1e-13 residual',
    () {
      test('[[2,1],[1,2]]^0.5 squares back to [[2,1],[1,2]] within 1e-13', () {
        final Matrix base = Matrix(<List<double>>[
          <double>[2, 1],
          <double>[1, 2],
        ]);

        final Matrix result = base.sqrt();
        final Matrix reconstructed = result * result;

        expect(
          reconstructed.almostEquals(
            base,
            relativeTolerance: 1e-13,
            absoluteTolerance: 0,
          ),
          isTrue,
          reason: 'result=$result, result*result=$reconstructed',
        );
      });

      test(
        'exp of a symmetric matrix matches the closed-form cosh/sinh '
        'result within 1e-13 relative',
        () {
          // [[0,1],[1,0]] has eigenpairs (1, (1,1)/sqrt2) and
          // (-1, (1,-1)/sqrt2), so exp(A) = [[cosh 1, sinh 1], [sinh 1,
          // cosh 1]] exactly.
          final Matrix result = Matrix(<List<double>>[
            <double>[0, 1],
            <double>[1, 0],
          ]).exp();

          final double coshOne = (math.exp(1) + math.exp(-1)) / 2;
          final double sinhOne = (math.exp(1) - math.exp(-1)) / 2;

          expect(
            (result.at(0, 0) - coshOne).abs() / coshOne,
            lessThanOrEqualTo(1e-13),
          );
          expect(
            (result.at(0, 1) - sinhOne).abs() / sinhOne,
            lessThanOrEqualTo(1e-13),
          );
          expect(
            (result.at(1, 0) - sinhOne).abs() / sinhOne,
            lessThanOrEqualTo(1e-13),
          );
          expect(
            (result.at(1, 1) - coshOne).abs() / coshOne,
            lessThanOrEqualTo(1e-13),
          );
        },
      );

      test(
        'log of a symmetric matrix matches the closed-form eigen '
        'reconstruction within 1e-13 relative',
        () {
          // [[2,1],[1,2]] has eigenpairs (3, (1,1)/sqrt2) and
          // (1, (1,-1)/sqrt2), so log(A) = (log 3 / 2) * [[1,1],[1,1]]
          // exactly (log 1 = 0 drops the second term).
          final Matrix result = Matrix(<List<double>>[
            <double>[2, 1],
            <double>[1, 2],
          ]).log();

          final double expected = math.log(3) / 2;

          expect(
            (result.at(0, 0) - expected).abs() / expected,
            lessThanOrEqualTo(1e-13),
          );
          expect(
            (result.at(0, 1) - expected).abs() / expected,
            lessThanOrEqualTo(1e-13),
          );
          expect(
            (result.at(1, 0) - expected).abs() / expected,
            lessThanOrEqualTo(1e-13),
          );
          expect(
            (result.at(1, 1) - expected).abs() / expected,
            lessThanOrEqualTo(1e-13),
          );
        },
      );

      test(
        // Round 9 correction, finding 4: restores runbook D25 case 5 /
        // issue #5 amendment D34. power() must reject a zero eigenvalue
        // with a non-integer exponent as log-undefined, unlike sqrt()
        // (which still accepts this exact matrix through this same
        // exactly-symmetric class: 0^0.5 = 0 carries through the eigen
        // decomposition for sqrt(), just not for power()).
        'a singular exactly-symmetric matrix with a zero eigenvalue and a '
        'positive power raises log-undefined',
        () {
          final Matrix base = Matrix(<List<double>>[
            <double>[1, 1],
            <double>[1, 1],
          ]);

          expect(
            () => base.power(Matrix.scalar(0.5)),
            throwsA(
              isA<MatrixDomainError>().having(
                (MatrixDomainError e) => e.errorId,
                'errorId',
                CalculatrixErrorId.logUndefined,
              ),
            ),
          );
        },
      );
    },
  );

  group(
    'Round 7, general 2x2: stable divided-difference closed form '
    '(Higham 2008, section 1.2)',
    () {
      test(
        '[[1,1],[0,1.000000000000001]].exp()[0][1] is about e (nearly '
        'repeated eigenvalues exercise the small-d series branch)',
        () {
          final Matrix result = Matrix(<List<double>>[
            <double>[1, 1],
            <double>[0, 1.000000000000001],
          ]).exp();

          expect(result.at(0, 1), closeTo(2.718281828459045, 1e-9));
        },
      );

      test(
        '[[3,1],[0,3.000000000000001]].log()[0][1] is about 1/3 (nearly '
        'repeated eigenvalues exercise the log1p divided-difference '
        'branch)',
        () {
          final Matrix result = Matrix(<List<double>>[
            <double>[3, 1],
            <double>[0, 3.000000000000001],
          ]).log();

          expect(result.at(0, 1), closeTo(1 / 3, 1e-9));
        },
      );

      test(
        '[[1001,-1000],[1000,-999]]^0.5 = [[501,-500],[500,-499]] within '
        '1e-13 relative (repeated positive eigenvalue with a nontrivial '
        'off-diagonal, analytic continuation via f-prime)',
        () {
          final Matrix result = Matrix(<List<double>>[
            <double>[1001, -1000],
            <double>[1000, -999],
          ]).power(Matrix.scalar(0.5));

          final Matrix expected = Matrix(<List<double>>[
            <double>[501, -500],
            <double>[500, -499],
          ]);

          expect(
            result.almostEquals(
              expected,
              relativeTolerance: 1e-13,
              absoluteTolerance: 0,
            ),
            isTrue,
            reason: 'result=$result',
          );
        },
      );

      test(
        '[[-1,2e-8],[-1e-8,-1]].log() exists (a genuine complex-conjugate '
        'pair extremely close to, but not on, the negative real axis)',
        () {
          final Matrix base = Matrix(<List<double>>[
            <double>[-1, 2e-8],
            <double>[-1e-8, -1],
          ]);

          expect(() => base.log(), returnsNormally);
        },
      );

      test(
        '[[-1e20,1],[0,-1e20]]^0.5 is log-undefined (a repeated negative '
        'eigenvalue with a genuine Jordan coupling has no real square '
        'root)',
        () {
          final Matrix base = Matrix(<List<double>>[
            <double>[-1e20, 1],
            <double>[0, -1e20],
          ]);

          expect(
            () => base.power(Matrix.scalar(0.5)),
            throwsA(
              isA<MatrixDomainError>().having(
                (MatrixDomainError e) => e.errorId,
                'errorId',
                CalculatrixErrorId.logUndefined,
              ),
            ),
          );
        },
      );
    },
  );

  group(
    'Round 7, outside the five supported classes: unsupported-matrix-'
    'function',
    () {
      final Matrix jordanBlock = Matrix(<List<double>>[
        <double>[1, 1, 0],
        <double>[0, 1, 1],
        <double>[0, 0, 1],
      ]);
      final Matrix nearlyTriangularWithHugeCoupling = Matrix(<List<double>>[
        <double>[1, 1e20, 0],
        <double>[0, 2, 1e20],
        <double>[0, 0, 3],
      ]);

      for (final MapEntry<String, Matrix> entry
          in <String, Matrix>{
            'a 3x3 Jordan block': jordanBlock,
            'a 3x3 upper-triangular matrix with huge off-diagonal coupling':
                nearlyTriangularWithHugeCoupling,
          }.entries) {
        group(entry.key, () {
          final Matrix base = entry.value;

          test('exp() is unsupported-matrix-function', () {
            expect(
              () => base.exp(),
              throwsA(
                isA<MatrixDomainError>().having(
                  (MatrixDomainError e) => e.errorId,
                  'errorId',
                  CalculatrixErrorId.unsupportedMatrixFunction,
                ),
              ),
            );
          });

          test('log() is unsupported-matrix-function', () {
            expect(
              () => base.log(),
              throwsA(
                isA<MatrixDomainError>().having(
                  (MatrixDomainError e) => e.errorId,
                  'errorId',
                  CalculatrixErrorId.unsupportedMatrixFunction,
                ),
              ),
            );
          });

          test('^0.5 (real non-integer power) is unsupported-matrix-function', () {
            expect(
              () => base.power(Matrix.scalar(0.5)),
              throwsA(
                isA<MatrixDomainError>().having(
                  (MatrixDomainError e) => e.errorId,
                  'errorId',
                  CalculatrixErrorId.unsupportedMatrixFunction,
                ),
              ),
            );
          });

          test('integer powers still work', () {
            final Matrix squared = base.power(Matrix.scalar(2));
            final Matrix expected = base * base;

            expect(squared.almostEquals(expected, absoluteTolerance: 0), isTrue);
          });
        });
      }
    },
  );

  group('Round 7, round 8 finding 11: sqrt() has no public maxSweeps '
      'parameter; Jacobi convergence is tested through the debug seam '
      'instead', () {
    test('a zero sweep budget on a symmetric matrix is no-convergence', () {
      expect(
        () => debugCyclicJacobiSqrtWithSweepBudget(
          Matrix(<List<double>>[
            <double>[2, 1],
            <double>[1, 2],
          ]),
          0,
        ),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.noConvergence,
          ),
        ),
      );
    });

    test('the default sweep budget converges for an ordinary symmetric input', () {
      final Matrix result = Matrix(<List<double>>[
        <double>[2, 1],
        <double>[1, 2],
      ]).sqrt();
      final Matrix reconstructed = result * result;

      expect(
        reconstructed.almostEquals(
          Matrix(<List<double>>[
            <double>[2, 1],
            <double>[1, 2],
          ]),
          relativeTolerance: 1e-13,
          absoluteTolerance: 0,
        ),
        isTrue,
      );
    });
  });
}
