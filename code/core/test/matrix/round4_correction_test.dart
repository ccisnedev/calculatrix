// Round 4 Codex correction (PR #7, on 1244ece): cases A-H.
//
// Root cause across A-G was absolute cutoffs (e.g. `1e-12`) compared
// directly against entries/eigenvalues/pivots/magnitudes whose own scale
// could be far above or below that fixed floor. The fix is exact
// power-of-two scale normalization before sqrt/log/inverse/eigenvalues and
// the power paths (see `Matrix._normalizedByPowerOfTwo`), a hypot-style
// magnitude for the complex-form log (`Matrix._hypot`), and a closed-form,
// series-free `exp` for the complex-form and scalar-multiple-of-identity
// cases. Case H's root cause was tracking "is a function pending" as a
// single boolean per parenthesis frame instead of a count, which lost
// track of a second, outer pending function once a nested group resolved
// the inner one.
import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Round 4 correction, case A: exp scale-relative fixes', () {
    test(
      'A1: e^[[1,1e20],[0,1]] = [[e, e*1e20],[0,e]] exactly (mean-eigenvalue '
      'shift makes the shifted matrix exactly nilpotent)',
      () {
        final Matrix result = Matrix.scalar(math.e).power(
          Matrix(<List<double>>[
            <double>[1, 1e20],
            <double>[0, 1],
          ]),
        );

        final double e = math.e;
        final Matrix expected = Matrix(<List<double>>[
          <double>[e, e * 1e20],
          <double>[0, e],
        ]);

        expect(
          result.almostEquals(
            expected,
            relativeTolerance: 1e-9,
            absoluteTolerance: 0,
          ),
          isTrue,
          reason: 'got $result',
        );
      },
    );

    test(
      'A2: e^(1e16*J) stays bounded (|entries| <= 1), not the ~1e74 the '
      'old scaling-and-squaring series produced',
      () {
        final Matrix result = Matrix.scalar(math.e).power(
          Matrix(<List<double>>[
            <double>[0, -1e16],
            <double>[1e16, 0],
          ]),
        );

        expect(result.isComplexForm, isTrue);
        expect(result.realPart.isFinite, isTrue);
        expect(result.imagPart.isFinite, isTrue);
        expect(result.realPart.abs(), lessThanOrEqualTo(1.0 + 1e-9));
        expect(result.imagPart.abs(), lessThanOrEqualTo(1.0 + 1e-9));
      },
    );
  });

  group('Round 4 correction, case B: must not hang (run isolate-guarded)', () {
    test(
      'B1: 10^[[1e308,0],[0,0]] raises non-finite quickly instead of '
      'hanging (ln(10)*1e308 overflows to Infinity; a loop whose only '
      'exit condition is "norm <= 0.5" never terminates on an infinite '
      'norm)',
      () async {
        final ReceivePort port = ReceivePort();
        final Isolate isolate = await Isolate.spawn(
          _runCaseB1,
          port.sendPort,
        );
        String outcome;
        try {
          outcome = await port.first.timeout(
            const Duration(seconds: 10),
          ) as String;
        } on TimeoutException {
          outcome = 'TIMED OUT (regression: this hung again)';
        } finally {
          isolate.kill(priority: Isolate.immediate);
          port.close();
        }

        expect(outcome, CalculatrixErrorId.nonFinite.id);
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test(
      'B2: [[1e200,0],[0,1e200]]^0.5 does not hang and returns the correct '
      'finite 1e100*I (once log\'s hypot fix stops it from ever producing '
      'an Infinity-containing intermediate)',
      () async {
        final ReceivePort port = ReceivePort();
        final Isolate isolate = await Isolate.spawn(
          _runCaseB2,
          port.sendPort,
        );
        List<dynamic> outcome;
        try {
          outcome = await port.first.timeout(
            const Duration(seconds: 10),
          ) as List<dynamic>;
        } on TimeoutException {
          outcome = <dynamic>['TIMEOUT'];
        } finally {
          isolate.kill(priority: Isolate.immediate);
          port.close();
        }

        expect(outcome, isNot(<dynamic>['TIMEOUT']));
        expect(outcome[0], 'ok');
        final double d00 = outcome[1] as double;
        final double d01 = outcome[2] as double;
        final double d10 = outcome[3] as double;
        final double d11 = outcome[4] as double;

        expect(d00, closeTo(1e100, 1e100 * 1e-9));
        expect(d01, closeTo(0, 1e91));
        expect(d10, closeTo(0, 1e91));
        expect(d11, closeTo(1e100, 1e100 * 1e-9));
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );
  });

  group('Round 4 correction, case C: tiny-scale sqrt/power', () {
    test(
      'C1: sqrt([[2e-30,1e-30],[1e-30,2e-30]]) is not the zero matrix; '
      'matches the exact eigen-based closed form',
      () {
        const double a = 2e-30;
        const double b = 1e-30;
        final double sqrtSum = math.sqrt(a + b);
        final double sqrtDiff = math.sqrt(a - b);
        final double c = (sqrtSum + sqrtDiff) / 2;
        final double d = (sqrtSum - sqrtDiff) / 2;
        final Matrix expected = Matrix(<List<double>>[
          <double>[c, d],
          <double>[d, c],
        ]);

        final Matrix result = Matrix(<List<double>>[
          <double>[a, b],
          <double>[b, a],
        ]).sqrt();

        expect(result.at(0, 0), isNot(0));
        expect(
          result.almostEquals(
            expected,
            relativeTolerance: 1e-6,
            absoluteTolerance: 0,
          ),
          isTrue,
          reason: 'got $result',
        );
      },
    );

    test(
      'C2: [[1e-30,1e-30],[0,1e-30]]^0.5 = [[1e-15,5e-16],[0,1e-15]] '
      '(Jordan-block sqrt formula), not diag 9.09e-13',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[1e-30, 1e-30],
          <double>[0, 1e-30],
        ]).power(Matrix.scalar(0.5));

        final Matrix expected = Matrix(<List<double>>[
          <double>[1e-15, 5e-16],
          <double>[0, 1e-15],
        ]);

        expect(
          result.almostEquals(
            expected,
            relativeTolerance: 1e-4,
            absoluteTolerance: 0,
          ),
          isTrue,
          reason: 'got $result',
        );
      },
    );
  });

  group('Round 4 correction, case D: tiny-scale eigenvalues no longer '
      'zeroed', () {
    test(
      '[[2e-14,1e-14,0],[1e-14,2e-14,0],[0,0,3e-14]]^0.5 succeeds '
      '(eigenvalues 1e-14, 3e-14, 3e-14 are all genuinely positive, not '
      'wrongly zeroed by an absolute 1e-12 cutoff)',
      () {
        const double a = 2e-14;
        const double b = 1e-14;
        final double sqrtSum = math.sqrt(a + b);
        final double sqrtDiff = math.sqrt(a - b);
        final double c = (sqrtSum + sqrtDiff) / 2;
        final double d = (sqrtSum - sqrtDiff) / 2;
        final double trailing = math.sqrt(3e-14);

        final Matrix expected = Matrix(<List<double>>[
          <double>[c, d, 0],
          <double>[d, c, 0],
          <double>[0, 0, trailing],
        ]);

        final Matrix result = Matrix(<List<double>>[
          <double>[2e-14, 1e-14, 0],
          <double>[1e-14, 2e-14, 0],
          <double>[0, 0, 3e-14],
        ]).power(Matrix.scalar(0.5));

        expect(
          result.almostEquals(
            expected,
            relativeTolerance: 1e-4,
            absoluteTolerance: 0,
          ),
          isTrue,
          reason: 'got $result',
        );
      },
    );
  });

  group('Round 4 correction, case E: tiny-scale log-complex-form', () {
    test(
      '[[1e-20,0],[0,1e-20]]^0.5 = 1e-10*I, not a wrong log-undefined '
      '(1e-20 is genuinely nonzero, just far below the old fixed '
      '1e-12 floor)',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[1e-20, 0],
          <double>[0, 1e-20],
        ]).power(Matrix.scalar(0.5));

        final Matrix expected = Matrix(<List<double>>[
          <double>[1e-10, 0],
          <double>[0, 1e-10],
        ]);

        expect(
          result.almostEquals(
            expected,
            relativeTolerance: 1e-9,
            absoluteTolerance: 0,
          ),
          isTrue,
          reason: 'got $result',
        );
      },
    );
  });

  group('Round 4 correction, case F: tiny-scale inverse', () {
    test(
      '[[1e-20,0],[0,2e-20]]^-1 = diag(1e20, 5e19), not a wrong '
      'singular-matrix (the pivot cutoff was an absolute 1e-12 floor, far '
      'above these genuinely nonsingular tiny pivots)',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[1e-20, 0],
          <double>[0, 2e-20],
        ]).power(Matrix.scalar(-1));

        final Matrix expected = Matrix(<List<double>>[
          <double>[1e20, 0],
          <double>[0, 5e19],
        ]);

        expect(
          result.almostEquals(
            expected,
            relativeTolerance: 1e-9,
            absoluteTolerance: 0,
          ),
          isTrue,
          reason: 'got $result',
        );
      },
    );
  });

  group('Round 4 correction, case G: cyclic permutation matrix', () {
    test(
      '[[0,0,1],[1,0,0],[0,1,0]]^0.5 is unsupported-matrix-function: not '
      'diagonal, not exactly symmetric and not 2x2, regardless of its '
      'spectrum',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[0, 0, 1],
          <double>[1, 0, 0],
          <double>[0, 1, 0],
        ]);

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
      },
    );
  });

  group('Round 4 correction, case H: nested bare function arguments', () {
    test(
      '√√(16)+1 is a syntax error (a pending-function stack, not a '
      'boolean, is needed to track that the OUTER √ is still bare once '
      'the inner √\'s argument is parenthesized)',
      () {
        expect(
          () => Calculatrix.evaluateInfix('√√(16)+1'),
          throwsA(
            isA<ExpressionSyntaxError>().having(
              (ExpressionSyntaxError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.syntaxError,
            ),
          ),
        );
      },
    );

    test('√(16)+1 stays valid (the inner group resolves its own √)', () {
      final Matrix result = Calculatrix.evaluateInfix('√(16)+1');
      expect(result, Matrix.scalar(5));
    });

    test(
      '√16+1 still correctly raises a syntax error (unchanged behavior)',
      () {
        expect(
          () => Calculatrix.evaluateInfix('√16+1'),
          throwsA(
            isA<ExpressionSyntaxError>().having(
              (ExpressionSyntaxError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.syntaxError,
            ),
          ),
        );
      },
    );

    test('√√16 alone stays valid (both √s resolved by the one operand)', () {
      final Matrix result = Calculatrix.evaluateInfix('√√16');
      expect(result.at(0, 0), closeTo(2, 1e-10));
    });
  });
}

void _runCaseB1(SendPort sendPort) {
  try {
    Matrix.scalar(10).power(
      Matrix(<List<double>>[
        <double>[1e308, 0],
        <double>[0, 0],
      ]),
    );
    sendPort.send('no-throw');
  } on CalculatrixError catch (e) {
    sendPort.send(e.errorId?.id ?? 'null-error-id');
  } catch (e) {
    sendPort.send('unexpected: $e');
  }
}

void _runCaseB2(SendPort sendPort) {
  try {
    final Matrix result = Matrix(<List<double>>[
      <double>[1e200, 0],
      <double>[0, 1e200],
    ]).power(Matrix.scalar(0.5));
    sendPort.send(<dynamic>[
      'ok',
      result.at(0, 0),
      result.at(0, 1),
      result.at(1, 0),
      result.at(1, 1),
    ]);
  } on CalculatrixError catch (e) {
    sendPort.send(<dynamic>['error', e.errorId?.id ?? 'null-error-id']);
  } catch (e) {
    sendPort.send(<dynamic>['unexpected', '$e']);
  }
}
