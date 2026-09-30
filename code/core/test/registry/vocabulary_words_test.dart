// Tests for issue #39 (runbook step S4d, D46): the rest of the core RPN
// vocabulary (stack words, constructors, structure edits, linear algebra,
// exp and ln), registered with 1-based indices.
//
// AC1: every new row of the runbook table "Command names" is a registry
// entry with the spec section 7 fields; aliases are exactly the table's
// (dup, rot, neg, det, norm, eig, adj); an HP-only spelling is unknown-word.
// AC2: every index is 1-based (stack levels and row/column indices), with
// the literal examples from the issue.
// AC3: counts and indices come from the stack, above their operands; a
// malformed or negative index/size is type-mismatch; an index of 0 is
// type-mismatch; a size of 0 is dimension-mismatch; an out-of-range
// row/column index is dimension-mismatch; pick/roll beyond the stack depth
// is stack-underflow; every error carries the user's token.
// AC4: the stack words, and the "one implementation per concept" equivalence
// of the four defined words with pick/roll, at stack depths 0 to 3.
// AC5: linear algebra, exp and ln give the same bits as their Matrix
// methods; multi-result words push in the table's order.
// AC6: the constructors.
// AC7: AppendRowCommand and AppendColumnCommand are not registered.
// AC8: covered by command_registry_test.dart (every example runs, infix is
// unchanged) and by the extension of defined_words_test.dart for the four
// new defined words; here, the CHANGELOG is not something a test can check.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('AC1: registry entries (issue #39)', () {
    const List<String> newWords = <String>[
      'exp',
      'ln',
      'negate',
      'pick',
      'roll',
      'drop',
      'duplicate',
      'over',
      'swap',
      'rotate',
      'zeros',
      'ones',
      'identity',
      'transpose',
      'delete-row',
      'delete-col',
      'duplicate-row',
      'duplicate-col',
      'move-row',
      'move-col',
      'determinant',
      'trace',
      'rank',
      'frobenius-norm',
      'spectral-norm',
      'eigenvalues',
      'diagonalize',
      'cofactors',
      'adjugate',
      'dot',
      'cross',
      'rref',
      'lu',
      'qr',
    ];

    test('every new word of the runbook table is registered with the spec '
        'section 7 fields', () {
      for (final String name in newWords) {
        final CalculatrixCommandEntry? entry = CalculatrixCommandRegistry
            .standard
            .lookup(name);
        expect(entry, isNotNull, reason: name);
        expect(entry!.name, name, reason: name);
        expect(entry.stackEffect, isNotEmpty, reason: name);
        expect(entry.description, isNotEmpty, reason: name);
        expect(entry.examples, isNotEmpty, reason: name);
        for (final String related in entry.seeAlso) {
          expect(
            CalculatrixCommandRegistry.standard.lookup(related),
            isNotNull,
            reason: '$name -> seeAlso "$related"',
          );
        }
      }
    });

    test('duplicate, over, swap and rotate are defined words over pick/roll '
        '(runbook D46)', () {
      expect(
        CalculatrixCommandRegistry.standard.lookup('duplicate')!.definition,
        '1 pick',
      );
      expect(
        CalculatrixCommandRegistry.standard.lookup('over')!.definition,
        '2 pick',
      );
      expect(
        CalculatrixCommandRegistry.standard.lookup('swap')!.definition,
        '2 roll',
      );
      expect(
        CalculatrixCommandRegistry.standard.lookup('rotate')!.definition,
        '3 roll',
      );
    });

    test('every other new word is primitive', () {
      const Set<String> defined = <String>{
        'duplicate',
        'over',
        'swap',
        'rotate',
      };
      for (final String name in newWords) {
        if (defined.contains(name)) {
          continue;
        }
        final CalculatrixCommandEntry entry = CalculatrixCommandRegistry
            .standard
            .lookup(name)!;
        expect(entry.isPrimitive, isTrue, reason: name);
        expect(entry.build, isNotNull, reason: name);
      }
    });

    test('aliases are exactly those of the table', () {
      const Map<String, List<String>> expectedAliases = <String, List<String>>{
        'exp': <String>[],
        'ln': <String>[],
        'negate': <String>['neg'],
        'pick': <String>[],
        'roll': <String>[],
        'drop': <String>[],
        'duplicate': <String>['dup'],
        'over': <String>[],
        'swap': <String>[],
        'rotate': <String>['rot'],
        'zeros': <String>[],
        'ones': <String>[],
        'identity': <String>[],
        'transpose': <String>[],
        'delete-row': <String>[],
        'delete-col': <String>[],
        'duplicate-row': <String>[],
        'duplicate-col': <String>[],
        'move-row': <String>[],
        'move-col': <String>[],
        'determinant': <String>['det'],
        'trace': <String>[],
        'rank': <String>[],
        'frobenius-norm': <String>['norm'],
        'spectral-norm': <String>[],
        'eigenvalues': <String>['eig'],
        'diagonalize': <String>[],
        'cofactors': <String>[],
        'adjugate': <String>['adj'],
        'dot': <String>[],
        'cross': <String>[],
        'rref': <String>[],
        'lu': <String>[],
        'qr': <String>[],
      };
      expectedAliases.forEach((String name, List<String> aliases) {
        final CalculatrixCommandEntry entry = CalculatrixCommandRegistry
            .standard
            .lookup(name)!;
        expect(entry.aliases, unorderedEquals(aliases), reason: name);
      });
    });

    // "DUP" is deliberately left out of this list: the runbook table gives
    // `duplicate` the alias `dup` (D41), and lookup is case-insensitive, so
    // "DUP" legitimately resolves through that alias, exactly like "PWR"
    // resolves to `power` (the alias-equals-HP-reference carve-out already
    // covered by command_registry_test.dart's D42 test). "TRN" and "FNORM"
    // are genuinely HP-only: transpose has no alias, and frobenius-norm's
    // only alias is "norm", not "fnorm".
    test('a genuinely HP-only spelling (TRN, FNORM) is unknown-word, never a '
        'word (D42)', () {
      for (final String hpOnly in <String>['TRN', 'FNORM']) {
        expect(
          CalculatrixCommandRegistry.standard.lookup(hpOnly),
          isNull,
          reason: hpOnly,
        );
        expect(
          () => Calculatrix.evaluateRpn(<String>['1', hpOnly]),
          throwsA(
            isA<UnknownWordError>().having(
              (UnknownWordError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.unknownWord,
            ),
          ),
          reason: hpOnly,
        );
      }
    });
  });

  group('AC7: the old typed-only append commands are not registered', () {
    test('append-row and append-column are never registry words', () {
      expect(CalculatrixCommandRegistry.standard.lookup('append-row'), isNull);
      expect(
        CalculatrixCommandRegistry.standard.lookup('append-column'),
        isNull,
      );
    });
  });

  group('AC2: 1-based indices, the issue\'s literal examples', () {
    test('[[1 2] [3 4]] 1 delete-row gives [[3 4]]', () {
      expect(
        Calculatrix.evaluateRpn(<String>['[[1 2] [3 4]]', '1', 'delete-row']),
        Matrix(<List<double>>[
          <double>[3, 4],
        ]),
      );
    });

    test('[[1 2] [3 4]] 2 1 move-row gives [[3 4] [1 2]]', () {
      expect(
        Calculatrix.evaluateRpn(<String>[
          '[[1 2] [3 4]]',
          '2',
          '1',
          'move-row',
        ]),
        Matrix(<List<double>>[
          <double>[3, 4],
          <double>[1, 2],
        ]),
      );
    });

    test('[[1 2] [3 4]] 1 duplicate-col gives [[1 1 2] [3 3 4]]', () {
      expect(
        Calculatrix.evaluateRpn(<String>[
          '[[1 2] [3 4]]',
          '1',
          'duplicate-col',
        ]),
        Matrix(<List<double>>[
          <double>[1, 1, 2],
          <double>[3, 3, 4],
        ]),
      );
    });

    test('level 1 is the top of the stack: 1 2 3 1 pick copies 3', () {
      expect(
        Calculatrix.evaluateRpnStack(<String>['1', '2', '3', '1', 'pick']),
        orderedEquals(<Matrix>[
          Matrix.scalar(1),
          Matrix.scalar(2),
          Matrix.scalar(3),
          Matrix.scalar(3),
        ]),
      );
    });
  });

  group('AC3: arguments from the stack, error ids', () {
    test('1 2 3 3 pick leaves 1 2 3 1', () {
      expect(
        Calculatrix.evaluateRpnStack(<String>['1', '2', '3', '3', 'pick']),
        orderedEquals(<Matrix>[
          Matrix.scalar(1),
          Matrix.scalar(2),
          Matrix.scalar(3),
          Matrix.scalar(1),
        ]),
      );
    });

    test('1 2 3 3 roll leaves 2 3 1', () {
      expect(
        Calculatrix.evaluateRpnStack(<String>['1', '2', '3', '3', 'roll']),
        orderedEquals(<Matrix>[
          Matrix.scalar(2),
          Matrix.scalar(3),
          Matrix.scalar(1),
        ]),
      );
    });

    test('a negative or non-integer index/size is type-mismatch', () {
      for (final List<String> tokens in <List<String>>[
        <String>['1', '2', '3', '-1', 'pick'],
        <String>['1', '2', '3', '1.5', 'pick'],
        <String>['[[1 2] [3 4]]', '-1', 'delete-row'],
        <String>['[[1 2] [3 4]]', '1.5', 'delete-row'],
        <String>['-1', '3', 'zeros'],
        <String>['2', '-1', 'zeros'],
        <String>['1.5', 'identity'],
      ]) {
        expect(
          () => Calculatrix.evaluateRpn(tokens),
          throwsA(
            isA<CalculatrixError>().having(
              (CalculatrixError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.typeMismatch,
            ),
          ),
          reason: tokens.join(' '),
        );
      }
    });

    test('an index of 0 is type-mismatch', () {
      for (final List<String> tokens in <List<String>>[
        <String>['1', '0', 'pick'],
        <String>['1', '0', 'roll'],
        <String>['[[1 2] [3 4]]', '0', 'delete-row'],
        <String>['[[1 2] [3 4]]', '0', 'delete-col'],
        <String>['[[1 2] [3 4]]', '0', 'duplicate-row'],
        <String>['[[1 2] [3 4]]', '0', 'duplicate-col'],
        <String>['[[1 2] [3 4]]', '0', '1', 'move-row'],
        <String>['[[1 2] [3 4]]', '1', '0', 'move-row'],
      ]) {
        expect(
          () => Calculatrix.evaluateRpn(tokens),
          throwsA(
            isA<CalculatrixError>().having(
              (CalculatrixError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.typeMismatch,
            ),
          ),
          reason: tokens.join(' '),
        );
      }
    });

    test('a size of 0 is dimension-mismatch, like 0 vector', () {
      for (final List<String> tokens in <List<String>>[
        <String>['0', '3', 'zeros'],
        <String>['3', '0', 'zeros'],
        <String>['0', '3', 'ones'],
        <String>['0', 'identity'],
      ]) {
        expect(
          () => Calculatrix.evaluateRpn(tokens),
          throwsA(
            isA<CalculatrixError>().having(
              (CalculatrixError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.dimensionMismatch,
            ),
          ),
          reason: tokens.join(' '),
        );
      }
    });

    test('a row or column index above the count is dimension-mismatch', () {
      for (final List<String> tokens in <List<String>>[
        <String>['[[1 2] [3 4]]', '3', 'delete-row'],
        <String>['[[1 2] [3 4]]', '3', 'delete-col'],
        <String>['[[1 2] [3 4]]', '3', 'duplicate-row'],
        <String>['[[1 2] [3 4]]', '3', 'duplicate-col'],
        <String>['[[1 2] [3 4]]', '3', '1', 'move-row'],
        <String>['[[1 2] [3 4]]', '1', '3', 'move-row'],
        <String>['[[1 2] [3 4]]', '3', '1', 'move-col'],
        <String>['[[1 2] [3 4]]', '1', '3', 'move-col'],
      ]) {
        expect(
          () => Calculatrix.evaluateRpn(tokens),
          throwsA(
            isA<CalculatrixError>().having(
              (CalculatrixError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.dimensionMismatch,
            ),
          ),
          reason: tokens.join(' '),
        );
      }
    });

    test('n pick or n roll with fewer than n values below the index is '
        'stack-underflow', () {
      for (final List<String> tokens in <List<String>>[
        <String>['1', '2', '3', 'pick'],
        <String>['1', '2', '3', 'roll'],
        <String>['3', 'pick'],
        <String>['3', 'roll'],
      ]) {
        expect(
          () => Calculatrix.evaluateRpn(tokens),
          throwsA(
            isA<CalculatrixError>().having(
              (CalculatrixError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.stackUnderflow,
            ),
          ),
          reason: tokens.join(' '),
        );
      }
    });

    test('every error carries the user\'s own token', () {
      final Map<List<String>, String> tokenByProgram = <List<String>, String>{
        <String>['1', '0', 'pick']: 'pick',
        <String>['0', 'identity']: 'identity',
        <String>['[[1 2] [3 4]]', '3', 'delete-row']: 'delete-row',
        <String>['1', '2', '3', 'pick']: 'pick',
      };
      tokenByProgram.forEach((List<String> tokens, String expectedToken) {
        try {
          Calculatrix.evaluateRpn(tokens);
          fail('expected a CalculatrixError for ${tokens.join(' ')}');
        } on CalculatrixError catch (error) {
          expect(error.token, expectedToken, reason: tokens.join(' '));
        }
      });
    });
  });

  group('AC4: stack words', () {
    test('drop removes the top', () {
      expect(
        Calculatrix.evaluateRpnStack(<String>['1', '2', 'drop']),
        orderedEquals(<Matrix>[Matrix.scalar(1)]),
      );
    });

    test('duplicate, over, swap and rotate follow the table', () {
      expect(
        Calculatrix.evaluateRpnStack(<String>['5', 'duplicate']),
        orderedEquals(<Matrix>[Matrix.scalar(5), Matrix.scalar(5)]),
      );
      expect(
        Calculatrix.evaluateRpnStack(<String>['1', '2', 'over']),
        orderedEquals(<Matrix>[
          Matrix.scalar(1),
          Matrix.scalar(2),
          Matrix.scalar(1),
        ]),
      );
      expect(
        Calculatrix.evaluateRpnStack(<String>['1', '2', 'swap']),
        orderedEquals(<Matrix>[Matrix.scalar(2), Matrix.scalar(1)]),
      );
      expect(
        Calculatrix.evaluateRpnStack(<String>['1', '2', '3', 'rotate']),
        orderedEquals(<Matrix>[
          Matrix.scalar(2),
          Matrix.scalar(3),
          Matrix.scalar(1),
        ]),
      );
    });

    // AC4's "one implementation per concept" equivalence at stack depths 0
    // to 3, comparing duplicate/over/swap/rotate directly against
    // "1 pick"/"2 pick"/"2 roll"/"3 roll", plus the session's dup/over/
    // swap/rot actions, lives in defined_words_test.dart and
    // calculatrix_session_test.dart alongside the rest of their own
    // defined-word and session-action coverage (issue #39).
  });

  group('AC5: linear algebra, exp, ln give the same bits as their Matrix '
      'method', () {
    test('transpose, determinant, trace, rank, frobenius-norm, '
        'spectral-norm, eigenvalues, cofactors, adjugate, rref', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);

      expect(
        Calculatrix.evaluateRpn(<String>['[[1 2] [3 4]]', 'transpose']),
        a.transpose(),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['[[1 2] [3 4]]', 'determinant']),
        a.determinant(),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['[[1 2] [3 4]]', 'trace']),
        a.trace(),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['[[1 2] [3 4]]', 'rank']),
        a.rank(),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['[[1 2] [3 4]]', 'frobenius-norm']),
        a.frobeniusNorm(),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['[[1 2] [3 4]]', 'spectral-norm']),
        a.spectralNorm(),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['[[1 2] [3 4]]', 'eigenvalues']),
        a.eigenvalues(),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['[[1 2] [3 4]]', 'cofactors']),
        a.cofactorMatrix(),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['[[1 2] [3 4]]', 'adjugate']),
        a.adjugate(),
      );

      final Matrix singular = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[2, 4],
      ]);
      expect(
        Calculatrix.evaluateRpn(<String>['[[1 2] [2 4]]', 'rref']),
        singular.rref(),
      );
    });

    test('dot and cross', () {
      final Matrix v1 = Matrix(<List<double>>[
        <double>[1],
        <double>[2],
        <double>[3],
      ]);
      final Matrix v2 = Matrix(<List<double>>[
        <double>[4],
        <double>[5],
        <double>[6],
      ]);

      expect(
        Calculatrix.evaluateRpn(<String>[
          '1',
          '2',
          '3',
          '3',
          'vector',
          '4',
          '5',
          '6',
          '3',
          'vector',
          'dot',
        ]),
        v1.dot(v2),
      );
      expect(
        Calculatrix.evaluateRpn(<String>[
          '1',
          '2',
          '3',
          '3',
          'vector',
          '4',
          '5',
          '6',
          '3',
          'vector',
          'cross',
        ]),
        v1.cross(v2),
      );
    });

    test('exp and ln, keeping their current errors', () {
      expect(Calculatrix.evaluateRpn(<String>['1', 'ln']), Matrix.scalar(0));
      expect(
        () => Calculatrix.evaluateRpn(<String>['0', 'ln']),
        throwsA(
          isA<CalculatrixError>().having(
            (CalculatrixError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.logUndefined,
          ),
        ),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['[[1 2] [3 4]]', 'exp']),
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
        ]).exp(),
      );
    });

    test('diagonalize leaves P D, with D on level 1', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[3, 0],
        <double>[0, 5],
      ]);
      final Diagonalization diagonalization = a.diagonalization();

      expect(
        Calculatrix.evaluateRpnStack(<String>['[[3 0] [0 5]]', 'diagonalize']),
        orderedEquals(<Matrix>[diagonalization.p, diagonalization.d]),
      );
    });

    test('lu leaves P L U, with U on level 1', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[1, 0],
        <double>[0, 1],
      ]);
      final LuDecomposition decomposition = a.luDecomposition();

      expect(
        Calculatrix.evaluateRpnStack(<String>['[[1 0] [0 1]]', 'lu']),
        orderedEquals(<Matrix>[
          decomposition.permutation,
          decomposition.lower,
          decomposition.upper,
        ]),
      );
    });

    test('qr leaves Q R, with R on level 1', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[1, 0],
        <double>[0, 1],
      ]);
      final QrDecomposition decomposition = a.qrDecomposition();

      expect(
        Calculatrix.evaluateRpnStack(<String>['[[1 0] [0 1]]', 'qr']),
        orderedEquals(<Matrix>[decomposition.q, decomposition.r]),
      );
    });
  });

  group('AC6: constructors', () {
    test('2 3 zeros gives the 2x3 zero matrix', () {
      expect(
        Calculatrix.evaluateRpn(<String>['2', '3', 'zeros']),
        Matrix.zeros(2, 3),
      );
    });

    test('2 2 ones gives [[1 1] [1 1]]', () {
      expect(
        Calculatrix.evaluateRpn(<String>['2', '2', 'ones']),
        Matrix(<List<double>>[
          <double>[1, 1],
          <double>[1, 1],
        ]),
      );
    });

    test('3 identity gives the 3x3 identity', () {
      expect(
        Calculatrix.evaluateRpn(<String>['3', 'identity']),
        Matrix.identity(3),
      );
    });
  });

  group('typed commands through the machine (issue #39)', () {
    test('PickWordCommand and PickCommand(n) agree, sharing RpnEngine.pick '
        '(D44)', () {
      final CalculatrixMachine viaWord = CalculatrixMachine();
      viaWord.executeAll(<CalculatrixCommand>[
        const PushScalarCommand(1),
        const PushScalarCommand(2),
        const PushScalarCommand(3),
        const PushScalarCommand(2),
        const PickWordCommand(),
      ]);

      final CalculatrixMachine viaTyped = CalculatrixMachine();
      viaTyped.executeAll(<CalculatrixCommand>[
        const PushScalarCommand(1),
        const PushScalarCommand(2),
        const PushScalarCommand(3),
        const PickCommand(2),
      ]);

      expect(viaWord.stackSnapshot, viaTyped.stackSnapshot);
    });

    test('MoveRowWordCommand and MoveRowCommand(from, to) agree, sharing '
        'Matrix.moveRow (D44)', () {
      final Matrix a = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);

      final CalculatrixMachine viaWord = CalculatrixMachine();
      viaWord.executeAll(<CalculatrixCommand>[
        PushMatrixCommand(a),
        const PushScalarCommand(2),
        const PushScalarCommand(1),
        const MoveRowWordCommand(),
      ]);

      final CalculatrixMachine viaTyped = CalculatrixMachine();
      viaTyped.executeAll(<CalculatrixCommand>[
        PushMatrixCommand(a),
        const MoveRowCommand(1, 0),
      ]);

      expect(viaWord.stackSnapshot, viaTyped.stackSnapshot);
    });

    test('ZerosCommand and PushZerosCommand agree, sharing Matrix.zeros '
        '(D44)', () {
      final CalculatrixMachine viaWord = CalculatrixMachine();
      viaWord.executeAll(<CalculatrixCommand>[
        const PushScalarCommand(2),
        const PushScalarCommand(3),
        const ZerosCommand(),
      ]);

      final CalculatrixMachine viaTyped = CalculatrixMachine();
      viaTyped.execute(const PushZerosCommand(2, 3));

      expect(viaWord.stackSnapshot, viaTyped.stackSnapshot);
    });

    test('a stack-driven word restores every popped operand on failure '
        '(atomicity, reused from CalculatrixMachine.execute)', () {
      final CalculatrixMachine machine = CalculatrixMachine();
      final Matrix a = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);
      machine.execute(PushMatrixCommand(a));
      machine.execute(const PushScalarCommand(5));

      expect(
        () => machine.execute(const DeleteRowWordCommand()),
        throwsA(
          isA<CalculatrixError>().having(
            (CalculatrixError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
      expect(
        machine.stackSnapshot,
        orderedEquals(<Matrix>[a, Matrix.scalar(5)]),
      );
    });
  });
}
