import 'token.dart';

/// Converts a raw expression string into a list of [Token]s.
///
/// Supports:
/// - Integer and decimal numbers (e.g. "3", "3.14")
/// - Operators: +, -, ×, *, ÷, /
/// - Parentheses: (, )
///
/// Throws [FormatException] on unrecognized characters.
class Tokenizer {
  /// Tokenizes the given [input] string into a list of tokens.
  List<Token> tokenize(String input) {
    final tokens = <Token>[];
    final chars = input.replaceAll(' ', '');
    var i = 0;

    while (i < chars.length) {
      final char = chars[i];

      if (_isDigit(char) || char == '.') {
        final start = i;
        while (i < chars.length && (_isDigit(chars[i]) || chars[i] == '.')) {
          i++;
        }
        final value = chars.substring(start, i);
        if (!_isValidNumber(value)) {
          throw FormatException('Invalid number: "$value"');
        }
        tokens.add(Token(TokenType.number, value));
      } else if (char == '+') {
        tokens.add(const Token(TokenType.plus, '+'));
        i++;
      } else if (char == '-') {
        tokens.add(const Token(TokenType.minus, '-'));
        i++;
      } else if (char == '×' || char == '*') {
        tokens.add(const Token(TokenType.multiply, '×'));
        i++;
      } else if (char == '÷' || char == '/') {
        tokens.add(const Token(TokenType.divide, '÷'));
        i++;
      } else if (char == '(') {
        tokens.add(const Token(TokenType.leftParen, '('));
        i++;
      } else if (char == ')') {
        tokens.add(const Token(TokenType.rightParen, ')'));
        i++;
      } else if (char == '√') {
        tokens.add(const Token(TokenType.sqrt, '√'));
        i++;
      } else if (char == '%') {
        tokens.add(const Token(TokenType.percent, '%'));
        i++;
      } else {
        throw FormatException('Unexpected character: "$char"');
      }
    }

    return tokens;
  }

  bool _isDigit(String char) => char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

  bool _isValidNumber(String value) {
    if (value.isEmpty) return false;
    final dotCount = value.split('.').length - 1;
    if (dotCount > 1) return false;
    if (value == '.') return false;
    return true;
  }
}
