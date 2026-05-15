import 'package:flutter_test/flutter_test.dart';
import 'package:calculatrix/modules/calc/controller.dart';

void main() {
  late CalculatorController controller;

  setUp(() {
    controller = CalculatorController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('CalculatorController', () {
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
}
