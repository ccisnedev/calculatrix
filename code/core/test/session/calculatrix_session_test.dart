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
  });
}