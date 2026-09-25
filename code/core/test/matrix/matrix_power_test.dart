import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Matrix.power - table D25', () {
    test('row 1: scalar negative base, non-integer scalar exponent is complex', () {
      final Matrix result = Matrix.scalar(-4).power(Matrix.scalar(0.5));

      expect(result.isComplexForm, isTrue);
      expect(result.realPart, closeTo(0, 1e-4));
      expect(result.imagPart, closeTo(2, 1e-4));
    });

    test('row 2: scalar positive base, square matrix exponent', () {
      final Matrix y = Matrix.complex(0, math.pi); // pi*i
      final Matrix result = Matrix.scalar(math.e).power(y);

      expect(result.at(0, 0), closeTo(-1, 1e-4));
      expect(result.at(0, 1), closeTo(0, 1e-4));
      expect(result.at(1, 0), closeTo(0, 1e-4));
      expect(result.at(1, 1), closeTo(-1, 1e-4));
    });

    test('row 3: complex base, complex exponent', () {
      final Matrix result = Matrix.i.power(Matrix.i);
      final double expected = math.exp(-math.pi / 2);

      expect(result.at(0, 0), closeTo(expected, 1e-4));
      expect(result.at(0, 1), closeTo(0, 1e-4));
      expect(result.at(1, 0), closeTo(0, 1e-4));
      expect(result.at(1, 1), closeTo(expected, 1e-4));
    });

    test('row 4: square base, positive integer exponent via repeated multiplication', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 1],
        <double>[0, 1],
      ]);
      final Matrix result = base.power(Matrix.scalar(3));

      expect(
        result.almostEquals(
          Matrix(<List<double>>[
            <double>[1, 3],
            <double>[0, 1],
          ]),
        ),
        isTrue,
      );
    });

    test('row 4b: square base, negative integer exponent uses the inverse', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[2, 0],
        <double>[0, 4],
      ]);
      final Matrix result = base.power(Matrix.scalar(-1));

      expect(
        result.almostEquals(
          Matrix(<List<double>>[
            <double>[0.5, 0],
            <double>[0, 0.25],
          ]),
        ),
        isTrue,
      );
    });

    test('row 4c: negative integer exponent on a singular matrix is singular-matrix', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[2, 4],
      ]);

      expect(
        () => base.power(Matrix.scalar(-2)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.singularMatrix,
          ),
        ),
      );
    });

    test('row 5: square base, non-integer scalar exponent uses principal log', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[2, 0],
        <double>[0, 3],
      ]);
      final Matrix result = base.power(Matrix.scalar(0.5));

      expect(result.at(0, 0), closeTo(math.sqrt(2), 5e-5));
      expect(result.at(0, 1), closeTo(0, 5e-5));
      expect(result.at(1, 0), closeTo(0, 5e-5));
      expect(result.at(1, 1), closeTo(math.sqrt(3), 5e-5));
    });

    test(
      'row 5b (owner-added): defective square base, non-integer scalar exponent',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[1, 1],
          <double>[0, 1],
        ]);
        final Matrix result = base.power(Matrix.scalar(0.5));

        expect(
          result.almostEquals(
            Matrix(<List<double>>[
              <double>[1, 0.5],
              <double>[0, 1],
            ]),
            absoluteTolerance: 5e-5,
          ),
          isTrue,
        );
      },
    );

    test('row 6: square base and square exponent that do not commute is ambiguous-power', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 1],
        <double>[0, 1],
      ]);
      final Matrix y = Matrix(<List<double>>[
        <double>[0, 1],
        <double>[1, 0],
      ]);

      expect(
        () => base.power(y),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.ambiguousPower,
          ),
        ),
      );
    });

    test('row 7: zero base, positive scalar exponent is zero', () {
      final Matrix result = Matrix.scalar(0).power(Matrix.scalar(5));
      expect(result, Matrix.scalar(0));
    });

    test('row 7b: zero base, zero exponent is one', () {
      final Matrix result = Matrix.scalar(0).power(Matrix.scalar(0));
      expect(result, Matrix.scalar(1));
    });

    test('row 7c: zero base, negative exponent is non-finite', () {
      expect(
        () => Matrix.scalar(0).power(Matrix.scalar(-1)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.nonFinite,
          ),
        ),
      );
    });

    test('row 8: zero base with a matrix exponent needs log 0, which is undefined', () {
      final Matrix y = Matrix.complex(0, math.pi);

      expect(
        () => Matrix.scalar(0).power(y),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.logUndefined,
          ),
        ),
      );
    });

    test('row 9: non-square base is a dimension-mismatch', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
      ]);

      expect(
        () => base.power(Matrix.scalar(2)),
        throwsA(
          isA<MatrixShapeError>().having(
            (MatrixShapeError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });

    test('row 10: scalar base with a non-square exponent is a dimension-mismatch', () {
      final Matrix y = Matrix(<List<double>>[
        <double>[1, 2],
      ]);

      expect(
        () => Matrix.scalar(2).power(y),
        throwsA(
          isA<MatrixShapeError>().having(
            (MatrixShapeError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });

    test('row 11: square base and square exponent of different sizes is a dimension-mismatch', () {
      final Matrix base = Matrix.identity(2);
      final Matrix y = Matrix.identity(3);

      expect(
        () => base.power(y),
        throwsA(
          isA<MatrixShapeError>().having(
            (MatrixShapeError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });

    test('row 12: negative scalar base and a non-commuting square exponent is ambiguous-power', () {
      final Matrix y = Matrix(<List<double>>[
        <double>[1, 0],
        <double>[0, 2],
      ]);

      expect(
        () => Matrix.scalar(-2).power(y),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.ambiguousPower,
          ),
        ),
      );
    });

    test('row 13: scalar overflow is non-finite', () {
      expect(
        () => Matrix.scalar(10).power(Matrix.scalar(400)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError e) => e.errorId,
            'errorId',
            CalculatrixErrorId.nonFinite,
          ),
        ),
      );
    });
  });

  group('Matrix.power - owner decisions D34', () {
    test(
      'square non-scalar base with a non-square exponent is dimension-mismatch, for any base',
      () {
        final Matrix base = Matrix.identity(2);
        final Matrix y = Matrix(<List<double>>[
          <double>[1, 2],
        ]);

        expect(
          () => base.power(y),
          throwsA(
            isA<MatrixShapeError>().having(
              (MatrixShapeError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.dimensionMismatch,
            ),
          ),
        );
      },
    );

    test(
      'complex base with a square non-complex non-scalar exponent is ambiguous-power',
      () {
        final Matrix y = Matrix(<List<double>>[
          <double>[1, 0],
          <double>[0, 2],
        ]);

        expect(
          () => Matrix.i.power(y),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.ambiguousPower,
            ),
          ),
        );
      },
    );

    test(
      'non-complex-form base with a non-positive real eigenvalue and a non-integer exponent is log-undefined',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[-1, 0],
          <double>[0, 2],
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

    test(
      'non-complex-form base with a complex-conjugate eigenvalue pair and a '
      'non-integer exponent is well-defined',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[1, -2],
          <double>[0.5, 1],
        ]);

        final Matrix half = base.power(Matrix.scalar(0.5));
        final Matrix squared = half.power(Matrix.scalar(2));

        expect(squared.almostEquals(base, absoluteTolerance: 1e-9), isTrue);
      },
    );

    test(
      'non-complex-form base with a complex-conjugate eigenvalue pair and a '
      'non-positive real eigenvalue is log-undefined',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[0, -1, 0],
          <double>[1, 0, 0],
          <double>[0, 0, -2],
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
  });

  group('Matrix.power - numerical robustness (#5)', () {
    test(
      'a tiny non-integer exponent on a matrix with huge diagonal '
      'magnitudes stays near the identity',
      () {
        // log() must not overflow while scaling and squaring down from
        // 1e40-magnitude eigenvalues; the sqrt() scaling factor used
        // internally must be computed as a floating point power, not an
        // integer one that silently overflows.
        final Matrix base = Matrix(<List<double>>[
          <double>[1e40, 0],
          <double>[0, 2e40],
        ]);
        final Matrix result = base.power(Matrix.scalar(1e-18));

        expect(
          result.almostEquals(Matrix.identity(2), absoluteTolerance: 1e-9),
          isTrue,
        );
      },
    );

    test(
      'integer exponent that overflows the double range is non-finite',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[1e200, 0],
          <double>[0, 1e200],
        ]);

        expect(
          () => base.power(Matrix.scalar(2)),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.nonFinite,
            ),
          ),
        );
      },
    );

    test(
      'the minimum 64-bit integer exponent terminates quickly and is exact '
      '(exponentiation by squaring, not int abs/round on the exponent)',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[1, 1],
          <double>[0, 1],
        ]);
        final Matrix result = base.power(Matrix.scalar(-9223372036854775808));

        expect(
          result.almostEquals(
            Matrix(<List<double>>[
              <double>[1, -9223372036854775808.0],
              <double>[0, 1],
            ]),
          ),
          isTrue,
        );
      },
    );

    test(
      'a large but not overflowing positive integer exponent gives the '
      'exact finite result for a unipotent base',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[1, 1],
          <double>[0, 1],
        ]);
        final Matrix result = base.power(Matrix.scalar(1e30));

        expect(
          result.almostEquals(
            Matrix(<List<double>>[
              <double>[1, 1e30],
              <double>[0, 1],
            ]),
          ),
          isTrue,
        );
      },
    );
  });

  group('Matrix.power - cancellation-resistant eigenvalue gate (#5)', () {
    test(
      'a genuinely tiny positive real eigenvalue at O(1) matrix scale is '
      'not mistaken for non-positive rounding noise',
      () {
        // Diagonal, so the eigenvalues are exactly 1e-13 and 1: the
        // quadratic-formula solver must not let cancellation (or an
        // overly coarse near-zero floor borrowed from a general-purpose
        // tolerance) turn 1e-13 into 0 and then reject it as
        // non-positive.
        final Matrix base = Matrix(<List<double>>[
          <double>[1e-13, 0],
          <double>[0, 1],
        ]);
        final Matrix result = base.power(Matrix.scalar(0.5));

        expect(result.at(0, 0), closeTo(math.sqrt(1e-13), 1e-4 * 3.1623e-7));
        expect(result.at(0, 1), closeTo(0, 1e-15));
        expect(result.at(1, 0), closeTo(0, 1e-15));
        expect(result.at(1, 1), closeTo(1, 1e-9));
      },
    );

    test(
      'a small real eigenvalue next to a hugely larger one in the same '
      'matrix is recovered without catastrophic cancellation',
      () {
        // Eigenvalues 1 and 1e20: the naive (trace ± sqrt(disc)) / 2
        // formula subtracts two nearly-equal ~1e20 quantities to find
        // the smaller root and loses it entirely to rounding. The
        // stable quadratic formula (q, then det/q) must not.
        final Matrix base = Matrix(<List<double>>[
          <double>[1, 0],
          <double>[0, 1e20],
        ]);
        final Matrix result = base.power(Matrix.scalar(0.5));

        expect(result.at(0, 0), closeTo(1, 1e-6));
        expect(result.at(0, 1), closeTo(0, 1e-6));
        expect(result.at(1, 0), closeTo(0, 1e-6));
        expect(result.at(1, 1), closeTo(1e10, 1e4));
      },
    );

    test(
      'a genuine complex-conjugate eigenvalue pair at tiny magnitude is '
      'not misclassified as a repeated non-positive real eigenvalue',
      () {
        // Eigenvalues are exactly ±1e-8i (trace 0, det 1e-15): an
        // absolute-tolerance discriminant test (e.g. |disc| <= 1e-12)
        // would clamp this genuinely negative discriminant to 0 and
        // misreport a repeated real eigenvalue of 0, which would then
        // wrongly reject the log as undefined. The discriminant test
        // must be scaled to the block itself (trace^2 + |det|), not to
        // a fixed absolute floor.
        final Matrix base = Matrix(<List<double>>[
          <double>[0, -2e-8],
          <double>[0.5e-8, 0],
        ]);
        final Matrix result = base.power(Matrix.scalar(0.5));
        final Matrix roundTrip = result * result;

        // Two of base's four entries are exactly zero, so a fixed
        // Matrix.almostEquals(absoluteTolerance: ...) floor is the wrong
        // instrument here: any floor loose enough to tolerate the ~1e-8
        // scale's own rounding noise on those zero entries is, by
        // construction, many orders of magnitude looser than the
        // "relative to the matrix's own scale" check this test is meant
        // to enforce. Compare the worst-case entrywise absolute
        // deviation against the matrix's own scale instead, which is
        // exactly what "S*S = A to N relative" means for a matrix with
        // exact-zero entries.
        double scale = 0;
        double maxAbsoluteDeviation = 0;
        for (int r = 0; r < 2; r++) {
          for (int c = 0; c < 2; c++) {
            scale = math.max(scale, base.at(r, c).abs());
            maxAbsoluteDeviation = math.max(
              maxAbsoluteDeviation,
              (roundTrip.at(r, c) - base.at(r, c)).abs(),
            );
          }
        }

        expect(maxAbsoluteDeviation / scale, lessThan(1e-9));
      },
    );

    test(
      'a real negative eigenvalue keeps raising log-undefined',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[-1, 0],
          <double>[0, 4],
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

    test(
      'an exact zero real eigenvalue from a diagonal matrix keeps raising '
      'log-undefined',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[0, 0],
          <double>[0, 1],
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

    test(
      'an exact zero real eigenvalue from a singular non-diagonal matrix '
      'keeps raising log-undefined',
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
  });

  group(
    'Matrix.power - scale-relative eigenvalue classification (round 3 '
    'correction)',
    () {
      test(
        'two tiny diagonal entries that are equal-looking under an '
        'absolute tolerance but not under a scale-relative one succeed',
        () {
          // diag(1e-20, 2e-20): under the old fixed-absolute-tolerance
          // isComplexForm check (1e-12), these two entries looked equal
          // and the matrix was misclassified as complex form aI+bJ,
          // wrongly raising "zero magnitude" log-undefined. Scale-
          // relatively, 1e-20 and 2e-20 are not remotely equal.
          final Matrix base = Matrix(<List<double>>[
            <double>[1e-20, 0],
            <double>[0, 2e-20],
          ]);
          final Matrix result = base.power(Matrix.scalar(0.5));

          expect(result.at(0, 0), closeTo(math.sqrt(1e-20), 1e-4 * 1e-10));
          expect(result.at(1, 1), closeTo(math.sqrt(2e-20), 1e-4 * 1.4e-10));
        },
      );

      test(
        'a tiny-scale upper triangular (non-diagonal) matrix with equal '
        'diagonal entries succeeds, not misclassified as complex form',
        () {
          final Matrix base = Matrix(<List<double>>[
            <double>[1e-20, 1e-20],
            <double>[0, 1e-20],
          ]);
          final Matrix result = base.power(Matrix.scalar(0.5));
          final Matrix roundTrip = result * result;

          double maxAbsoluteDeviation = 0;
          for (int r = 0; r < 2; r++) {
            for (int c = 0; c < 2; c++) {
              maxAbsoluteDeviation = math.max(
                maxAbsoluteDeviation,
                (roundTrip.at(r, c) - base.at(r, c)).abs(),
              );
            }
          }
          expect(maxAbsoluteDeviation / 1e-20, lessThan(1e-6));
        },
      );

      test(
        'a genuinely positive diagonal entry far below the old fixed '
        'eigenvalue-rounding-noise floor still succeeds',
        () {
          // diag(4e-16, 1): 4e-16 is below the old fixed 1e-14
          // eigenvalueRoundingNoiseTolerance, but it is an exact
          // diagonal entry of a triangular matrix, not rounding noise.
          final Matrix base = Matrix(<List<double>>[
            <double>[4e-16, 0],
            <double>[0, 1],
          ]);
          final Matrix result = base.power(Matrix.scalar(0.5));

          expect(result.at(0, 0), closeTo(math.sqrt(4e-16), 1e-4 * 2e-8));
          expect(result.at(1, 1), closeTo(1, 1e-9));
        },
      );

      test(
        'a 3x3 diagonal matrix with one entry far below the old fixed '
        'eigenvalue-rounding-noise floor still succeeds',
        () {
          final Matrix base = Matrix(<List<double>>[
            <double>[2, 0, 0],
            <double>[0, 1e-18, 0],
            <double>[0, 0, 3],
          ]);
          final Matrix result = base.power(Matrix.scalar(0.5));

          expect(result.at(0, 0), closeTo(math.sqrt(2), 1e-6));
          expect(result.at(1, 1), closeTo(math.sqrt(1e-18), 1e-4 * 1e-9));
          expect(result.at(2, 2), closeTo(math.sqrt(3), 1e-6));
        },
      );

      test(
        'a symmetric positive definite matrix that is nearly singular '
        '(condition ~2.5e7) succeeds instead of raising no-convergence '
        'with a contradictory "is undefined" message',
        () {
          final Matrix base = Matrix(<List<double>>[
            <double>[1, 2],
            <double>[2, 4.000001],
          ]);
          final Matrix result = base.power(Matrix.scalar(0.5));
          final Matrix roundTrip = result * result;

          expect(
            roundTrip.almostEquals(base, relativeTolerance: 1e-6),
            isTrue,
          );
        },
      );

      test(
        'a tiny-scale negative diagonal entry keeps raising log-undefined',
        () {
          final Matrix base = Matrix(<List<double>>[
            <double>[-1e-20, 0],
            <double>[0, 1],
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

      test(
        'a block-triangular matrix with a negative real eigenvalue on the '
        'diagonal block keeps raising log-undefined',
        () {
          // Eigenvalues: -0.37 and 5.37 (from the [[1,2],[3,4]] block)
          // and 1 (from the trailing diagonal entry).
          final Matrix base = Matrix(<List<double>>[
            <double>[1, 2, 0],
            <double>[3, 4, 0],
            <double>[0, 0, 1],
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
}
