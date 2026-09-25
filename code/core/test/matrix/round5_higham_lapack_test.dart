// Round 5 Codex correction: 9 issues found in round 3, reproduced with
// probes. Root cause across all of them is that the ad hoc algorithms broke
// at the extremes; this round replaces them with the standard algorithms
// from Higham, "Functions of Matrices" (2008), and from LAPACK. See
// `Matrix.eigenvalues`, `Matrix._inverse`, `Matrix.exp`, `Matrix.sqrt` and
// `Matrix.log` for the citations.
import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Round 5, case 1: non-finite power exponent must not hang', () {
    test(
      'identity ^ Infinity raises non-finite quickly instead of hanging '
      '(roundToDouble() classifies Infinity as "an integer", and halving '
      'Infinity in the binary-exponentiation loop never reaches zero)',
      () async {
        final ReceivePort port = ReceivePort();
        final Isolate isolate = await Isolate.spawn(_runCase1, port.sendPort);
        String outcome;
        try {
          outcome = await port.first.timeout(const Duration(seconds: 10))
              as String;
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

    test('a plain non-finite scalar exponent also raises non-finite', () {
      expect(
        () => Matrix(<List<double>>[
          <double>[1, 0],
          <double>[0, 1],
        ]).power(Matrix.scalar(double.nan)),
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

  group(
    'Round 5, case 4: overflowing infinity-norm must not misclassify '
    'complex form',
    () {
      test(
        '[[1e308,1e308],[1e308,1e308]]^0.5 raises non-finite (its row sum '
        'overflows to Infinity, so its true infinity-norm is not '
        'representable; it must not be silently misclassified as complex '
        'form by comparing Infinity <= Infinity, nor silently normalized '
        'as if nothing overflowed)',
        () {
          final Matrix a = Matrix(<List<double>>[
            <double>[1e308, 1e308],
            <double>[1e308, 1e308],
          ]);

          expect(a.isComplexForm, isFalse);
          expect(
            () => a.power(Matrix.scalar(0.5)),
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
    },
  );

  group('Round 5, case 9: PowerCommand checks arity before popping', () {
    test(
      'PowerCommand on a 1-deep stack raises stack-underflow and leaves '
      'the stack as [2], not empty (arity must be checked before any pop, '
      'through the shared applyBinary path)',
      () {
        final RpnEngine engine = RpnEngine();
        engine.pushScalar(2);

        expect(
          () => const PowerCommand().executeOn(engine),
          throwsA(
            isA<RpnStackUnderflowError>().having(
              (RpnStackUnderflowError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.stackUnderflow,
            ),
          ),
        );

        expect(engine.stack, <Matrix>[Matrix.scalar(2)]);
      },
    );
  });

  group('Round 5, case 6: power-of-two scaling by bounded steps', () {
    test(
      '[[2e-320,1e-320],[0,2e-320]].sqrt() does not hang or underflow to '
      'the zero matrix (general 2x2 with a repeated positive eigenvalue, '
      'handled by the closed-form divided-difference formula with no '
      'matrix-wide power-of-two normalization needed)',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[2e-320, 1e-320],
          <double>[0, 2e-320],
        ]).sqrt();

        expect(result.at(0, 0), isNot(0));
        expect(result.at(0, 0).isFinite, isTrue);
        final Matrix reconstructed = result * result;
        expect(reconstructed.at(0, 0), closeTo(2e-320, 2e-320 * 1e-6));
      },
    );

    test(
      'diag(1e308, 1.5e308).eigenvalues() gives exactly {1e308, 1.5e308} '
      '(exactly triangular/diagonal input returns its diagonal directly, '
      'never reaching a power-of-two normalization step that would '
      'otherwise need to pick k around 1024 and overflow a single-step '
      '2^k multiply)',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[1e308, 0],
          <double>[0, 1.5e308],
        ]).eigenvalues();

        expect(result.at(0, 0), 1.5e308);
        expect(result.at(1, 0), 1e308);
      },
    );
  });

  group('Round 5, eigenvalues: Hessenberg + Francis double-shift QR', () {
    test('triangular input returns its diagonal exactly: diag(1,2,1e20)', () {
      final Matrix result = Matrix(<List<double>>[
        <double>[1, 0, 0],
        <double>[0, 2, 0],
        <double>[0, 0, 1e20],
      ]).eigenvalues();

      final List<double> values = <double>[
        result.at(0, 0),
        result.at(1, 0),
        result.at(2, 0),
      ]..sort();

      expect(values, <double>[1, 2, 1e20]);
    });
  });

  group('Round 5, inverse: LU with partial pivoting', () {
    test('[[1,1e20],[0,1]]^-1 = [[1,-1e20],[0,1]] exactly', () {
      final Matrix result = Matrix(<List<double>>[
        <double>[1, 1e20],
        <double>[0, 1],
      ]).inverse();

      expect(result.at(0, 0), 1);
      expect(result.at(0, 1), -1e20);
      expect(result.at(1, 0), 0);
      expect(result.at(1, 1), 1);
    });
  });

  group('Round 5, exp: degree-13 Pade scaling and squaring (Higham 2005)', () {
    test(
      '[[1,1e20],[0,2]] exp has diagonal e and e^2 within 1e-13 relative '
      '(general-2x2 divided-difference closed form, Higham 1.2)',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[1, 1e20],
          <double>[0, 2],
        ]).exp();

        // The general-2x2 divided-difference formula (f(A) = c0*I + c1*A)
        // has no diagonal-overwrite step, so its diagonal entries are not
        // bit-identical to a direct `math.exp()` call even though they are
        // mathematically equal to it, hence a tight relative tolerance
        // instead of exact equality.
        expect(
          (result.at(0, 0) - math.exp(1.0)).abs() / math.exp(1.0),
          lessThanOrEqualTo(1e-13),
        );
        expect(
          (result.at(1, 1) - math.exp(2.0)).abs() / math.exp(2.0),
          lessThanOrEqualTo(1e-13),
        );
      },
    );

    test('diag(-1000,-500) exp gives diag(0, 7.124576406741286e-218)', () {
      final Matrix result = Matrix(<List<double>>[
        <double>[-1000, 0],
        <double>[0, -500],
      ]).exp();

      expect(result.at(0, 0), 0);
      expect(result.at(1, 1), closeTo(7.124576406741286e-218, 1e-218 * 1e-8));
    });

    test('diag(0,-1600) exp gives diag(1,0)', () {
      final Matrix result = Matrix(<List<double>>[
        <double>[0, 0],
        <double>[0, -1600],
      ]).exp();

      expect(result.at(0, 0), 1);
      expect(result.at(1, 1), 0);
    });

    test('overflow of a real diagonal entry gives non-finite', () {
      expect(
        () => Matrix(<List<double>>[
          <double>[1000, 0],
          <double>[0, 0],
        ]).exp(),
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

  group(
    'Round 5, sqrt/log accuracy: tight relative error for diagonal and '
    'triangular input',
    () {
      test(
        'diag(1e-20,2e-20)^0.5 = diag(1e-10, 1.4142135623730951e-10) '
        'within 1e-14 relative',
        () {
          final Matrix result = Matrix(<List<double>>[
            <double>[1e-20, 0],
            <double>[0, 2e-20],
          ]).power(Matrix.scalar(0.5));

          expect(
            (result.at(0, 0) - 1e-10).abs() / 1e-10,
            lessThanOrEqualTo(1e-14),
          );
          expect(
            (result.at(1, 1) - 1.4142135623730951e-10).abs() /
                1.4142135623730951e-10,
            lessThanOrEqualTo(1e-14),
          );
        },
      );

      test(
        '3x3 cyclic permutation^0.5 is unsupported-matrix-function: not '
        'diagonal, not exactly symmetric and not 2x2',
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
    },
  );
}

void _runCase1(SendPort sendPort) {
  try {
    Matrix(<List<double>>[
      <double>[1, 0],
      <double>[0, 1],
    ]).power(Matrix.scalar(double.infinity));
    sendPort.send('no-throw');
  } on CalculatrixError catch (e) {
    sendPort.send(e.errorId?.id ?? 'null-error-id');
  } catch (e) {
    sendPort.send('unexpected: $e');
  }
}
