import 'package:flutter_test/flutter_test.dart';
import 'package:calculatrix/controllers/calculator_controller.dart';

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
}
