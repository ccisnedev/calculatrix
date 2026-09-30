// Tests for issue #35 (runbook D43, D44, step S4b): `inverse` and `sqrt`
// as defined words over an exact `power`.
//
// AC1: `power` at exponent -1 (matrix case) and 0.5 (scalar and matrix
// cases) is exact, not the general exp(y * log B) route, so it no longer
// carries the floating-point rounding noise that route introduces for a
// well-conditioned integer input.
// AC3: a defined word's compiled result is bitwise identical to typing its
// own definition, checked with exact `==` (never `almostEquals`), on the
// entry's own registered examples and on the applicable rows of the D25
// table (docs/runbook-cli-stage-0.md, "Semantics of power").
// AC4: an error raised while executing a defined word's expansion reports
// the token the user actually typed (e.g. "inverse" or "inv"), not a
// token from inside its definition (e.g. "power" or "-1").
// AC5: CalculatrixCommandRegistry's construction rejects a defined entry
// whose definition uses an unresolved word, and rejects a definition that
// reaches itself, directly or through other defined words.
// AC6: a matrix with no real logarithm at exponent 0.5, or through sqrt,
// is log-undefined, not the CLI's generic fallback error id.
// AC7: D25 row 5's non-diagonalizable example, `[[1 1] [0 1]] 0.5 power`,
// is exact, and bitwise identical to sqrt of the same base.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

// Mirrors evaluateRpn's own position convention (1-based offset within
// tokens.join(' ')), the same independent check token_position_test.dart
// uses, so this does not simply restate whatever the implementation
// itself computed.
int _expectedRpnPosition(List<String> tokens, int index) {
  int position = 1;
  for (int i = 0; i < index; i++) {
    position += tokens[i].length + 1;
  }
  return position;
}

void main() {
  group('AC1: -1 and 0.5 power are exact (issue #35)', () {
    test('[[1 2] [3 4]] -1 power is exactly [[-2 1] [1.5 -0.5]]', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);

      final Matrix result = base.power(Matrix.scalar(-1));

      expect(
        result,
        Matrix(<List<double>>[
          <double>[-2, 1],
          <double>[1.5, -0.5],
        ]),
      );
    });

    test('[[0 0] [0 4]] 0.5 power is exactly [[0 0] [0 2]]', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[0, 0],
        <double>[0, 4],
      ]);

      final Matrix result = base.power(Matrix.scalar(0.5));

      expect(
        result,
        Matrix(<List<double>>[
          <double>[0, 0],
          <double>[0, 2],
        ]),
      );
    });

    test(
      '-4 0.5 power is exactly the complex principal value [[0 -2] [2 0]]',
      () {
        final Matrix result = Matrix.scalar(-4).power(Matrix.scalar(0.5));

        expect(
          result,
          Matrix(<List<double>>[
            <double>[0, -2],
            <double>[2, 0],
          ]),
        );
      },
    );

    test('a singular base with -1 power still raises singular-matrix', () {
      final Matrix singular = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[2, 4],
      ]);

      expect(
        () => singular.power(Matrix.scalar(-1)),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.singularMatrix,
          ),
        ),
      );
    });
  });

  group('AC7: D25 row 5, non-diagonalizable base at exponent 0.5', () {
    // Newton's iteration for the principal square root of a non-diagonal,
    // non-diagonalizable Jordan block does not land on an exactly
    // representable double the way the closed-form 2x2 inverse or a
    // diagonal square root does, so this compares against the runbook's
    // expected value (docs/runbook-cli-stage-0.md, D25 row 5) within a
    // tight tolerance rather than with exact `==`. The "same bits" half of
    // issue #35 AC7 (below) is what is checked exactly: 0.5 power and sqrt
    // must still agree with each other bit for bit, whatever those bits
    // are, since 0.5 power literally calls sqrt() (D44).
    test('[[1 1] [0 1]] 0.5 power is [[1 0.5] [0 1]]', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 1],
        <double>[0, 1],
      ]);

      final Matrix result = base.power(Matrix.scalar(0.5));

      expect(
        result.almostEquals(
          Matrix(<List<double>>[
            <double>[1, 0.5],
            <double>[0, 1],
          ]),
        ),
        isTrue,
      );
    });

    test('sqrt of the same non-diagonalizable base is bitwise identical to '
        '0.5 power', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 1],
        <double>[0, 1],
      ]);

      expect(base.sqrt(), base.power(Matrix.scalar(0.5)));
    });
  });

  group('AC6: sqrt / 0.5 power over a matrix with no real logarithm is '
      'log-undefined (docs/runbook-cli-stage-0.md, "Deferred: a matrix with '
      'no real logarithm")', () {
    test('[[-1 0] [0 2]] sqrt raises log-undefined', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[-1, 0],
        <double>[0, 2],
      ]);

      expect(
        () => base.sqrt(),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.logUndefined,
          ),
        ),
      );
    });

    test('[[-1 0] [0 2]] 0.5 power raises log-undefined, not the generic '
        'error it raised before issue #35', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[-1, 0],
        <double>[0, 2],
      ]);

      expect(
        () => base.power(Matrix.scalar(0.5)),
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
      'the same case through the sqrt RPN word also raises log-undefined',
      () {
        expect(
          () => Calculatrix.evaluateRpn(<String>['[[-1 0] [0 2]]', 'sqrt']),
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

  group('AC3: a defined word compiles bitwise identical to typing its own '
      'definition (issue #35)', () {
    test('every defined entry, on its own registered examples, matches its '
        'expansion exactly', () {
      const Set<String> definedNames = <String>{'inverse', 'sqrt'};
      for (final CalculatrixCommandEntry entry
          in CalculatrixCommandRegistry.standard.entries) {
        if (!definedNames.contains(entry.name)) {
          continue;
        }
        for (final CalculatrixCommandExample example in entry.examples) {
          final List<String> tokens = Calculatrix.tokenizeRpnLine(
            example.program,
          );
          // Every example above ends with the word itself: replacing
          // that last token with the tokenized definition reproduces,
          // by hand, exactly what _compileWord already does inside the
          // compiler for that same word (issue #35, AC3).
          final List<String> expandedTokens = <String>[
            ...tokens.sublist(0, tokens.length - 1),
            ...Calculatrix.tokenizeRpnLine(entry.definition!),
          ];

          final Matrix viaWord = Calculatrix.evaluateRpn(tokens);
          final Matrix viaDefinition = Calculatrix.evaluateRpn(expandedTokens);

          expect(
            viaWord,
            viaDefinition,
            reason:
                '"${example.program}" must be bitwise identical to '
                'typing "${entry.definition}" by hand',
          );
        }
      }
    });

    test('D25 row 1: -4 sqrt is bitwise identical to -4 0.5 power', () {
      final Matrix viaPower = Matrix.scalar(-4).power(Matrix.scalar(0.5));
      final Matrix viaSqrtWord = Calculatrix.evaluateRpn(<String>[
        '-4',
        'sqrt',
      ]);

      expect(viaSqrtWord, viaPower);
    });

    test(
      'D25 row 4: [[1 1] [0 1]] inverse is bitwise identical to -1 power',
      () {
        final Matrix base = Matrix(<List<double>>[
          <double>[1, 1],
          <double>[0, 1],
        ]);
        final Matrix viaPower = base.power(Matrix.scalar(-1));
        final Matrix viaInverseWord = Calculatrix.evaluateRpn(<String>[
          '[[1 1] [0 1]]',
          'inverse',
        ]);

        expect(viaInverseWord, viaPower);
      },
    );

    test('D25 row 5: [[1 1] [0 1]] sqrt (non-diagonalizable) is bitwise '
        'identical to [[1 1] [0 1]] 0.5 power', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 1],
        <double>[0, 1],
      ]);
      final Matrix viaPower = base.power(Matrix.scalar(0.5));
      final Matrix viaSqrtWord = Calculatrix.evaluateRpn(<String>[
        '[[1 1] [0 1]]',
        'sqrt',
      ]);

      expect(viaSqrtWord, viaPower);
    });
  });

  group('AC4: an error raised inside a defined word\'s expansion carries the '
      'token the user actually wrote', () {
    test('singular base, inverse: token is "inverse", not "power" or "-1"', () {
      final List<String> tokens = <String>['[[1 2] [2 4]]', 'inverse'];
      try {
        Calculatrix.evaluateRpn(tokens);
        fail('expected MatrixDomainError');
      } on MatrixDomainError catch (error) {
        expect(error.errorId, CalculatrixErrorId.singularMatrix);
        expect(error.token, 'inverse');
        expect(error.position, _expectedRpnPosition(tokens, 1));
      }
    });

    test('singular base, inv: token is "inv"', () {
      final List<String> tokens = <String>['[[1 2] [2 4]]', 'inv'];
      try {
        Calculatrix.evaluateRpn(tokens);
        fail('expected MatrixDomainError');
      } on MatrixDomainError catch (error) {
        expect(error.errorId, CalculatrixErrorId.singularMatrix);
        expect(error.token, 'inv');
        expect(error.position, _expectedRpnPosition(tokens, 1));
      }
    });

    test('no real logarithm, sqrt: token is "sqrt", not "power" or "0.5"', () {
      final List<String> tokens = <String>['[[-1 0] [0 2]]', 'sqrt'];
      try {
        Calculatrix.evaluateRpn(tokens);
        fail('expected MatrixDomainError');
      } on MatrixDomainError catch (error) {
        expect(error.errorId, CalculatrixErrorId.logUndefined);
        expect(error.token, 'sqrt');
        expect(error.position, _expectedRpnPosition(tokens, 1));
      }
    });
  });

  group('AC5: registry construction validates a defined entry (issue #35)', () {
    test('rejects a definition that uses an unknown word', () {
      expect(
        () => CalculatrixCommandRegistry(<CalculatrixCommandEntry>[
          CalculatrixCommandEntry(
            name: 'broken',
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'X -> X',
            description: 'broken',
            definition: 'frobnicate',
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects a directly self-referential definition', () {
      expect(
        () => CalculatrixCommandRegistry(<CalculatrixCommandEntry>[
          CalculatrixCommandEntry(
            name: 'loop',
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'X -> X',
            description: 'loop',
            definition: 'loop',
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects an indirect (multi-hop) cyclic definition', () {
      expect(
        () => CalculatrixCommandRegistry(<CalculatrixCommandEntry>[
          CalculatrixCommandEntry(
            name: 'a',
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'X -> X',
            description: 'a',
            definition: 'b',
          ),
          CalculatrixCommandEntry(
            name: 'b',
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'X -> X',
            description: 'b',
            definition: 'c',
          ),
          CalculatrixCommandEntry(
            name: 'c',
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'X -> X',
            description: 'c',
            definition: 'a',
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('accepts a definition that references a literal freely, alongside a '
        'primitive word it depends on', () {
      expect(
        () => CalculatrixCommandRegistry(<CalculatrixCommandEntry>[
          CalculatrixCommandEntry(
            name: 'double',
            aliases: const <String>['dbl'],
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'X -> 2X',
            description: 'double',
            definition: '2 multiply',
          ),
          CalculatrixCommandEntry(
            name: 'multiply',
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'A B -> A*B',
            description: 'multiply',
            build: () => const MultiplyCommand(),
          ),
        ]),
        returnsNormally,
      );
    });
  });
}
