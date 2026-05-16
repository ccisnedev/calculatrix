import 'dart:convert';

import '../errors/errors.dart';
import '../matrix/matrix.dart';
import '../rpn/rpn_engine.dart';

class Calculatrix {
  static Matrix evaluateInfix(String expression) {
    final String source = expression.trim();
    if (source.isEmpty) {
      throw ExpressionSyntaxError('Expression cannot be empty.');
    }

    final List<String> infixTokens = _tokenizeInfix(source);
    final List<String> rpnTokens = _toRpn(infixTokens);
    try {
      return evaluateRpn(rpnTokens);
    } on RpnStackUnderflowError catch (_) {
      throw ExpressionSyntaxError('Invalid infix expression: $expression');
    }
  }

  static Matrix evaluateRpn(List<String> tokens) {
    if (tokens.isEmpty) {
      throw ExpressionSyntaxError('RPN token list cannot be empty.');
    }

    final RpnEngine engine = RpnEngine();

    for (final String rawToken in tokens) {
      final String token = rawToken.trim();
      if (token.isEmpty) {
        continue;
      }

      switch (token) {
        case '+':
          engine.applyBinary(RpnBinaryOperator.add);
          continue;
        case '-':
          engine.applyBinary(RpnBinaryOperator.subtract);
          continue;
        case '*':
          engine.applyBinary(RpnBinaryOperator.multiply);
          continue;
        case '/':
          engine.applyBinary(RpnBinaryOperator.divide);
          continue;
        case '√':
          engine.applyUnary(RpnUnaryOperator.sqrt);
          continue;
        case '%':
          engine.applyUnary(RpnUnaryOperator.percent);
          continue;
        default:
          engine.push(_parseOperandToken(token));
      }
    }

    if (engine.depth != 1) {
      throw ExpressionSyntaxError(
        'Invalid RPN expression: expected single result, found ${engine.depth}.',
      );
    }

    return engine.pop();
  }

  static Matrix _parseOperandToken(String token) {
    if (_looksLikeMatrixLiteral(token)) {
      return _parseMatrixLiteral(token);
    }

    final double? value = double.tryParse(token);
    if (value != null) {
      return Matrix.scalar(value);
    }

    throw ExpressionSyntaxError('Invalid operand token: $token');
  }

  static bool _looksLikeMatrixLiteral(String token) {
    return token.startsWith('[') && token.endsWith(']');
  }

  static Matrix _parseMatrixLiteral(String token) {
    dynamic decoded;
    try {
      decoded = jsonDecode(token);
    } catch (_) {
      throw ExpressionSyntaxError('Invalid matrix literal: $token');
    }

    if (decoded is num) {
      return Matrix.scalar(decoded.toDouble());
    }

    if (decoded is! List) {
      throw ExpressionSyntaxError(
        'Matrix literal must decode to a list: $token',
      );
    }

    if (decoded.isEmpty) {
      throw MatrixShapeError('Matrix literal cannot be empty.');
    }

    if (decoded.every((dynamic item) => item is num)) {
      return Matrix(<List<double>>[
        decoded.map((dynamic item) => (item as num).toDouble()).toList(),
      ]);
    }

    final List<List<double>> rows = <List<double>>[];
    for (final dynamic row in decoded) {
      if (row is! List || row.isEmpty) {
        throw ExpressionSyntaxError('Invalid matrix row in literal: $token');
      }

      final List<double> parsedRow = <double>[];
      for (final dynamic item in row) {
        if (item is! num) {
          throw ExpressionSyntaxError(
            'Matrix literal must contain only numbers.',
          );
        }
        parsedRow.add(item.toDouble());
      }
      rows.add(parsedRow);
    }

    return Matrix(rows);
  }

  static List<String> _tokenizeInfix(String expression) {
    final List<String> tokens = <String>[];
    int index = 0;

    while (index < expression.length) {
      final String char = expression[index];

      if (char.trim().isEmpty) {
        index++;
        continue;
      }

      if (_isSignedNumberStart(expression, index, tokens)) {
        final _NumberScanResult scan = _scanNumber(expression, index);
        tokens.add(scan.token);
        index = scan.nextIndex;
        continue;
      }

      if (_isOperator(char) ||
          _isFunction(char) ||
          _isPostfixOperator(char) ||
          char == '(' ||
          char == ')') {
        tokens.add(char);
        index++;
        continue;
      }

      if (char == '[') {
        final int start = index;
        int depth = 0;
        while (index < expression.length) {
          final String current = expression[index];
          if (current == '[') {
            depth++;
          } else if (current == ']') {
            depth--;
            if (depth == 0) {
              index++;
              break;
            }
          }
          index++;
        }

        if (depth != 0) {
          throw ExpressionSyntaxError('Unbalanced matrix literal brackets.');
        }

        tokens.add(expression.substring(start, index));
        continue;
      }

      if (_isNumberStart(char)) {
        final _NumberScanResult scan = _scanNumber(expression, index);
        tokens.add(scan.token);
        index = scan.nextIndex;
        continue;
      }

      throw ExpressionSyntaxError('Unexpected token near "$char".');
    }

    return tokens;
  }

  static List<String> _toRpn(List<String> infixTokens) {
    final List<String> output = <String>[];
    final List<String> operators = <String>[];

    for (final String token in infixTokens) {
      if (_isOperand(token)) {
        output.add(token);
        continue;
      }

      if (_isOperator(token)) {
        while (operators.isNotEmpty &&
            _isOperator(operators.last) &&
            _precedence(operators.last) >= _precedence(token)) {
          output.add(operators.removeLast());
        }
        operators.add(token);
        continue;
      }

      if (_isFunction(token)) {
        operators.add(token);
        continue;
      }

      if (_isPostfixOperator(token)) {
        output.add(token);
        continue;
      }

      if (token == '(') {
        operators.add(token);
        continue;
      }

      if (token == ')') {
        bool foundOpen = false;
        while (operators.isNotEmpty) {
          final String op = operators.removeLast();
          if (op == '(') {
            foundOpen = true;
            break;
          }
          output.add(op);
        }
        if (!foundOpen) {
          throw ExpressionSyntaxError('Mismatched parentheses in expression.');
        }

        if (operators.isNotEmpty && _isFunction(operators.last)) {
          output.add(operators.removeLast());
        }
        continue;
      }

      throw ExpressionSyntaxError(
        'Unsupported token in infix expression: $token',
      );
    }

    while (operators.isNotEmpty) {
      final String op = operators.removeLast();
      if (op == '(' || op == ')') {
        throw ExpressionSyntaxError('Mismatched parentheses in expression.');
      }
      output.add(op);
    }

    return output;
  }

  static bool _isOperand(String token) {
    return !_isOperator(token) &&
        !_isFunction(token) &&
        !_isPostfixOperator(token) &&
        token != '(' &&
        token != ')';
  }

  static bool _isOperator(String token) {
    return token == '+' || token == '-' || token == '*' || token == '/';
  }

  static bool _isFunction(String token) {
    return token == '√';
  }

  static bool _isPostfixOperator(String token) {
    return token == '%';
  }

  static int _precedence(String token) {
    switch (token) {
      case '+':
      case '-':
        return 1;
      case '*':
      case '/':
        return 2;
      default:
        return -1;
    }
  }

  static bool _isNumberStart(String char) {
    final int code = char.codeUnitAt(0);
    return _isAsciiDigit(code) || code == _dotCode;
  }

  static bool _isSignedNumberStart(
    String source,
    int index,
    List<String> tokens,
  ) {
    final String sign = source[index];
    if (sign != '-' && sign != '+') {
      return false;
    }

    final bool unaryPosition =
        tokens.isEmpty ||
        _isOperator(tokens.last) ||
        _isFunction(tokens.last) ||
        tokens.last == '(';

    if (!unaryPosition) {
      return false;
    }

    if (index + 1 >= source.length) {
      return false;
    }

    return _isNumberStart(source[index + 1]);
  }

  static _NumberScanResult _scanNumber(String source, int start) {
    int index = start;
    bool seenDot = false;
    bool seenExponent = false;

    if (index < source.length &&
        (source[index] == '-' || source[index] == '+')) {
      index++;
    }

    while (index < source.length) {
      final int current = source.codeUnitAt(index);

      if (_isAsciiDigit(current)) {
        index++;
        continue;
      }

      if (current == _dotCode && !seenDot && !seenExponent) {
        seenDot = true;
        index++;
        continue;
      }

      if ((current == _lowerECode || current == _upperECode) && !seenExponent) {
        seenExponent = true;
        index++;
        if (index < source.length &&
            (source[index] == '+' || source[index] == '-')) {
          index++;
        }
        continue;
      }

      break;
    }

    return _NumberScanResult(source.substring(start, index), index);
  }

  static bool _isAsciiDigit(int code) {
    return code >= _zeroCode && code <= _nineCode;
  }

  static const int _zeroCode = 48;
  static const int _nineCode = 57;
  static const int _dotCode = 46;
  static const int _lowerECode = 101;
  static const int _upperECode = 69;
}

class _NumberScanResult {
  const _NumberScanResult(this.token, this.nextIndex);

  final String token;
  final int nextIndex;
}
