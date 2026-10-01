import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  late CalculatrixSession session;

  setUp(() {
    session = CalculatrixSession();
  });

  group('CalculatrixSession - memory', () {
    test('memory is initially empty', () {
      expect(session.hasMemory, isFalse);
      expect(session.memoryValue, isNull);
    });

    test('M+ stores a committed matrix in memory', () {
      session.insertMatrixLiteral('[[1,2],[3,4]]');
      session.evaluate();

      session.memoryAdd();

      expect(session.hasMemory, isTrue);
      expect(
        session.memoryValue,
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
        ]),
      );
    });

    test('MR recalls matrix memory into the infix draft', () {
      session.insertMatrixLiteral('[[1,2],[3,4]]');
      session.evaluate();
      session.memoryAdd();
      session.clear();

      session.memoryRecall();

      expect(session.expression, '[[1,2],[3,4]]');
    });

    test('MR pushes matrix memory onto the rpn stack', () {
      session.insertMatrixLiteral('[[1,2],[3,4]]');
      session.evaluate();
      session.memoryAdd();

      session.setMode(CalculatrixMode.rpn);
      session.memoryRecall();

      expect(session.rpnStackDepth, 2);
      expect(
        session.rpnTopValue,
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
        ]),
      );
    });

    test('M- on empty memory stores the negated matrix', () {
      session.insertMatrixLiteral('[[1,2],[3,4]]');
      session.evaluate();

      session.memorySubtract();

      expect(session.hasMemory, isTrue);
      expect(
        session.memoryValue,
        Matrix(<List<double>>[
          <double>[-1, -2],
          <double>[-3, -4],
        ]),
      );
    });
  });

  group('CalculatrixSession - infix calculator actions', () {
    test('sqrt rewrites a bare infix operand immediately', () {
      session.input('9');

      session.input('√');

      expect(session.expression, '3');
      expect(session.currentValue, isNull);
    });

    test('sqrt rewrites the trailing operand of an infix expression', () {
      session.input('9');
      session.input('+');
      session.input('1');
      session.input('6');

      session.input('√');

      expect(session.expression, '9+4');

      session.evaluate();

      expect(session.currentValue, Matrix.scalar(13));
    });

    test('sqrt of negative bare operand returns imaginary unit', () {
      session.input('1');
      session.toggleSign();

      session.input('√');

      expect(session.hasError, isFalse);
      expect(session.expression, '[[0,-1],[1,0]]');

      session.evaluate();
      expect(session.currentValue, Matrix.i);
    });

    test('sqrt applies immediately to the committed infix value', () {
      session.input('1');
      session.input('4');
      session.input('4');
      session.evaluate();

      session.input('√');

      expect(session.expression, '');
      expect(session.currentValue, Matrix.scalar(12));
    });

    test('percent keeps a bare infix operand pending for casio-style flow', () {
      session.input('5');
      session.input('0');

      session.input('%');

      expect(session.expression, '50%');
      expect(session.currentValue, isNull);
    });

    test('percent evaluates a bare infix operand as a fraction on equals', () {
      session.input('5');
      session.input('0');
      session.input('%');

      session.evaluate();

      expect(session.expression, '');
      expect(session.currentValue, Matrix.scalar(0.5));
    });

    test('percent supports casio-style x percent y flow', () {
      session.input('1');
      session.input('2');
      session.input('%');
      session.input('5');
      session.input('0');

      expect(session.expression, '12%50');

      session.evaluate();

      expect(session.currentValue, Matrix.scalar(6));
    });

    test('percent evaluates additive infix context relative to the left operand', () {
      session.input('5');
      session.input('0');
      session.input('+');
      session.input('1');
      session.input('2');

      session.input('%');

      expect(session.expression, '50+12%');

      session.evaluate();

      expect(session.currentValue, Matrix.scalar(56));
    });

    test('percent evaluates multiplicative infix context as a fractional scalar', () {
      session.input('5');
      session.input('0');
      session.input('×');
      session.input('1');
      session.input('2');

      session.input('%');

      expect(session.expression, '50×12%');

      session.evaluate();

      expect(session.currentValue, Matrix.scalar(6));
    });
  });

  group('CalculatrixSession - shared current value', () {
    test('switching to rpn keeps an infix draft private and uncommitted', () {
      session.input('3');
      session.input('+');
      session.input('4');

      session.setMode(CalculatrixMode.rpn);

      expect(session.expression, '');
      expect(session.currentValue, isNull);
      expect(session.rpnStackDepth, 0);

      session.setMode(CalculatrixMode.infix);

      expect(session.expression, '3+4');
    });

    test('switching away from rpn keeps the rpn draft private and uncommitted', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('42');

      session.setMode(CalculatrixMode.infix);

      expect(session.expression, '');
      expect(session.currentValue, isNull);

      session.setMode(CalculatrixMode.rpn);

      expect(session.expression, '42');
      expect(session.rpnStackDepth, 0);
    });

    test('switching from infix to rpn preserves committed current value', () {
      session.input('3');
      session.input('+');
      session.input('4');
      session.evaluate();

      session.setMode(CalculatrixMode.rpn);

      expect(session.currentValue, Matrix.scalar(7));
      expect(session.rpnStackDepth, 1);
      expect(session.rpnTopValue, Matrix.scalar(7));
    });

    test('switching back to infix uses the current rpn top as next operand seed', () {
      session.input('3');
      session.input('+');
      session.input('4');
      session.evaluate();
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.enter();
      session.applyRpnBinary(RpnBinaryOperator.add);

      session.setMode(CalculatrixMode.infix);
      session.input('+');

      expect(session.expression, '9+');
    });

    test('rpn binary actions commit the draft and execute through the machine', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('3');
      session.enter();
      session.input('4');

      session.applyRpnBinary(RpnBinaryOperator.add);

      expect(session.rpnDraft, '');
      expect(session.rpnStackDepth, 1);
      expect(session.rpnTopValue, Matrix.scalar(7));
      expect(session.currentValue, Matrix.scalar(7));
    });

    test('rpn stack commands keep the stack synchronized through the machine', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('1');
      session.enter();
      session.input('2');
      session.enter();
      session.input('3');
      session.enter();

      session.rotRpn();

      expect(
        session.rpnStack,
        orderedEquals(<Matrix>[
          Matrix.scalar(2),
          Matrix.scalar(3),
          Matrix.scalar(1),
        ]),
      );
      expect(session.currentValue, Matrix.scalar(1));
    });

    test('rpn enter without a draft duplicates the top like the HP 50g', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('5');
      session.enter();

      session.enter();

      expect(
        session.rpnStack,
        orderedEquals(<Matrix>[Matrix.scalar(5), Matrix.scalar(5)]),
      );
      expect(session.currentValue, Matrix.scalar(5));
      expect(session.hasError, isFalse);
    });

    test('rpn enter without a draft on an empty stack does nothing', () {
      session.setMode(CalculatrixMode.rpn);

      session.enter();

      expect(session.rpnStackDepth, 0);
      expect(session.hasError, isFalse);
    });
  });

  group('CalculatrixSession - rpn SPC key', () {
    test('SPC appends a single space to the rpn draft', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');

      session.appendSpace();

      expect(session.rpnDraft, '2 ');
    });

    test('SPC does nothing when the rpn draft is empty', () {
      session.setMode(CalculatrixMode.rpn);

      session.appendSpace();

      expect(session.rpnDraft, '');
    });

    test('SPC does nothing when the rpn draft already ends with a space', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();

      session.appendSpace();

      expect(session.rpnDraft, '2 ');
    });

    test('SPC is a no-op in infix mode', () {
      session.input('2');

      session.appendSpace();

      expect(session.expression, '2');
    });

    test('ENTER splits the draft on spaces and pushes tokens left to right', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('3');

      session.enter();

      expect(
        session.rpnStack,
        orderedEquals(<Matrix>[Matrix.scalar(2), Matrix.scalar(3)]),
      );
      expect(session.rpnDraft, '');
      expect(session.hasError, isFalse);
    });

    test('an operation commits a spaced draft the same way ENTER does', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('3');

      session.applyRpnBinary(RpnBinaryOperator.add);

      expect(session.rpnStackDepth, 1);
      expect(session.rpnTopValue, Matrix.scalar(5));
      expect(session.rpnDraft, '');
    });

    test('an invalid token pushes nothing and keeps the draft as typed on enter', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('abc');

      session.enter();

      expect(session.rpnDraft, '2 abc');
      expect(session.rpnStackDepth, 0);
      expect(session.hasError, isTrue);
      expect(session.lastError, isA<CalculatrixError>());
    });

    test('an invalid token in a spaced draft leaves the stack untouched before an operation', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('abc');

      session.applyRpnBinary(RpnBinaryOperator.add);

      expect(session.rpnDraft, '2 abc');
      expect(session.rpnStackDepth, 0);
      expect(session.hasError, isTrue);
    });

    test('backspace removes the trailing space from the draft', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();

      session.backspace();

      expect(session.rpnDraft, '2');
    });

    test('inserting a matrix literal is unaffected by a pending spaced draft', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('3');

      session.insertMatrixLiteral('[[1,2],[3,4]]');

      expect(session.rpnDraft, '');
      expect(session.rpnStackDepth, 1);
      expect(
        session.rpnTopValue,
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
        ]),
      );
    });
  });

  group('CalculatrixSession - rpn multi-token sign toggle', () {
    test('toggleSign negates only the last space-delimited token', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('3');

      session.toggleSign();

      expect(session.rpnDraft, '2 -3');

      session.enter();

      expect(
        session.rpnStack,
        orderedEquals(<Matrix>[Matrix.scalar(2), Matrix.scalar(-3)]),
      );
    });

    test('toggleSign twice on the last token returns it to its original sign', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('3');

      session.toggleSign();
      session.toggleSign();

      expect(session.rpnDraft, '2 3');
    });

    test(
      'toggleSign on an empty last token after a trailing SPC starts a negative '
      'operand',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('2');
        session.appendSpace();

        session.toggleSign();

        expect(session.rpnDraft, '2 -');

        session.input('3');

        expect(session.rpnDraft, '2 -3');
      },
    );

    test('toggleSign twice on an empty last token returns to the empty token', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();

      session.toggleSign();
      session.toggleSign();

      expect(session.rpnDraft, '2 ');
    });

    test(
      'committing a lone dash left by toggling an empty token surfaces a typed '
      'error and pushes nothing',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('2');
        session.appendSpace();
        session.toggleSign();

        session.enter();

        expect(session.rpnDraft, '2 -');
        expect(session.rpnStackDepth, 0);
        expect(session.hasError, isTrue);
        expect(session.lastError, isA<CalculatrixError>());
      },
    );
  });

  group('CalculatrixSession - rpn action keys commit the draft first', () {
    void seedMemoryWithNine() {
      session.insertMatrixLiteral('9');
      session.evaluate();
      session.memoryAdd();
      session.clear();
    }

    test('MR commits a pending multi-token draft before recalling memory', () {
      seedMemoryWithNine();

      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('3');

      session.memoryRecall();

      expect(
        session.rpnStack,
        orderedEquals(<Matrix>[
          Matrix.scalar(2),
          Matrix.scalar(3),
          Matrix.scalar(9),
        ]),
      );
      expect(session.rpnDraft, '');
      expect(session.hasError, isFalse);
    });

    test(
      'MR with an invalid pending draft surfaces a typed error and does not '
      'recall memory',
      () {
        seedMemoryWithNine();

        session.setMode(CalculatrixMode.rpn);
        session.input('2');
        session.appendSpace();
        session.input('abc');

        session.memoryRecall();

        expect(session.rpnDraft, '2 abc');
        expect(session.rpnStackDepth, 0);
        expect(session.hasError, isTrue);
        expect(session.lastError, isA<CalculatrixError>());
      },
    );

    test('MC commits a pending multi-token draft before clearing memory', () {
      seedMemoryWithNine();

      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('3');

      session.memoryClear();

      expect(
        session.rpnStack,
        orderedEquals(<Matrix>[Matrix.scalar(2), Matrix.scalar(3)]),
      );
      expect(session.rpnDraft, '');
      expect(session.hasMemory, isFalse);
      expect(session.hasError, isFalse);
    });

    test(
      'MC with an invalid pending draft surfaces a typed error and leaves '
      'memory unchanged',
      () {
        seedMemoryWithNine();

        session.setMode(CalculatrixMode.rpn);
        session.input('2');
        session.appendSpace();
        session.input('abc');

        session.memoryClear();

        expect(session.rpnDraft, '2 abc');
        expect(session.rpnStackDepth, 0);
        expect(session.hasMemory, isTrue);
        expect(session.memoryValue, Matrix.scalar(9));
        expect(session.hasError, isTrue);
        expect(session.lastError, isA<CalculatrixError>());
      },
    );
  });

  group('CalculatrixSession - rpn MR with empty memory', () {
    test(
      'MR with empty memory commits a pending multi-token draft first, then '
      'surfaces a typed empty-memory error',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('2');
        session.appendSpace();
        session.input('3');

        session.memoryRecall();

        expect(
          session.rpnStack,
          orderedEquals(<Matrix>[Matrix.scalar(2), Matrix.scalar(3)]),
        );
        expect(session.rpnDraft, '');
        expect(session.hasError, isTrue);
        expect(session.lastError, isA<EmptyMemoryError>());
      },
    );

    test(
      'MR with empty memory and an invalid pending draft surfaces the '
      'parse error, not the empty-memory error',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('2');
        session.appendSpace();
        session.input('abc');

        session.memoryRecall();

        expect(session.rpnDraft, '2 abc');
        expect(session.rpnStackDepth, 0);
        expect(session.hasError, isTrue);
        expect(session.lastError, isNot(isA<EmptyMemoryError>()));
        expect(session.lastError, isA<CalculatrixError>());
      },
    );

    test(
      'MR with empty memory and no pending draft surfaces a typed error '
      'and pushes nothing',
      () {
        session.setMode(CalculatrixMode.rpn);

        session.memoryRecall();

        expect(session.rpnStackDepth, 0);
        expect(session.hasError, isTrue);
        expect(session.lastError, isA<EmptyMemoryError>());
      },
    );
  });

  group('CalculatrixSession - rpn sign toggle whitespace parity', () {
    test(
      'toggleSign treats a tab between tokens as a boundary, like '
      'tokenizeRpnLine',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('2');
        session.input('\t');
        session.input('3');

        session.toggleSign();

        expect(session.rpnDraft, '2\t-3');
      },
    );

    test(
      'toggleSign treats a newline between tokens as a boundary, like '
      'tokenizeRpnLine',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('2');
        session.input('\n');
        session.input('3');

        session.toggleSign();

        expect(session.rpnDraft, '2\n-3');
      },
    );

    test('a tab-separated draft commits as two separate tokens', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.input('\t');
      session.input('3');

      session.enter();

      expect(
        session.rpnStack,
        orderedEquals(<Matrix>[Matrix.scalar(2), Matrix.scalar(3)]),
      );
      expect(session.rpnDraft, '');
      expect(session.hasError, isFalse);
    });
  });

  group('CalculatrixSession - rpn matrix literal tokens', () {
    test(
      'a JSON matrix literal with spaces after commas commits as one token',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('[[1, 2], [3, 4]]');

        session.enter();

        expect(
          session.rpnStack,
          orderedEquals(<Matrix>[
            Matrix(<List<double>>[
              <double>[1, 2],
              <double>[3, 4],
            ]),
          ]),
        );
        expect(session.rpnDraft, '');
        expect(session.hasError, isFalse);
      },
    );

    test(
      'an HP-style comma-less matrix literal with internal spaces commits '
      'as one token',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('[[1 2] [3 4]]');

        session.enter();

        expect(
          session.rpnStack,
          orderedEquals(<Matrix>[
            Matrix(<List<double>>[
              <double>[1, 2],
              <double>[3, 4],
            ]),
          ]),
        );
        expect(session.rpnDraft, '');
        expect(session.hasError, isFalse);
      },
    );

    test('a scalar and a spaced matrix literal on one line multiply correctly', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('[[1 2] [3 4]]');

      session.applyRpnBinary(RpnBinaryOperator.multiply);

      expect(session.rpnStackDepth, 1);
      expect(
        session.rpnTopValue,
        Matrix(<List<double>>[
          <double>[2, 4],
          <double>[6, 8],
        ]),
      );
      expect(session.rpnDraft, '');
      expect(session.hasError, isFalse);
    });

    test(
      'toggleSign on a matrix literal token toggles a leading minus without '
      're-serializing',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('[[1,2],[3,4]]');

        session.toggleSign();

        expect(session.rpnDraft, '-[[1,2],[3,4]]');
      },
    );

    test(
      'toggleSign on a matrix literal token preserves exponent notation '
      'exactly, with no rounding',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('[[1.25e-10]]');

        session.toggleSign();

        expect(session.rpnDraft, '-[[1.25e-10]]');
      },
    );

    test(
      'toggleSign twice on an exponent matrix literal token returns to the '
      'exact original text',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('[[1.25e-10]]');

        session.toggleSign();
        session.toggleSign();

        expect(session.rpnDraft, '[[1.25e-10]]');
      },
    );

    test(
      'toggleSign on a matrix literal token preserves 17 significant '
      'digits, with no rounding',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('[[1.2345678901234567]]');

        session.toggleSign();

        expect(session.rpnDraft, '-[[1.2345678901234567]]');
      },
    );

    test('toggleSign on a 1x1 matrix literal token toggles losslessly', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('[[42]]');

      session.toggleSign();

      expect(session.rpnDraft, '-[[42]]');
    });

    test('toggleSign on a 2x2 matrix literal token toggles losslessly', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('[[1,2],[3,4]]');

      session.toggleSign();

      expect(session.rpnDraft, '-[[1,2],[3,4]]');
    });

    test(
      'a toggled matrix literal token commits as the negated matrix value',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('[[1.25e-10]]');
        session.toggleSign();

        session.enter();

        expect(session.rpnStackDepth, 1);
        expect(session.rpnTopValue, Matrix.scalar(-1.25e-10));
        expect(session.rpnDraft, '');
        expect(session.hasError, isFalse);
      },
    );

    test(
      'toggleSign twice on a matrix literal token returns to the original '
      'matrix',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('[[1,2],[3,4]]');

        session.toggleSign();
        session.toggleSign();

        expect(session.rpnDraft, '[[1,2],[3,4]]');
      },
    );

    test('toggleSign negates only the trailing matrix token after a scalar', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('[[1 2] [3 4]]');

      session.toggleSign();

      expect(session.rpnDraft, '2 -[[1 2] [3 4]]');
    });

    test('an unclosed matrix literal bracket surfaces a typed error on commit', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('[[1,2]');

      session.enter();

      expect(session.rpnDraft, '[[1,2]');
      expect(session.rpnStackDepth, 0);
      expect(session.hasError, isTrue);
      expect(session.lastError, isA<CalculatrixError>());
    });
  });

  group('CalculatrixSession - rpn operation atomicity', () {
    test(
      'a failing operation rolls back only itself, keeping already-committed '
      'operands on the stack',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('2');
        session.appendSpace();
        session.input('3');
        session.appendSpace();
        session.input('0');

        session.applyRpnBinary(RpnBinaryOperator.divide);

        expect(
          session.rpnStack,
          orderedEquals(<Matrix>[
            Matrix.scalar(2),
            Matrix.scalar(3),
            Matrix.scalar(0),
          ]),
        );
        expect(session.rpnDraft, '');
        expect(session.hasError, isTrue);
        expect(session.lastError, isA<MatrixDomainError>());
      },
    );

    test(
      'a post-commit stack underflow keeps the committed operand and an '
      'empty draft',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('2');
        session.appendSpace();

        session.applyRpnBinary(RpnBinaryOperator.add);

        expect(session.rpnStack, orderedEquals(<Matrix>[Matrix.scalar(2)]));
        expect(session.rpnDraft, '');
        expect(session.hasError, isTrue);
        expect(session.lastError, isA<RpnStackUnderflowError>());
      },
    );
  });

  group('CalculatrixSession - rpn stale currentValue after failed operation', () {
    void setUpFailedDivision() {
      session.setMode(CalculatrixMode.rpn);
      session.input('9');
      session.enter();
      session.input('2');
      session.appendSpace();
      session.input('3');
      session.appendSpace();
      session.input('0');
      session.applyRpnBinary(RpnBinaryOperator.divide);
    }

    test(
      'currentValue reflects the new stack top even though the operation failed',
      () {
        setUpFailedDivision();

        expect(session.hasError, isTrue);
        expect(
          session.rpnStack,
          orderedEquals(<Matrix>[
            Matrix.scalar(9),
            Matrix.scalar(2),
            Matrix.scalar(3),
            Matrix.scalar(0),
          ]),
        );
        expect(session.currentValue, Matrix.scalar(0));
      },
    );

    test(
      'toggleSign after a failed operation negates the new top, not a stale value',
      () {
        setUpFailedDivision();

        session.toggleSign();

        expect(
          session.rpnStack,
          orderedEquals(<Matrix>[
            Matrix.scalar(9),
            Matrix.scalar(2),
            Matrix.scalar(3),
            Matrix.scalar(0),
          ]),
        );
      },
    );

    test(
      'memoryAdd after a failed operation adds the new top, not a stale value',
      () {
        setUpFailedDivision();

        session.memoryAdd();

        expect(session.memoryValue, Matrix.scalar(0));
      },
    );
  });

  group('CalculatrixSession - rpn memory ops with multi-token drafts', () {
    test('M+ with a two-token draft commits it like ENTER, then adds the new top', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('3');

      session.memoryAdd();

      expect(session.memoryValue, Matrix.scalar(3));
      expect(
        session.rpnStack,
        orderedEquals(<Matrix>[Matrix.scalar(2), Matrix.scalar(3)]),
      );
      expect(session.rpnDraft, '');
    });

    test(
      'M+ with a two-token draft whose last token was sign-toggled adds the '
      'negated new top',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('2');
        session.appendSpace();
        session.input('3');
        session.toggleSign();

        session.memoryAdd();

        expect(session.memoryValue, Matrix.scalar(-3));
        expect(
          session.rpnStack,
          orderedEquals(<Matrix>[Matrix.scalar(2), Matrix.scalar(-3)]),
        );
      },
    );

    test('M- with a two-token draft commits it like ENTER, then subtracts the new top', () {
      session.setMode(CalculatrixMode.rpn);
      session.input('2');
      session.appendSpace();
      session.input('3');

      session.memorySubtract();

      expect(session.memoryValue, Matrix.scalar(-3));
      expect(
        session.rpnStack,
        orderedEquals(<Matrix>[Matrix.scalar(2), Matrix.scalar(3)]),
      );
      expect(session.rpnDraft, '');
    });

    test(
      'M+ with an invalid token in a multi-token draft raises a typed error, '
      'leaves memory unchanged and keeps the draft',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('2');
        session.appendSpace();
        session.input('abc');

        session.memoryAdd();

        expect(session.memoryValue, isNull);
        expect(session.hasMemory, isFalse);
        expect(session.rpnDraft, '2 abc');
        expect(session.rpnStackDepth, 0);
        expect(session.hasError, isTrue);
        expect(session.lastError, isA<CalculatrixError>());
      },
    );
  });

  group('CalculatrixSession - rpn memory ops with single-token drafts', () {
    test(
      'M+ with an invalid single-token draft surfaces the typed error, '
      'changes nothing and keeps the draft',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('.');

        session.memoryAdd();

        expect(session.memoryValue, isNull);
        expect(session.hasMemory, isFalse);
        expect(session.rpnDraft, '.');
        expect(session.rpnStackDepth, 0);
        expect(session.hasError, isTrue);
        expect(session.lastError, isA<CalculatrixError>());
      },
    );

    test(
      'M- with an invalid single-token draft surfaces the typed error, '
      'changes nothing and keeps the draft',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('.');

        session.memorySubtract();

        expect(session.memoryValue, isNull);
        expect(session.hasMemory, isFalse);
        expect(session.rpnDraft, '.');
        expect(session.rpnStackDepth, 0);
        expect(session.hasError, isTrue);
        expect(session.lastError, isA<CalculatrixError>());
      },
    );

    test(
      'M+ with an invalid single-token draft followed by a trailing space '
      'still surfaces the typed error and keeps the draft as typed',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('.');
        session.appendSpace();

        session.memoryAdd();

        expect(session.memoryValue, isNull);
        expect(session.hasMemory, isFalse);
        expect(session.rpnDraft, '. ');
        expect(session.rpnStackDepth, 0);
        expect(session.hasError, isTrue);
        expect(session.lastError, isA<CalculatrixError>());
      },
    );

    test(
      'M+ with a valid single-token draft commits it like ENTER, then adds '
      'the new top',
      () {
        session.setMode(CalculatrixMode.rpn);
        session.input('5');

        session.memoryAdd();

        expect(session.memoryValue, Matrix.scalar(5));
        expect(session.rpnStack, orderedEquals(<Matrix>[Matrix.scalar(5)]));
        expect(session.rpnDraft, '');
        expect(session.hasError, isFalse);
      },
    );
  });

  group('CalculatrixSession - rpn failure preserves repeat-equals state', () {
    test(
      'a failed rpn command that mutates nothing leaves the infix repeat '
      'operator and operand intact',
      () {
        session.input('2');
        session.input('+');
        session.input('3');
        session.evaluate();
        expect(session.currentValue, Matrix.scalar(5));

        session.setMode(CalculatrixMode.rpn);
        session.swapRpn();

        expect(session.hasError, isTrue);
        expect(session.lastError, isA<RpnStackUnderflowError>());
        expect(session.rpnStack, orderedEquals(<Matrix>[Matrix.scalar(5)]));

        session.setMode(CalculatrixMode.infix);
        session.evaluate();

        expect(session.currentValue, Matrix.scalar(8));
      },
    );

    test(
      'a failed rpn command whose draft commit already mutated the stack '
      'still invalidates the infix repeat operator and operand',
      () {
        session.input('2');
        session.input('+');
        session.input('3');
        session.evaluate();
        expect(session.currentValue, Matrix.scalar(5));

        session.setMode(CalculatrixMode.rpn);
        session.input('0');
        session.applyRpnBinary(RpnBinaryOperator.divide);

        expect(session.hasError, isTrue);
        expect(session.lastError, isA<MatrixDomainError>());
        expect(
          session.rpnStack,
          orderedEquals(<Matrix>[Matrix.scalar(5), Matrix.scalar(0)]),
        );

        session.setMode(CalculatrixMode.infix);
        expect(session.currentValue, Matrix.scalar(0));

        session.evaluate();

        expect(session.currentValue, Matrix.scalar(0));
      },
    );

    test(
      'a macro that mutates then fails leaves stack depth unchanged but '
      'still invalidates the infix repeat operator and operand',
      () {
        session.input('2');
        session.input('+');
        session.input('3');
        session.evaluate();
        expect(session.currentValue, Matrix.scalar(5));

        session.setMode(CalculatrixMode.rpn);

        session.executeMacro(const _NegateThenSwapMacro());

        expect(session.hasError, isTrue);
        expect(session.lastError, isA<RpnStackUnderflowError>());
        expect(session.rpnStack, orderedEquals(<Matrix>[Matrix.scalar(-5)]));

        session.setMode(CalculatrixMode.infix);
        expect(session.currentValue, Matrix.scalar(-5));

        session.evaluate();

        expect(session.currentValue, Matrix.scalar(-5));
      },
    );
  });

  group('CalculatrixSession - infix repeat-equals with signed operands', () {
    test(
      'repeat-equals on a multiplication whose right operand is a signed '
      "matrix literal replays the true binary operator, not the operand's "
      'own unary sign',
      () {
        session.input('2');
        session.input('×');
        session.input('-[[3]]');
        session.evaluate();

        expect(session.currentValue, Matrix.scalar(-6));

        session.evaluate();

        expect(session.currentValue, Matrix.scalar(18));
      },
    );

    test(
      'repeat-equals on a multiplication whose right operand is a signed '
      'number replays the true binary operator',
      () {
        session.input('5');
        session.input('×');
        session.input('-3');
        session.evaluate();

        expect(session.currentValue, Matrix.scalar(-15));

        session.evaluate();

        expect(session.currentValue, Matrix.scalar(45));
      },
    );

    test(
      'repeat-equals on a genuine binary subtraction between two matrix '
      "literals still repeats the subtraction operator, not the left-hand "
      "literal's sign",
      () {
        session.input('[[1]]');
        session.input('-');
        session.input('[[3]]');
        session.evaluate();

        expect(session.currentValue, Matrix.scalar(-2));

        session.evaluate();

        expect(session.currentValue, Matrix.scalar(-5));
      },
    );
  });

  group(
    'CalculatrixSession - rpn memory keys invalidate infix repeat-equals '
    'only when the stack actually changes',
    () {
      test(
        'MC with no pending rpn draft leaves infix repeat-equals intact',
        () {
          session.input('2');
          session.input('+');
          session.input('3');
          session.evaluate();
          expect(session.currentValue, Matrix.scalar(5));

          session.setMode(CalculatrixMode.rpn);
          session.memoryClear();
          expect(session.rpnStack, orderedEquals(<Matrix>[Matrix.scalar(5)]));

          session.setMode(CalculatrixMode.infix);
          session.evaluate();

          expect(session.currentValue, Matrix.scalar(8));
        },
      );

      test(
        'MC that first commits a pending rpn draft invalidates infix '
        'repeat-equals',
        () {
          session.input('2');
          session.input('+');
          session.input('3');
          session.evaluate();
          expect(session.currentValue, Matrix.scalar(5));

          session.setMode(CalculatrixMode.rpn);
          session.input('7');
          session.memoryClear();
          expect(
            session.rpnStack,
            orderedEquals(<Matrix>[Matrix.scalar(5), Matrix.scalar(7)]),
          );

          session.setMode(CalculatrixMode.infix);
          session.evaluate();

          expect(session.currentValue, Matrix.scalar(7));
        },
      );

      test(
        'MR that pushes a memory value invalidates infix repeat-equals even '
        'with no pending draft',
        () {
          session.input('2');
          session.input('+');
          session.input('3');
          session.evaluate();
          expect(session.currentValue, Matrix.scalar(5));

          session.memoryAdd();
          expect(session.memoryValue, Matrix.scalar(5));

          session.setMode(CalculatrixMode.rpn);
          session.memoryRecall();
          expect(
            session.rpnStack,
            orderedEquals(<Matrix>[Matrix.scalar(5), Matrix.scalar(5)]),
          );

          session.setMode(CalculatrixMode.infix);
          session.evaluate();

          expect(session.currentValue, Matrix.scalar(5));
        },
      );

      test(
        'MR that pushes a memory value after first committing a pending '
        'draft invalidates infix repeat-equals',
        () {
          session.input('2');
          session.input('+');
          session.input('3');
          session.evaluate();
          expect(session.currentValue, Matrix.scalar(5));

          session.memoryAdd();
          expect(session.memoryValue, Matrix.scalar(5));

          session.setMode(CalculatrixMode.rpn);
          session.input('7');
          session.memoryRecall();
          expect(
            session.rpnStack,
            orderedEquals(<Matrix>[
              Matrix.scalar(5),
              Matrix.scalar(7),
              Matrix.scalar(5),
            ]),
          );

          session.setMode(CalculatrixMode.infix);
          session.evaluate();

          expect(session.currentValue, Matrix.scalar(5));
        },
      );

      test(
        'M+ with no pending draft folds the committed value into memory '
        'without touching infix repeat-equals',
        () {
          session.input('2');
          session.input('+');
          session.input('3');
          session.evaluate();
          expect(session.currentValue, Matrix.scalar(5));

          session.setMode(CalculatrixMode.rpn);
          session.memoryAdd();
          expect(session.memoryValue, Matrix.scalar(5));
          expect(session.rpnStack, orderedEquals(<Matrix>[Matrix.scalar(5)]));

          session.setMode(CalculatrixMode.infix);
          session.evaluate();

          expect(session.currentValue, Matrix.scalar(8));
        },
      );

      test(
        'M+ that first commits a pending draft invalidates infix '
        'repeat-equals',
        () {
          session.input('2');
          session.input('+');
          session.input('3');
          session.evaluate();
          expect(session.currentValue, Matrix.scalar(5));

          session.setMode(CalculatrixMode.rpn);
          session.input('7');
          session.memoryAdd();
          expect(session.memoryValue, Matrix.scalar(7));
          expect(
            session.rpnStack,
            orderedEquals(<Matrix>[Matrix.scalar(5), Matrix.scalar(7)]),
          );

          session.setMode(CalculatrixMode.infix);
          session.evaluate();

          expect(session.currentValue, Matrix.scalar(7));
        },
      );
    },
  );

  group(
    'CalculatrixSession - rpn sign toggle on an explicitly positive token',
    () {
      test(
        'toggleSign on a token with an explicit leading + replaces it with '
        'a single leading -, for a number',
        () {
          session.setMode(CalculatrixMode.rpn);
          session.input('+3');

          session.toggleSign();

          expect(session.rpnDraft, '-3');

          session.enter();

          expect(session.hasError, isFalse);
          expect(session.rpnStack, orderedEquals(<Matrix>[Matrix.scalar(-3)]));
        },
      );

      test(
        'toggleSign on a token with an explicit leading + replaces it with '
        'a single leading -, for a matrix literal',
        () {
          session.setMode(CalculatrixMode.rpn);
          session.input('+[[3]]');

          session.toggleSign();

          expect(session.rpnDraft, '-[[3]]');

          session.enter();

          expect(session.hasError, isFalse);
          expect(session.rpnStack, orderedEquals(<Matrix>[Matrix.scalar(-3)]));
        },
      );

      test(
        'toggling twice on an explicitly positive token lands on the plain '
        'unsigned token, not back on the explicit +',
        () {
          session.setMode(CalculatrixMode.rpn);
          session.input('+3');

          session.toggleSign();
          expect(session.rpnDraft, '-3');

          session.toggleSign();
          expect(session.rpnDraft, '3');
        },
      );
    },
  );

  group('CalculatrixSession - dup/over/swap/rot agree with duplicate/over/'
      'swap/rotate at stack depths 0 to 3 (AC4, issue #39)', () {
    // Correction to the issue text: dup/over/swap/rot have no command of
    // their own on the session either (D44). Each action runs the
    // registered word (duplicate/over/swap/rotate) through
    // Calculatrix.executeWordOn, so it must give the same resulting stack,
    // or the same error id with the stack left exactly as it was, as
    // evaluating that word directly through evaluateRpnStack.
    final Map<String, void Function(CalculatrixSession)> actionByWord =
        <String, void Function(CalculatrixSession)>{
          'duplicate': (CalculatrixSession s) => s.dupRpn(),
          'over': (CalculatrixSession s) => s.overRpn(),
          'swap': (CalculatrixSession s) => s.swapRpn(),
          'rotate': (CalculatrixSession s) => s.rotRpn(),
        };

    void seed(CalculatrixSession target, int depth) {
      target.setMode(CalculatrixMode.rpn);
      for (int i = 1; i <= depth; i++) {
        target.input('$i');
        target.enter();
      }
    }

    actionByWord.forEach((
      String word,
      void Function(CalculatrixSession) action,
    ) {
      for (int depth = 0; depth <= 3; depth++) {
        test('$word at depth $depth', () {
          final List<String> seedTokens = List<String>.generate(
            depth,
            (int i) => '${i + 1}',
          );

          final CalculatrixSession target = CalculatrixSession();
          seed(target, depth);
          final List<Matrix> stackBefore = List<Matrix>.of(target.rpnStack);
          action(target);

          if (target.hasError) {
            expect(
              () => Calculatrix.evaluateRpnStack(<String>[...seedTokens, word]),
              throwsA(
                isA<CalculatrixError>().having(
                  (CalculatrixError error) => error.runtimeType,
                  'runtimeType',
                  target.lastError.runtimeType,
                ),
              ),
              reason: 'depth $depth',
            );
            // A failed action never changes the stack (issue #39, AC4).
            expect(
              target.rpnStack,
              orderedEquals(stackBefore),
              reason: 'depth $depth',
            );
          } else {
            expect(
              target.rpnStack,
              orderedEquals(
                Calculatrix.evaluateRpnStack(<String>[...seedTokens, word]),
              ),
              reason: 'depth $depth',
            );
          }
        });
      }
    });
  });

  group('CalculatrixSession - exact values (runbook T5, D54, D59)', () {
    void type(String keys) {
      for (final String key in keys.split(' ')) {
        session.input(key);
      }
    }

    String text(Matrix? value) => MatrixDisplayFormatter.text(value!);

    test('infix results are exact: 1 ÷ 3 × 3 = 1 and 0.1 + 0.2 = 0.3', () {
      type('1 ÷ 3 × 3');
      session.evaluate();
      expect(session.currentValue!.isExact, isTrue);
      expect(text(session.currentValue), '1');

      session.clear();
      type('0 . 1 + 0 . 2');
      session.evaluate();
      expect(text(session.currentValue), '0.3');
    });

    test('a fraction result seeds the next expression in parentheses', () {
      type('1 ÷ 3');
      session.evaluate();
      expect(text(session.currentValue), '1/3');

      session.input('÷');
      expect(session.expression, '(1/3)÷');
      type('2');
      session.evaluate();
      expect(text(session.currentValue), '1/6');
    });

    test('± on a fraction seed flips the sign inside the parentheses', () {
      type('1 ÷ 3');
      session.evaluate();
      session.memoryAdd();
      session.clear();
      session.memoryRecall();
      expect(session.expression, '(1/3)');

      session.toggleSign();
      expect(session.expression, '(-1/3)');
      session.toggleSign();
      expect(session.expression, '(1/3)');
    });

    test('an approximate result is marked and keeps its mark', () {
      type('2');
      session.input('√');
      // The seed keeps the whole double, so it reads back as the same value.
      expect(session.expression, '~1.4142135623730951');

      session.toggleSign();
      expect(session.expression, '~-1.4142135623730951');
      session.evaluate();
      expect(session.currentValue!.isExact, isFalse);
      expect(text(session.currentValue), '~-1.41421356237');
    });

    test('√ and INV are exact when the result is rational', () {
      type('9');
      session.input('√');
      expect(session.expression, '3');

      session.clear();
      type('4');
      session.input('INV');
      expect(session.expression, '0.25');
    });

    test('memory keeps exactness', () {
      type('1 ÷ 3');
      session.evaluate();
      session.memoryAdd();
      session.memoryAdd();
      expect(text(session.memoryValue), '2/3');

      session.memorySubtract();
      expect(text(session.memoryValue), '1/3');
    });

    test('rpn: fractions type in and stack literals read back', () {
      session.setMode(CalculatrixMode.rpn);
      type('1 / 3');
      session.enter();
      type('3');
      session.applyRpnBinary(RpnBinaryOperator.multiply);
      expect(session.rpnTopValue!.isExact, isTrue);
      expect(session.rpnTopLiteral, '[[1]]');

      type('3');
      session.applyRpnBinary(RpnBinaryOperator.divide);
      expect(session.rpnTopLiteral, '[[1/3]]');

      session.applyRpnUnary(RpnUnaryOperator.sqrt);
      expect(session.rpnTopValue!.isExact, isFalse);
      expect(session.rpnTopLiteral, startsWith('~[[0.577350269189'));
    });

    test('rpn: ± keeps the sign after the mark', () {
      session.setMode(CalculatrixMode.rpn);
      type('~ 0 . 5');
      session.toggleSign();
      expect(session.rpnDraft, '~-0.5');
      session.toggleSign();
      expect(session.rpnDraft, '~0.5');
    });

    test('an approximate seed with an exponent reads back as itself', () {
      type('2 e 4 0');
      session.input('√');
      final double root = Calculatrix.evaluateRpn(<String>['~2e40', 'sqrt'])
          .scalarValue;
      expect(session.expression, startsWith('~'));

      session.evaluate();
      expect(session.hasError, isFalse);
      expect(session.currentValue!.isExact, isFalse);
      expect(session.currentValue!.scalarValue, root);
    });

    test('± on a fraction seed followed by an operator stays valid', () {
      type('1 ÷ 3');
      session.evaluate();
      session.input('×');
      type('3');
      expect(session.expression, '(1/3)×3');

      session.toggleSign();
      expect(session.expression, '(-1/3)×3');
      session.evaluate();
      expect(session.hasError, isFalse);
      expect(text(session.currentValue), '-1');
    });

    test('rpn: a draft token is read as rpn, as cx reads it (D59)', () {
      session.setMode(CalculatrixMode.rpn);
      type('1 . 5 / 2');
      session.enter();
      expect(session.hasError, isTrue);
      expect(session.rpnStack, isEmpty);

      session.clear();
      type('- 5 / 3');
      session.enter();
      expect(session.hasError, isFalse);
      expect(session.rpnTopLiteral, '[[-5/3]]');
    });
  });
}

// Regression fixture for round 4 defect 2: a macro whose first command
// mutates the stack's content (Negate: 5 -> -5) and whose second command
// fails on underflow after popping its single operand (Swap requires two).
// Stack depth is 1 before and after (Negate keeps depth 1, Swap's failure is
// atomic and rolls itself back), so a depth comparison alone cannot detect
// that the stack's content actually changed. `CalculatrixMachine.execute`
// only rolls back the command that throws, not prior commands in the same
// macro, so the Negate mutation legitimately survives the later failure.
class _NegateThenSwapMacro implements CalculatrixMacro {
  const _NegateThenSwapMacro();

  @override
  Iterable<CalculatrixCommand> expand(CalculatrixMachine machine) {
    return const <CalculatrixCommand>[NegateCommand(), RollCommand(2)];
  }
}