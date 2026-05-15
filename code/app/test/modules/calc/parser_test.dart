import 'package:flutter_test/flutter_test.dart';
import 'package:calculatrix/modules/calc/models/token.dart';
import 'package:calculatrix/modules/calc/models/parser.dart';

void main() {
  late Parser parser;

  setUp(() {
    parser = Parser();
  });

  group('Parser - single numbers', () {
    test('parses single integer', () {
      final tokens = [const Token(TokenType.number, '42')];
      final ast = parser.parse(tokens);
      expect(ast, isA<NumberNode>());
      expect((ast as NumberNode).value, 42.0);
    });

    test('parses single decimal', () {
      final tokens = [const Token(TokenType.number, '3.14')];
      final ast = parser.parse(tokens);
      expect((ast as NumberNode).value, 3.14);
    });
  });

  group('Parser - binary operations', () {
    test('parses addition', () {
      final tokens = [
        const Token(TokenType.number, '3'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '4'),
      ];
      final ast = parser.parse(tokens);
      expect(ast, isA<BinaryOpNode>());
      final bin = ast as BinaryOpNode;
      expect(bin.operator, '+');
      expect((bin.left as NumberNode).value, 3.0);
      expect((bin.right as NumberNode).value, 4.0);
    });

    test('parses subtraction', () {
      final tokens = [
        const Token(TokenType.number, '10'),
        const Token(TokenType.minus, '-'),
        const Token(TokenType.number, '3'),
      ];
      final ast = parser.parse(tokens);
      final bin = ast as BinaryOpNode;
      expect(bin.operator, '-');
    });

    test('parses multiplication', () {
      final tokens = [
        const Token(TokenType.number, '5'),
        const Token(TokenType.multiply, '×'),
        const Token(TokenType.number, '6'),
      ];
      final ast = parser.parse(tokens);
      final bin = ast as BinaryOpNode;
      expect(bin.operator, '×');
    });

    test('parses division', () {
      final tokens = [
        const Token(TokenType.number, '8'),
        const Token(TokenType.divide, '÷'),
        const Token(TokenType.number, '2'),
      ];
      final ast = parser.parse(tokens);
      final bin = ast as BinaryOpNode;
      expect(bin.operator, '÷');
    });
  });

  group('Parser - precedence (PEMDAS)', () {
    test('multiplication before addition: 3+4×5 = 3+(4×5)', () {
      final tokens = [
        const Token(TokenType.number, '3'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '4'),
        const Token(TokenType.multiply, '×'),
        const Token(TokenType.number, '5'),
      ];
      final ast = parser.parse(tokens);
      // Should be: Add(3, Mul(4, 5))
      final bin = ast as BinaryOpNode;
      expect(bin.operator, '+');
      expect((bin.left as NumberNode).value, 3.0);
      final right = bin.right as BinaryOpNode;
      expect(right.operator, '×');
      expect((right.left as NumberNode).value, 4.0);
      expect((right.right as NumberNode).value, 5.0);
    });

    test('division before subtraction: 10-8÷2 = 10-(8÷2)', () {
      final tokens = [
        const Token(TokenType.number, '10'),
        const Token(TokenType.minus, '-'),
        const Token(TokenType.number, '8'),
        const Token(TokenType.divide, '÷'),
        const Token(TokenType.number, '2'),
      ];
      final ast = parser.parse(tokens);
      final bin = ast as BinaryOpNode;
      expect(bin.operator, '-');
      expect((bin.left as NumberNode).value, 10.0);
      final right = bin.right as BinaryOpNode;
      expect(right.operator, '÷');
    });

    test('left associativity: 10-3-2 = (10-3)-2', () {
      final tokens = [
        const Token(TokenType.number, '10'),
        const Token(TokenType.minus, '-'),
        const Token(TokenType.number, '3'),
        const Token(TokenType.minus, '-'),
        const Token(TokenType.number, '2'),
      ];
      final ast = parser.parse(tokens);
      final bin = ast as BinaryOpNode;
      expect(bin.operator, '-');
      expect((bin.right as NumberNode).value, 2.0);
      final left = bin.left as BinaryOpNode;
      expect(left.operator, '-');
      expect((left.left as NumberNode).value, 10.0);
      expect((left.right as NumberNode).value, 3.0);
    });
  });

  group('Parser - parentheses', () {
    test('parens override precedence: (3+4)×5', () {
      final tokens = [
        const Token(TokenType.leftParen, '('),
        const Token(TokenType.number, '3'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '4'),
        const Token(TokenType.rightParen, ')'),
        const Token(TokenType.multiply, '×'),
        const Token(TokenType.number, '5'),
      ];
      final ast = parser.parse(tokens);
      // Should be: Mul(Add(3, 4), 5)
      final bin = ast as BinaryOpNode;
      expect(bin.operator, '×');
      final left = bin.left as BinaryOpNode;
      expect(left.operator, '+');
      expect((bin.right as NumberNode).value, 5.0);
    });

    test('nested parens: (2+(3×4))', () {
      final tokens = [
        const Token(TokenType.leftParen, '('),
        const Token(TokenType.number, '2'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.leftParen, '('),
        const Token(TokenType.number, '3'),
        const Token(TokenType.multiply, '×'),
        const Token(TokenType.number, '4'),
        const Token(TokenType.rightParen, ')'),
        const Token(TokenType.rightParen, ')'),
      ];
      final ast = parser.parse(tokens);
      final bin = ast as BinaryOpNode;
      expect(bin.operator, '+');
      expect((bin.left as NumberNode).value, 2.0);
      final right = bin.right as BinaryOpNode;
      expect(right.operator, '×');
    });
  });

  group('Parser - unary negation', () {
    test('leading negative: -5', () {
      final tokens = [
        const Token(TokenType.minus, '-'),
        const Token(TokenType.number, '5'),
      ];
      final ast = parser.parse(tokens);
      expect(ast, isA<UnaryOpNode>());
      final unary = ast as UnaryOpNode;
      expect(unary.operator, '-');
      expect((unary.operand as NumberNode).value, 5.0);
    });

    test('negative after operator: 3×-2', () {
      final tokens = [
        const Token(TokenType.number, '3'),
        const Token(TokenType.multiply, '×'),
        const Token(TokenType.minus, '-'),
        const Token(TokenType.number, '2'),
      ];
      final ast = parser.parse(tokens);
      final bin = ast as BinaryOpNode;
      expect(bin.operator, '×');
      expect((bin.left as NumberNode).value, 3.0);
      final right = bin.right as UnaryOpNode;
      expect(right.operator, '-');
      expect((right.operand as NumberNode).value, 2.0);
    });

    test('negative in parens: (-3+4)', () {
      final tokens = [
        const Token(TokenType.leftParen, '('),
        const Token(TokenType.minus, '-'),
        const Token(TokenType.number, '3'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '4'),
        const Token(TokenType.rightParen, ')'),
      ];
      final ast = parser.parse(tokens);
      final bin = ast as BinaryOpNode;
      expect(bin.operator, '+');
      expect(bin.left, isA<UnaryOpNode>());
    });
  });

  group('Parser - errors', () {
    test('throws on empty input', () {
      expect(() => parser.parse([]), throwsA(isA<FormatException>()));
    });

    test('throws on missing right operand', () {
      final tokens = [
        const Token(TokenType.number, '3'),
        const Token(TokenType.plus, '+'),
      ];
      expect(() => parser.parse(tokens), throwsA(isA<FormatException>()));
    });

    test('throws on unmatched left paren', () {
      final tokens = [
        const Token(TokenType.leftParen, '('),
        const Token(TokenType.number, '3'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '4'),
      ];
      expect(() => parser.parse(tokens), throwsA(isA<FormatException>()));
    });
  });
}
