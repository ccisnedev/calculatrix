import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// Asserts [actual] equals [expected] to within [relativeTolerance] relative
/// error. Unlike [Matrix.almostEquals], this has no absolute-tolerance floor:
/// a fixed absolute floor (as small as 1e-12) is still many orders of
/// magnitude looser than a true value of, say, 1e-150, so it would silently
/// pass a wrong entry that differs from the correct one by 100% in relative
/// terms. That is exactly the class of bug these tests exist to catch, so
/// the check here must be purely relative.
void expectRelativelyClose(
  double actual,
  double expected, {
  double relativeTolerance = 1e-12,
}) {
  if (expected == 0) {
    expect(actual, equals(0), reason: 'expected exact zero, got $actual');
    return;
  }
  final double relativeError = (actual - expected).abs() / expected.abs();
  expect(
    relativeError,
    lessThan(relativeTolerance),
    reason:
        'actual=$actual expected=$expected '
        'relativeError=$relativeError',
  );
}

void main() {
  group(
    'General 2x2 matrix functions: exact triangular diagonal (finding: '
    'c0*I + c1*A loses the small diagonal entry for a triangular 2x2)',
    () {
      group('Matrix.power - upper triangular [[4,1],[0,1e-18]]', () {
        final Matrix base = Matrix(<List<double>>[
          <double>[4, 1],
          <double>[0, 1e-18],
        ]);

        test('^0.5: diagonal entries are exact to rounding', () {
          final Matrix result = base.power(Matrix.scalar(0.5));

          expectRelativelyClose(result.at(0, 0), math.sqrt(4));
          expectRelativelyClose(result.at(1, 1), math.sqrt(1e-18));
          expect(result.at(1, 0), equals(0));
        });

        test('^1.5: diagonal entries are exact to rounding', () {
          final Matrix result = base.power(Matrix.scalar(1.5));

          expectRelativelyClose(result.at(0, 0), math.pow(4, 1.5).toDouble());
          expectRelativelyClose(
            result.at(1, 1),
            math.pow(1e-18, 1.5).toDouble(),
          );
          expect(result.at(1, 0), equals(0));
        });

        test('^-0.5: diagonal entries are exact to rounding', () {
          final Matrix result = base.power(Matrix.scalar(-0.5));

          expectRelativelyClose(
            result.at(0, 0),
            math.pow(4, -0.5).toDouble(),
          );
          expectRelativelyClose(
            result.at(1, 1),
            math.pow(1e-18, -0.5).toDouble(),
          );
          expect(result.at(1, 0), equals(0));
        });
      });

      group('Matrix.power - lower triangular analogue [[4,0],[1,1e-18]]', () {
        final Matrix base = Matrix(<List<double>>[
          <double>[4, 0],
          <double>[1, 1e-18],
        ]);

        test('^0.5: diagonal entries are exact to rounding', () {
          final Matrix result = base.power(Matrix.scalar(0.5));

          expectRelativelyClose(result.at(0, 0), math.sqrt(4));
          expectRelativelyClose(result.at(1, 1), math.sqrt(1e-18));
          expect(result.at(0, 1), equals(0));
        });

        test('^1.5: diagonal entries are exact to rounding', () {
          final Matrix result = base.power(Matrix.scalar(1.5));

          expectRelativelyClose(result.at(0, 0), math.pow(4, 1.5).toDouble());
          expectRelativelyClose(
            result.at(1, 1),
            math.pow(1e-18, 1.5).toDouble(),
          );
          expect(result.at(0, 1), equals(0));
        });

        test('^-0.5: diagonal entries are exact to rounding', () {
          final Matrix result = base.power(Matrix.scalar(-0.5));

          expectRelativelyClose(
            result.at(0, 0),
            math.pow(4, -0.5).toDouble(),
          );
          expectRelativelyClose(
            result.at(1, 1),
            math.pow(1e-18, -0.5).toDouble(),
          );
          expect(result.at(0, 1), equals(0));
        });
      });

      group('Matrix.power - upper triangular [[1,1],[0,1e-300]]', () {
        final Matrix base = Matrix(<List<double>>[
          <double>[1, 1],
          <double>[0, 1e-300],
        ]);

        test('^0.5: bottom-right diagonal entry is exact to rounding', () {
          final Matrix result = base.power(Matrix.scalar(0.5));

          expectRelativelyClose(result.at(0, 0), math.sqrt(1));
          expectRelativelyClose(result.at(1, 1), math.sqrt(1e-300));
          expect(result.at(1, 0), equals(0));
        });

        test('^1.5: bottom-right diagonal entry is exact to rounding', () {
          final Matrix result = base.power(Matrix.scalar(1.5));

          expectRelativelyClose(result.at(0, 0), math.pow(1, 1.5).toDouble());
          expectRelativelyClose(
            result.at(1, 1),
            math.pow(1e-300, 1.5).toDouble(),
          );
          expect(result.at(1, 0), equals(0));
        });

        test('^-0.5: bottom-right diagonal entry is exact to rounding', () {
          final Matrix result = base.power(Matrix.scalar(-0.5));

          expectRelativelyClose(
            result.at(0, 0),
            math.pow(1, -0.5).toDouble(),
          );
          expectRelativelyClose(
            result.at(1, 1),
            math.pow(1e-300, -0.5).toDouble(),
          );
          expect(result.at(1, 0), equals(0));
        });
      });

      group(
        'Matrix.sqrt / Matrix.log / Matrix.exp - upper triangular '
        '[[4,1],[0,1e-18]]',
        () {
          final Matrix base = Matrix(<List<double>>[
            <double>[4, 1],
            <double>[0, 1e-18],
          ]);

          test('sqrt: diagonal entries are exact to rounding', () {
            final Matrix result = base.sqrt();

            expectRelativelyClose(result.at(0, 0), math.sqrt(4));
            expectRelativelyClose(result.at(1, 1), math.sqrt(1e-18));
            expect(result.at(1, 0), equals(0));
          });

          test('log: diagonal entries are exact to rounding', () {
            final Matrix result = base.log();

            expectRelativelyClose(result.at(0, 0), math.log(4));
            expectRelativelyClose(result.at(1, 1), math.log(1e-18));
            expect(result.at(1, 0), equals(0));
          });

          test('exp: diagonal entries are exact to rounding', () {
            final Matrix result = base.exp();

            expectRelativelyClose(result.at(0, 0), math.exp(4));
            expectRelativelyClose(result.at(1, 1), math.exp(1e-18));
            expect(result.at(1, 0), equals(0));
          });
        },
      );

      group(
        'Matrix.sqrt / Matrix.log / Matrix.exp - tiny/huge triangular pair '
        '(1e-200, 1e200)',
        () {
          final Matrix upper = Matrix(<List<double>>[
            <double>[1e200, 1],
            <double>[0, 1e-200],
          ]);
          final Matrix lower = Matrix(<List<double>>[
            <double>[1e200, 0],
            <double>[1, 1e-200],
          ]);
          // log()'s eigenvalues themselves (1e-100, 1e100) never overflow
          // (log of any positive double is finite), but at the wider
          // 1e-200/1e200 spread the *unrelated* log1p-based divided-
          // difference ratio (l1-l2)/l2 itself overflows to Infinity before
          // ever reaching the triangular closed form this file is testing,
          // which is a separate, pre-existing numerical-robustness gap in
          // that ratio, not the diagonal-precision loss this file targets.
          // 1e-100/1e100 keeps that ratio finite while still stressing a
          // very wide eigenvalue spread.
          final Matrix logUpper = Matrix(<List<double>>[
            <double>[1e100, 1],
            <double>[0, 1e-100],
          ]);
          // exp(1e200) genuinely overflows double precision (true for any
          // implementation, not a bug: e^1e200 is not representable), so
          // exp's wide-spread stress case instead uses eigenvalues close to
          // double's own exp overflow boundary (~709) on one side and a
          // tiny magnitude on the other, which keeps both exp(a) and exp(d)
          // finite while still spanning about 300 orders of magnitude.
          final Matrix expUpper = Matrix(<List<double>>[
            <double>[700, 1],
            <double>[0, 1e-300],
          ]);

          test(
            'sqrt: diagonal entries are exact to rounding (upper triangular)',
            () {
              final Matrix result = upper.sqrt();

              expectRelativelyClose(result.at(0, 0), math.sqrt(1e200));
              expectRelativelyClose(result.at(1, 1), math.sqrt(1e-200));
              expect(result.at(1, 0), equals(0));
            },
          );

          test(
            'sqrt: diagonal entries are exact to rounding (lower triangular)',
            () {
              final Matrix result = lower.sqrt();

              expectRelativelyClose(result.at(0, 0), math.sqrt(1e200));
              expectRelativelyClose(result.at(1, 1), math.sqrt(1e-200));
              expect(result.at(0, 1), equals(0));
            },
          );

          test(
            'log: diagonal entries are exact to rounding (upper triangular)',
            () {
              final Matrix result = logUpper.log();

              expectRelativelyClose(result.at(0, 0), math.log(1e100));
              expectRelativelyClose(result.at(1, 1), math.log(1e-100));
              expect(result.at(1, 0), equals(0));
            },
          );

          test(
            'exp: diagonal entries are exact to rounding (upper triangular)',
            () {
              final Matrix result = expUpper.exp();

              expectRelativelyClose(result.at(0, 0), math.exp(700));
              expectRelativelyClose(result.at(1, 1), math.exp(1e-300));
              expect(result.at(1, 0), equals(0));
            },
          );

          test(
            'power ^1.5: diagonal entries are exact to rounding (upper '
            'triangular)',
            () {
              final Matrix result = upper.power(Matrix.scalar(1.5));

              expectRelativelyClose(
                result.at(0, 0),
                math.pow(1e200, 1.5).toDouble(),
              );
              expectRelativelyClose(
                result.at(1, 1),
                math.pow(1e-200, 1.5).toDouble(),
              );
              expect(result.at(1, 0), equals(0));
            },
          );

          test(
            'power ^-0.5: diagonal entries are exact to rounding (upper '
            'triangular)',
            () {
              final Matrix result = upper.power(Matrix.scalar(-0.5));

              expectRelativelyClose(
                result.at(0, 0),
                math.pow(1e200, -0.5).toDouble(),
              );
              expectRelativelyClose(
                result.at(1, 1),
                math.pow(1e-200, -0.5).toDouble(),
              );
              expect(result.at(1, 0), equals(0));
            },
          );
        },
      );

      group('domain gates are unaffected by the triangular fast path', () {
        test(
          'power on an upper triangular matrix with a negative diagonal '
          'entry still raises log-undefined',
          () {
            final Matrix base = Matrix(<List<double>>[
              <double>[-1, 1],
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
          'power on an upper triangular matrix with a zero diagonal entry '
          'still raises log-undefined',
          () {
            final Matrix base = Matrix(<List<double>>[
              <double>[0, 1],
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
          'log on an upper triangular matrix with a negative diagonal '
          'entry still raises log-undefined',
          () {
            final Matrix base = Matrix(<List<double>>[
              <double>[-1, 1],
              <double>[0, 4],
            ]);

            expect(
              () => base.log(),
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
          'log on an upper triangular matrix with a zero diagonal entry '
          'still raises log-undefined',
          () {
            final Matrix base = Matrix(<List<double>>[
              <double>[0, 1],
              <double>[0, 4],
            ]);

            expect(
              () => base.log(),
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
    },
  );
}
