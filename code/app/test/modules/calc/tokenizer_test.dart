import 'package:flutter_test/flutter_test.dart';
import 'package:calculatrix_app/modules/calc/models/token.dart';
import 'package:calculatrix_app/modules/calc/models/tokenizer.dart';

void main() {
  late Tokenizer tokenizer;

  setUp(() {
    tokenizer = Tokenizer();
  });

  group('Tokenizer - numbers', () {
    test('tokenizes single integer', () {
      final tokens = tokenizer.tokenize('42');
      expect(tokens, [const Token(TokenType.number, '42')]);
    });

    test('tokenizes single decimal', () {
      final tokens = tokenizer.tokenize('3.14');
      expect(tokens, [const Token(TokenType.number, '3.14')]);
    });

    test('tokenizes number starting with dot', () {
      final tokens = tokenizer.tokenize('.5');
      expect(tokens, [const Token(TokenType.number, '.5')]);
    });

    test('tokenizes multiple digits', () {
      final tokens = tokenizer.tokenize('12345');
      expect(tokens, [const Token(TokenType.number, '12345')]);
    });

    test('rejects double dots', () {
      expect(
        () => tokenizer.tokenize('3.14.15'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects lone dot', () {
      expect(
        () => tokenizer.tokenize('.'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Tokenizer - operators', () {
    test('tokenizes plus', () {
      final tokens = tokenizer.tokenize('+');
      expect(tokens, [const Token(TokenType.plus, '+')]);
    });

    test('tokenizes minus', () {
      final tokens = tokenizer.tokenize('-');
      expect(tokens, [const Token(TokenType.minus, '-')]);
    });

    test('tokenizes multiply (×)', () {
      final tokens = tokenizer.tokenize('×');
      expect(tokens, [const Token(TokenType.multiply, '×')]);
    });

    test('tokenizes multiply (*) as ×', () {
      final tokens = tokenizer.tokenize('*');
      expect(tokens, [const Token(TokenType.multiply, '×')]);
    });

    test('tokenizes divide (÷)', () {
      final tokens = tokenizer.tokenize('÷');
      expect(tokens, [const Token(TokenType.divide, '÷')]);
    });

    test('tokenizes divide (/) as ÷', () {
      final tokens = tokenizer.tokenize('/');
      expect(tokens, [const Token(TokenType.divide, '÷')]);
    });
  });

  group('Tokenizer - parentheses', () {
    test('tokenizes left paren', () {
      final tokens = tokenizer.tokenize('(');
      expect(tokens, [const Token(TokenType.leftParen, '(')]);
    });

    test('tokenizes right paren', () {
      final tokens = tokenizer.tokenize(')');
      expect(tokens, [const Token(TokenType.rightParen, ')')]);
    });
  });

  group('Tokenizer - expressions', () {
    test('tokenizes simple addition', () {
      final tokens = tokenizer.tokenize('3+4');
      expect(tokens, [
        const Token(TokenType.number, '3'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '4'),
      ]);
    });

    test('tokenizes expression with spaces', () {
      final tokens = tokenizer.tokenize('3 + 4');
      expect(tokens, [
        const Token(TokenType.number, '3'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '4'),
      ]);
    });

    test('tokenizes complex expression', () {
      final tokens = tokenizer.tokenize('(3+4)×5');
      expect(tokens, [
        const Token(TokenType.leftParen, '('),
        const Token(TokenType.number, '3'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '4'),
        const Token(TokenType.rightParen, ')'),
        const Token(TokenType.multiply, '×'),
        const Token(TokenType.number, '5'),
      ]);
    });

    test('tokenizes expression with decimals', () {
      final tokens = tokenizer.tokenize('3.14×2.0');
      expect(tokens, [
        const Token(TokenType.number, '3.14'),
        const Token(TokenType.multiply, '×'),
        const Token(TokenType.number, '2.0'),
      ]);
    });

    test('tokenizes empty string as empty list', () {
      final tokens = tokenizer.tokenize('');
      expect(tokens, isEmpty);
    });

    test('tokenizes spaces-only string as empty list', () {
      final tokens = tokenizer.tokenize('   ');
      expect(tokens, isEmpty);
    });
  });

  group('Tokenizer - errors', () {
    test('throws on unrecognized character', () {
      expect(
        () => tokenizer.tokenize('3 & 4'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on letter', () {
      expect(
        () => tokenizer.tokenize('abc'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

