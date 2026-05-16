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

    test('throws when binary operation has fewer than two values', () {
      final RpnEngine engine = RpnEngine();
      engine.pushScalar(1);

      expect(() => engine.applyBinary(RpnBinaryOperator.add), throwsStateError);
    });
  });
}
