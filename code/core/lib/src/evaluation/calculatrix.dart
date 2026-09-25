import 'dart:convert';

import '../errors/errors.dart';
import '../machine/calculatrix_command.dart';
import '../machine/calculatrix_machine.dart';
import '../machine/calculatrix_program.dart';
import '../machine/commands.dart';
import '../matrix/matrix.dart';

class Calculatrix {
  static CalculatrixProgram compileInfix(String expression) {
    final String source = expression.trim();
    if (source.isEmpty) {
      throw ExpressionSyntaxError(
        'Expression cannot be empty.',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }

    final List<String> infixTokens = _tokenizeInfix(source);
    _validateInfixTokens(infixTokens);
    final List<String> rpnTokens = _toRpn(infixTokens);
    return _compileRpnTokens(rpnTokens);
  }

  static Matrix evaluateInfix(String expression) {
    try {
      final CalculatrixMachine machine = CalculatrixMachine();
      machine.executeProgram(compileInfix(expression));
      return _singleResult(machine, expression: expression, notation: 'infix');
    } on RpnStackUnderflowError catch (_) {
      throw ExpressionSyntaxError(
        'Invalid infix expression: $expression',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }
  }

  static Matrix evaluateRpn(List<String> tokens) {
    final CalculatrixMachine machine = CalculatrixMachine();
    machine.executeProgram(_compileRpnTokens(tokens));
    return _singleResult(machine, expression: tokens.join(' '), notation: 'RPN');
  }

  static CalculatrixProgram _compileRpnTokens(List<String> tokens) {
    if (tokens.isEmpty) {
      throw ExpressionSyntaxError(
        'RPN token list cannot be empty.',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }

    final List<CalculatrixCommand> commands = <CalculatrixCommand>[];
    for (final String rawToken in tokens) {
      final String token = rawToken.trim();
      if (token.isEmpty) {
        continue;
      }

      commands.add(_compileRpnToken(token));
    }

    return CalculatrixProgram(commands);
  }

  static CalculatrixCommand _compileRpnToken(String token) {
    switch (token) {
      case '+':
        return const AddCommand();
      case '-':
        return const SubtractCommand();
      case '*':
        return const MultiplyCommand();
      case '/':
        return const DivideCommand();
      case '√':
        return const SqrtCommand();
      case '%':
        return const PercentCommand();
      case '^':
        return const PowerCommand();
      default:
        if (_looksLikeMatrixLiteral(token)) {
          return PushMatrixCommand(_parseMatrixLiteral(token));
        }

        final double? value = double.tryParse(token);
        if (value != null) {
          if (!value.isFinite) {
            throw MatrixDomainError(
              'Numeric literal is not a finite number: $token',
              errorId: CalculatrixErrorId.nonFinite,
              token: token,
            );
          }
          return PushScalarCommand(value);
        }

        throw UnknownWordError(token);
    }
  }

  static Matrix _singleResult(
    CalculatrixMachine machine, {
    required String expression,
    required String notation,
  }) {
    final Matrix? top = machine.top;
    if (machine.depth != 1 || top == null) {
      throw ExpressionSyntaxError(
        'Invalid $notation expression: expected single result, found ${machine.depth}.',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }

    return top;
  }

  static bool _looksLikeMatrixLiteral(String token) {
    return token.startsWith('[') && token.endsWith(']');
  }

  static Matrix _parseMatrixLiteral(String token) {
    dynamic decoded;
    try {
      decoded = jsonDecode(token);
    } catch (_) {
      throw ExpressionSyntaxError(
        'Invalid matrix literal: $token',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }

    if (decoded is num) {
      return Matrix.scalar(_checkFiniteLiteralEntry(decoded, token));
    }

    if (decoded is! List) {
      throw ExpressionSyntaxError(
        'Matrix literal must decode to a list: $token',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }

    if (decoded.isEmpty) {
      throw MatrixShapeError(
        'Matrix literal cannot be empty.',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }

    if (decoded.every((dynamic item) => item is num)) {
      return Matrix(<List<double>>[
        decoded
            .map(
              (dynamic item) => _checkFiniteLiteralEntry(item as num, token),
            )
            .toList(),
      ]);
    }

    final List<List<double>> rows = <List<double>>[];
    for (final dynamic row in decoded) {
      if (row is! List || row.isEmpty) {
        throw ExpressionSyntaxError(
          'Invalid matrix row in literal: $token',
          errorId: CalculatrixErrorId.syntaxError,
        );
      }

      final List<double> parsedRow = <double>[];
      for (final dynamic item in row) {
        if (item is! num) {
          throw ExpressionSyntaxError(
            'Matrix literal must contain only numbers.',
            errorId: CalculatrixErrorId.syntaxError,
          );
        }
        parsedRow.add(_checkFiniteLiteralEntry(item, token));
      }
      rows.add(parsedRow);
    }

    return Matrix(rows);
  }

  /// Guards a decoded matrix-literal entry against non-finite values
  /// (`Infinity`, `-Infinity`, `NaN`) so a literal like `1e999` never
  /// silently becomes an infinite matrix entry; it raises `non-finite`
  /// instead.
  static double _checkFiniteLiteralEntry(num item, String token) {
    final double value = item.toDouble();
    if (!value.isFinite) {
      throw MatrixDomainError(
        'Matrix literal contains a non-finite value: $token',
        errorId: CalculatrixErrorId.nonFinite,
      );
    }
    return value;
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
        tokens.add(_requireParseableNumberToken(scan.token));
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
          throw ExpressionSyntaxError(
            'Unbalanced matrix literal brackets.',
            errorId: CalculatrixErrorId.syntaxError,
          );
        }

        tokens.add(expression.substring(start, index));
        continue;
      }

      if (_isNumberStart(char)) {
        final _NumberScanResult scan = _scanNumber(expression, index);
        tokens.add(_requireParseableNumberToken(scan.token));
        index = scan.nextIndex;
        continue;
      }

      throw ExpressionSyntaxError(
        'Unexpected token near "$char".',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }

    return tokens;
  }

  /// Rejects a scanned number token that is not a parseable double (for
  /// example `1e`, an exponent marker with no exponent digits) right at
  /// tokenize time, with `syntax-error`. Without this, an unparseable
  /// number token would otherwise reach the RPN compiler as an opaque
  /// operand and surface as the wrong id (`unknown-word`) instead of the
  /// syntax error it actually is; this check is infix-only; RPN's own
  /// token compiler already validates numeric literals independently.
  static String _requireParseableNumberToken(String token) {
    if (double.tryParse(token) == null) {
      throw ExpressionSyntaxError(
        'Invalid numeric literal: $token',
        errorId: CalculatrixErrorId.syntaxError,
        token: token,
      );
    }
    return token;
  }

  static void _validateInfixTokens(List<String> tokens) {
    final List<_InfixValidationFrame> frames = <_InfixValidationFrame>[
      _InfixValidationFrame(),
    ];
    bool expectOperand = true;

    for (final String token in tokens) {
      final _InfixValidationFrame frame = frames.last;

      if (frame.bareClosed && token != ')') {
        throw ExpressionSyntaxError(
          'A bare function argument must be parenthesized to combine it '
          'with further operators near "$token".',
          errorId: CalculatrixErrorId.syntaxError,
        );
      }

      if (_isOperand(token)) {
        if (!expectOperand) {
          throw ExpressionSyntaxError(
            'Unexpected operand "$token"; an operator was expected.',
            errorId: CalculatrixErrorId.syntaxError,
          );
        }
        if (frame.pendingFunctionCount > 0) {
          frame.pendingFunctionCount = 0;
          frame.bareClosed = true;
        }
        expectOperand = false;
        continue;
      }

      if (_isFunction(token)) {
        if (!expectOperand) {
          throw ExpressionSyntaxError(
            'Unexpected function "$token"; an operator was expected.',
            errorId: CalculatrixErrorId.syntaxError,
          );
        }
        // Tracked as a count, not a boolean (round 4 correction, case H):
        // consecutive prefix functions (e.g. `√√(16)`) each push their own
        // pending obligation onto the *same* frame: a boolean can only
        // ever remember whether *some* function is pending, not how many,
        // so a nested `(...)` group that resolves one of them (see below)
        // would wrongly erase all of them at once.
        frame.pendingFunctionCount++;
        continue;
      }

      if (token == '(') {
        if (!expectOperand) {
          throw ExpressionSyntaxError(
            'Unexpected "("; an operator was expected.',
            errorId: CalculatrixErrorId.syntaxError,
          );
        }
        // Only the *immediately* preceding function is parenthesized by
        // this group (`f(...)` makes `f` no longer bare): any further
        // pending functions stacked on this same frame from before it
        // (e.g. the outer `√` in `√√(16)`) remain pending across the
        // nested group and must still be resolved once it closes.
        if (frame.pendingFunctionCount > 0) {
          frame.pendingFunctionCount--;
        }
        frames.add(_InfixValidationFrame());
        continue;
      }

      if (token == ')') {
        if (expectOperand) {
          throw ExpressionSyntaxError(
            'Empty parentheses are not a valid operand.',
            errorId: CalculatrixErrorId.syntaxError,
          );
        }
        if (frames.length > 1) {
          frames.removeLast();
          // The just-closed group is itself a complete operand for
          // whatever pending function(s) remain on the parent frame (e.g.
          // the outer `√` in `√√(16)`), resolve it exactly as an operand
          // token would, so a further bare operator after it is still
          // rejected.
          final _InfixValidationFrame parent = frames.last;
          if (parent.pendingFunctionCount > 0) {
            parent.pendingFunctionCount = 0;
            parent.bareClosed = true;
          }
        }
        expectOperand = false;
        continue;
      }

      if (_isOperator(token)) {
        if (expectOperand) {
          throw ExpressionSyntaxError(
            'Unexpected operator "$token"; an operand was expected.',
            errorId: CalculatrixErrorId.syntaxError,
          );
        }
        expectOperand = true;
        continue;
      }

      if (_isPostfixOperator(token)) {
        if (expectOperand) {
          throw ExpressionSyntaxError(
            'Unexpected "$token"; an operand was expected.',
            errorId: CalculatrixErrorId.syntaxError,
          );
        }
        continue;
      }

      throw ExpressionSyntaxError(
        'Unsupported token in infix expression: $token',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }

    if (expectOperand) {
      throw ExpressionSyntaxError(
        'Expression ends with an incomplete operand.',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }
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
            (_isRightAssociative(token)
                ? _precedence(operators.last) > _precedence(token)
                : _precedence(operators.last) >= _precedence(token))) {
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
          throw ExpressionSyntaxError(
            'Mismatched parentheses in expression.',
            errorId: CalculatrixErrorId.syntaxError,
          );
        }

        if (operators.isNotEmpty && _isFunction(operators.last)) {
          output.add(operators.removeLast());
        }
        continue;
      }

      throw ExpressionSyntaxError(
        'Unsupported token in infix expression: $token',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }

    while (operators.isNotEmpty) {
      final String op = operators.removeLast();
      if (op == '(' || op == ')') {
        throw ExpressionSyntaxError(
          'Mismatched parentheses in expression.',
          errorId: CalculatrixErrorId.syntaxError,
        );
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
    return token == '+' ||
        token == '-' ||
        token == '*' ||
        token == '/' ||
        token == '^';
  }

  static bool _isRightAssociative(String token) {
    return token == '^';
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
      case '^':
        return 3;
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

class _InfixValidationFrame {
  // A count, not a boolean, because consecutive prefix functions (e.g.
  // `√√(16)`) stack more than one pending obligation on the same frame:
  // see the round 4 correction (case H) doc comments at the call sites in
  // [Calculatrix._validateInfixTokens].
  int pendingFunctionCount = 0;
  bool bareClosed = false;
}
