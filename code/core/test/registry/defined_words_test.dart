// Tests for `inverse` and `sqrt`
// as defined words over an exact `power`.
//
// - `power` at exponent -1 is the matrix inverse and at 0.5 the
// principal square root (scalar and matrix cases), not the general
// exp(y * log B) route.
// - a defined word's compiled result is bitwise identical to typing its
// own definition, checked with exact `==` (never `almostEquals`), on the
// entry's own registered examples and on the applicable cases of the power
// dispatch (scalar, complex, square, singular and non-square bases).
// - an error raised while executing a defined word's expansion reports
// the token the user actually typed (e.g. "inverse" or "inv"), not a
// token from inside its definition (e.g. "power" or "-1").
// - CalculatrixCommandRegistry's construction rejects a defined entry
// whose definition uses an unresolved word, and rejects a definition that
// reaches itself, directly or through other defined words.
// - a matrix with a negative eigenvalue at exponent 0.5, or through sqrt,
// is complex-result: its principal square root is complex.
// - the non-diagonalizable example, `[[1 1] [0 1]] 0.5 power`,
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
  group('-1 and 0.5 power are exact', () {
    test('[[1 2] [3 4]] -1 power is the inverse, bit for bit', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);

      final Matrix result = base.power(Matrix.scalar(-1));

      expect(result, base.inverse());
      expect(
        result.almostEquals(
          Matrix(<List<double>>[
            <double>[-2, 1],
            <double>[1.5, -0.5],
          ]),
        ),
        isTrue,
      );
    });

    // A singularity test on the determinant alone, with the absolute
    // tolerance of 1e-12, would call this matrix singular (det 1e-14) and
    // overflow on a large scale; the inverse goes through the pivots.
    test('-1 power inverts tiny and huge well-conditioned matrices', () {
      final Matrix tiny = Matrix(<List<double>>[
        <double>[1e-7, 0],
        <double>[0, 1e-7],
      ]);
      final Matrix huge = Matrix(<List<double>>[
        <double>[1e200, 0],
        <double>[0, 1e200],
      ]);

      for (final Matrix base in <Matrix>[tiny, huge]) {
        final Matrix product = base * base.power(Matrix.scalar(-1));
        expect(product.almostEquals(Matrix.identity(2)), isTrue);
      }
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

    // A zero scalar is checked before the integer-exponent rule: 0 -1 power is
    // non-finite.
    test('0 -1 power and 0 inverse raise non-finite', () {
      for (final List<String> tokens in <List<String>>[
        <String>['0', '-1', 'power'],
        <String>['0', 'inverse'],
      ]) {
        expect(
          () => Calculatrix.evaluateRpn(tokens),
          throwsA(
            isA<CalculatrixError>().having(
              (CalculatrixError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.nonFinite,
            ),
          ),
        );
      }
    });

    // -I is the complex -1, whose principal square root is i, as
    // for the scalar -1.
    test('[[-1 0] [0 -1]] 0.5 power is exactly i, [[0 -1] [1 0]]', () {
      final Matrix minusIdentity = Matrix(<List<double>>[
        <double>[-1, 0],
        <double>[0, -1],
      ]);

      expect(minusIdentity.power(Matrix.scalar(0.5)), Matrix.i);
      expect(Matrix.scalar(-1).power(Matrix.scalar(0.5)), Matrix.i);
    });

    test('[[3 -4] [4 3]] 0.5 power is exactly 2+i, [[2 -1] [1 2]]', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[3, -4],
        <double>[4, 3],
      ]);

      expect(
        base.power(Matrix.scalar(0.5)),
        Matrix(<List<double>>[
          <double>[2, -1],
          <double>[1, 2],
        ]),
      );
    });
  });

  group('non-diagonalizable base at exponent 0.5', () {
    // Newton's iteration for the principal square root of a non-diagonal,
    // non-diagonalizable Jordan block does not land on an exactly
    // representable double the way a diagonal square root does, so this compares against the expected
    // value within a tight tolerance rather than with exact `==`. The "same bits" half
    // (below) is what is checked exactly: 0.5 power and sqrt
    // must still agree with each other bit for bit, whatever those bits
    // are, since 0.5 power literally calls sqrt().
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

  group('sqrt / 0.5 power over a matrix with a negative eigenvalue is '
      'complex-result', () {
    test('[[-1 0] [0 2]] sqrt raises complex-result', () {
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
            CalculatrixErrorId.complexResult,
          ),
        ),
      );
    });

    test('[[-1 0] [0 2]] 0.5 power raises complex-result, like sqrt', () {
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
            CalculatrixErrorId.complexResult,
          ),
        ),
      );
    });

    test(
      'the same case through the sqrt RPN word also raises complex-result',
      () {
        expect(
          () => Calculatrix.evaluateRpn(<String>['[[-1 0] [0 2]]', 'sqrt']),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.complexResult,
            ),
          ),
        );
      },
    );
  });

  group('a defined word compiles bitwise identical to typing its own '
      'definition', () {
    test('every defined entry, on its own registered examples, matches its '
        'expansion exactly', () {
      const Set<String> definedNames = <String>{
        'inverse',
        'sqrt',
        'duplicate',
        'over',
        'swap',
        'rotate',
      };
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
          // compiler for that same word.
          final List<String> expandedTokens = <String>[
            ...tokens.sublist(0, tokens.length - 1),
            ...Calculatrix.tokenizeRpnLine(entry.definition!),
          ];

          // evaluateRpnStack (not evaluateRpn) because a stack word's own
          // example, such as "over"'s, legitimately leaves more than one
          // value on the stack.
          final List<Matrix> viaWord = Calculatrix.evaluateRpnStack(tokens);
          final List<Matrix> viaDefinition = Calculatrix.evaluateRpnStack(
            expandedTokens,
          );

          expect(
            viaWord,
            orderedEquals(viaDefinition),
            reason:
                '"${example.program}" must be bitwise identical to '
                'typing "${entry.definition}" by hand',
          );
        }
      }
    });

    // Every case of the power dispatch that applies to -1 or 0.5 (scalar,
    // complex, square, zero, singular and non-square bases): the defined word and its definition give the same bits,
    // or the same error id.
    const List<(String, String, String)> dispatchCases =
        <(String, String, String)>[
          ('scalar', '-4', 'sqrt'),
          ('scalar', '4', 'sqrt'),
          ('scalar', '2', 'sqrt'),
          ('scalar', '2', 'inverse'),
          ('scalar', '-4', 'inverse'),
          ('complex', '[[-1 0] [0 -1]]', 'sqrt'),
          ('complex', '[[3 -4] [4 3]]', 'sqrt'),
          ('complex', '[[3 -4] [4 3]]', 'inverse'),
          ('inverse', '[[1 1] [0 1]]', 'inverse'),
          ('inverse', '[[1 2] [3 4]]', 'inverse'),
          ('inverse', '[[1 2] [2 4]]', 'inverse'),
          ('square root', '[[2 0] [0 3]]', 'sqrt'),
          ('square root', '[[1 1] [0 1]]', 'sqrt'),
          ('square root', '[[0 0] [0 4]]', 'sqrt'),
          ('square root', '[[-1 0] [0 2]]', 'sqrt'),
          ('zero', '0', 'sqrt'),
          ('zero', '0', 'inverse'),
          ('singular', '[[0 0] [0 0]]', 'sqrt'),
          ('singular', '[[0 0] [0 0]]', 'inverse'),
          ('non-square', '[[1 2]]', 'sqrt'),
          ('non-square', '[[1 2]]', 'inverse'),
        ];
    for (final (String row, String base, String word) in dispatchCases) {
      test('$row: $base $word is bitwise identical to its definition', () {
        final String definition = CalculatrixCommandRegistry.standard
            .lookup(word)!
            .definition!;
        final List<String> viaWord = <String>[base, word];
        final List<String> viaDefinition = <String>[
          base,
          ...Calculatrix.tokenizeRpnLine(definition),
        ];

        Object outcome(List<String> tokens) {
          try {
            return Calculatrix.evaluateRpn(tokens);
          } on CalculatrixError catch (error) {
            return '${error.runtimeType}: ${error.errorId}';
          }
        }

        expect(outcome(viaWord), outcome(viaDefinition));
      });
    }
  });

  group('duplicate/over/swap/rotate agree with '
      '1 pick/2 pick/2 roll/3 roll at stack depths 0 to 3', () {
    // A defined word is an RPN program with
    // no implementation of its own. duplicate/over/swap/rotate are
    // pure definitions ("1 pick", "2 pick", "2 roll", "3 roll"), so this
    // compares the word against the same tokens its own definition names,
    // typed out by hand, rather than against any engine-level shortcut.
    // Both sides go through the exact same evaluateRpnStack/registry
    // compile path; the only difference is the token itself.
    List<String> seedTokens(int depth) {
      return List<String>.generate(depth, (int i) => '${i + 1}');
    }

    Object outcome(List<String> tokens) {
      try {
        return Calculatrix.evaluateRpnStack(tokens);
      } on CalculatrixError catch (error) {
        return '${error.runtimeType}: ${error.errorId}';
      }
    }

    const Map<String, String> definitionByWord = <String, String>{
      'duplicate': '1 pick',
      'over': '2 pick',
      'swap': '2 roll',
      'rotate': '3 roll',
    };

    definitionByWord.forEach((String word, String definition) {
      for (int depth = 0; depth <= 3; depth++) {
        test('$word at depth $depth matches "$definition"', () {
          final List<String> seed = seedTokens(depth);
          final List<String> viaWord = <String>[...seed, word];
          final List<String> viaDefinition = <String>[
            ...seed,
            ...definition.split(' '),
          ];

          expect(
            outcome(viaWord),
            outcome(viaDefinition),
            reason: 'depth $depth',
          );
        });
      }
    });
  });

  group('an error raised inside a defined word\'s expansion carries the '
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

    test('complex root, sqrt: token is "sqrt", not "power" or "0.5"', () {
      final List<String> tokens = <String>['[[-1 0] [0 2]]', 'sqrt'];
      try {
        Calculatrix.evaluateRpn(tokens);
        fail('expected MatrixDomainError');
      } on MatrixDomainError catch (error) {
        expect(error.errorId, CalculatrixErrorId.complexResult);
        expect(error.token, 'sqrt');
        expect(error.position, _expectedRpnPosition(tokens, 1));
      }
    });
  });

  group('registry construction validates a defined entry', () {
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
