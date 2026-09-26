// Core PR #7 Codex round 9 (reviewed at commit 789d1c2) findings 1, 2, 3, 4,
// 5, 6 and 8 (finding 7 is intentionally excluded: it depends on a pending
// accuracy-contract decision by the user and is out of scope here).
//
// Every numeric reference value below was independently derived with Python
// mpmath (never copied from this implementation's own output) using the
// generic 2x2 Sylvester-formula closed form
// `f(A) = f(l1)*(A-l2*I)/(l1-l2) + f(l2)*(A-l1*I)/(l2-l1)` for distinct
// eigenvalues, or `f(A) = f(l)*I + f'(l)*(A-l*I)` for a repeated eigenvalue,
// at a `dps` chosen to resolve the specific cancellation each computation
// involves (not merely the final answer's own magnitude); see each test's
// comment for the exact dps used and, where relevant, an independent
// cross-check (e.g. squaring a computed square root back to the original
// matrix, or comparing against `atanh`).
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// Frobenius norm of [m], computed scale-aware so entries at 1e150+ do not
/// overflow when squared. Copied from `round13_d38_precision_contract_test`
/// for this file's own use (kept file-local so this test file has no
/// dependency on another test file's internals).
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

/// The D38 contract's own accuracy criterion: normwise (Frobenius) relative
/// error, `||computed - reference|| / ||reference|| <= tolerance`.
void expectNormwiseRelativeError(
  Matrix computed,
  Matrix reference, {
  double tolerance = 1e-9,
}) {
  expect(computed.rowCount, reference.rowCount);
  expect(computed.columnCount, reference.columnCount);

  final double frobeniusDiff = _frobeniusNorm(computed - reference);
  final double frobeniusReference = _frobeniusNorm(reference);
  final double relativeError = frobeniusReference == 0
      ? frobeniusDiff
      : frobeniusDiff / frobeniusReference;

  expect(
    relativeError,
    lessThanOrEqualTo(tolerance),
    reason:
        'computed=$computed reference=$reference '
        'normwiseRelativeError=$relativeError',
  );
}

/// Componentwise relative-error check, used (alongside the normwise one)
/// wherever a finding is about one specific entry losing precision while
/// other entries in the same matrix dominate the Frobenius norm and would
/// otherwise mask it.
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
    'Codex round 9 finding 1: exp underflow-before-multiply, now converted '
    'to a rule A rejection',
    () {
      test(
        'exp([[-750,1e150],[0,-750]]) now raises '
        'matrix-out-of-precision-range under rule A, converted from its '
        'previous finite result (entry00=entry11=0, entry01='
        '1.901684963475006403550798e-176, entry10=0): the repeated '
        'eigenvalue -750 has magnitude 750, above '
        'ln(1e150)~=345.3877639491069, so the result eigenvalue '
        'log-magnitude (the eigenvalue itself, for exp) is out of the '
        'declared range, even though the true off-diagonal entry this '
        'test used to check was representable and this is rejected '
        'before math.exp(-750) is ever called',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[-750, 1e150],
            <double>[0, -750],
          ]);

          expect(m.exp, throwsOutOfPrecisionRange());
        },
      );
    },
  );

  group(
    'Codex round 9 finding 2: repeated-eigenvalue power underflow/overflow '
    'before multiply, now converted to rule A rejections',
    () {
      test(
        '[[1e-150,1e-150],[0,1e-150]]^-1.5 now raises '
        'matrix-out-of-precision-range under rule A, converted from its '
        'previous finite result (entry00=entry11='
        '9.999999999999999905569627e+224, entry01='
        '-1.499999999999999985835444e+225, entry10=0): the repeated '
        'eigenvalue 1e-150 has ln(1e-150)=-345.3877639491069, and rule A '
        'requires the result eigenvalue log-magnitude y*ln(|l|) to stay '
        'within +/-345.3877639491069, but y*ln(l) = -1.5 * '
        '-345.3877639491069 = 518.08164592366035, above the declared '
        'bound, even though the true entries above were finite doubles',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1e-150, 1e-150],
            <double>[0, 1e-150],
          ]);

          expect(
            () => m.power(Matrix.scalar(-1.5)),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        '[[1e150,1e150],[0,1e150]]^-1.5 now raises '
        'matrix-out-of-precision-range under rule A, converted from its '
        'previous finite result (entry00=entry11='
        '1.000000000000000028746606e-225, entry01='
        '-1.500000000000000043119909e-225, entry10=0): the repeated '
        'eigenvalue 1e150 has ln(1e150)=345.3877639491069, and rule A '
        'requires the result eigenvalue log-magnitude y*ln(|l|) to stay '
        'within +/-345.3877639491069, but y*ln(l) = -1.5 * '
        '345.3877639491069 = -518.08164592366035, above the declared '
        'bound in magnitude, even though the true entries above were '
        'finite doubles',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1e150, 1e150],
            <double>[0, 1e150],
          ]);

          expect(
            () => m.power(Matrix.scalar(-1.5)),
            throwsOutOfPrecisionRange(),
          );
        },
      );
    },
  );

  group(
    'Codex round 9 finding 3: sqrt discriminant underflow misclassifies '
    'repeated negative real eigenvalues',
    () {
      test(
        'sqrt([[-1e100,1e-150],[-2e-150,-1e100]]) now raises '
        'matrix-out-of-precision-range under rule A (converted from the '
        'previous "must not throw log-undefined" classification): the '
        'discriminant halfDiff^2+b*c is still representable, so the old '
        'log-undefined misclassification this test guarded against is '
        'gone, but rule A also requires every NONZERO ENTRY of the '
        'computed result to be in the declared range, not just its '
        'eigenvalues (sqrt itself can never fail the eigenvalue-side '
        'check, since 0.5*ln(|lambda|) is always within '
        '[-172.7, 172.7] whenever the argument-side check already '
        'passed). Reference (mpmath, dps=700, needed because a*d~1e200 '
        'and b*c~-2e-300 span about 500 decimal orders of magnitude, so '
        'a lower dps silently rounds the discriminant correction away; '
        'independently cross-checked by squaring the computed root back '
        'to the original matrix): entry00=entry11='
        '7.071067811865475244008443621048490392848e-201, entry01='
        '7.071067811865475244008443621048490392848e+49, entry10='
        '-1.41421356237309504880168872420969807857e+50. entry00/entry11 '
        'are nonzero but below matrixFunctionMinMagnitude=1e-150, so rule '
        'A rejects this before the accuracy contract ever applies.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[-1e100, 1e-150],
            <double>[-2e-150, -1e100],
          ]);

          expect(() => m.sqrt(), throwsOutOfPrecisionRange());
        },
      );
    },
  );

  group(
    'Codex round 9 finding 4: matrix-exponent power paths bypass the raw-'
    'input D38 gate',
    () {
      test(
        'Matrix.scalar(1e200).power(diag(0.5,0.5)) must raise matrix-out-'
        'of-precision-range: the scalar base 1e200 is above '
        'matrixFunctionMaxMagnitude=1e150, but the current '
        '_powerByMatrixExponent path never validates the base before '
        'scaling by log(b) and exponentiating.',
        () {
          final Matrix exponent = Matrix(<List<double>>[
            <double>[0.5, 0],
            <double>[0, 0.5],
          ]);

          expect(
            () => Matrix.scalar(1e200).power(exponent),
            throwsOutOfPrecisionRange(),
          );
        },
      );

      test(
        'Matrix.scalar(1).power(diag(1e200,1e200)) must raise matrix-out-'
        'of-precision-range instead of silently returning the identity: '
        'the exponent 1e200 is above matrixFunctionMaxMagnitude=1e150, but '
        'the current _powerByMatrixExponent path never validates the '
        'exponent operand either.',
        () {
          final Matrix exponent = Matrix(<List<double>>[
            <double>[1e200, 0],
            <double>[0, 1e200],
          ]);

          expect(
            () => Matrix.scalar(1).power(exponent),
            throwsOutOfPrecisionRange(),
          );
        },
      );
    },
  );

  group(
    'Codex round 9 finding 5: complex-pair D38 checks must bound '
    'hypot(m,w), not m and w individually. This disproves the earlier '
    '"structurally unreachable" claim about this check: all three cases '
    'below are reachable inputs that the current per-component check '
    'gets wrong in both directions.',
    () {
      test(
        'log([[1e-150,1],[-2,0]]) must NOT throw: m=0.5e-150 individually '
        'looks out-of-range-small, but the true eigenvalue magnitude '
        'hypot(m,w) is about sqrt(2), safely inside range, so this must '
        'succeed. Reference (mpmath, dps=80, complex-eigenvalue-pair '
        'closed form, m=5e-151, w=sqrt(2 - 2.5e-301)~sqrt(2)): '
        'entry00=entry11=0.3465735902799726547086161, '
        'entry01=1.11072073453959156175397, '
        'entry10=-2.22144146907918312350794.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1e-150, 1],
            <double>[-2, 0],
          ]);

          final Matrix computed = m.log();
          expectRelativelyClose(
            computed.at(0, 0),
            0.3465735902799726547086161,
          );
          expectRelativelyClose(
            computed.at(1, 1),
            0.3465735902799726547086161,
          );
          expectRelativelyClose(computed.at(0, 1), 1.11072073453959156175397);
          expectRelativelyClose(
            computed.at(1, 0),
            -2.22144146907918312350794,
          );
        },
      );

      test(
        '[[9e149,9e149],[-8e149,9e149]].log() must throw matrix-out-of-'
        'precision-range: m=9e149 and w~8.4853e149 each individually look '
        'in-range, but the true eigenvalue magnitude hypot(m,w) is about '
        '1.2369e150, above matrixFunctionMaxMagnitude=1e150, so this must '
        'be rejected. Reference (mpmath, dps=400): m=9.0e+149, '
        'w=8.4852813742385702928e+149, hypot(m,w)=1.2369316876852981649e'
        '+150.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[9e149, 9e149],
            <double>[-8e149, 9e149],
          ]);

          expect(m.log, throwsOutOfPrecisionRange());
        },
      );

      test(
        'exp(Matrix.complex(1e150,1e150)) must throw matrix-out-of-'
        'precision-range: both components sit exactly at the declared '
        'boundary 1e150 and pass the per-entry stage-1 gate, but the '
        'eigenvalue magnitude hypot(1e150,1e150)=1e150*sqrt(2) is above '
        '1e150, so this must be rejected by a stage-2 check even though '
        'stage 1 lets it through.',
        () {
          final Matrix m = Matrix.complex(1e150, 1e150);

          expect(m.exp, throwsOutOfPrecisionRange());
        },
      );
    },
  );

  group(
    'Codex round 9 finding 6: cancellation-unsafe divided-difference '
    'log(lBig)-log(lSmall) loses accuracy for nearby-but-not-close '
    'eigenvalues',
    () {
      test(
        'power: A=[[1e100,1e150],[0,1e100*(1-1.4916e-8)]], A^0.25: the '
        'far-eigenvalue branch\'s naive log(lBig)-log(lSmall) subtracts two '
        'nearly-equal ~230.26 magnitude logarithms to recover a much '
        'smaller true difference, losing accuracy relative to the '
        '1e-12 normwise contract. Reference (mpmath, dps=100, distinct-'
        'eigenvalue closed form, y=0.25): entry00='
        '1.000000000000000003975723e+25, entry01='
        '2.500000013983750043123183e+74, entry11='
        '9999999962709999833363600.0, entry10=0.',
        () {
          final double d = 1e100 * (1 - 1.4916e-8);
          final Matrix m = Matrix(<List<double>>[
            <double>[1e100, 1e150],
            <double>[0, d],
          ]);

          final Matrix computed = m.power(Matrix.scalar(0.25));
          expect(computed.at(1, 0), equals(0));
          expectRelativelyClose(
            computed.at(0, 0),
            1.000000000000000003975723e25,
            relativeTolerance: 1e-10,
          );
          expectRelativelyClose(
            computed.at(0, 1),
            2.500000013983750043123183e74,
            relativeTolerance: 1e-10,
          );
          expectRelativelyClose(
            computed.at(1, 1),
            9999999962709999833363600.0,
            relativeTolerance: 1e-10,
          );
        },
      );

      test(
        'log([[1e100,1e150],[0,1e100*(1-1.01e-3)]]): same cancellation '
        'pattern in log\'s own far-eigenvalue branch, at a relative gap '
        '(1.01e-3) comfortably on the "far" side of the close-eigenvalue '
        'threshold. Reference (mpmath, dps=100, distinct-eigenvalue closed '
        'form, f=log): entry00=230.258509299404568417702, entry01='
        '1.000505340291116775381773e+50, entry11='
        '230.2574987890108745275847, entry10=0.',
        () {
          final double d = 1e100 * (1 - 1.01e-3);
          final Matrix m = Matrix(<List<double>>[
            <double>[1e100, 1e150],
            <double>[0, d],
          ]);

          final Matrix computed = m.log();
          expect(computed.at(1, 0), equals(0));
          // Tolerance tightened to the D38 contract's own 1e-12 accuracy
          // bound (not the looser 1e-10 used elsewhere in this file): this
          // matrix's naive log(lBig)-log(lSmall) cancellation error is much
          // smaller in absolute terms than the power case above (the
          // coordinator's own cited example was 1.81e-11), so a looser
          // tolerance would not observe it.
          expectRelativelyClose(
            computed.at(0, 0),
            230.258509299404568417702,
            relativeTolerance: 1e-12,
          );
          expectRelativelyClose(
            computed.at(0, 1),
            1.000505340291116775381773e50,
            relativeTolerance: 1e-12,
          );
          expectRelativelyClose(
            computed.at(1, 1),
            230.2574987890108745275847,
            relativeTolerance: 1e-12,
          );
        },
      );
    },
  );

  group(
    'Codex round 9 finding 8: Jacobi eigenvalue-offset-from-1 precision '
    'loss in log',
    () {
      test(
        'log([[1,1e-10],[1e-10,1]]): eigenvalues are 1+1e-10 and 1-1e-10, '
        'each individually rounding away the 1e-10 offset from 1 (double '
        'has ~16 significant decimal digits, so 1+1e-10 loses precision '
        'well before the offset itself does), which the current Jacobi '
        'per-eigenvalue evaluation never recovers from since it never '
        'performs a Sterbenz-safe subtraction step the way the general '
        '2x2 divided-difference formulas do. Reference (mpmath, dps=60, '
        'independently cross-checked against atanh(1e-10)='
        '1.000000000000000036432197e-10, since log of this symmetric '
        'matrix\'s off-diagonal entry equals atanh of the off-diagonal '
        'input for this particular matrix family): entry00=entry11='
        '-5.000000000000000364346973e-21, entry01=entry10='
        '1.000000000000000036435531e-10.',
        () {
          final Matrix m = Matrix(<List<double>>[
            <double>[1, 1e-10],
            <double>[1e-10, 1],
          ]);

          final Matrix computed = m.log();
          expectRelativelyClose(
            computed.at(0, 0),
            -5.000000000000000364346973e-21,
          );
          expectRelativelyClose(
            computed.at(1, 1),
            -5.000000000000000364346973e-21,
          );
          expectRelativelyClose(
            computed.at(0, 1),
            1.000000000000000036435531e-10,
          );
          expectRelativelyClose(
            computed.at(1, 0),
            1.000000000000000036435531e-10,
          );
        },
      );
    },
  );
}
