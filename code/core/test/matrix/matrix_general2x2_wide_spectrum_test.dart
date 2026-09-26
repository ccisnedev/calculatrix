import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// Asserts [actual] is within [relativeTolerance] of [expected]. Exactly 0
/// is required when [expected] is exactly 0 (no relative tolerance is
/// meaningful there); otherwise the check is purely relative, since an
/// absolute tolerance would mask large relative errors on tiny expected
/// values (some of the eigenvalues exercised here span hundreds of orders
/// of magnitude).
void expectRelativelyClose(
  double actual,
  double expected, {
  double relativeTolerance = 1e-9,
}) {
  if (expected == 0) {
    expect(actual, equals(0));
    return;
  }
  final double relativeError = (actual - expected).abs() / expected.abs();
  expect(
    relativeError,
    lessThan(relativeTolerance),
    reason: 'actual=$actual expected=$expected relativeError=$relativeError',
  );
}

void main() {
  group(
    'Matrix.log divided-difference overflow protection at extreme '
    'eigenvalue spread (finding: (l1-l2)/l2 overflows for a huge '
    'eigenvalue ratio even though (log l1 - log l2)/(l1-l2) is finite)',
    () {
      test(
        'triangular [[1e200,1],[0,1e-200]]: D38 declared precision '
        'contract now rejects this input outright (entries 1e200 and '
        '1e-200 both sit outside [1e-150, 1e150]), so the overflow-'
        'protection fix this test used to exercise is unreachable for '
        'this exact input',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e200, 1],
            <double>[0, 1e-200],
          ]);

          expect(
            value.log,
            throwsA(
              isA<MatrixDomainError>().having(
                (MatrixDomainError e) => e.errorId,
                'errorId',
                CalculatrixErrorId.matrixOutOfPrecisionRange,
              ),
            ),
          );
        },
      );

      test(
        'non-triangular analogue [[1e200,1],[1e-300,1e-200]]: D38 declared '
        'precision contract now rejects this input outright (entries '
        '1e200, 1e-300 and 1e-200 all sit outside [1e-150, 1e150])',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e200, 1],
            <double>[1e-300, 1e-200],
          ]);

          expect(
            value.log,
            throwsA(
              isA<MatrixDomainError>().having(
                (MatrixDomainError e) => e.errorId,
                'errorId',
                CalculatrixErrorId.matrixOutOfPrecisionRange,
              ),
            ),
          );
        },
      );
    },
  );

  group(
    'General 2x2 spectrum helper: smaller eigenvalue via scale-safe '
    'determinant (finding: the smaller root was derived as trace minus '
    'the larger root, which cancels to exactly 0 once the matrix entries '
    'themselves span a huge dynamic range)',
    () {
      final Matrix wideSpread = Matrix(<List<double>>[
        <double>[1e200, 1],
        <double>[1e-300, 1e-200],
      ]);

      // D38 declared precision contract: every one of the four operations
      // below now rejects `wideSpread` outright (entries 1e200, 1e-300
      // and 1e-200 all sit outside [matrixFunctionMinMagnitude,
      // matrixFunctionMaxMagnitude] = [1e-150, 1e150]), before the
      // scale-safe-determinant fix these tests used to regression-check
      // ever runs. The fix itself is not undone; it is simply no longer
      // reachable for this specific, now out-of-range, input.
      test(
        'log raises matrix-out-of-precision-range, not log-undefined from '
        'a cancellation artifact',
        () {
          expect(
            wideSpread.log,
            throwsA(
              isA<MatrixDomainError>().having(
                (MatrixDomainError e) => e.errorId,
                'errorId',
                CalculatrixErrorId.matrixOutOfPrecisionRange,
              ),
            ),
          );
        },
      );

      test(
        'sqrt raises matrix-out-of-precision-range, not log-undefined',
        () {
          expect(
            wideSpread.sqrt,
            throwsA(
              isA<MatrixDomainError>().having(
                (MatrixDomainError e) => e.errorId,
                'errorId',
                CalculatrixErrorId.matrixOutOfPrecisionRange,
              ),
            ),
          );
        },
      );

      test(
        'power(0.5) (the ^0.5 entry point, distinct from sqrt()) raises '
        'matrix-out-of-precision-range, not log-undefined',
        () {
          expect(
            () => wideSpread.power(Matrix.scalar(0.5)),
            throwsA(
              isA<MatrixDomainError>().having(
                (MatrixDomainError e) => e.errorId,
                'errorId',
                CalculatrixErrorId.matrixOutOfPrecisionRange,
              ),
            ),
          );
        },
      );

      test(
        'power(1.5) also raises matrix-out-of-precision-range',
        () {
          expect(
            () => wideSpread.power(Matrix.scalar(1.5)),
            throwsA(
              isA<MatrixDomainError>().having(
                (MatrixDomainError e) => e.errorId,
                'errorId',
                CalculatrixErrorId.matrixOutOfPrecisionRange,
              ),
            ),
          );
        },
      );

      test(
        'a genuinely singular matrix like [[1,1],[1,1]] still raises '
        'log-undefined for log (the zero-eigenvalue gate is unaffected)',
        () {
          final Matrix singular = Matrix(<List<double>>[
            <double>[1, 1],
            <double>[1, 1],
          ]);

          expect(
            () => singular.log(),
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
        'a genuinely singular matrix like [[1,1],[1,1]] still raises '
        'log-undefined for power(0.5) (the zero-eigenvalue gate is '
        'unaffected)',
        () {
          final Matrix singular = Matrix(<List<double>>[
            <double>[1, 1],
            <double>[1, 1],
          ]);

          expect(
            () => singular.power(Matrix.scalar(0.5)),
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
