// Tests for issue #66, point 4: a minus sign in infix negates any operand
// that follows it, not only a numeric literal, with the precedence of
// standard notation and Giac: tighter than "*" and "/", looser than "^".

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

String _infix(String expression) =>
    MatrixDisplayFormatter.text(Calculatrix.evaluateInfix(expression));

final Matcher _syntaxError = throwsA(
  isA<ExpressionSyntaxError>().having(
    (ExpressionSyntaxError error) => error.errorId,
    'errorId',
    CalculatrixErrorId.syntaxError,
  ),
);

void main() {
  group('unary minus before any operand (issue #66)', () {
    test('-(2+3) is -5', () {
      expect(_infix('-(2+3)'), '-5');
    });

    test('a unary minus after an operator: 2*-(3) is -6', () {
      expect(_infix('2*-(3)'), '-6');
    });

    test('a unary minus before a function: -√9 is -3', () {
      expect(_infix('-√9'), '-3');
    });

    test('a minus apart from its number: - 2 is -2', () {
      expect(_infix('- 2'), '-2');
    });

    test('two signs: --2 is 2', () {
      expect(_infix('--2'), '2');
    });

    test('a unary plus changes nothing: +(5) is 5', () {
      expect(_infix('+(5)'), '5');
    });

    test('the result stays exact: -(1/3) is -1/3', () {
      final Matrix value = Calculatrix.evaluateInfix('-(1/3)');
      expect(value.isExact, isTrue);
      expect(MatrixDisplayFormatter.text(value), '-1/3');
    });

    test('a unary minus before a matrix group: -([[1 2]]) is [[-1 -2]]', () {
      expect(_infix('-([[1 2]])'), '[[-1 -2]]');
    });

    test('a function before a negated group is still bare: √--(4)+5 is '
        'a syntax error, √--(4) is 2', () {
      expect(() => Calculatrix.evaluateInfix('√--(4)+5'), _syntaxError);
      expect(_infix('√--(4)'), '2');
      expect(_infix('(√--(4))+5'), '7');
    });

    test('a unary minus with nothing after it is a syntax error', () {
      expect(() => Calculatrix.evaluateInfix('2*-'), _syntaxError);
      expect(() => Calculatrix.evaluateInfix('-'), _syntaxError);
    });
  });

  group('precedence of unary minus (issue #66)', () {
    test('-2^2 is -(2^2) = -4, as in Giac', () {
      expect(_infix('-2^2'), '-4');
      expect(_infix('- 2 ^ 2'), '-4');
    });

    test('(-2)^2 is 4', () {
      expect(_infix('(-2)^2'), '4');
    });

    test('a negative exponent is unchanged: 2^-2 is 0.25', () {
      expect(_infix('2^-2'), '0.25');
    });

    test('2^-2^2 is 2^(-(2^2)) = 0.0625', () {
      expect(_infix('2^-2^2'), '0.0625');
    });

    test('-(2+3)*4 is -20: the minus applies before the product', () {
      expect(_infix('-(2+3)*4'), '-20');
    });

    test('2^-(1)*4 is (2^-1)*4 = 2', () {
      expect(_infix('2^-(1)*4'), '2');
    });

    test('a percent base: -2%^2 is -(2%^2), --2%^2 is 2%^2', () {
      expect(_infix('-2%^2'), '-0.0004');
      expect(_infix('--2%^2'), '0.0004');
    });

    test('a matrix base: -[[2 0] [0 3]]^2 is -([[2 0] [0 3]]^2)', () {
      expect(_infix('-[[2 0] [0 3]]^2'), '[[-4 0] [0 -9]]');
      expect(_infix('--[[2 0] [0 3]]^2'), '[[4 0] [0 9]]');
    });

    test('signed literals that are not a base keep their meaning', () {
      expect(_infix('-2+3'), '1');
      expect(_infix('3*-2'), '-6');
      expect(_infix('-50%'), '-0.5');
      expect(_infix('-[[1 2]]'), '[[-1 -2]]');
      expect(_infix('[[1 2]]-[[3 4]]'), '[[-2 -2]]');
    });
  });

  group('tokenizeInfixExpression (issue #66)', () {
    test('a unary minus is its own token, never "-"', () {
      expect(Calculatrix.tokenizeInfixExpression('2*-(3)'), <String>[
        '2',
        '*',
        Calculatrix.infixUnaryMinus,
        '(',
        '3',
        ')',
      ]);
    });

    test('a signed literal is still one token', () {
      expect(Calculatrix.tokenizeInfixExpression('3*-2'), <String>[
        '3',
        '*',
        '-2',
      ]);
    });
  });
}
