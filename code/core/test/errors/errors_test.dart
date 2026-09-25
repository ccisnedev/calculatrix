import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('CalculatrixErrorId', () {
    test('defines the eleven domain error ids from the spec', () {
      final Set<String> ids = CalculatrixErrorId.values
          .map((CalculatrixErrorId id) => id.id)
          .toSet();

      expect(ids, <String>{
        'unknown-word',
        'stack-underflow',
        'type-mismatch',
        'dimension-mismatch',
        'singular-matrix',
        'non-finite',
        'log-undefined',
        'ambiguous-power',
        'syntax-error',
        'no-convergence',
        'unsupported-matrix-function',
      });
    });
  });

  group('CalculatrixError', () {
    test('carries an optional errorId, token and position', () {
      final MatrixDomainError error = MatrixDomainError(
        'boom',
        errorId: CalculatrixErrorId.nonFinite,
        token: '1e999',
        position: 3,
      );

      expect(error.errorId, CalculatrixErrorId.nonFinite);
      expect(error.token, '1e999');
      expect(error.position, 3);
      expect(error.message, 'boom');
    });

    test('errorId, token and position default to null', () {
      final MatrixDomainError error = MatrixDomainError('boom');

      expect(error.errorId, isNull);
      expect(error.token, isNull);
      expect(error.position, isNull);
    });
  });

  group('UnknownWordError', () {
    test('carries the unknown-word id and the offending token', () {
      final UnknownWordError error = UnknownWordError('banana');

      expect(error.errorId, CalculatrixErrorId.unknownWord);
      expect(error.token, 'banana');
      expect(error, isA<CalculatrixError>());
    });
  });

  group('structured error ids at real throw sites (#5)', () {
    test(
      'addition of mismatched shapes carries dimension-mismatch',
      () {
        final Matrix a = Matrix(<List<double>>[
          <double>[1, 2],
        ]);
        final Matrix b = Matrix(<List<double>>[
          <double>[1],
          <double>[2],
        ]);

        expect(
          () => a + b,
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
      'every CalculatrixErrorId has at least one real operation that '
      'raises it with a non-null errorId',
      () {
        final Map<CalculatrixErrorId, void Function()> representatives =
            <CalculatrixErrorId, void Function()>{
          CalculatrixErrorId.unknownWord: () =>
              Calculatrix.evaluateRpn(<String>['banana']),
          CalculatrixErrorId.stackUnderflow: () =>
              Calculatrix.evaluateRpn(<String>['+']),
          CalculatrixErrorId.typeMismatch: () =>
              Matrix.identity(2) / Matrix.identity(2),
          CalculatrixErrorId.dimensionMismatch: () => Matrix(<List<double>>[
            <double>[1, 2],
          ]) +
              Matrix(<List<double>>[
                <double>[1],
                <double>[2],
              ]),
          CalculatrixErrorId.singularMatrix: () => Matrix(<List<double>>[
            <double>[1, 2],
            <double>[2, 4],
          ]).inverse(),
          CalculatrixErrorId.nonFinite: () =>
              Matrix.scalar(10).power(Matrix.scalar(400)),
          CalculatrixErrorId.logUndefined: () => Matrix.scalar(0).log(),
          CalculatrixErrorId.ambiguousPower: () {
            final Matrix base = Matrix(<List<double>>[
              <double>[1, 1],
              <double>[0, 1],
            ]);
            final Matrix y = Matrix(<List<double>>[
              <double>[0, 1],
              <double>[1, 0],
            ]);
            base.power(y);
          },
          CalculatrixErrorId.syntaxError: () =>
              Calculatrix.evaluateInfix('1 2 +'),
          // Exactly symmetric, so sqrt() takes the cyclic Jacobi
          // eigendecomposition path (Golub & Van Loan 8.5). sqrt() itself
          // has no public sweep budget parameter (round 8 correction,
          // finding 11), so this goes through the testing-only debug seam
          // with a sweep budget of 0, meaning the sweep loop never runs, so
          // the post-loop off-diagonal-norm convergence check fails
          // deterministically.
          CalculatrixErrorId.noConvergence: () =>
              debugCyclicJacobiSqrtWithSweepBudget(
                Matrix(<List<double>>[
                  <double>[2, 1],
                  <double>[1, 2],
                ]),
                0,
              ),
          // Not scalar, complex-form, diagonal or exactly symmetric, and not
          // 2x2 either: no supported closed form applies.
          CalculatrixErrorId.unsupportedMatrixFunction: () => Matrix(<List<double>>[
            <double>[1, 1, 0],
            <double>[0, 1, 1],
            <double>[0, 0, 1],
          ]).exp(),
        };

        expect(
          representatives.keys.toSet(),
          CalculatrixErrorId.values.toSet(),
          reason: 'every declared error id must have a representative op',
        );

        for (final MapEntry<CalculatrixErrorId, void Function()> entry
            in representatives.entries) {
          CalculatrixErrorId? observedId;
          try {
            entry.value();
            fail('expected ${entry.key} to throw, but nothing was thrown');
          } on CalculatrixError catch (e) {
            observedId = e.errorId;
          }

          expect(
            observedId,
            entry.key,
            reason: 'representative op for ${entry.key} did not carry its id',
          );
        }
      },
    );
  });
}
