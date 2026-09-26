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
    return const <CalculatrixCommand>[NegateCommand(), SwapCommand()];
  }
}