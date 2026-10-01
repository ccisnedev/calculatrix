// Tests for issue #37 (runbook step S4c): vector, rows, append-cols and
// append-rows.
//
// AC1: the four words are registry entries with the spec section 7 fields,
// category `matrix`, no aliases, the documented search terms and HP 50g
// references; using a search term in a program raises unknown-word.
// AC2: vector's success and error cases, including the "0 vector" decision.
// AC3: rows' success cases (the round-trip test lives in
// calculatrix_machine_test.dart, since it needs typed commands: "drop" is
// not a registered RPN word yet).
// AC4: append-cols' success and dimension-mismatch cases.
// AC5: append-rows' success and dimension-mismatch cases.
// AC6: Matrix.appendRows/appendColumns are the single implementation behind
// appendRow/appendColumn and the new words alike.
// AC7: errors raised by the new words carry the user's own token.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('AC1: registry entries (issue #37)', () {
    test('vector, rows, append-cols and append-rows are matrix-category '
        'entries with no aliases', () {
      for (final String name in <String>[
        'vector',
        'rows',
        'append-cols',
        'append-rows',
      ]) {
        final CalculatrixCommandEntry? entry = CalculatrixCommandRegistry
            .standard
            .lookup(name);
        expect(entry, isNotNull, reason: name);
        expect(entry!.name, name);
        expect(entry.aliases, isEmpty, reason: name);
        expect(entry.category, CalculatrixCommandCategory.matrix, reason: name);
        expect(entry.isPrimitive, isTrue, reason: name);
        expect(entry.stackEffect, isNotEmpty, reason: name);
        expect(entry.description, isNotEmpty, reason: name);
        expect(entry.examples, isNotEmpty, reason: name);
      }
    });

    test('vector and rows carry their HP 50g references, the append words '
        'carry none', () {
      expect(
        CalculatrixCommandRegistry.standard.lookup('vector')!.hp50gReference,
        '→ARRY',
      );
      expect(
        CalculatrixCommandRegistry.standard.lookup('rows')!.hp50gReference,
        'ROW→',
      );
      expect(
        CalculatrixCommandRegistry.standard
            .lookup('append-cols')!
            .hp50gReference,
        isNull,
      );
      expect(
        CalculatrixCommandRegistry.standard
            .lookup('append-rows')!
            .hp50gReference,
        isNull,
      );
    });

    test('append-cols and append-rows carry the documented search terms', () {
      expect(
        CalculatrixCommandRegistry.standard.lookup('append-cols')!.searchTerms,
        containsAll(<String>['hcat', 'horzcat', 'concatenate', 'column']),
      );
      expect(
        CalculatrixCommandRegistry.standard.lookup('append-rows')!.searchTerms,
        containsAll(<String>['vcat', 'vertcat', 'concatenate', 'row']),
      );
    });

    test('a search term is never a resolvable word: using one raises '
        'unknown-word', () {
      for (final String searchTerm in <String>[
        'hcat',
        'horzcat',
        'vcat',
        'vertcat',
        'concatenate',
      ]) {
        expect(
          CalculatrixCommandRegistry.standard.lookup(searchTerm),
          isNull,
          reason: searchTerm,
        );
        expect(
          () => Calculatrix.evaluateRpn(<String>['[[1]]', '[[2]]', searchTerm]),
          throwsA(
            isA<UnknownWordError>().having(
              (UnknownWordError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.unknownWord,
            ),
          ),
          reason: searchTerm,
        );
      }
    });
  });

  group('AC2: vector', () {
    test('0 1 2 vector gives the 2x1 column [[0] [1]]', () {
      expect(
        Calculatrix.evaluateRpn(<String>['0', '1', '2', 'vector']),
        Matrix(<List<double>>[
          <double>[0],
          <double>[1],
        ]),
      );
    });

    test('5 1 vector gives the 1x1 column [[5]]', () {
      expect(
        Calculatrix.evaluateRpn(<String>['5', '1', 'vector']),
        Matrix(<List<double>>[
          <double>[5],
        ]),
      );
    });

    test('1 2 3 3 vector gives the 3x1 column [[1] [2] [3]]', () {
      expect(
        Calculatrix.evaluateRpn(<String>['1', '2', '3', '3', 'vector']),
        Matrix(<List<double>>[
          <double>[1],
          <double>[2],
          <double>[3],
        ]),
      );
    });

    test('0 vector raises dimension-mismatch: an empty column is not '
        'representable', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>['0', 'vector']),
        throwsA(
          isA<CalculatrixError>().having(
            (CalculatrixError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });

    test('a negative or non-integer count is type-mismatch', () {
      for (final List<String> tokens in <List<String>>[
        <String>['1', '-1', 'vector'],
        <String>['1', '1.5', 'vector'],
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

    test('a non-scalar count is type-mismatch', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>['1', '[[1 2]]', 'vector']),
        throwsA(
          isA<CalculatrixError>().having(
            (CalculatrixError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.typeMismatch,
          ),
        ),
      );
    });

    test('fewer than n items below the count is stack-underflow', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>['1', '3', 'vector']),
        throwsA(
          isA<CalculatrixError>().having(
            (CalculatrixError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.stackUnderflow,
          ),
        ),
      );
    });

    test(
      '1 2 3 vector names the real need, 3 values short by 1, not the '
      'engine pop\'s own generic "needs 1 value, found 0" (issue #51, AC5 '
      'regression: the count says 3, only 2 data values remain)',
      () {
        expect(
          () => Calculatrix.evaluateRpn(<String>['1', '2', '3', 'vector']),
          throwsA(
            isA<CalculatrixError>().having(
              (CalculatrixError error) => error.message,
              'message',
              'vector needs 3 values on the stack, found 2.',
            ),
          ),
        );
      },
    );

    test('an operand that is not a scalar is type-mismatch', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>['[[1 2]]', '5', '2', 'vector']),
        throwsA(
          isA<CalculatrixError>().having(
            (CalculatrixError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.typeMismatch,
          ),
        ),
      );
    });
  });

  group('AC3: rows', () {
    test('[[1 2] [3 4]] rows leaves two 1x2 rows and the count 2', () {
      expect(
        Calculatrix.evaluateRpnStack(<String>['[[1 2] [3 4]]', 'rows']),
        orderedEquals(<Matrix>[
          Matrix(<List<double>>[
            <double>[1, 2],
          ]),
          Matrix(<List<double>>[
            <double>[3, 4],
          ]),
          Matrix.scalar(2),
        ]),
      );
    });

    test('7 rows leaves 7 and the count 1', () {
      expect(
        Calculatrix.evaluateRpnStack(<String>['7', 'rows']),
        orderedEquals(<Matrix>[Matrix.scalar(7), Matrix.scalar(1)]),
      );
    });

    test('rows on an empty stack is stack-underflow', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>['rows']),
        throwsA(
          isA<CalculatrixError>().having(
            (CalculatrixError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.stackUnderflow,
          ),
        ),
      );
    });
  });

  group('AC4: append-cols', () {
    test('the spec example: two column vectors side by side', () {
      expect(
        Calculatrix.evaluateRpn(<String>[
          '0',
          '1',
          '2',
          'vector',
          '-1',
          '0',
          '2',
          'vector',
          'append-cols',
        ]),
        Matrix(<List<double>>[
          <double>[0, -1],
          <double>[1, 0],
        ]),
      );
    });

    test('a 2x2 and a 2x3 matrix append to a 2x5 matrix', () {
      expect(
        Calculatrix.evaluateRpn(<String>[
          '[[1 2] [3 4]]',
          '[[5 6 7] [8 9 10]]',
          'append-cols',
        ]),
        Matrix(<List<double>>[
          <double>[1, 2, 5, 6, 7],
          <double>[3, 4, 8, 9, 10],
        ]),
      );
    });

    test('different row counts raise dimension-mismatch', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>[
          '[[1 2]]',
          '[[3] [4]]',
          'append-cols',
        ]),
        throwsA(
          isA<CalculatrixError>().having(
            (CalculatrixError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });
  });

  group('AC5: append-rows', () {
    test('a 1x2 and a 2x2 matrix append to a 3x2 matrix', () {
      expect(
        Calculatrix.evaluateRpn(<String>[
          '[[1 2]]',
          '[[3 4] [5 6]]',
          'append-rows',
        ]),
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
          <double>[5, 6],
        ]),
      );
    });

    test('different column counts raise dimension-mismatch', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>[
          '[[1 2]]',
          '[[3 4 5]]',
          'append-rows',
        ]),
        throwsA(
          isA<CalculatrixError>().having(
            (CalculatrixError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });
  });

  group('AC6: one implementation per concept (D44)', () {
    test('Matrix.appendRow and Matrix.appendRows agree for a single row', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);
      final Matrix row = Matrix(<List<double>>[
        <double>[5, 6],
      ]);

      expect(base.appendRow(row), base.appendRows(row));
    });

    test('Matrix.appendColumn and Matrix.appendColumns agree for a single '
        'column', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);
      final Matrix column = Matrix(<List<double>>[
        <double>[5],
        <double>[6],
      ]);

      expect(base.appendColumn(column), base.appendColumns(column));
    });

    test('appendRows generalizes to any matching matrix, not just a single '
        'row', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
      ]);
      final Matrix rows = Matrix(<List<double>>[
        <double>[3, 4],
        <double>[5, 6],
      ]);

      expect(
        base.appendRows(rows),
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
          <double>[5, 6],
        ]),
      );
    });

    test('appendColumns generalizes to any matching matrix, not just a '
        'single column', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1],
        <double>[2],
      ]);
      final Matrix columns = Matrix(<List<double>>[
        <double>[3, 4],
        <double>[5, 6],
      ]);

      expect(
        base.appendColumns(columns),
        Matrix(<List<double>>[
          <double>[1, 3, 4],
          <double>[2, 5, 6],
        ]),
      );
    });

    test('appendRow still rejects a multi-row operand', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1, 2],
      ]);
      final Matrix twoRows = Matrix(<List<double>>[
        <double>[3, 4],
        <double>[5, 6],
      ]);

      expect(() => base.appendRow(twoRows), throwsA(isA<MatrixShapeError>()));
    });

    test('appendColumn still rejects a multi-column operand', () {
      final Matrix base = Matrix(<List<double>>[
        <double>[1],
        <double>[2],
      ]);
      final Matrix twoColumns = Matrix(<List<double>>[
        <double>[3, 4],
        <double>[5, 6],
      ]);

      expect(
        () => base.appendColumn(twoColumns),
        throwsA(isA<MatrixShapeError>()),
      );
    });
  });

  group('AC7: errors carry the user\'s own token', () {
    test('a dimension-mismatch from append-cols reports "append-cols"', () {
      try {
        Calculatrix.evaluateRpn(<String>[
          '[[1 2]]',
          '[[3] [4]]',
          'append-cols',
        ]);
        fail('expected a CalculatrixError');
      } on CalculatrixError catch (error) {
        expect(error.token, 'append-cols');
      }
    });

    test('a dimension-mismatch from append-rows reports "append-rows"', () {
      try {
        Calculatrix.evaluateRpn(<String>[
          '[[1 2]]',
          '[[3 4 5]]',
          'append-rows',
        ]);
        fail('expected a CalculatrixError');
      } on CalculatrixError catch (error) {
        expect(error.token, 'append-rows');
      }
    });

    test('a type-mismatch from vector reports "vector"', () {
      try {
        Calculatrix.evaluateRpn(<String>['1', '-1', 'vector']);
        fail('expected a CalculatrixError');
      } on CalculatrixError catch (error) {
        expect(error.token, 'vector');
      }
    });

    test('a stack-underflow from rows reports "rows"', () {
      try {
        Calculatrix.evaluateRpn(<String>['rows']);
        fail('expected a CalculatrixError');
      } on CalculatrixError catch (error) {
        expect(error.token, 'rows');
      }
    });
  });

  group('typed commands through the machine (issue #37)', () {
    test('rows then append-rows round-trips a matrix through the engine '
        '(issue #37, AC3)', () {
      // "drop" is not a registered RPN word yet, so the round trip is
      // driven through typed commands directly, exactly the pattern the
      // issue calls for.
      final CalculatrixMachine machine = CalculatrixMachine();
      final Matrix original = Matrix(<List<double>>[
        <double>[1, 2],
        <double>[3, 4],
      ]);

      machine.execute(PushMatrixCommand(original));
      machine.execute(const RowsCommand());

      expect(
        machine.stackSnapshot,
        orderedEquals(<Matrix>[
          Matrix(<List<double>>[
            <double>[1, 2],
          ]),
          Matrix(<List<double>>[
            <double>[3, 4],
          ]),
          Matrix.scalar(2),
        ]),
      );

      machine.execute(const DropCommand());
      machine.execute(const AppendRowsCommand());

      expect(machine.depth, 1);
      expect(machine.top, original);
    });
    test(
      'builds a column vector through a typed VectorCommand (issue #37, AC2)',
      () {
        final CalculatrixMachine machine = CalculatrixMachine();

        machine.executeAll(<CalculatrixCommand>[
          const PushScalarCommand(1),
          const PushScalarCommand(2),
          const PushScalarCommand(3),
          const PushScalarCommand(3),
          const VectorCommand(),
        ]);

        expect(
          machine.top,
          Matrix(<List<double>>[
            <double>[1],
            <double>[2],
            <double>[3],
          ]),
        );
      },
    );
    test('appends any matching matrix through AppendColsCommand and '
        'AppendRowsCommand (issue #37, AC4, AC5)', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.executeAll(<CalculatrixCommand>[
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[1, 2],
            <double>[3, 4],
          ]),
        ),
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[5, 6, 7],
            <double>[8, 9, 10],
          ]),
        ),
        const AppendColsCommand(),
      ]);

      expect(
        machine.top,
        Matrix(<List<double>>[
          <double>[1, 2, 5, 6, 7],
          <double>[3, 4, 8, 9, 10],
        ]),
      );

      machine.clear();
      machine.executeAll(<CalculatrixCommand>[
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[1, 2],
          ]),
        ),
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[3, 4],
            <double>[5, 6],
          ]),
        ),
        const AppendRowsCommand(),
      ]);

      expect(
        machine.top,
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
          <double>[5, 6],
        ]),
      );
    });
    test('AppendRowsCommand restores both operands when column counts differ '
        '(issue #37, AC5)', () {
      final CalculatrixMachine machine = CalculatrixMachine();
      final Matrix a = Matrix(<List<double>>[
        <double>[1, 2],
      ]);
      final Matrix b = Matrix(<List<double>>[
        <double>[3, 4, 5],
      ]);

      machine.execute(PushMatrixCommand(a));
      machine.execute(PushMatrixCommand(b));

      expect(
        () => machine.execute(const AppendRowsCommand()),
        throwsA(isA<MatrixShapeError>()),
      );
      expect(machine.stackSnapshot, orderedEquals(<Matrix>[a, b]));
    });
    test('AppendColsCommand restores both operands when row counts differ '
        '(issue #37, AC4)', () {
      final CalculatrixMachine machine = CalculatrixMachine();
      final Matrix a = Matrix(<List<double>>[
        <double>[1],
        <double>[2],
      ]);
      final Matrix b = Matrix(<List<double>>[
        <double>[3],
      ]);

      machine.execute(PushMatrixCommand(a));
      machine.execute(PushMatrixCommand(b));

      expect(
        () => machine.execute(const AppendColsCommand()),
        throwsA(isA<MatrixShapeError>()),
      );
      expect(machine.stackSnapshot, orderedEquals(<Matrix>[a, b]));
    });
    test('VectorCommand restores every popped operand when the count exceeds '
        'the stack (issue #37, AC2)', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.execute(const PushScalarCommand(1));
      machine.execute(const PushScalarCommand(3));

      expect(
        () => machine.execute(const VectorCommand()),
        throwsA(isA<RpnStackUnderflowError>()),
      );
      expect(
        machine.stackSnapshot,
        orderedEquals(<Matrix>[Matrix.scalar(1), Matrix.scalar(3)]),
      );
    });
  });
}
