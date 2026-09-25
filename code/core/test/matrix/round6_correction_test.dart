// Round 6 Codex correction: 12 issues found in round 4, 4 fixed here under
// strict TDD (items 4, 10, 6, 7, 11: see the coordinator's task for exact
// wording). The exp/log/sqrt scope decision for general and triangular
// matrices (items covered elsewhere in round 4) is explicitly OUT of scope
// for this file and is not touched.
//
// Item 6 is not exercised by an independently-named "Givens absolute
// cutoff" fix: `_qrStepGivens` (the buggy method item 6 named) was deleted
// wholesale as part of item 11's full replacement of the QR iteration
// pipeline with a real Francis double-shift QR on Hessenberg form. Item 6's
// test case is still covered below, through the new pipeline.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Round 6, item 4: inverse finiteness on every path', () {
    test(
      '[[1e-310,0],[0,1]].inverse() raises non-finite (1/1e-310 overflows '
      'the diagonal fast path: 1e-310 is subnormal, so 1/1e-310 ~ 1e310, '
      'not representable as a finite double)',
      () {
        expect(
          () => Matrix(<List<double>>[
            <double>[1e-310, 0],
            <double>[0, 1],
          ]).inverse(),
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
      'a non-diagonal matrix producing a non-finite inverse entry also '
      'raises non-finite (exercises the raw LU path, not just the '
      'diagonal fast path)',
      () {
        expect(
          () => Matrix(<List<double>>[
            <double>[1e-310, 1],
            <double>[0, 1],
          ]).inverse(),
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
  });

  group(
    'Round 6, item 4 (CLI crash path): no uncaught toInt on non-finite '
    'values',
    () {
      test(
        'CalculatrixSession rpnTopLiteral does not crash on an Infinity '
        'value pushed onto the RPN stack (mirrors the reported CLI '
        'command-mode crash: `1e300*1e300` overflows to Infinity; matrix '
        'multiply does not check finiteness by design, so the value '
        'reaches the stack, and only the *display* formatting must cope)',
        () {
          final CalculatrixSession session = CalculatrixSession();
          session.setMode(CalculatrixMode.rpn);

          session.insertMatrixLiteral('1e300*1e300');

          expect(() => session.rpnTopLiteral, returnsNormally);
          expect(session.rpnTopLiteral, contains('Infinity'));
        },
      );

      test(
        'CalculatrixSession rpnStackLiterals does not crash on an Infinity '
        'value',
        () {
          final CalculatrixSession session = CalculatrixSession();
          session.setMode(CalculatrixMode.rpn);

          session.insertMatrixLiteral('1e300*1e300');

          expect(() => session.rpnStackLiterals, returnsNormally);
          expect(session.rpnStackLiterals.single, contains('Infinity'));
        },
      );

      test(
        'MatrixDisplayFormatter.compact does not crash on a matrix '
        'containing Infinity, -Infinity or NaN',
        () {
          final Matrix nonFiniteMatrix = Matrix(<List<double>>[
            <double>[double.infinity, double.negativeInfinity],
            <double>[double.nan, 1],
          ]);

          expect(
            () => MatrixDisplayFormatter.compact(nonFiniteMatrix),
            returnsNormally,
          );
          final String rendered = MatrixDisplayFormatter.compact(
            nonFiniteMatrix,
          );
          expect(rendered, contains('Infinity'));
          expect(rendered, contains('NaN'));
        },
      );

      test(
        'MatrixDisplayFormatter.expanded does not crash on a matrix '
        'containing Infinity',
        () {
          final Matrix nonFiniteMatrix = Matrix(<List<double>>[
            <double>[double.infinity, 1],
          ]);

          expect(
            () => MatrixDisplayFormatter.expanded(nonFiniteMatrix),
            returnsNormally,
          );
        },
      );
    },
  );

  group('Round 6, item 10: inverse without global normalization', () {
    test(
      'diag(1e200,1e-200).inverse() gives diag(1e-200,1e200), not a false '
      '"singular matrix" (the previous global power-of-two normalization '
      'underflowed the small diagonal entry to exact zero before pivoting '
      'ever ran)',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[1e200, 0],
          <double>[0, 1e-200],
        ]).inverse();

        expect(result.at(0, 0), 1e-200);
        expect(result.at(0, 1), 0);
        expect(result.at(1, 0), 0);
        expect(result.at(1, 1), 1e200);
      },
    );

    test(
      'diag(1e160,1e-160).inverse() gives a finite diag(1e-160,1e160), not '
      'a false "non-finite" result (the previous normalization overflowed '
      'the undo-scale step)',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[1e160, 0],
          <double>[0, 1e-160],
        ]).inverse();

        expect(result.at(0, 0).isFinite, isTrue);
        expect(result.at(1, 1).isFinite, isTrue);
        expect(result.at(0, 0), 1e-160);
        expect(result.at(1, 1), 1e160);
      },
    );

    test(
      'a non-diagonal, ordinary-scale matrix still inverts correctly '
      '(regression: removing the global normalization must not break the '
      'common case)',
      () {
        final Matrix result = Matrix(<List<double>>[
          <double>[4, 7],
          <double>[2, 6],
        ]).inverse();

        expect(result.at(0, 0), closeTo(0.6, 1e-12));
        expect(result.at(0, 1), closeTo(-0.7, 1e-12));
        expect(result.at(1, 0), closeTo(-0.2, 1e-12));
        expect(result.at(1, 1), closeTo(0.4, 1e-12));
      },
    );

    test(
      'an exactly singular matrix still raises singular-matrix (regression: '
      'the diagonal fast path and the raw LU path must both still detect '
      'genuine singularity, not just skip the check)',
      () {
        expect(
          () => Matrix(<List<double>>[
            <double>[0, 0],
            <double>[0, 1],
          ]).inverse(),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.singularMatrix,
            ),
          ),
        );

        expect(
          () => Matrix(<List<double>>[
            <double>[1, 2],
            <double>[2, 4],
          ]).inverse(),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError e) => e.errorId,
              'errorId',
              CalculatrixErrorId.singularMatrix,
            ),
          ),
        );
      },
    );
  });

  group(
    'Round 6, items 6 and 11: Francis double-shift QR with no absolute '
    'subdiagonal cutoff',
    () {
      test(
        '[[1,1e6,0],[1e-6,2,1e6],[0,1e-6,3]].eigenvalues() gives '
        '{2+sqrt(3), 2, 2-sqrt(3)} within 1e-12 relative (the previous '
        '`_qrStepGivens` zeroed any subdiagonal entry at or below an '
        'absolute 1e-12, which wrongly destroyed the genuinely tiny 1e-6 '
        'subdiagonal entries here before they could do their job in the '
        'QR iteration)',
        () {
          final Matrix result = Matrix(<List<double>>[
            <double>[1, 1e6, 0],
            <double>[1e-6, 2, 1e6],
            <double>[0, 1e-6, 3],
          ]).eigenvalues();

          final List<double> values = <double>[
            result.at(0, 0),
            result.at(1, 0),
            result.at(2, 0),
          ]..sort();

          final List<double> expected = <double>[
            2 - math.sqrt(3),
            2,
            2 + math.sqrt(3),
          ]..sort();

          for (int i = 0; i < 3; i++) {
            expect(
              (values[i] - expected[i]).abs() / expected[i].abs(),
              lessThanOrEqualTo(1e-12),
            );
          }
        },
      );

      test(
        'a symmetric tridiagonal 3x3 with known eigenvalues 4, 4+/-sqrt(2) '
        'converges correctly (a genuinely non-diagonal input, exercising '
        'the Hessenberg reduction and at least one real double-shift step)',
        () {
          final Matrix result = Matrix(<List<double>>[
            <double>[4, 1, 0],
            <double>[1, 4, 1],
            <double>[0, 1, 4],
          ]).eigenvalues();

          final List<double> values = <double>[
            result.at(0, 0),
            result.at(1, 0),
            result.at(2, 0),
          ]..sort();

          final List<double> expected = <double>[
            4 - math.sqrt(2),
            4,
            4 + math.sqrt(2),
          ]..sort();

          for (int i = 0; i < 3; i++) {
            expect(values[i], closeTo(expected[i], 1e-9));
          }
        },
      );

      test(
        'a 4x4 non-diagonal, non-symmetric matrix with known integer '
        'eigenvalues converges (upper Hessenberg-but-not-triangular input, '
        'forcing at least one real double-shift QR step through a block '
        'larger than 2x2)',
        () {
          // Companion-style matrix of x^4 - 10x^3 + 35x^2 - 50x + 24
          // = (x-1)(x-2)(x-3)(x-4).
          final Matrix result = Matrix(<List<double>>[
            <double>[10, -35, 50, -24],
            <double>[1, 0, 0, 0],
            <double>[0, 1, 0, 0],
            <double>[0, 0, 1, 0],
          ]).eigenvalues();

          final List<double> values = <double>[
            result.at(0, 0),
            result.at(1, 0),
            result.at(2, 0),
            result.at(3, 0),
          ]..sort();

          expect(values[0], closeTo(1, 1e-7));
          expect(values[1], closeTo(2, 1e-7));
          expect(values[2], closeTo(3, 1e-7));
          expect(values[3], closeTo(4, 1e-7));
        },
      );
    },
  );

  group('Round 6, item 7: scaled 2x2 eigenvalue solver, no absolute zeroing', () {
    test('[[0,1e20],[1e-20,0]].eigenvalues() gives exactly {1,-1}', () {
      final Matrix result = Matrix(<List<double>>[
        <double>[0, 1e20],
        <double>[1e-20, 0],
      ]).eigenvalues();

      expect(result.at(0, 0), 1);
      expect(result.at(1, 0), -1);
    });

    test(
      'a genuinely complex 2x2 pair still throws (regression: the scaled '
      'solver must not turn a real discriminant test into one that misses '
      'a genuine complex pair)',
      () {
        expect(
          () => Matrix(<List<double>>[
            <double>[0, -1],
            <double>[1, 0],
          ]).eigenvalues(),
          throwsA(isA<MatrixDomainError>()),
        );
      },
    );
  });

  group(
    'Round 6, item 11: real Francis double-shift QR on Hessenberg form, '
    'Schur vectors',
    () {
      test(
        'eigenvalues() on the same 8x8 2I+C matrix throws (it has a '
        'genuine complex-conjugate spectrum, so the real-only public API '
        'must still reject it rather than silently dropping the complex '
        'part)',
        () {
          final List<List<double>> a = List<List<double>>.generate(
            8,
            (int i) => List<double>.generate(8, (int j) {
              final double identity = i == j ? 2.0 : 0.0;
              final double cyclic = j == (i + 1) % 8 ? 1.0 : 0.0;
              return identity + cyclic;
            }, growable: false),
            growable: false,
          );

          expect(
            () => Matrix(a).eigenvalues(),
            throwsA(isA<MatrixDomainError>()),
          );
        },
      );
    },
  );
}
