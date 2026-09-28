import 'dart:convert';

import '../errors/errors.dart';
import '../machine/calculatrix_command.dart';
import '../machine/calculatrix_machine.dart';
import '../machine/calculatrix_program.dart';
import '../machine/commands.dart';
import '../matrix/matrix.dart';

class Calculatrix {
  static CalculatrixProgram compileInfix(String expression) {
    return CalculatrixProgram(
      _compileRpnCommands(_compileInfixToRpnTokens(expression)),
    );
  }

  // Shared by compileInfix and evaluateInfix: tokenizes, validates and
  // shunting-yards the infix expression down to the same positioned RPN
  // token stream either caller needs, one of them to compile into a typed
  // CalculatrixProgram, the other to compile and execute token-by-token so
  // execution-time errors can be enriched (see _executePositioned).
  static List<_PositionedToken> _compileInfixToRpnTokens(String expression) {
    if (expression.trim().isEmpty) {
      throw ExpressionSyntaxError(
        'Expression cannot be empty.',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }

    // Tokenized untrimmed: _tokenizeInfixPositioned already skips whitespace
    // characters wherever they fall (its main loop's own `char.trim().isEmpty`
    // check), so trimming here bought nothing but made every token position
    // an offset into the trimmed string instead of the original input line
    // (spec section 6) -- a leading-whitespace expression such as "  1/0"
    // reported its "/" at position 2 instead of the correct 4.
    final List<_PositionedToken> infixTokens = _tokenizeInfixPositioned(
      expression,
    );
    _validateInfixTokens(infixTokens);
    return _toRpn(infixTokens);
  }

  // The infix tokenizer's own token stream, exposed so a caller such as
  // CalculatrixSession's repeat-equals bookkeeping can find "the last
  // top-level binary operator" by looking at real tokens, using the exact
  // same unary-vs-binary call _isSignedNumberStart/_isSignedBracketStart
  // already make while tokenizing. Re-implementing that call as a second,
  // separate character scan is what let a token such as "-[[3]]" (a signed
  // matrix literal) be mistaken for a binary subtraction.
  static List<String> tokenizeInfixExpression(String expression) {
    return _tokenizeInfixPositioned(
      expression.trim(),
    ).map((_PositionedToken token) => token.value).toList();
  }

  static Matrix evaluateInfix(String expression) {
    try {
      final CalculatrixMachine machine = CalculatrixMachine();
      _executePositioned(machine, _compileInfixToRpnTokens(expression));
      return _singleResult(machine, expression: expression, notation: 'infix');
    } on RpnStackUnderflowError catch (error) {
      throw ExpressionSyntaxError(
        'Invalid infix expression: $expression',
        errorId: CalculatrixErrorId.syntaxError,
        token: error.token,
        position: error.position,
      );
    }
  }

  static Matrix evaluateRpn(List<String> tokens) {
    if (tokens.isEmpty) {
      throw ExpressionSyntaxError(
        'RPN token list cannot be empty.',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }

    final CalculatrixMachine machine = CalculatrixMachine();
    _executePositioned(machine, _positionRawRpnTokens(tokens));
    return _singleResult(
      machine,
      expression: tokens.join(' '),
      notation: 'RPN',
    );
  }

  // Assigns each raw RPN token its 1-based character position in the
  // "input line" (spec section 6): the same string evaluateRpn reports as
  // the expression, tokens.join(' '), so a caller reading a reported
  // position can find the token by counting characters into that exact
  // string. Blank tokens (e.g. from a stray double space) are dropped
  // here, before compiling, exactly as _compileRpnTokens used to drop
  // them inline.
  static List<_PositionedToken> _positionRawRpnTokens(List<String> rawTokens) {
    final List<_PositionedToken> positioned = <_PositionedToken>[];
    int cursor = 1;
    for (final String rawToken in rawTokens) {
      final String token = rawToken.trim();
      if (token.isNotEmpty) {
        positioned.add(
          _PositionedToken(token, cursor + rawToken.indexOf(token)),
        );
      }
      cursor += rawToken.length + 1; // +1 for the joining space.
    }
    return positioned;
  }

  // Compiles each already-positioned token to a command, the one place
  // (per notation) where a raw input token and the command it compiles to
  // are both in hand at once. A compile-time failure (an unrecognized
  // word, a non-finite literal, a malformed matrix literal, ...) is
  // enriched with that token right here. The commands themselves are kept
  // as their own concrete types (PushScalarCommand, MultiplyCommand, ...)
  // rather than wrapped, so a CalculatrixProgram built from them stays a
  // deterministic, typed program a caller can inspect; execution-time
  // enrichment (stack underflow, a dimension mismatch, ...) is instead the
  // job of _executePositioned, which dispatches each command with its
  // token still in hand.
  static List<CalculatrixCommand> _compileRpnCommands(
    List<_PositionedToken> tokens,
  ) {
    final List<CalculatrixCommand> commands = <CalculatrixCommand>[];
    for (final _PositionedToken positioned in tokens) {
      try {
        commands.add(_compileRpnToken(positioned.value));
      } on CalculatrixError catch (error) {
        error.enrichToken(positioned.value, positioned.position);
        rethrow;
      }
    }
    return commands;
  }

  // Compiles and runs positioned tokens one at a time against machine, the
  // choke point where an execution-time domain error (stack underflow, a
  // dimension mismatch, a singular matrix, ...) is enriched with the token
  // that produced the command that threw it: Matrix and RpnEngine methods
  // have no notion of "token" or "input position" themselves, so they
  // cannot set these on the errors they raise.
  static void _executePositioned(
    CalculatrixMachine machine,
    List<_PositionedToken> tokens,
  ) {
    final List<CalculatrixCommand> commands = _compileRpnCommands(tokens);
    for (int index = 0; index < commands.length; index++) {
      final _PositionedToken positioned = tokens[index];
      try {
        machine.execute(commands[index]);
      } on CalculatrixError catch (error) {
        error.enrichToken(positioned.value, positioned.position);
        rethrow;
      }
    }
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
          return PushMatrixCommand(_parseSignedMatrixLiteral(token));
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
      // syntax-error is infix only (spec section 6): an empty matrix
      // literal is well-formed syntax that names an impossible shape, in
      // both RPN and infix, so this is dimension-mismatch, not
      // syntax-error.
      throw MatrixShapeError(
        'Matrix literal cannot be empty.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    if (decoded.every((dynamic item) => item is num)) {
      return Matrix(<List<double>>[
        decoded
            .map((dynamic item) => _checkFiniteLiteralEntry(item as num, token))
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

    throw ExpressionSyntaxError(
      'Unbalanced matrix literal brackets.',
      errorId: CalculatrixErrorId.syntaxError,
    );
  }

  static List<_PositionedToken> _tokenizeInfixPositioned(String expression) {
    final List<_PositionedToken> tokens = <_PositionedToken>[];
    int index = 0;

    while (index < expression.length) {
      final String char = expression[index];

      if (char.trim().isEmpty) {
        index++;
        continue;
      }

      if (_isSignedNumberStart(expression, index, tokens)) {
        final int start = index;
        final _NumberScanResult scan = _scanNumber(expression, index);
        tokens.add(
          _PositionedToken(
            _requireParseableNumberToken(scan.token, start + 1),
            start + 1,
          ),
        );
        index = scan.nextIndex;
        continue;
      }

      if (_isSignedBracketStart(expression, index, tokens)) {
        final int start = index;
        index = _scanBracketedLiteral(expression, index + 1);
        tokens.add(
          _PositionedToken(expression.substring(start, index), start + 1),
        );
        continue;
      }

      if (_isOperator(char) ||
          _isFunction(char) ||
          _isPostfixOperator(char) ||
          char == '(' ||
          char == ')') {
        tokens.add(_PositionedToken(char, index + 1));
        index++;
        continue;
      }

      if (char == '[') {
        final int start = index;
        index = _scanBracketedLiteral(expression, index);
        tokens.add(
          _PositionedToken(expression.substring(start, index), start + 1),
        );
        continue;
      }

      if (_isNumberStart(char)) {
        final int start = index;
        final _NumberScanResult scan = _scanNumber(expression, index);
        tokens.add(
          _PositionedToken(
            _requireParseableNumberToken(scan.token, start + 1),
            start + 1,
          ),
        );
        index = scan.nextIndex;
        continue;
      }

      // "NaN" is not a digit-led token, so the number scan above never
      // starts on it, but it is still a recognized (non-finite) numeric
      // literal (issue #5 bug 4): let it through as an ordinary operand
      // token instead of raising syntax-error here, so the RPN token
      // compiler's own finite-value check (shared with plain RPN input)
      // is what rejects it, with the non-finite id instead of
      // syntax-error.
      if (expression.startsWith('NaN', index)) {
        tokens.add(_PositionedToken('NaN', index + 1));
        index += 3;
        continue;
      }

      throw ExpressionSyntaxError(
        'Unexpected token near "$char".',
        errorId: CalculatrixErrorId.syntaxError,
        token: char,
        position: index + 1,
      );
    }

    return tokens;
  }

  /// Rejects a scanned number token that is not a parseable double (for
  /// example `1e`, an exponent marker with no exponent digits) right at
  /// tokenize time, with `syntax-error`. Without this, an unparseable
  /// number token would otherwise reach the RPN compiler as an opaque
  /// operand and surface as the wrong id (`unknown-word`) instead of the
  /// syntax error it actually is; this check is infix-only. RPN's own
  /// token compiler already validates numeric literals independently.
  static String _requireParseableNumberToken(String token, int position) {
    if (double.tryParse(token) == null) {
      throw ExpressionSyntaxError(
        'Invalid numeric literal: $token',
        errorId: CalculatrixErrorId.syntaxError,
        token: token,
        position: position,
      );
    }
    return token;
  }

  /// A small state machine that walks the raw infix token list, before it
  /// reaches the shunting yard converter, and enforces operand/operator
  /// alternation plus the rule that a bare (unparenthesized) function
  /// argument may only be followed by the ')' that closes its own group,
  /// or by the end of the expression. This is what makes "1 2 +" (two
  /// operands with no operator between them), "1()" (an operand directly
  /// followed by an empty group) and "root9+7" (a function that would
  /// otherwise swallow the whole trailing sum instead of only its own
  /// argument) all raise syntax-error instead of silently evaluating to
  /// something surprising. Combining a bare function argument with a
  /// further operator now requires parenthesizing it explicitly, e.g.
  /// "(root 9)+7".
  static void _validateInfixTokens(List<_PositionedToken> tokens) {
    final List<_InfixValidationFrame> frames = <_InfixValidationFrame>[
      _InfixValidationFrame(),
    ];
    bool expectOperand = true;

    for (final _PositionedToken positioned in tokens) {
      final String token = positioned.value;
      final int position = positioned.position;
      final _InfixValidationFrame frame = frames.last;

      // A postfix operator (e.g. "%") is exempt from the bare-function
      // guard below: it applies unambiguously to whatever value already
      // resolved the pending function ("(root 0)%" and "root 0 %" mean
      // the same thing either way), unlike a further binary operator or
      // function, which would be ambiguous about how much of the
      // expression the original bare function's argument covers.
      if (frame.bareClosed && token != ')' && !_isPostfixOperator(token)) {
        throw ExpressionSyntaxError(
          'A bare function argument must be parenthesized to combine it '
          'with further operators near "$token".',
          errorId: CalculatrixErrorId.syntaxError,
          token: token,
          position: position,
        );
      }

      if (_isOperand(token)) {
        if (!expectOperand) {
          throw ExpressionSyntaxError(
            'Unexpected operand "$token"; an operator was expected.',
            errorId: CalculatrixErrorId.syntaxError,
            token: token,
            position: position,
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
            token: token,
            position: position,
          );
        }
        // Tracked as a count, not a boolean: consecutive prefix functions
        // (e.g. "√√(16)") each push their own pending obligation onto the
        // same frame. A boolean can only ever remember whether *some*
        // function is pending, not how many, so a nested "(...)" group
        // that resolves one of them (see below) would wrongly erase all
        // of them at once.
        frame.pendingFunctionCount++;
        continue;
      }

      if (token == '(') {
        if (!expectOperand) {
          throw ExpressionSyntaxError(
            'Unexpected "("; an operator was expected.',
            errorId: CalculatrixErrorId.syntaxError,
            token: token,
            position: position,
          );
        }
        // Only the immediately preceding function is parenthesized by this
        // group ("f(...)" makes "f" no longer bare) -- any further pending
        // functions stacked on this same frame from before it (e.g. the
        // outer "√" in "√√(16)") remain pending across the nested group
        // and must still be resolved once it closes.
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
            token: token,
            position: position,
          );
        }
        if (frames.length > 1) {
          frames.removeLast();
          // The just-closed group is itself a complete operand for
          // whatever pending function(s) remain on the parent frame (e.g.
          // the outer "√" in "√√(16)") -- resolve it exactly as an operand
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
            token: token,
            position: position,
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
            token: token,
            position: position,
          );
        }
        continue;
      }

      throw ExpressionSyntaxError(
        'Unsupported token in infix expression: $token',
        errorId: CalculatrixErrorId.syntaxError,
        token: token,
        position: position,
      );
    }

    if (expectOperand) {
      throw ExpressionSyntaxError(
        'Expression ends with an incomplete operand.',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }
  }

  static List<_PositionedToken> _toRpn(List<_PositionedToken> infixTokens) {
    final List<_PositionedToken> output = <_PositionedToken>[];
    final List<_PositionedToken> operators = <_PositionedToken>[];

    for (final _PositionedToken positioned in infixTokens) {
      final String token = positioned.value;

      if (_isOperand(token)) {
        output.add(positioned);
        continue;
      }

      if (_isOperator(token)) {
        while (operators.isNotEmpty &&
            _isOperator(operators.last.value) &&
            (_isRightAssociative(token)
                ? _precedence(operators.last.value) > _precedence(token)
                : _precedence(operators.last.value) >= _precedence(token))) {
          output.add(operators.removeLast());
        }
        operators.add(positioned);
        continue;
      }

      if (_isFunction(token)) {
        operators.add(positioned);
        continue;
      }

      if (_isPostfixOperator(token)) {
        output.add(positioned);
        continue;
      }

      if (token == '(') {
        operators.add(positioned);
        continue;
      }

      if (token == ')') {
        bool foundOpen = false;
        while (operators.isNotEmpty) {
          final _PositionedToken op = operators.removeLast();
          if (op.value == '(') {
            foundOpen = true;
            break;
          }
          output.add(op);
        }
        if (!foundOpen) {
          throw ExpressionSyntaxError(
            'Mismatched parentheses in expression.',
            errorId: CalculatrixErrorId.syntaxError,
            token: token,
            position: positioned.position,
          );
        }

        if (operators.isNotEmpty && _isFunction(operators.last.value)) {
          output.add(operators.removeLast());
        }
        continue;
      }

      throw ExpressionSyntaxError(
        'Unsupported token in infix expression: $token',
        errorId: CalculatrixErrorId.syntaxError,
        token: token,
        position: positioned.position,
      );
    }

    while (operators.isNotEmpty) {
      final _PositionedToken op = operators.removeLast();
      if (op.value == '(' || op.value == ')') {
        throw ExpressionSyntaxError(
          'Mismatched parentheses in expression.',
          errorId: CalculatrixErrorId.syntaxError,
          token: op.value,
          position: op.position,
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
    List<_PositionedToken> tokens,
  ) {
    final String sign = source[index];
    if (sign != '-' && sign != '+') {
      return false;
    }

    final bool unaryPosition =
        tokens.isEmpty ||
        _isOperator(tokens.last.value) ||
        _isFunction(tokens.last.value) ||
        tokens.last.value == '(';

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
    List<_PositionedToken> tokens,
  ) {
    final String sign = source[index];
    if (sign != '-' && sign != '+') {
      return false;
    }

    final bool unaryPosition =
        tokens.isEmpty ||
        _isOperator(tokens.last.value) ||
        _isFunction(tokens.last.value) ||
        tokens.last.value == '(';

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

// A token paired with its 1-based character position in the source
// program (the RPN "input line", tokens.join(' '), or the raw infix
// expression string; spec section 6). Threaded through tokenizing,
// validation, shunting-yard reordering and command compiling so that
// whichever input token ultimately causes a domain error is still known
// by the time that error is thrown or caught.
class _PositionedToken {
  const _PositionedToken(this.value, this.position);

  final String value;
  final int position;
}

class _InfixValidationFrame {
  // A count, not a boolean, because consecutive prefix functions (e.g.
  // "√√(16)") stack more than one pending obligation on the same frame --
  // see the doc comment on [Calculatrix._validateInfixTokens].
  int pendingFunctionCount = 0;
  bool bareClosed = false;
}
