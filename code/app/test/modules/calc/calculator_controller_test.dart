import 'package:calculatrix/calculatrix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calculatrix_app/modules/calc/controller.dart';
import 'package:calculatrix_app/modules/calc/matrix_editor_draft.dart';

void main() {
  late CalculatorController controller;

  setUp(() {
    controller = CalculatorController();
  });

  tearDown(() {
    controller.dispose();
  });

  void openInfixEditor() {
    if (!controller.isInfixMode) {
      controller.openInfixEditor();
    }
  }

  group('CalculatorController', () {
    test('initial shell mode is rpn', () {
      expect(controller.mode, CalculatorMode.rpn);
      expect(controller.isRpnMode, isTrue);
    });

    test('can switch notation mode', () {
      controller.setMode(CalculatorMode.rpn);

      expect(controller.mode, CalculatorMode.rpn);
    });

    test('can switch to matrix mode and exit back to the previous mode', () {
      controller.setMode(CalculatorMode.rpn);
      controller.setMode(CalculatorMode.matrix);

      expect(controller.mode, CalculatorMode.matrix);
      expect(controller.isMatrixMode, isTrue);

      controller.exitMatrixMode();

      expect(controller.mode, CalculatorMode.rpn);
    });

    test('submitting the infix editor pushes the resolved result into the rpn shell', () {
      controller.openInfixEditor();
      controller.input('3');
      controller.input('+');
      controller.input('4');

      controller.submitInfixEditor();

      expect(controller.mode, CalculatorMode.rpn);
      expect(controller.rpnStackDepth, 1);
      expect(controller.rpnTopLiteral, '[[7]]');
      expect(controller.expression, '');
    });

    test('can execute public matrix commands and macros in rpn mode', () {
      controller.setMode(CalculatorMode.rpn);
      controller.insertMatrixLiteral('[[1,2],[3,4]]');

      controller.executeRpnCommand(const TransposeCommand());
      controller.executeRpnMacro(const AppendZeroColumnMacro());

      expect(controller.rpnTopLiteral, '[[1,3,0],[2,4,0]]');
    });

    test('initial display is "0"', () {
      expect(controller.display, '0');
      expect(controller.expression, '');
    });

    test('input appends to expression', () {
      openInfixEditor();
      controller.input('3');
      expect(controller.expression, '3');
      expect(controller.display, '3');
    });

    test('multiple inputs concatenate', () {
      openInfixEditor();
      controller.input('3');
      controller.input('+');
      controller.input('4');
      expect(controller.expression, '3+4');
    });

    test('clear resets expression', () {
      openInfixEditor();
      controller.input('3');
      controller.input('+');
      controller.clear();
      expect(controller.expression, '');
      expect(controller.display, '0');
    });

    test('backspace removes last character', () {
      openInfixEditor();
      controller.input('3');
      controller.input('+');
      controller.input('4');
      controller.backspace();
      expect(controller.expression, '3+');
    });

    test('backspace on empty does nothing', () {
      openInfixEditor();
      controller.backspace();
      expect(controller.expression, '');
    });

    test('notifies listeners on input', () {
      openInfixEditor();
      var notified = false;
      controller.addListener(() => notified = true);
      controller.input('5');
      expect(notified, isTrue);
    });

    test('notifies listeners on clear', () {
      openInfixEditor();
      controller.input('5');
      var notified = false;
      controller.addListener(() => notified = true);
      controller.clear();
      expect(notified, isTrue);
    });

    test('notifies listeners on backspace', () {
      openInfixEditor();
      controller.input('5');
      var notified = false;
      controller.addListener(() => notified = true);
      controller.backspace();
      expect(notified, isTrue);
    });
  });

  group('CalculatorController - evaluation', () {
    setUp(() {
      openInfixEditor();
    });

    test('evaluate simple addition', () {
      controller.input('3');
      controller.input('+');
      controller.input('4');
      controller.evaluate();
      expect(controller.result, '7');
      expect(controller.display, '7');
    });

    test('evaluate with precedence', () {
      controller.input('3');
      controller.input('+');
      controller.input('4');
      controller.input('×');
      controller.input('5');
      controller.evaluate();
      expect(controller.result, '23');
    });

    test('evaluate with parentheses', () {
      // (3+4)×5 = 35
      for (final c in '(3+4)×5'.split('')) {
        controller.input(c);
      }
      controller.evaluate();
      expect(controller.result, '35');
    });

    test('evaluate decimal result', () {
      controller.input('1');
      controller.input('÷');
      controller.input('4');
      controller.evaluate();
      expect(controller.result, '0.25');
    });

    test('evaluate shows Error on invalid expression', () {
      controller.input('+');
      controller.input('+');
      controller.evaluate();
      expect(controller.error, 'Error');
      expect(controller.display, 'Error');
    });

    test('evaluate division by zero shows Error', () {
      controller.input('1');
      controller.input('÷');
      controller.input('0');
      controller.evaluate();
      expect(controller.display, 'Error');
    });

    test('evaluate matrix division by a non-scalar denominator shows Error', () {
      controller.input('[[3,1],[7,3]]');
      controller.input('÷');
      controller.input('[[2,1],[1,1]]');

      controller.evaluate();

      expect(controller.error, 'Error');
      expect(controller.display, 'Error');
    });

    test('after result, operator continues expression', () {
      controller.input('3');
      controller.input('+');
      controller.input('4');
      controller.evaluate();
      expect(controller.result, '7');
      controller.input('+');
      expect(controller.expression, '7+');
      expect(controller.result, '');
    });

    test('after result, digit starts new expression', () {
      controller.input('3');
      controller.input('+');
      controller.input('4');
      controller.evaluate();
      controller.input('9');
      expect(controller.expression, '9');
    });

    test('backspace after result clears all', () {
      controller.input('5');
      controller.evaluate();
      controller.backspace();
      expect(controller.display, '0');
    });
  });

  group('CalculatorController - memory', () {
    setUp(() {
      openInfixEditor();
    });

    test('memory is initially empty', () {
      expect(controller.hasMemory, isFalse);
    });

    test('M+ adds current display to memory', () {
      controller.input('4');
      controller.input('2');
      controller.evaluate();
      controller.memoryAdd();
      expect(controller.hasMemory, isTrue);
    });

    test('MR recalls memory into expression', () {
      controller.input('4');
      controller.input('2');
      controller.evaluate();
      controller.memoryAdd();
      controller.clear();
      controller.memoryRecall();
      expect(controller.expression, '42');
    });

    test('M- subtracts from memory', () {
      controller.input('1');
      controller.input('0');
      controller.evaluate();
      controller.memoryAdd(); // memory = 10
      controller.clear();
      controller.input('3');
      controller.evaluate();
      controller.memorySubtract(); // memory = 7
      controller.clear();
      controller.memoryRecall();
      expect(controller.expression, '7');
    });

    test('MC clears memory', () {
      controller.input('5');
      controller.evaluate();
      controller.memoryAdd();
      controller.memoryClear();
      expect(controller.hasMemory, isFalse);
    });

    test('MR does nothing when memory is 0', () {
      controller.memoryRecall();
      expect(controller.expression, '');
    });

    test('M+ stores non-scalar infix results in memory', () {
      controller.input('[[1],[2]]');
      controller.input('×');
      controller.input('[[3,4]]');
      controller.evaluate();

      controller.memoryAdd();

      controller.clear();
      controller.memoryRecall();

      expect(controller.error, '');
      expect(controller.hasMemory, isTrue);
      expect(controller.expression, '[[3,4],[6,8]]');
    });

    test('M- stores non-scalar RPN stack values in memory', () {
      controller.setMode(CalculatorMode.rpn);
      controller.insertMatrixLiteral('[[1,2],[3,4]]');

      controller.memorySubtract();

      controller.memoryRecall();

      expect(controller.error, '');
      expect(controller.hasMemory, isTrue);
      expect(controller.rpnStackDepth, 2);
      expect(controller.rpnTopLiteral, '[[-1,-2],[-3,-4]]');
    });

    test('MRC recalls memory on the first press', () {
      controller.openInfixEditor();
      controller.input('8');
      controller.evaluate();
      controller.memoryAdd();

      controller.clear();
      controller.memoryRecallClear();

      expect(controller.expression, '8');
      expect(controller.hasMemory, isTrue);
    });

    test('MRC clears memory on the second consecutive press', () {
      controller.openInfixEditor();
      controller.input('8');
      controller.evaluate();
      controller.memoryAdd();

      controller.clear();
      controller.memoryRecallClear();
      controller.memoryRecallClear();

      expect(controller.hasMemory, isFalse);
    });

    test('a non-MRC action resets the consecutive MRC cycle', () {
      controller.openInfixEditor();
      controller.input('8');
      controller.evaluate();
      controller.memoryAdd();

      controller.clear();
      controller.memoryRecallClear();
      controller.clear();
      controller.memoryRecallClear();

      expect(controller.hasMemory, isTrue);
      expect(controller.expression, '8');
    });
  });

  group('CalculatorController - sign toggle', () {
    setUp(() {
      openInfixEditor();
    });

    test('toggle sign on expression', () {
      controller.input('5');
      controller.toggleSign();
      expect(controller.expression, '-5');
    });

    test('toggle sign back to positive', () {
      controller.input('5');
      controller.toggleSign();
      controller.toggleSign();
      expect(controller.expression, '5');
    });

    test('toggle sign on result', () {
      controller.input('3');
      controller.input('+');
      controller.input('4');
      controller.evaluate();
      expect(controller.result, '7');
      controller.toggleSign();
      expect(controller.result, '-7');
    });

    test('toggle sign multiplies a committed infix matrix by -1', () {
      controller.insertMatrixLiteral('[[1,2],[3,4]]');
      controller.evaluate();

      controller.toggleSign();

      expect(controller.display, '[[-1, -2], [-3, -4]]');
      expect(
        controller.displayMatrix,
        Matrix(<List<double>>[
          <double>[-1, -2],
          <double>[-3, -4],
        ]),
      );
    });

    test('toggle sign multiplies the committed rpn top matrix by -1', () {
      controller.setMode(CalculatorMode.rpn);
      controller.insertMatrixLiteral('[[1,2],[3,4]]');

      controller.toggleSign();

      expect(controller.rpnStackDepth, 1);
      expect(controller.rpnTopLiteral, '[[-1,-2],[-3,-4]]');
      expect(
        controller.displayMatrix,
        Matrix(<List<double>>[
          <double>[-1, -2],
          <double>[-3, -4],
        ]),
      );
    });
  });

  group('CalculatorController - sqrt and percent', () {
    setUp(() {
      openInfixEditor();
    });

    test('sqrt evaluation', () {
      controller.input('√');
      controller.input('9');
      controller.evaluate();
      expect(controller.result, '3');
    });

    test('percent evaluation', () {
      controller.input('5');
      controller.input('0');
      controller.input('%');
      controller.evaluate();
      expect(controller.result, '0.5');
    });

    test('sqrt of negative returns scaled imaginary unit', () {
      controller.input('√');
      controller.input('(');
      controller.input('-');
      controller.input('4');
      controller.input(')');
      controller.evaluate();
      // sqrt(-4) = 2i — displayed in complex notation, not raw matrix literal
      expect(controller.result, '2i');
    });

    test('insertImaginaryUnit inserts Matrix.i into Infix expression', () {
      controller.input('2');
      controller.input('×');
      controller.insertImaginaryUnit();
      controller.evaluate();
      // 2 * i = [[0,-2],[2,0]] = 2i
      expect(controller.result, '2i');
    });

    test('3 + 2*i = 3 + 2i via scalar promotion', () {
      controller.input('3');
      controller.input('+');
      controller.input('2');
      controller.input('×');
      controller.insertImaginaryUnit();
      controller.evaluate();
      expect(controller.result, '3 + 2i');
    });
  });

  group('CalculatorController - repeat equals', () {
    setUp(() {
      openInfixEditor();
    });

    test('pressing = again repeats last operation', () {
      controller.input('5');
      controller.input('+');
      controller.input('3');
      controller.evaluate();
      expect(controller.result, '8');
      // Press = again: 8 + 3 = 11
      controller.evaluate();
      expect(controller.result, '11');
      // Press = again: 11 + 3 = 14
      controller.evaluate();
      expect(controller.result, '14');
    });

    test('repeat with multiplication', () {
      controller.input('2');
      controller.input('×');
      controller.input('3');
      controller.evaluate();
      expect(controller.result, '6');
      controller.evaluate();
      expect(controller.result, '18');
    });

    test('clear stops repeat', () {
      controller.input('5');
      controller.input('+');
      controller.input('3');
      controller.evaluate();
      controller.clear();
      controller.input('1');
      controller.evaluate();
      expect(controller.result, '1');
    });
  });

  group('CalculatorController - precision', () {
    setUp(() {
      openInfixEditor();
    });

    test('1÷3 has reasonable precision', () {
      controller.input('1');
      controller.input('÷');
      controller.input('3');
      controller.evaluate();
      expect(controller.result, startsWith('0.3333333'));
    });

    test('large numbers display correctly', () {
      controller.input('9');
      controller.input('9');
      controller.input('9');
      controller.input('9');
      controller.input('9');
      controller.input('9');
      controller.input('9');
      controller.input('9');
      controller.input('9');
      controller.evaluate();
      expect(controller.result, '999999999');
    });
  });

  group('MatrixEditorDraft', () {
    test('serializes rectangular cells into core literal format', () {
      final MatrixEditorDraft draft = MatrixEditorDraft(rowCount: 2, columnCount: 2);

      draft.setCell(0, 0, '1');
      draft.setCell(0, 1, '2');
      draft.setCell(1, 0, '3');
      draft.setCell(1, 1, '4');

      expect(draft.buildLiteral(), '[[1,2],[3,4]]');
    });

    test('throws when any cell is empty', () {
      final MatrixEditorDraft draft = MatrixEditorDraft(rowCount: 1, columnCount: 2);
      draft.setCell(0, 0, '1');

      expect(draft.buildLiteral, throwsFormatException);
    });

    test('preserves overlapping values when resized', () {
      final MatrixEditorDraft draft = MatrixEditorDraft(rowCount: 1, columnCount: 1);
      draft.setCell(0, 0, '9');

      draft.resize(rowCount: 2, columnCount: 2);

      expect(draft.cellValue(0, 0), '9');
      expect(draft.cellValue(1, 1), '');
    });
  });

  group('CalculatorController - matrix entry', () {
    setUp(() {
      openInfixEditor();
    });

    test('inserts matrix literal into infix expression', () {
      controller.insertMatrixLiteral('[[1,2],[3,4]]');

      expect(controller.expression, '[[1,2],[3,4]]');
      expect(controller.display, '[[1,2],[3,4]]');
    });

    test('inserts a non-square literal produced by structural draft edits', () {
      final MatrixEditorDraft draft = _seededMatrixDraft(
        rowCount: 2,
        columnCount: 2,
      );

      expect(draft.appendColumn(), isTrue);
      draft.setCell(0, 2, '5');
      draft.setCell(1, 2, '6');
      final String literal = draft.buildLiteral();

      controller.insertMatrixLiteral(literal);

      expect(controller.expression, '[[1,2,5],[3,4,6]]');
      expect(controller.display, '[[1,2,5],[3,4,6]]');
    });

    test('pushes matrix literal onto RPN stack in rpn mode', () {
      controller.setMode(CalculatorMode.rpn);

      controller.insertMatrixLiteral('[[1,2],[3,4]]');

      expect(controller.rpnStackDepth, 1);
      expect(controller.rpnTopLiteral, '[[1,2],[3,4]]');
    });

    test('pushes a reordered literal produced by structural draft edits in rpn mode', () {
      final MatrixEditorDraft draft = _seededMatrixDraft(
        rowCount: 2,
        columnCount: 3,
      );

      expect(draft.moveColumn(0, 2), isTrue);

      controller.setMode(CalculatorMode.rpn);
      controller.insertMatrixLiteral(draft.buildLiteral());

      expect(controller.rpnStackDepth, 1);
      expect(controller.rpnTopLiteral, '[[2,3,1],[5,6,4]]');
    });
  });

  group('CalculatorController - rpn mode', () {
    test('evaluate acts as ENTER and commits current draft in rpn mode', () {
      controller.setMode(CalculatorMode.rpn);
      controller.input('4');
      controller.input('2');

      controller.evaluate();

      expect(controller.rpnStackDepth, 1);
      expect(controller.rpnTopLiteral, '[[42]]');
      expect(controller.expression, '');
    });

    test('binary operator auto-commits active draft before execution', () {
      controller.setMode(CalculatorMode.rpn);
      controller.input('3');
      controller.evaluate();
      controller.input('4');

      controller.applyRpnBinary(RpnBinaryOperator.add);

      expect(controller.rpnStackDepth, 1);
      expect(controller.rpnTopLiteral, '[[7]]');
      expect(controller.display, '[[7]]');
    });

    test('clear removes draft but preserves committed stack in rpn mode', () {
      controller.setMode(CalculatorMode.rpn);
      controller.input('3');
      controller.evaluate();
      controller.input('4');

      controller.clear();

      expect(controller.expression, '');
      expect(controller.rpnStackDepth, 1);
      expect(controller.rpnTopLiteral, '[[3]]');
    });

    test('memory recall pushes scalar onto RPN stack', () {
      controller.input('8');
      controller.evaluate();
      controller.memoryAdd();
      controller.setMode(CalculatorMode.rpn);

      controller.memoryRecall();

      expect(controller.rpnStackDepth, 2);
      expect(controller.rpnTopLiteral, '[[8]]');
    });
  });

  group('CalculatorController - shared current value', () {
    setUp(() {
      openInfixEditor();
    });

    test('switching to rpn keeps an infix draft private and uncommitted', () {
      controller.input('1');
      controller.input('+');

      controller.setMode(CalculatorMode.rpn);

      expect(controller.rpnStackDepth, 0);
      expect(controller.expression, '');
      expect(controller.display, '0');

      controller.setMode(CalculatorMode.infix);

      expect(controller.expression, '1+');
      expect(controller.display, '1+');
    });

    test('switching away from rpn keeps the rpn draft private and uncommitted', () {
      controller.setMode(CalculatorMode.rpn);
      controller.input('4');
      controller.input('2');

      controller.setMode(CalculatorMode.infix);

      expect(controller.rpnStackDepth, 0);
      expect(controller.expression, '');
      expect(controller.display, '0');

      controller.setMode(CalculatorMode.rpn);

      expect(controller.expression, '42');
      expect(controller.display, '42');
      expect(controller.rpnStackDepth, 0);
    });

    test('switching from infix to rpn preserves committed current value as top of stack', () {
      controller.input('3');
      controller.input('+');
      controller.input('4');

      controller.evaluate();
      controller.setMode(CalculatorMode.rpn);

      expect(controller.rpnStackDepth, 1);
      expect(controller.rpnTopLiteral, '[[7]]');
      expect(controller.display, '[[7]]');
    });

    test('switching back to infix uses the current rpn top as the next operand seed', () {
      controller.input('3');
      controller.input('+');
      controller.input('3');
      controller.evaluate();

      controller.setMode(CalculatorMode.rpn);
      controller.input('5');
      controller.evaluate();

      controller.setMode(CalculatorMode.infix);
      expect(controller.display, '5');

      controller.input('+');
      controller.input('3');
      controller.evaluate();

      expect(controller.display, '8');
    });

    test('rpn mutations invalidate stale infix repeat-equals state', () {
      controller.input('3');
      controller.input('+');
      controller.input('3');
      controller.evaluate();
      controller.evaluate();
      expect(controller.display, '9');

      controller.setMode(CalculatorMode.rpn);
      controller.input('5');
      controller.evaluate();

      controller.setMode(CalculatorMode.infix);
      expect(controller.display, '5');

      controller.evaluate();

      expect(controller.display, '5');
    });
  });

  group('CalculatorController - matrix display', () {
    setUp(() {
      openInfixEditor();
    });

    test('keeps non-scalar infix results instead of collapsing to scalarValue', () {
      controller.input('[[1],[2]]');
      controller.input('×');
      controller.input('[[3,4]]');

      controller.evaluate();

      expect(controller.display, '[[3, 4], [6, 8]]');
      expect(
        controller.displayMatrix,
        Matrix(<List<double>>[
          <double>[3, 4],
          <double>[6, 8],
        ]),
      );
    });
  });
}

MatrixEditorDraft _seededMatrixDraft({
  required int rowCount,
  required int columnCount,
}) {
  final MatrixEditorDraft draft = MatrixEditorDraft(
    rowCount: rowCount,
    columnCount: columnCount,
  );

  int nextValue = 1;
  for (int row = 0; row < rowCount; row++) {
    for (int column = 0; column < columnCount; column++) {
      draft.setCell(row, column, '${nextValue++}');
    }
  }

  return draft;
}

