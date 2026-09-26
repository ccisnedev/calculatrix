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
      throw ExpressionSyntaxError('Expression cannot be empty.');
    }

    final List<String> infixTokens = _tokenizeInfix(source);
    final List<String> rpnTokens = _toRpn(infixTokens);
    return _compileRpnTokens(rpnTokens);
  }

  static Matrix evaluateInfix(String expression) {
    try {
      final CalculatrixMachine machine = CalculatrixMachine();
      machine.executeProgram(compileInfix(expression));
      return _singleResult(machine, expression: expression, notation: 'infix');
    } on RpnStackUnderflowError catch (_) {
      throw ExpressionSyntaxError('Invalid infix expression: $expression');
    }
  }

  static Matrix evaluateRpn(List<String> tokens) {
    final CalculatrixMachine machine = CalculatrixMachine();
    machine.executeProgram(_compileRpnTokens(tokens));
    return _singleResult(machine, expression: tokens.join(' '), notation: 'RPN');
  }

  static CalculatrixProgram _compileRpnTokens(List<String> tokens) {
    if (tokens.isEmpty) {
      throw ExpressionSyntaxError('RPN token list cannot be empty.');
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
      default:
        if (_looksLikeMatrixLiteral(token)) {
          return PushMatrixCommand(_parseSignedMatrixLiteral(token));
        }

        final double? value = double.tryParse(token);
        if (value != null) {
          return PushScalarCommand(value);
        }

        throw ExpressionSyntaxError('Invalid operand token: $token');
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
      );
    }

    return top;
  }

  static bool _looksLikeMatrixLiteral(String token) {
    final String unsigned = _stripLeadingMatrixSign(token);
    return unsigned.startsWith('[') && unsigned.endsWith(']');
  }

  // A matrix literal token may carry a leading sign, e.g. "-[[1,2],[3,4]]",
  // produced by toggling ± on a matrix operand in the rpn command line (see
  // CalculatrixSession._toggleSignOfLastToken). The sign is handled here,
  // as a scale(-1) applied after the ordinary, unsigned literal is decoded,
  // rather than inside _parseMatrixLiteral, so the JSON-decode/normalization
  // pipeline for the bracketed digits themselves never re-serializes or
  // rounds anything: the sign toggle and the digits are two independent,
  // lossless concerns.
  static Matrix _parseSignedMatrixLiteral(String token) {
    final bool negative = token.startsWith('-');
    final Matrix matrix = _parseMatrixLiteral(_stripLeadingMatrixSign(token));
    return negative ? matrix.scale(-1) : matrix;
  }

  static String _stripLeadingMatrixSign(String token) {
    if (token.startsWith('-') || token.startsWith('+')) {
      return token.substring(1);
    }
    return token;
  }

  static Matrix _parseMatrixLiteral(String token) {
    dynamic decoded;
    try {
      decoded = jsonDecode(_normalizeMatrixLiteralSeparators(token));
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

  // HP-style matrix literals separate rows and entries with plain
  // whitespace instead of commas (e.g. "[[1 2] [3 4]]"). jsonDecode only
  // understands comma-separated JSON, so this inserts the implied commas
  // before decoding. A comma already present is left untouched, so
  // "[[1, 2], [3, 4]]" round-trips unchanged.
  static String _normalizeMatrixLiteralSeparators(String token) {
    final RegExp impliedSeparator = RegExp(r'(?<=[0-9.\]])\s+(?=[-0-9.\[])');
    return token.replaceAll(impliedSeparator, ',');
  }

  /// One shared rule for the RPN command line and RPN programs: tokens are
  /// separated by whitespace, except inside matrix literal brackets, where
  /// whitespace is part of the literal (or an implied HP-style separator)
  /// rather than a token boundary. Both the command-line draft parser and
  /// the RPN program/word parser must call this so a bracketed literal such
  /// as "[[1 2] [3 4]]" is always kept as a single token.
  static List<String> tokenizeRpnLine(String line) {
    final List<String> tokens = <String>[];
    int index = 0;

    while (index < line.length) {
      if (_isRpnTokenSeparator(line[index])) {
        index++;
        continue;
      }

      final int start = index;
      while (index < line.length && !_isRpnTokenSeparator(line[index])) {
        if (line[index] == '[') {
          index = _scanBracketedLiteral(line, index);
          continue;
        }
        index++;
      }

      tokens.add(line.substring(start, index));
    }

    return tokens;
  }

  /// Where the last token of a still-uncommitted rpn draft starts, using the
  /// same bracket-aware, whitespace-agnostic boundary rule as
  /// tokenizeRpnLine (so a tab or a newline is a token boundary here exactly
  /// as it is when the draft is committed, rather than only a literal space
  /// in one place and any whitespace in the other). Used by
  /// CalculatrixSession's ± key to edit only the trailing token of a
  /// multi-token draft. Returns 0 when the draft has no top-level separator,
  /// meaning the whole draft is the "last token".
  static int lastRpnTokenBoundary(String line) {
    int bracketDepth = 0;
    int tokenStart = 0;

    for (int index = 0; index < line.length; index++) {
      final String character = line[index];
      if (character == '[') {
        bracketDepth++;
      } else if (character == ']') {
        bracketDepth--;
      } else if (bracketDepth == 0 && _isRpnTokenSeparator(character)) {
        tokenStart = index + 1;
      }
    }

    return tokenStart;
  }

  // Whitespace predicate shared by tokenizeRpnLine and lastRpnTokenBoundary:
  // any character that trims away is a token boundary (spaces, tabs,
  // newlines, ...), never just the literal space character.
  static bool _isRpnTokenSeparator(String character) {
    return character.trim().isEmpty;
  }

  // Scans a balanced-bracket span starting at a '[' and returns the index
  // just past its matching ']'. Shared by _tokenizeInfix and
  // tokenizeRpnLine so both agree on where a matrix literal ends.
  static int _scanBracketedLiteral(String source, int start) {
    int index = start;
    int depth = 0;
    while (index < source.length) {
      final String current = source[index];
      if (current == '[') {
        depth++;
      } else if (current == ']') {
        depth--;
        if (depth == 0) {
          return index + 1;
        }
      }
      index++;
    }

    throw ExpressionSyntaxError('Unbalanced matrix literal brackets.');
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

      if (_isSignedBracketStart(expression, index, tokens)) {
        final int start = index;
        index = _scanBracketedLiteral(expression, index + 1);
        tokens.add(expression.substring(start, index));
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
        index = _scanBracketedLiteral(expression, index);
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

  // A sign immediately followed by '[' in unary position (start of the
  // expression, or right after an operator/function/open paren) is a signed
  // matrix literal token such as "-[[1,2],[3,4]]", not a lone operator. In
  // any other position (e.g. between two operands as in "[[1,2]]-[[3,4]]" or
  // "2-[[1,2]]") tokens.last is an operand, unaryPosition is false, and this
  // returns false so the sign is tokenized as ordinary binary subtraction,
  // unaffected.
  static bool _isSignedBracketStart(
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

    return index + 1 < source.length && source[index + 1] == '[';
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
