import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Calculatrix facade', () {
    test('evaluates scalar infix expression with precedence', () {
      final Matrix result = Calculatrix.evaluateInfix('3 + 4 * 5');
      expect(result, Matrix.scalar(23));
    });

    test('evaluates scalar rpn expression', () {
      final Matrix result = Calculatrix.evaluateRpn(<String>['3', '4', '+']);
      expect(result, Matrix.scalar(7));
    });

    test('evaluates matrix product in infix mode', () {
      final Matrix result = Calculatrix.evaluateInfix(
        '[[1,2],[3,4]] * [[5],[6]]',
      );

      expect(
        result,
        Matrix(<List<double>>[
          <double>[17],
          <double>[39],
        ]),
      );
    });

    test('evaluates matrix product in rpn mode', () {
      final Matrix result = Calculatrix.evaluateRpn(<String>[
        '[[1,2],[3,4]]',
        '[[5],[6]]',
        '*',
      ]);

      expect(
        result,
        Matrix(<List<double>>[
          <double>[17],
          <double>[39],
        ]),
      );
    });

    test('produces equivalent results for infix and rpn', () {
      final Matrix infix = Calculatrix.evaluateInfix('[[1,2]] * [[3],[4]]');
      final Matrix rpn = Calculatrix.evaluateRpn(<String>[
        '[[1,2]]',
        '[[3],[4]]',
        '*',
      ]);

      expect(infix, rpn);
      expect(infix, Matrix.scalar(11));
    });

    test('throws syntax error for invalid infix', () {
      expect(
        () => Calculatrix.evaluateInfix('3 + * 4'),
        throwsA(isA<ExpressionSyntaxError>()),
      );
    });

    test('throws shape error for invalid matrix operation in rpn', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>[
          '[[1,2]]',
          '[[1,2],[3,4]]',
          '+',
        ]),
        throwsA(isA<MatrixShapeError>()),
      );
    });
  });
}
