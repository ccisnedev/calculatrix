import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// Asserts [actual] is within [relativeTolerance] of [expected]. Exactly 0
/// is required when [expected] is exactly 0; otherwise the check is purely
/// relative, since an absolute tolerance would mask large relative errors
/// on tiny expected values (some of the entries exercised here span
/// hundreds of orders of magnitude).
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

Matcher throwsOutOfPrecisionRange() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.matrixOutOfPrecisionRange,
  ),
);

void main() {
  group(
    'Matrix.exp diagonal reconstruction for a genuinely non-triangular, '
    'widely separated eigenvalue pair (finding: c0 + c1*A anchors at the '
    'smaller eigenvalue, c0 = fLo - c1*lLo, and once fHi dwarfs fLo that '
    'subtraction loses fLo entirely, the same class of bug already fixed '
    'for the power path)',
    () {
      test(
        'near triangular [[700,1],[1e-300,-700]]: D38 declared precision '
        'contract now rejects this input outright (entry (1,0)=1e-300 sits '
        'below matrixFunctionMinMagnitude=1e-150), so the far-branch fix '
        'this test used to exercise (exp recovers the true (1,1) entry, '
        'not exp(-700)) is unreachable for this exact input; see '
        'round13_d38_precision_contract_test.dart for the in-range '
        'analogue that still exercises the underlying fix',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[700, 1],
            <double>[1e-300, -700],
          ]);

          expect(
            value.exp,
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
        'triangular analogue [[700,1],[0,-700]] now raises '
        'matrix-out-of-precision-range under rule A (converted from the '
        'previous "already exact via the triangular closed form" '
        'expectation): every raw entry (700, 1, 0, -700) is in range, and '
        'both eigenvalues (700, -700, the diagonal entries) are '
        'individually in range as argument-side magnitudes, but rule A '
        'also requires the RESULT eigenvalue (exp(700), log-magnitude 700) '
        'to sit in the declared range, and 700 is far above '
        'ln(1e150)~=345.39. This is now rejected before ever reaching the '
        'triangular closed form, superseding the previous exact-value '
        'assertions',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[700, 1],
            <double>[0, -700],
          ]);

          expect(value.exp, throwsOutOfPrecisionRange());
        },
      );

      test(
        'mirrored [[-700,1],[1e-300,700]]: D38 declared precision contract '
        'now rejects this input outright (entry (1,0)=1e-300 sits below '
        'matrixFunctionMinMagnitude=1e-150), the same way as the '
        'unmirrored near-triangular case above',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[-700, 1],
            <double>[1e-300, 700],
          ]);

          expect(
            value.exp,
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
        'moderately separated [[20,1],[1e-10,-20]]: checked against an '
        'independent high-precision (mpmath, dps=60) eigendecomposition, '
        'not a double-precision hand-rolled formula sharing this fix\'s own '
        'cancellation risk',
        () {
          // trace = a + d = 20 + (-20) = 0.
          // det = a*d - b*c = -400 - 1e-10.
          // Characteristic polynomial lambda^2 - trace*lambda + det = 0
          // reduces (trace == 0) to lambda^2 = -det = 400 + 1e-10.
          //
          // Round 12 correction, finding 1: an earlier version of this
          // test computed its own reference in plain double precision via
          // `lambdaSmall = -sqrt(400 + 1e-10)` and then `x - lambdaSmall`
          // directly, under the claim that `1e-10` is well within double
          // precision's relative resolution against `400` so that
          // subtraction would carry no cancellation. That claim is false:
          // `x - lambdaSmall` is a subtraction of two ~20-magnitude
          // doubles down to a ~2.5e-12 result, which is exactly the
          // cancellation pattern this fix targets, and it loses enough
          // precision to be wrong by a relative 4.4e-4 (verified against
          // mpmath). The reference below instead comes directly from
          // mpmath at dps=60, independent of any double-precision
          // subtraction of nearby eigenvalues.
          const double expected00 = 485165195.4109728681329196;
          const double expected01 = 12129129.88527356358117632;
          const double expected10 = 0.001212912988527356358117632;
          const double expected11 = 0.00003032488586680444718134013;

          final Matrix value = Matrix(<List<double>>[
            <double>[20, 1],
            <double>[1e-10, -20],
          ]);

          final Matrix result = value.exp();

          expectRelativelyClose(result.at(0, 0), expected00);
          expectRelativelyClose(result.at(1, 1), expected11);
          expectRelativelyClose(result.at(0, 1), expected01);
          expectRelativelyClose(result.at(1, 0), expected10);
        },
      );
    },
  );

  group(
    'Matrix.sqrt general-2x2 audit: sqrt has no separate non-power general '
    '2x2 implementation, it always goes through the already-fixed power '
    'path (_matrixRealPower(0.5, ...) -> _general2x2RealPower), so these '
    'are regression tests confirming that, not a new fix',
    () {
      test(
        'sqrt([[1e200,1],[1e-300,1e-200]]): D38 declared precision '
        'contract now rejects this input outright (entries 1e200, 1e-300 '
        'and 1e-200 all sit outside [1e-150, 1e150]), so the power-path '
        'Lagrange fix this test used to regression-check is unreachable '
        'for this exact input; see round13_d38_precision_contract_test.dart '
        'for the in-range analogue',
        () {
          final Matrix value = Matrix(<List<double>>[
            <double>[1e200, 1],
            <double>[1e-300, 1e-200],
          ]);

          expect(
            value.sqrt,
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
        'sqrt([[4,1],[1e-30,1e-18]]) recovers both diagonal entries '
        '(eigenvalues approximately 4 and det/4 = 1e-18, det = '
        '4e-18 - 1e-30)',
        () {
          // trace = 4 + 1e-18 ~= 4.
          // det = a*d - b*c = 4e-18 - 1e-30 ~= 4e-18.
          // lambdaBig ~= 4, lambdaSmall = det / lambdaBig ~= 1e-18.
          final double lambdaBig = 4.0;
          final double lambdaSmall = ((4 * 1e-18) - (1 * 1e-30)) / lambdaBig;
          final double fBig = math.sqrt(lambdaBig);
          final double fSmall = math.sqrt(lambdaSmall);

          final Matrix value = Matrix(<List<double>>[
            <double>[4, 1],
            <double>[1e-30, 1e-18],
          ]);

          final Matrix result = value.sqrt();

          expectRelativelyClose(result.at(0, 0), fBig, relativeTolerance: 1e-6);
          expectRelativelyClose(
            result.at(1, 1),
            fSmall,
            relativeTolerance: 1e-6,
          );
        },
      );
    },
  );
}
