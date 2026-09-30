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

    test('applies scalar 1x1 multiplication through stack operations', () {
      final RpnEngine engine = RpnEngine();

      engine.push(
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
        ]),
      );
      engine.pushScalar(3);

      final Matrix result = engine.applyBinary(RpnBinaryOperator.multiply);

      expect(
        result,
        Matrix(<List<double>>[
          <double>[3, 6],
          <double>[9, 12],
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

    test('rejects matrix division through stack operations', () {
      final RpnEngine engine = RpnEngine();

      engine.push(
        Matrix(<List<double>>[
          <double>[3, 1],
          <double>[7, 3],
        ]),
      );
      engine.push(
        Matrix(<List<double>>[
          <double>[2, 1],
          <double>[1, 1],
        ]),
      );

      expect(
        () => engine.applyBinary(RpnBinaryOperator.divide),
        throwsA(isA<UnsupportedCalculatrixOperationError>()),
      );
    });

    test('applies square root unary operation', () {
      final RpnEngine engine = RpnEngine();

      engine.pushScalar(9);
      final Matrix result = engine.applyUnary(RpnUnaryOperator.sqrt);

      expect(result, Matrix.scalar(3));
      expect(engine.depth, 1);
    });

    test('applies square root unary operation to a square matrix', () {
      final RpnEngine engine = RpnEngine();

      engine.push(
        Matrix(<List<double>>[
          <double>[5, 4],
          <double>[4, 5],
        ]),
      );
      final Matrix result = engine.applyUnary(RpnUnaryOperator.sqrt);

      expect(
        result.almostEquals(
          Matrix(<List<double>>[
            <double>[2, 1],
            <double>[1, 2],
          ]),
        ),
        isTrue,
      );
      expect(engine.depth, 1);
    });

    test('applies percent unary operation', () {
      final RpnEngine engine = RpnEngine();

      engine.pushScalar(50);
      final Matrix result = engine.applyUnary(RpnUnaryOperator.percent);

      expect(result, Matrix.scalar(0.5));
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

    test('drops top value with drop', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(1);
      engine.pushScalar(2);

      final Matrix dropped = engine.drop();

      expect(dropped, Matrix.scalar(2));
      expect(engine.depth, 1);
      expect(engine.peek(), Matrix.scalar(1));
    });

    test('throws underflow for drop on empty stack', () {
      final RpnEngine engine = RpnEngine();

      expect(() => engine.drop(), throwsA(isA<RpnStackUnderflowError>()));
    });

    test('pick copies nth value from top using 1-based indexing', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(10);
      engine.pushScalar(20);
      engine.pushScalar(30);

      final Matrix copied = engine.pick(2);

      expect(copied, Matrix.scalar(20));
      expect(engine.depth, 4);
      expect(engine.pop(), Matrix.scalar(20));
      expect(engine.pop(), Matrix.scalar(30));
      expect(engine.pop(), Matrix.scalar(20));
      expect(engine.pop(), Matrix.scalar(10));
    });

    test('roll moves nth value from top to the top using 1-based indexing', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(10);
      engine.pushScalar(20);
      engine.pushScalar(30);

      final Matrix moved = engine.roll(3);

      expect(moved, Matrix.scalar(10));
      expect(engine.depth, 3);
      expect(engine.pop(), Matrix.scalar(10));
      expect(engine.pop(), Matrix.scalar(30));
      expect(engine.pop(), Matrix.scalar(20));
    });

    test('pick throws range error for a malformed index, underflow beyond depth', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(1);

      expect(() => engine.pick(0), throwsA(isA<RpnStackRangeError>()));
      expect(() => engine.pick(2), throwsA(isA<RpnStackUnderflowError>()));
      expect(() => engine.pick(0), throwsA(isA<RpnStackError>()));
    });

    test('roll throws range error for a malformed index, underflow beyond depth', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(1);

      expect(() => engine.roll(0), throwsA(isA<RpnStackRangeError>()));
      expect(() => engine.roll(2), throwsA(isA<RpnStackUnderflowError>()));
    });

    test('applyUnary throws stack error on empty stack', () {
      final RpnEngine engine = RpnEngine();

      expect(
        () => engine.applyUnary(RpnUnaryOperator.sqrt),
        throwsA(isA<RpnStackError>()),
      );
    });

    test('applyBinary keeps both operands on the stack when the operation throws', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(3);
      engine.pushScalar(0);

      expect(
        () => engine.applyBinary(RpnBinaryOperator.divide),
        throwsA(isA<MatrixDomainError>()),
      );

      expect(engine.depth, 2);
      expect(engine.pop(), Matrix.scalar(0));
      expect(engine.pop(), Matrix.scalar(3));
    });

    test('applyBinary keeps both matrices on the stack when the operation is unsupported', () {
      final RpnEngine engine = RpnEngine();
      final Matrix left = Matrix(<List<double>>[
        <double>[3, 1],
        <double>[7, 3],
      ]);
      final Matrix right = Matrix(<List<double>>[
        <double>[2, 1],
        <double>[1, 1],
      ]);
      engine.push(left);
      engine.push(right);

      expect(
        () => engine.applyBinary(RpnBinaryOperator.divide),
        throwsA(isA<UnsupportedCalculatrixOperationError>()),
      );

      expect(engine.depth, 2);
      expect(engine.pop(), right);
      expect(engine.pop(), left);
    });

    test('applyUnary keeps the operand on the stack when the operation throws', () {
      final RpnEngine engine = RpnEngine();
      final Matrix nonSquare = Matrix(<List<double>>[
        <double>[1, 2],
      ]);
      engine.push(nonSquare);

      expect(
        () => engine.applyUnary(RpnUnaryOperator.sqrt),
        throwsA(isA<MatrixShapeError>()),
      );

      expect(engine.depth, 1);
      expect(engine.pop(), nonSquare);
    });
  });
}
