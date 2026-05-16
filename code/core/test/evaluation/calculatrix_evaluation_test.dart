import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Calculatrix facade', () {
    test('evaluates scalar infix expression with precedence', () {
      final Matrix result = Calculatrix.evaluateInfix('3 + 4 * 5');
      expect(result, Matrix.scalar(23));
    });

    test('evaluates scalar division in infix mode', () {
      final Matrix result = Calculatrix.evaluateInfix('10 / 4');
      expect(result, Matrix.scalar(2.5));
    });

    test('evaluates scalar square root in infix mode', () {
      final Matrix result = Calculatrix.evaluateInfix('√9');
      expect(result, Matrix.scalar(3));
    });

    test('evaluates scalar percent in infix mode', () {
      final Matrix result = Calculatrix.evaluateInfix('50%');
      expect(result, Matrix.scalar(0.5));
    });

    test('evaluates scientific notation in infix mode', () {
      final Matrix result = Calculatrix.evaluateInfix('1e-3 + 2');
      expect(result.almostEquals(Matrix.scalar(2.001)), isTrue);
    });

    test('evaluates explicit unary plus in infix mode', () {
      final Matrix result = Calculatrix.evaluateInfix('+3 + (+4)');
      expect(result, Matrix.scalar(7));
    });

    test('evaluates scalar rpn expression', () {
      final Matrix result = Calculatrix.evaluateRpn(<String>['3', '4', '+']);
      expect(result, Matrix.scalar(7));
    });

    test('evaluates scalar division in rpn mode', () {
      final Matrix result = Calculatrix.evaluateRpn(<String>['10', '4', '/']);
      expect(result, Matrix.scalar(2.5));
    });

    test('evaluates scalar unary operators in rpn mode', () {
      final Matrix sqrt = Calculatrix.evaluateRpn(<String>['9', '√']);
      final Matrix percent = Calculatrix.evaluateRpn(<String>['50', '%']);

      expect(sqrt, Matrix.scalar(3));
      expect(percent, Matrix.scalar(0.5));
    });

    test('evaluates scientific notation in rpn mode', () {
      final Matrix result = Calculatrix.evaluateRpn(<String>['1e-3', '2', '+']);
      expect(result.almostEquals(Matrix.scalar(2.001)), isTrue);
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

    test('evaluates non-square outer product in infix mode', () {
      final Matrix result = Calculatrix.evaluateInfix('[[1],[2]] * [[3,4]]');

      expect(
        result,
        Matrix(<List<double>>[
          <double>[3, 4],
          <double>[6, 8],
        ]),
      );
    });

    test('evaluates matrix multiplied by scalar 1x1 in infix mode', () {
      final Matrix result = Calculatrix.evaluateInfix('[[1,0],[0,1]] * 3');

      expect(
        result,
        Matrix(<List<double>>[
          <double>[3, 0],
          <double>[0, 3],
        ]),
      );
    });

    test('evaluates scalar 1x1 multiplied by matrix in infix mode', () {
      final Matrix result = Calculatrix.evaluateInfix('3 * [[1,0],[0,1]]');

      expect(
        result,
        Matrix(<List<double>>[
          <double>[3, 0],
          <double>[0, 3],
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

    test('evaluates matrix multiplied by scalar 1x1 in rpn mode', () {
      final Matrix result = Calculatrix.evaluateRpn(<String>[
        '[[1,0],[0,1]]',
        '3',
        '*',
      ]);

      expect(
        result,
        Matrix(<List<double>>[
          <double>[3, 0],
          <double>[0, 3],
        ]),
      );
    });

    test('evaluates scalar 1x1 multiplied by matrix in rpn mode', () {
      final Matrix result = Calculatrix.evaluateRpn(<String>[
        '3',
        '[[1,0],[0,1]]',
        '*',
      ]);

      expect(
        result,
        Matrix(<List<double>>[
          <double>[3, 0],
          <double>[0, 3],
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

    test('produces numerically equivalent floating results across notations', () {
      final Matrix infix = Calculatrix.evaluateInfix('0.1 + 0.2');
      final Matrix rpn = Calculatrix.evaluateRpn(<String>['0.1', '0.2', '+']);

      expect(infix.almostEquals(rpn), isTrue);
      expect(infix.almostEquals(Matrix.scalar(0.3)), isTrue);
    });

    test('throws syntax error for invalid infix', () {
      expect(
        () => Calculatrix.evaluateInfix('3 + * 4'),
        throwsA(isA<ExpressionSyntaxError>()),
      );
    });

    test('throws syntax error for mismatched parentheses', () {
      expect(
        () => Calculatrix.evaluateInfix('(3 + 4'),
        throwsA(isA<ExpressionSyntaxError>()),
      );
    });

    test('throws shape error for ragged matrix literal', () {
      expect(
        () => Calculatrix.evaluateInfix('[[1,2],[3]]'),
        throwsA(isA<MatrixShapeError>()),
      );
    });

    test('throws shape error for invalid matrix operation in rpn', () {
      expect(
        () =>
            Calculatrix.evaluateRpn(<String>['[[1,2]]', '[[1,2],[3,4]]', '+']),
        throwsA(isA<MatrixShapeError>()),
      );
    });

    test(
      'throws unsupported operation error for matrix division by non-scalar',
      () {
        expect(
          () => Calculatrix.evaluateRpn(<String>[
            '[[1,2],[3,4]]',
            '[[1,0],[0,1]]',
            '/',
          ]),
          throwsA(isA<UnsupportedCalculatrixOperationError>()),
        );
      },
    );

    test('throws matrix domain error for division by zero scalar', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>['5', '0', '/']),
        throwsA(isA<MatrixDomainError>()),
      );
    });

    test('throws matrix domain error for sqrt of negative scalar', () {
      expect(
        () => Calculatrix.evaluateInfix('√(-4)'),
        throwsA(isA<MatrixDomainError>()),
      );
    });
  });
}
