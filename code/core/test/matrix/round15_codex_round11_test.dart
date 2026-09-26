// Core PR #7 Codex round 11 (reviewed at commit e0b22df), five medium
// defects in the D38 precision-range contract (rule A):
//
//   1. matrix.dart:3943, sqrt([[1,2,4],[2,4,8],[4,8,16]]) (exact PSD,
//      eigenvalues 21, 0, 0) threw log-undefined because cyclic Jacobi
//      returns a tiny negative floating-point approximation of the true
//      zero eigenvalue, not exactly zero.
//   2. matrix.dart:3062, the log-magnitude gate rejected boundary results
//      purely from its own comparison's rounding, e.g.
//      scalar(1e-100)^1.5 (true result exactly 1e-150, the declared
//      inclusive lower bound).
//   3. matrix.dart:2426 and :2597, exp's and log's own complex-form
//      branches returned without ever checking the computed result's
//      entries against the declared range, unlike every other branch of
//      exp/log/sqrt/power.
//   4. matrix.dart:2772, (-2)^(1e-150) rejected its own internal
//      intermediate (ln(2)*1e-150) by routing it through the public,
//      argument-gated log()/exp() methods instead of computing the
//      complex principal power directly.
//   5. matrix.dart:5062, [[1e-150,1e150],[0,1e-150]]^-0.5 raised the
//      generic non-finite error instead of the declarative
//      matrix-out-of-precision-range: the off-diagonal's true magnitude
//      (~5e374) is knowably out of the declared range in log space before
//      math.exp(logMagnitude) is ever called to materialize it, but the
//      old code called math.exp regardless and let the resulting Infinity
//      fall through to the generic finiteness check instead.
//
// Every numeric reference value below not already exactly representable
// (e.g. 1/sqrt(21)) was independently derived with Python mpmath (never
// copied from this implementation's own output); see each group's leading
// comment for the derivation.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// Frobenius norm of [m], computed scale-aware so entries at 1e150+ do not
/// overflow when squared. Copied from `round13_d38_precision_contract_test`
/// for this file's own use (kept file-local so this test file has no
/// dependency on another test file's internals, matching the established
/// convention in `round14_codex_round9_test.dart`).
double _frobeniusNorm(Matrix m) {
  double maxAbs = 0;
  for (int row = 0; row < m.rowCount; row++) {
    for (int column = 0; column < m.columnCount; column++) {
      final double abs = m.at(row, column).abs();
      if (abs > maxAbs) maxAbs = abs;
    }
  }
  if (maxAbs == 0) return 0;

  double sumSquaredScaled = 0;
  for (int row = 0; row < m.rowCount; row++) {
    for (int column = 0; column < m.columnCount; column++) {
      final double scaled = m.at(row, column) / maxAbs;
      sumSquaredScaled += scaled * scaled;
    }
  }
  return maxAbs * math.sqrt(sumSquaredScaled);
}

Matcher throwsOutOfPrecisionRange() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.matrixOutOfPrecisionRange,
  ),
);

Matcher throwsLogUndefined() => throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError e) => e.errorId,
    'errorId',
    CalculatrixErrorId.logUndefined,
  ),
);

/// Rule B (runbook D38 amendment): the absolute-bound analogue used for a
/// genuinely singular `sqrt` result, whose reference is itself partly or
/// wholly zero, so a relative bound is either undefined or vacuous.
/// `||X - sqrt(A)||_F <= 1e4*sqrt(unitRoundoff*||A||_F)`, where `X` is the
/// computed result and `A` is the original (singular) input this bound is
/// stated against. Copied from `round13_d38_precision_contract_test` for
/// this file's own use, same rationale as [_frobeniusNorm] above.
void expectSqrtSingularBound(Matrix computed, Matrix reference, Matrix a) {
  final double tolerance =
      1e4 * math.sqrt(CalculatrixNumericPolicy.unitRoundoff * _frobeniusNorm(a));
  final double frobeniusDiff = _frobeniusNorm(computed - reference);
  expect(
    frobeniusDiff,
    lessThanOrEqualTo(tolerance),
    reason:
        'computed=$computed reference=$reference '
        'frobeniusDiff=$frobeniusDiff tolerance=$tolerance',
  );
}

void main() {
  group('Codex round 11, finding 1: Jacobi near-zero eigenvalue snapping', () {
    test(
      'sqrt([[1,2,4],[2,4,8],[4,8,16]]) (rank-1 PSD, eigenvalues 21, 0, 0) '
      'no longer throws log-undefined from a tiny negative Jacobi '
      'approximation of the true zero eigenvalue: this matrix is exactly '
      'v*v^T for v=(1,2,4), so, since v*v^T is PSD, '
      'sqrt(v*v^T) = v*v^T / ||v|| = A/sqrt(21) exactly (independently '
      'verified: (A/sqrt(21))^2 = v*(v^T*v)*v^T/21 = v*21*v^T/21 = A). '
      'Reference (mpmath, dps 50): sqrt(21) = 4.5825756949558400066.',
      () {
        final Matrix a = Matrix(<List<double>>[
          <double>[1, 2, 4],
          <double>[2, 4, 8],
          <double>[4, 8, 16],
        ]);
        final double s21 = math.sqrt(21);
        final Matrix reference = a.scale(1 / s21);

        final Matrix computed = a.sqrt();

        expectSqrtSingularBound(computed, reference, a);
      },
    );

    test(
      'sqrt([[4,6,12],[6,9,18],[12,18,36]]) (rank-1 PSD, eigenvalues 49, 0, '
      '0, a second 3x3 singular regression case with a different vector, '
      'v=(2,3,6), ||v||^2=49) equals A/7 exactly, the same closed form as '
      'above. Reference (mpmath, dps 50): entries are exact sevenths of the '
      'original entries.',
      () {
        final Matrix a = Matrix(<List<double>>[
          <double>[4, 6, 12],
          <double>[6, 9, 18],
          <double>[12, 18, 36],
        ]);
        final Matrix reference = a.scale(1 / 7);

        final Matrix computed = a.sqrt();

        expectSqrtSingularBound(computed, reference, a);
      },
    );

    test(
      'log([[1,2,4],[2,4,8],[4,8,16]]) still raises log-undefined (decision: '
      'a Jacobi-computed eigenvalue snapped to exactly zero by the finding-1 '
      'fix is still exactly zero, and zero is log-undefined for log, the '
      'same as an exactly-diagonal or general-2x2 input with a genuine zero '
      'eigenvalue already is)',
      () {
        final Matrix a = Matrix(<List<double>>[
          <double>[1, 2, 4],
          <double>[2, 4, 8],
          <double>[4, 8, 16],
        ]);

        expect(a.log, throwsLogUndefined());
      },
    );

    test(
      'power([[1,2,4],[2,4,8],[4,8,16]], 1.5) still raises log-undefined '
      '(decision: power keeps rejectZeroEigenvalue=true for a non-scalar, '
      'non-complex-form base regardless of the finding-1 zero-snapping fix, '
      'the same as the existing round-9-finding-4 semantics for a genuine, '
      'exactly-representable zero eigenvalue)',
      () {
        final Matrix a = Matrix(<List<double>>[
          <double>[1, 2, 4],
          <double>[2, 4, 8],
          <double>[4, 8, 16],
        ]);

        expect(() => a.power(Matrix.scalar(1.5)), throwsLogUndefined());
      },
    );

    test(
      'sqrt([[0,1,0],[1,0,0],[0,0,1]]) (symmetric, non-diagonal, exact '
      'eigenvalues 1, 1, -1, a genuinely negative eigenvalue far outside '
      'any Jacobi rounding noise) still raises log-undefined: the '
      'finding-1 zero-snapping fix must not widen far enough to swallow a '
      'real, meaningfully negative eigenvalue',
      () {
        final Matrix a = Matrix(<List<double>>[
          <double>[0, 1, 0],
          <double>[1, 0, 0],
          <double>[0, 0, 1],
        ]);

        expect(a.sqrt, throwsLogUndefined());
      },
    );
  });

  group(
    'Codex round 11, finding 2: log-magnitude gate boundary rounding',
    () {
      test(
        'scalar(1e-100)^1.5 (true result exactly 1e-150, the declared '
        'inclusive lower bound) no longer throws matrix-out-of-precision-'
        'range purely from the log-domain comparison\'s own rounding '
        '(measured: y*ln(1e-100) computes about 5.68e-14 below '
        'ln(1e-150) in double precision, under 1 ULP of either operand\'s '
        'own magnitude, ~345.39)',
        () {
          final Matrix result = Matrix.scalar(
            1e-100,
          ).power(Matrix.scalar(1.5));

          expect(result.scalarValue, closeTo(1e-150, 1e-164));
        },
      );

      test(
        'scalar(1e-100)^-1.5 (true result exactly 1e150, the declared '
        'inclusive upper bound, the finding\'s named "-1.5 upper-bound '
        'analogue") no longer throws matrix-out-of-precision-range for the '
        'same reason',
        () {
          final Matrix result = Matrix.scalar(
            1e-100,
          ).power(Matrix.scalar(-1.5));

          expect(result.scalarValue, closeTo(1e150, 1e136));
        },
      );
    },
  );

  group(
    'Codex round 11, finding 3: complex-form exp/log result-entry check',
    () {
      test(
        'complex(-345, 1e-150).exp() now raises matrix-out-of-precision-'
        'range instead of silently returning an off-diagonal entry '
        '(~1.47e-300, measured from the unfixed implementation) below '
        'matrixFunctionMinMagnitude: the result eigenvalue magnitude '
        '(exp(-345)) is in range, but a computed result ENTRY is not, the '
        'same gap [_requireResultEntriesInPrecisionRange] already closes '
        'for every other branch of exp/log/sqrt/power',
        () {
          expect(
            () => Matrix.complex(-345, 1e-150).exp(),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        'complex(1e150, 1e-150).log() now raises matrix-out-of-precision-'
        'range instead of silently returning a result entry (~1e-300, '
        'measured from the unfixed implementation, the imaginary/rotation '
        'part atan2(1e-150, 1e150)) below matrixFunctionMinMagnitude: the '
        'combined hypot(logRadius, angle) eigenvalue-style check passes '
        '(dominated by logRadius ~345.39), but the angle entry alone does '
        'not',
        () {
          expect(
            () => Matrix.complex(1e150, 1e-150).log(),
            throwsOutOfPrecisionRange(),
          );
        },
      );
    },
  );

  group(
    'Codex round 11, finding 4: internal intermediate must skip the public '
    'argument gate',
    () {
      test(
        '(-2)^(1e-150) no longer raises matrix-out-of-precision-range on '
        'its own internal intermediate ln(2)*1e-150 (~6.93e-151, below '
        'matrixFunctionMinMagnitude on its own, but never a raw argument '
        'the caller supplied): the true result is complex principal value '
        'exp(1e-150*ln(2)) * (cos(1e-150*pi) + i*sin(1e-150*pi)), whose '
        'real part rounds to exactly 1.0 in double precision and whose '
        'imaginary part is pi*1e-150 (mpmath, dps 60): '
        '3.141592653589793238462643e-150, both comfortably in range',
        () {
          final Matrix result = Matrix.scalar(-2).power(Matrix.scalar(1e-150));

          expect(result.realPart, 1.0);
          expect(result.imagPart, closeTo(math.pi * 1e-150, 1e-164));
        },
      );
    },
  );

  group(
    'Codex round 11, finding 5: result-entry magnitude checked before a '
    'log-space product is materialized',
    () {
      test(
        '[[1e-150,1e150],[0,1e-150]]^-0.5 now raises matrix-out-of-'
        'precision-range instead of the generic non-finite error: the '
        'result eigenvalue magnitude ((1e-150)^-0.5 = 1e75) is in range, '
        'but the off-diagonal entry\'s true magnitude '
        '(0.5 * (1e-150)^-1.5 * 1e150, about 5e374) is knowably out of the '
        'declared range in log space (its natural log is about 862.8, far '
        'past ln(1e150) ~= 345.39) before math.exp(logMagnitude) is ever '
        'called to materialize it. This establishes precedence: an '
        'in-range result eigenvalue does not by itself guarantee an '
        'in-range result entry, and the more specific '
        'matrix-out-of-precision-range must win over the generic '
        'non-finite check when both would otherwise apply',
        () {
          final Matrix a = Matrix(<List<double>>[
            <double>[1e-150, 1e150],
            <double>[0, 1e-150],
          ]);

          expect(
            () => a.power(Matrix.scalar(-0.5)),
            throwsOutOfPrecisionRange(),
          );
        },
      );
    },
  );
}
