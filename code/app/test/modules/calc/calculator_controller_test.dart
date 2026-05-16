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

  group('CalculatorController', () {
    test('initial notation mode is infix', () {
      expect(controller.mode, CalculatorMode.infix);
    });

    test('can switch notation mode', () {
      controller.setMode(CalculatorMode.rpn);

      expect(controller.mode, CalculatorMode.rpn);
    });

    test('initial display is "0"', () {
      expect(controller.display, '0');
      expect(controller.expression, '');
    });

    test('input appends to expression', () {
      controller.input('3');
      expect(controller.expression, '3');
      expect(controller.display, '3');
    });

    test('multiple inputs concatenate', () {
      controller.input('3');
      controller.input('+');
      controller.input('4');
      expect(controller.expression, '3+4');
    });

    test('clear resets expression', () {
      controller.input('3');
      controller.input('+');
      controller.clear();
      expect(controller.expression, '');
      expect(controller.display, '0');
    });

    test('backspace removes last character', () {
      controller.input('3');
      controller.input('+');
      controller.input('4');
      controller.backspace();
      expect(controller.expression, '3+');
    });

    test('backspace on empty does nothing', () {
      controller.backspace();
      expect(controller.expression, '');
    });

    test('notifies listeners on input', () {
      var notified = false;
      controller.addListener(() => notified = true);
      controller.input('5');
      expect(notified, isTrue);
    });

    test('notifies listeners on clear', () {
      controller.input('5');
      var notified = false;
      controller.addListener(() => notified = true);
      controller.clear();
      expect(notified, isTrue);
    });

    test('notifies listeners on backspace', () {
      controller.input('5');
      var notified = false;
      controller.addListener(() => notified = true);
      controller.backspace();
      expect(notified, isTrue);
    });
  });

  group('CalculatorController - evaluation', () {
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
  });

  group('CalculatorController - sign toggle', () {
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
  });

  group('CalculatorController - sqrt and percent', () {
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

    test('sqrt of negative shows Error', () {
      controller.input('√');
      controller.input('(');
      controller.input('-');
      controller.input('4');
      controller.input(')');
      controller.evaluate();
      expect(controller.display, 'Error');
    });
  });

  group('CalculatorController - repeat equals', () {
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
    test('inserts matrix literal into infix expression', () {
      controller.insertMatrixLiteral('[[1,2],[3,4]]');

      expect(controller.expression, '[[1,2],[3,4]]');
      expect(controller.display, '[[1,2],[3,4]]');
    });

    test('pushes matrix literal onto RPN stack in rpn mode', () {
      controller.setMode(CalculatorMode.rpn);

      controller.insertMatrixLiteral('[[1,2],[3,4]]');

      expect(controller.rpnStackDepth, 1);
      expect(controller.rpnTopLiteral, '[[1,2],[3,4]]');
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

      expect(controller.rpnStackDepth, 1);
      expect(controller.rpnTopLiteral, '[[8]]');
    });
  });

  group('CalculatorController - matrix display', () {
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

