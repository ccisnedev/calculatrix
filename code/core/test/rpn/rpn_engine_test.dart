import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('RpnEngine', () {
    test('pushes and peeks scalar values as 1x1 matrices', () {
      final RpnEngine engine = RpnEngine();

      engine.pushScalar(5);

      expect(engine.depth, 1);
      expect(engine.peek(), Matrix.scalar(5));
    });

    test('applies addition over top two stack values', () {
      final RpnEngine engine = RpnEngine();

      engine.pushScalar(2);
      engine.pushScalar(3);
      final Matrix result = engine.applyBinary(RpnBinaryOperator.add);

      expect(result, Matrix.scalar(5));
      expect(engine.depth, 1);
      expect(engine.peek(), Matrix.scalar(5));
    });

    test('applies matrix multiplication through stack operations', () {
      final RpnEngine engine = RpnEngine();

      engine.push(
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
        ]),
      );
      engine.push(
        Matrix(<List<double>>[
          <double>[5, 6],
          <double>[7, 8],
        ]),
      );

      final Matrix result = engine.applyBinary(RpnBinaryOperator.multiply);

      expect(
        result,
        Matrix(<List<double>>[
          <double>[19, 22],
          <double>[43, 50],
        ]),
      );
      expect(engine.depth, 1);
    });

    test('applies scalar division through stack operations', () {
      final RpnEngine engine = RpnEngine();

      engine.pushScalar(9);
      engine.pushScalar(3);
      final Matrix result = engine.applyBinary(RpnBinaryOperator.divide);

      expect(result, Matrix.scalar(3));
      expect(engine.depth, 1);
    });

    test('throws when binary operation has fewer than two values', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(1);

      expect(
        () => engine.applyBinary(RpnBinaryOperator.add),
        throwsA(isA<RpnStackUnderflowError>()),
      );
    });

    test('duplicates top value with dup', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(9);

      final Matrix duplicated = engine.dup();

      expect(duplicated, Matrix.scalar(9));
      expect(engine.depth, 2);
      expect(engine.pop(), Matrix.scalar(9));
      expect(engine.pop(), Matrix.scalar(9));
    });

    test('drops top value with drop', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(1);
      engine.pushScalar(2);

      final Matrix dropped = engine.drop();

      expect(dropped, Matrix.scalar(2));
      expect(engine.depth, 1);
      expect(engine.peek(), Matrix.scalar(1));
    });

    test('swaps top two values with swap', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(1);
      engine.pushScalar(2);

      engine.swap();

      expect(engine.pop(), Matrix.scalar(1));
      expect(engine.pop(), Matrix.scalar(2));
    });

    test('copies second value to top with over', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(3);
      engine.pushScalar(7);

      final Matrix copied = engine.over();

      expect(copied, Matrix.scalar(3));
      expect(engine.depth, 3);
      expect(engine.pop(), Matrix.scalar(3));
      expect(engine.pop(), Matrix.scalar(7));
      expect(engine.pop(), Matrix.scalar(3));
    });

    test('throws underflow for dup on empty stack', () {
      final RpnEngine engine = RpnEngine();

      expect(() => engine.dup(), throwsA(isA<RpnStackUnderflowError>()));
    });

    test('throws underflow for drop on empty stack', () {
      final RpnEngine engine = RpnEngine();

      expect(() => engine.drop(), throwsA(isA<RpnStackUnderflowError>()));
    });

    test('throws underflow for swap with fewer than two values', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(1);

      expect(() => engine.swap(), throwsA(isA<RpnStackUnderflowError>()));
    });

    test('throws underflow for over with fewer than two values', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(1);

      expect(() => engine.over(), throwsA(isA<RpnStackUnderflowError>()));
    });
  });
}
