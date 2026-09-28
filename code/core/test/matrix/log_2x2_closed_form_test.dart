// Tests for Matrix.log()'s 2x2 closed form (issue #5, D25 power table row
// 5): `log A = c1*A + c0*I`, derived from Sylvester's formula for a
// function of a 2x2 matrix. This is what makes a defective 2x2 base (a
// repeated eigenvalue with only one independent eigenvector, so
// diagonalization's eigenvector matrix P is singular) still have a
// well-defined log, and what tells "no real eigenvalue" (a genuine
// complex-conjugate pair, log-undefined outside complex form) apart from
// "a real eigenvalue is non-positive" (also log-undefined, but for a
// different reason).

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Matrix.log 2x2 closed form (issue #5)', () {
    test('defective (Jordan block) base has a well-defined log', () {
      // [[1, 1], [0, 1]] has the repeated eigenvalue 1 with only one
      // independent eigenvector, so diagonalization's P is singular; the
      // closed form never needs P. log of this Jordan block is the known
      // nilpotent shift [[0, 1], [0, 0]] (exp of which is the base again).
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 1],
        <double>[0, 1],
      ]);

      final Matrix result = base.log();

      expect(
        result.almostEquals(
          Matrix(<List<double>>[
            <double>[0, 1],
            <double>[0, 0],
          ]),
          absoluteTolerance: 1e-8,
        ),
        isTrue,
      );
      expect(result.exp().almostEquals(base, absoluteTolerance: 1e-8), isTrue);
    });

    test('defective base with a non-unit repeated eigenvalue works too', () {
      // [[2, 1], [0, 2]]: repeated eigenvalue 2, defective. Round trip
      // through exp is the only practical way to check correctness here.
      final Matrix base = Matrix(<List<double>>[
        <double>[2, 1],
        <double>[0, 2],
      ]);

      final Matrix result = base.log();
      expect(result.exp().almostEquals(base, absoluteTolerance: 1e-6), isTrue);
    });

    test('raising a defective base to a non-integer power works (row 5)', () {
      // [[1, 1], [0, 1]] 0.5 ^ : previously routed through diagonalization
      // and failed with a singular P; the power dispatch calls log()
      // internally for a non-integer scalar exponent.
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 1],
        <double>[0, 1],
      ]);

      final Matrix result = base.power(Matrix.scalar(0.5));
      final Matrix squared = result * result;
      expect(squared.almostEquals(base, absoluteTolerance: 1e-6), isTrue);
    });

    test('a genuine 2x2 complex-conjugate pair off the branch cut has a real '
        'principal log', () {
      // [[0, -2], [1, 0]]: eigenvalues are +-i*sqrt(2), a genuine complex
      // pair not in complex form (aI + bJ). Its real part is 0, not on
      // the closed negative real axis, so the principal branch of the
      // matrix logarithm is still well-defined and real-valued (issue #5
      // review round 1, finding 4: this used to be rejected as
      // log-undefined outright).
      final Matrix base = Matrix(<List<double>>[
        <double>[0, -2],
        <double>[1, 0],
      ]);

      final Matrix result = base.log();
      expect(result.exp().almostEquals(base, absoluteTolerance: 1e-8), isTrue);
    });

    test('another 2x2 complex-conjugate pair off the branch cut round trips '
        'through exp', () {
      // [[2, -5], [1, 0]]: eigenvalues are 1+-2i, complex conjugate,
      // matrix not in complex form (diagonal entries differ).
      final Matrix base = Matrix(<List<double>>[
        <double>[2, -5],
        <double>[1, 0],
      ]);

      final Matrix result = base.log();
      expect(result.exp().almostEquals(base, absoluteTolerance: 1e-8), isTrue);
    });

    test('raising a complex-conjugate-eigenvalue base to a non-integer power '
        'matches the closed-form principal log (issue #5 review round 1, '
        'finding 4)', () {
      // [[1, -2], [0.5, 1]]: eigenvalues 1+-i, complex conjugate pair.
      // Expected value derived from the closed form c1 = arg(lambda)/b,
      // c0 = ln|lambda| - a*c1 for eigenvalues a +- bi, b > 0.
      final Matrix base = Matrix(<List<double>>[
        <double>[1, -2],
        <double>[0.5, 1],
      ]);

      final Matrix result = base.power(Matrix.scalar(0.5));

      expect(
        result.almostEquals(
          Matrix(<List<double>>[
            <double>[1.098684, -0.910180],
            <double>[0.227545, 1.098684],
          ]),
          absoluteTolerance: 1e-6,
        ),
        isTrue,
      );
    });

    test(
      'a 2x2 matrix with a non-positive real eigenvalue is log-undefined',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[-1, 0],
          <double>[0, 2],
        ]);

        expect(
          () => base.log(),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.logUndefined,
            ),
          ),
        );
      },
    );

    test(
      'distinct positive real eigenvalues match the diagonalization path',
      () {
        // A triangular matrix, distinct eigenvalues 3 and 2: exercises the
        // "distinct eigenvalues" branch of the closed form (as opposed to
        // the repeated-eigenvalue derivative branch above).
        final Matrix base = Matrix(<List<double>>[
          <double>[3, 1],
          <double>[0, 2],
        ]);

        final Matrix result = base.log();
        expect(
          result.exp().almostEquals(base, absoluteTolerance: 1e-8),
          isTrue,
        );
      },
    );
  });

  group('Matrix.log domain errors carry log-undefined (issue #5)', () {
    test('log of scalar zero carries the log-undefined error id', () {
      expect(
        () => Matrix.scalar(0).log(),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.logUndefined,
          ),
        ),
      );
    });

    test(
      'log of a non-positive eigenvalue matrix (n > 2) carries log-undefined',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[-1, 0, 0],
          <double>[0, 2, 0],
          <double>[0, 0, 3],
        ]);

        expect(
          () => base.log(),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.logUndefined,
            ),
          ),
        );
      },
    );
  });
}
