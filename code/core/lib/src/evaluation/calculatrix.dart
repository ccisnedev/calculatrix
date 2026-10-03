import '../errors/errors.dart';
import '../exact/exact_arithmetic.dart';
import '../machine/calculatrix_command.dart';
import '../machine/calculatrix_machine.dart';
import '../machine/calculatrix_program.dart';
import '../machine/commands.dart';
import '../matrix/matrix.dart';
import '../names/name_table.dart';
import '../registry/command_registry.dart';
import '../rpn/rpn_engine.dart';
import 'literals.dart';

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
  //
  // A unary minus that is not part of a literal ("-(2+3)", "-√9", and the
  // "-" of "-2^2") is the token [infixUnaryMinus], never "-": a "-" in this
  // list is always binary subtraction.
  static List<String> tokenizeInfixExpression(String expression) {
    return _tokenizeInfixPositioned(
      expression.trim(),
    ).map((_PositionedToken token) => token.value).toList();
  }

  /// Evaluates an infix expression. Exact literals give exact results
  /// (runbook D50); [maxDigits] is the size limit of runbook D55. With
  /// [approximate], the result is converted to an approximate value, for a
  /// caller that only handles those (the app, until step T5 of the
  /// runbook).
  static Matrix evaluateInfix(
    String expression, {
    int maxDigits = ExactArithmetic.defaultMaxDigits,
    bool approximate = false,
  }) {
    try {
      final CalculatrixMachine machine = _newMachine(maxDigits);
      _executePositioned(
        machine,
        _compileInfixToRpnTokens(expression),
        maxDigits,
      );
      final Matrix result = _singleResult(
        machine,
        expression: expression,
        notation: 'infix',
      );
      return approximate ? result.toApproximate() : result;
    } on RpnStackUnderflowError catch (error) {
      throw ExpressionSyntaxError(
        'Invalid infix expression: $expression',
        errorId: CalculatrixErrorId.syntaxError,
        token: error.token,
        position: error.position,
      );
    }
  }

  static Matrix evaluateRpn(
    List<String> tokens, {
    int maxDigits = ExactArithmetic.defaultMaxDigits,
  }) {
    final CalculatrixMachine machine = _runRpn(tokens, maxDigits);
    return _singleResult(
      machine,
      expression: tokens.join(' '),
      notation: 'RPN',
    );
  }

  /// Runs `tokens` as an RPN program and returns the full stack it leaves,
  /// bottom to top, instead of requiring a single result (unlike
  /// [evaluateRpn]). Needed for words such as `rows` (issue #37, S4c) whose
  /// documented, tested behavior leaves more than one value on the stack.
  static List<Matrix> evaluateRpnStack(
    List<String> tokens, {
    int maxDigits = ExactArithmetic.defaultMaxDigits,
  }) {
    return _runRpn(tokens, maxDigits).stackSnapshot;
  }

  /// Compiles `word` through the command registry, exactly as any RPN
  /// token is compiled (a primitive word to its own command, a defined
  /// word such as `over` (runbook D43) to the commands its definition
  /// program compiles to, recursively), and runs the result on `machine`
  /// as one atomic unit. Used by [CalculatrixSession]'s dup/over/swap/rot
  /// actions so a defined word runs through this one compile path instead
  /// of a hand-written command that would duplicate its own definition
  /// (D44, issue #39): `over` on the session behaves exactly as typing
  /// "2 pick" does anywhere else.
  static void executeWordOn(CalculatrixMachine machine, String word) {
    machine.executeAtomic(_compileWord(word, ExactArithmetic.defaultMaxDigits));
  }

  static CalculatrixMachine _newMachine(int maxDigits) {
    return CalculatrixMachine(
      engine: RpnEngine(exact: ExactArithmetic(maxDigits: maxDigits)),
    );
  }

  static CalculatrixMachine _runRpn(List<String> tokens, int maxDigits) {
    if (tokens.isEmpty) {
      throw ExpressionSyntaxError(
        'RPN token list cannot be empty.',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }

    final CalculatrixMachine machine = _newMachine(maxDigits);
    _executePositioned(machine, _positionRawRpnTokens(tokens), maxDigits);
    return machine;
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

  // Compiles each already-positioned token to its command(s), the one
  // place (per notation) where a raw input token and the command(s) it
  // compiles to are both in hand at once. A compile-time failure (an
  // unrecognized word, a non-finite literal, a malformed matrix literal,
  // an unresolved word inside a defined word's definition can never reach
  // here: the registry itself validates that at construction, see
  // CalculatrixCommandRegistry) is enriched with that token right here.
  //
  // A single input token compiles to more than one command exactly when
  // it names a defined word (runbook D43): _compileWord then expands its
  // definition through this very same compiler path, so a token such as
  // "inverse" can compile down to the two commands "-1 power" would
  // compile to. Every command produced this way is paired with the
  // *original* input token (not the defined word's own inner tokens), so
  // an error raised while executing one of them is still reported against
  // the word the user actually wrote (issue #35, AC4).
  static List<_PositionedCommand> _compilePositionedCommands(
    List<_PositionedToken> tokens,
    int maxDigits,
  ) {
    final List<_PositionedCommand> commands = <_PositionedCommand>[];
    for (final _PositionedToken positioned in tokens) {
      if (positioned.value == '--') {
        throw _doubleDashError(tokens, positioned);
      }
      try {
        for (final CalculatrixCommand command in _compileWord(
          positioned.value,
          maxDigits,
        )) {
          commands.add(_PositionedCommand(command, positioned));
        }
      } on CalculatrixError catch (error) {
        error.enrichToken(positioned.value, positioned.position);
        rethrow;
      }
    }
    return commands;
  }

  // `--` inside a program (issue #73, runbook D67): it ends the options of
  // the command line, so it goes before the quoted program, never inside
  // it. The message gives the form to type, built from the program without
  // that token and one adjacent space (the tokens joined by one space, so
  // that is the neighbour token's separator), with no suggestions: the
  // registry would only offer the nearest word to "--".
  static UnknownWordError _doubleDashError(
    List<_PositionedToken> tokens,
    _PositionedToken dash,
  ) {
    final String program = tokens
        .where((_PositionedToken token) => !identical(token, dash))
        .map((_PositionedToken token) => token.value)
        .join(' ');
    final String form = program.startsWith('-')
        ? "cx eval rpn -- '$program'"
        : "cx eval rpn '$program'";
    return UnknownWordError(
      dash.value,
      position: dash.position,
      message:
          '"--" is not part of a program: it ends the options and goes '
          'before the quoted program: $form',
    );
  }

  // The command types a CalculatrixProgram is built from (compileInfix):
  // callers that only need the typed program, not per-token error
  // enrichment during execution, get the plain command list.
  static List<CalculatrixCommand> _compileRpnCommands(
    List<_PositionedToken> tokens,
  ) {
    return _compilePositionedCommands(
      tokens,
      ExactArithmetic.defaultMaxDigits,
    ).map((_PositionedCommand positioned) => positioned.command).toList();
  }

  // Compiles and runs positioned tokens one at a time against machine, the
  // choke point where an execution-time domain error (stack underflow, a
  // dimension mismatch, a singular matrix, ...) is enriched with the token
  // that produced the command that threw it: Matrix and RpnEngine methods
  // have no notion of "token" or "input position" themselves, so they
  // cannot set these on the errors they raise. A defined word's expanded
  // commands all carry their original token (see
  // _compilePositionedCommands), so this enriches with e.g. "inverse"
  // even though the command that actually threw came from its "power"
  // expansion.
  static void _executePositioned(
    CalculatrixMachine machine,
    List<_PositionedToken> tokens,
    int maxDigits,
  ) {
    final List<_PositionedCommand> commands = _compilePositionedCommands(
      tokens,
      maxDigits,
    );
    int index = 0;
    while (index < commands.length) {
      // Every command a single original token expands to (one, for a
      // primitive word; more than one, for a defined word's whole program)
      // carries that same token object (see _compilePositionedCommands), so
      // grouping consecutive commands by identity on it recovers exactly
      // the original, pre-expansion tokens, one group per token.
      final _PositionedToken token = commands[index].token;
      int end = index + 1;
      while (end < commands.length && identical(commands[end].token, token)) {
        end++;
      }
      _requireSufficientDepth(machine, token);
      final List<Matrix> before = machine.stackSnapshot;
      for (int i = index; i < end; i++) {
        final _PositionedCommand positioned = commands[i];
        try {
          machine.execute(positioned.command);
        } on CalculatrixError catch (error) {
          error.enrichToken(positioned.token.value, positioned.token.position);
          rethrow;
        }
      }
      _requireFiniteResults(before, machine.stackSnapshot, token);
      index = end;
    }
  }

  // A word whose result overflows (`1e300 1e300 *`) must not leave
  // Infinity or NaN on the stack: spec section 6 makes any non-finite
  // value the error `non-finite`, reported on the word that produced it,
  // as `^` already does on its own. Every level from the lowest one the
  // word changed up to level 1 is checked, since a word may push more than
  // one value (`diagonalize` pushes P, then D); the levels below it are the
  // same objects as before the word ran, already checked. An exact value
  // is always finite.
  static void _requireFiniteResults(
    List<Matrix> before,
    List<Matrix> after,
    _PositionedToken token,
  ) {
    int first = 0;
    while (first < before.length &&
        first < after.length &&
        identical(before[first], after[first])) {
      first++;
    }
    for (int level = first; level < after.length; level++) {
      final Matrix value = after[level];
      if (value.isExact) {
        continue;
      }
      for (int row = 0; row < value.rowCount; row++) {
        for (int column = 0; column < value.columnCount; column++) {
          if (!value.at(row, column).isFinite) {
            throw MatrixDomainError(
              'Result is not a finite number.',
              errorId: CalculatrixErrorId.nonFinite,
              token: token.value,
              position: token.position,
            );
          }
        }
      }
    }
  }

  // Checks the real, pre-expansion stack depth against the arity of the
  // user-facing word `token` names, before any of the commands its own
  // expansion produced run (issue #51, AC5). Needed because a defined
  // word's expansion can inflate the depth an inner primitive sees: "sqrt"
  // is defined as "0.5 power", so by the time PowerCommand itself runs,
  // the stack already holds the literal 0.5 it just pushed, and
  // PowerCommand's own sequential pops would (each on its own) only ever
  // report "needs 1, found 0", never the true arity and depth of the word
  // the user actually wrote. Skipped for a literal token (nothing to look
  // up) and for a word whose arity is only known at run time (entry.arity
  // is null), which already reports its own accurate needed/found, e.g.
  // pick, roll, vector.
  static void _requireSufficientDepth(
    CalculatrixMachine machine,
    _PositionedToken token,
  ) {
    if (isLiteralToken(token.value)) {
      return;
    }

    final int? arity = CalculatrixCommandRegistry.standard
        .lookup(token.value)
        ?.arity;
    if (arity == null) {
      return;
    }

    final int depth = machine.depth;
    if (depth < arity) {
      final String valueWord = arity == 1 ? 'value' : 'values';
      throw RpnStackUnderflowError(
        '${token.value} needs $arity $valueWord on the stack, found $depth.',
        errorId: CalculatrixErrorId.stackUnderflow,
        token: token.value,
        position: token.position,
        needed: arity,
        found: depth,
      );
    }
  }

  // Every non-literal word is resolved through the core command registry
  // (case-insensitive, by name or alias), not through a hardcoded switch
  // (issue #32): a literal comes first, both because a numeric or matrix
  // token can never collide with a registered word and because the
  // registry has nothing to say about literals in the first place. A
  // defined entry (runbook D43) expands to the commands its own
  // definition program compiles to, via _compileDefinition, which
  // tokenizes the definition with the exact same tokenizeRpnLine used for
  // any other RPN input and recurses back through this function -- so a
  // defined word's compiled result is, command for command, identical to
  // typing its definition out by hand (issue #35, AC3).
  static List<CalculatrixCommand> _compileWord(String token, int maxDigits) {
    final Matrix? literal = Literals.parse(token, maxDigits: maxDigits);
    if (literal != null) {
      return <CalculatrixCommand>[PushMatrixCommand(literal)];
    }

    final CalculatrixCommandEntry? entry = CalculatrixCommandRegistry.standard
        .lookup(token);
    if (entry != null) {
      if (entry.isPrimitive) {
        return <CalculatrixCommand>[entry.build!()];
      }
      return _compileDefinition(entry.definition!, maxDigits);
    }

    final UnknownWordError? signed = _signedConstantError(token);
    if (signed != null) {
      throw signed;
    }

    throw UnknownWordError(
      token,
      suggestions: CalculatrixCommandRegistry.standard.suggest(token),
      infixHint: _looksLikeInfixExpression(token)
          ? 'this looks like an infix expression: cx eval infix "$token"'
          : null,
    );
  }

  // A constant is a name, not a number: a sign or the approximate mark in
  // front of it does not make a literal (runbook-agent-usability.md D66).
  // The error names the words that do what the user meant, with no
  // suggestions.
  static UnknownWordError? _signedConstantError(String token) {
    if (token.length < 2) {
      return null;
    }
    final String prefix = token[0];
    final String rest = token.substring(1);
    if ((prefix != '-' && prefix != Literals.approximateMark) ||
        CalculatrixNameTable.standard.lookup(rest) == null) {
      return null;
    }
    return UnknownWordError(
      token,
      message: prefix == '-'
          ? '"-" is not part of a name; to negate it: $rest negate'
          : '"${Literals.approximateMark}" marks numeric literals only; to '
                'make it approximate: $rest approx',
    );
  }

  // A non-word RPN token is flagged as "looks like infix" when it carries
  // parentheses, or an operator sandwiched between two operand-shaped
  // characters ("3.7^2.5"): neither can ever be a valid RPN word, but both
  // are exactly what someone who meant to write an infix expression types.
  // A plain negative literal such as "-5" never reaches this check at all
  // (it parses as a number before _compileWord gets here), so there is no
  // risk of this flagging it as infix-like.
  //
  // The right-hand operand may itself carry a sign ("3^-2") or lead with a
  // bare decimal point ("1+.5"), issue #51 AC3: both are operand-shaped to
  // a person reading the token, even though neither is a digit or "("
  // itself, which the original character class alone required.
  static final RegExp _infixOperatorBetweenOperands = RegExp(
    r'[0-9)][+\-*/^][+-]?[0-9.(]',
  );

  static bool _looksLikeInfixExpression(String token) {
    return token.contains('(') ||
        token.contains(')') ||
        _infixOperatorBetweenOperands.hasMatch(token);
  }

  // Compiles a defined word's definition program to commands, by
  // tokenizing it with tokenizeRpnLine (the same tokenizer any other RPN
  // input goes through) and compiling each of its words through
  // _compileWord, recursively. A definition can itself reference another
  // defined word: CalculatrixCommandRegistry rejects a cyclic definition
  // at construction time (issue #35, AC5), so this recursion is always
  // finite.
  static List<CalculatrixCommand> _compileDefinition(
    String definition,
    int maxDigits,
  ) {
    final List<CalculatrixCommand> commands = <CalculatrixCommand>[];
    for (final String word in tokenizeRpnLine(definition)) {
      commands.addAll(_compileWord(word, maxDigits));
    }
    return commands;
  }

  /// Whether `token` is a literal (a finite number or a matrix literal)
  /// rather than a word the command registry must resolve. Exposed for
  /// [CalculatrixCommandRegistry]'s definition validation (issue #35,
  /// AC5): a defined word's definition may reference literals freely,
  /// only its non-literal words must resolve in the registry. The same
  /// classification _compileWord itself uses, so the registry's notion of
  /// "literal" never drifts from the compiler's.
  static bool isLiteralToken(String token) {
    return Literals.isLiteral(token);
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

  /// The token [tokenizeInfixExpression] gives a unary minus that is not
  /// part of a literal, such as the "-" of "-(2+3)" (issue #66). It cannot
  /// be typed: the tokenizer never reads "u-" as one token.
  static const String infixUnaryMinus = 'u-';

  static List<_PositionedToken> _tokenizeInfixPositioned(String expression) {
    final List<_PositionedToken> tokens = <_PositionedToken>[];
    int index = 0;

    while (index < expression.length) {
      final String char = expression[index];

      if (char.trim().isEmpty) {
        index++;
        continue;
      }

      if (char == Literals.approximateMark) {
        final int start = index;
        index = _scanMarkedLiteral(expression, index);
        tokens.add(
          _PositionedToken(
            _requireParseableNumberToken(
              expression.substring(start, index),
              start + 1,
            ),
            start + 1,
          ),
        );
        continue;
      }

      if (_isMisplacedMark(expression, index, tokens)) {
        final int literalEnd = _scanMarkedLiteral(expression, index + 1);
        final String fixed =
            '${Literals.approximateMark}$char'
            '${expression.substring(index + 2, literalEnd)}';
        throw ExpressionSyntaxError(
          'The approximate mark goes before the sign: $fixed',
          errorId: CalculatrixErrorId.syntaxError,
          token: expression.substring(index, literalEnd),
          position: index + 1,
        );
      }

      // A signed number or matrix literal followed by "^" (past any "%")
      // is a unary minus and a power, -(2^2), as in standard notation and
      // Giac: the sign is not part of the base (issue #66). A "+" there
      // changes nothing and is skipped.
      if ((_isSignedNumberStart(expression, index, tokens) &&
              _isFollowedByPower(
                expression,
                _scanNumber(expression, index + 1).nextIndex,
              )) ||
          (_isSignedBracketStart(expression, index, tokens) &&
              _isFollowedByPower(
                expression,
                _scanBracketedLiteral(expression, index + 1),
              ))) {
        if (char == '-') {
          tokens.add(_PositionedToken(infixUnaryMinus, index + 1));
        }
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

      // A sign in unary position that no literal claimed above, as in
      // "-(2+3)" or "-√9": a "-" negates the operand that follows, a "+"
      // leaves it as it is (issue #66).
      if ((char == '-' || char == '+') && _isUnaryPosition(tokens)) {
        if (char == '-') {
          tokens.add(_PositionedToken(infixUnaryMinus, index + 1));
        }
        index++;
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

      // Infix has no notion of a function call or a bare name at all: a
      // letter-led run of characters here is never a valid infix token,
      // whether it is a call-like "sqrt(7)" or a lone "e". Scanning the
      // whole name (rather than letting the generic fallthrough below
      // report only its first character) is what lets the error explain
      // the limitation and, when the name is already a known RPN word or
      // alias, show its RPN form (AC2, issue #51).
      //
      // A name of the name table (pi, e, i, π; runbook-agent-usability.md
      // D65, D66) is the exception: it is an operand, resolved later as the
      // registry word of the same name. It is recognized only as a whole
      // name (letters and digits, no hyphen), so "e3" and "pi2" are still
      // names that are not constants, and "pi-e" is a subtraction.
      if (char == 'π' || _isNameStart(char)) {
        final int start = index;
        final String plain = char == 'π'
            ? char
            : _scanPlainName(expression, start);
        if (CalculatrixNameTable.standard.lookup(plain) != null) {
          tokens.add(_PositionedToken(plain, start + 1));
          index = start + plain.length;
          continue;
        }
        throw _buildInfixNameError(expression, start);
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
    if (!Literals.isNumber(token) && !Literals.looksLikeMatrix(token)) {
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
    String? previous;

    for (final _PositionedToken positioned in tokens) {
      final String token = positioned.value;
      final int position = positioned.position;
      final _InfixValidationFrame frame = frames.last;
      final String? before = previous;
      previous = token;

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

      // The tokenizer emits a unary minus only where an operand is
      // expected, and an operand must still follow it.
      if (token == infixUnaryMinus) {
        continue;
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
        // A unary minus between them ("√-(4)") leaves the function bare:
        // the group is then the operand of the minus, not the function's
        // own parentheses (issue #66).
        if (frame.pendingFunctionCount > 0 &&
            before != null &&
            _isFunction(before)) {
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

      // A prefix operator: it waits on the stack for its operand, and an
      // operator that binds less tightly pops it.
      if (token == infixUnaryMinus) {
        operators.add(positioned);
        continue;
      }

      if (_isOperator(token)) {
        while (operators.isNotEmpty &&
            (_isOperator(operators.last.value) ||
                operators.last.value == infixUnaryMinus) &&
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

    return <_PositionedToken>[
      for (final _PositionedToken positioned in output)
        positioned.value == infixUnaryMinus
            ? _PositionedToken('negate', positioned.position)
            : positioned,
    ];
  }

  static bool _isOperand(String token) {
    return token != infixUnaryMinus &&
        !_isOperator(token) &&
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
      // Unary minus binds tighter than "*" and "/" and looser than "^":
      // -2^2 is -(2^2) and -(2+3)*4 is (-(2+3))*4.
      case infixUnaryMinus:
        return 3;
      case '^':
        return 4;
      default:
        return -1;
    }
  }

  static bool _isNumberStart(String char) {
    final int code = char.codeUnitAt(0);
    return _isAsciiDigit(code) || code == _dotCode;
  }

  static bool _isNameStart(String char) {
    final int code = char.codeUnitAt(0);
    return (code >= _lowerACode && code <= _lowerZCode) ||
        (code >= _upperACode && code <= _upperZCode) ||
        char == '_';
  }

  static bool _isNameChar(String char) {
    return _isNameStart(char) || _isAsciiDigit(char.codeUnitAt(0));
  }

  // The run of name characters (letters, digits, "_") starting at `start`,
  // with no hyphen: the whole name of a constant of the name table.
  static String _scanPlainName(String expression, int start) {
    int index = start;
    while (index < expression.length && _isNameChar(expression[index])) {
      index++;
    }
    return expression.substring(start, index);
  }

  // Scans the full run of name characters starting at `start` (already
  // known to be a name start), rather than reporting just its first
  // character: the resulting name is both what the error message names
  // and what it looks up against the RPN registry.
  //
  // A "-" is also consumed, together with whatever further run of name
  // characters follows it, when it is immediately followed by a name
  // start: the registry has words of its own written with a hyphen
  // ("frobenius-norm", "append-cols"), and the whole word, not just the
  // run of letters up to its first hyphen, is what both the lookup below
  // and the message need to name (issue #51, AC2). A "-" with nothing
  // name-shaped after it (end of input, a digit, another "-") is left
  // alone: infix has no bare names at all, so nothing here depends on
  // telling an actual subtraction apart from one, only on not swallowing
  // it into a name it is not part of.
  static String _scanName(String expression, int start) {
    int index = start;
    while (index < expression.length) {
      if (_isNameChar(expression[index])) {
        index++;
        continue;
      }
      if (expression[index] == '-' &&
          index + 1 < expression.length &&
          _isNameStart(expression[index + 1])) {
        index++;
        continue;
      }
      break;
    }
    return expression.substring(start, index);
  }

  // Finds the index just past the "(" at `openIndex`'s matching ")",
  // accounting for nesting, or -1 when the parenthesis is never closed:
  // the caller then knows there is no real argument to read out, rather
  // than reading one out of a substring range that was never a closed
  // group in the first place (issue #51, AC1; this used to crash on a
  // truncated call such as "sqrt(" by handing the caller a range past the
  // end of the very "(" it opened).
  static int _matchingParenEnd(String expression, int openIndex) {
    int depth = 0;
    for (int index = openIndex; index < expression.length; index++) {
      if (expression[index] == '(') {
        depth++;
      } else if (expression[index] == ')') {
        depth--;
        if (depth == 0) {
          return index + 1;
        }
      }
    }
    return -1;
  }

  // The call-like arguments of a registered name's "(a, b, ...)", when the
  // call is both present (a closed parenthesis right after the name) and
  // made only of literals (issue #51, AC2; extended by issue #73, runbook
  // D67): "sqrt(7)" gives ["7"], "power(2, 3)" gives ["2", "3"] and
  // "inverse([[1 2] [3 4]])" gives ["[[1 2] [3 4]]"], each trimmed and
  // verbatim. "sqrt(1+2)" and "sqrt (7)" (space before the paren, so not
  // call-like at all) give null, and so do "sqrt(" (never closed), an empty
  // argument or element, and any argument that is not a literal. Read
  // verbatim rather than parsed, since only the argument slots RPN would
  // occupy are needed here, not a full nested expression evaluation;
  // restricted to literals because only a literal is guaranteed to still
  // mean the same thing once it is moved in front of the word instead of
  // inside the call ("1+2 sqrt" is not "sqrt(1+2)", it is two RPN tokens,
  // the second of which is unknown). A comma inside brackets belongs to a
  // matrix literal and does not separate arguments.
  static List<String>? _literalCallArguments(String expression, int nameEnd) {
    if (nameEnd >= expression.length || expression[nameEnd] != '(') {
      return null;
    }
    final int closeIndex = _matchingParenEnd(expression, nameEnd);
    if (closeIndex < 0) {
      return null;
    }
    final String inside = expression.substring(nameEnd + 1, closeIndex - 1);
    final List<String> arguments = <String>[];
    int depth = 0;
    int start = 0;
    for (int index = 0; index <= inside.length; index++) {
      if (index < inside.length) {
        final String character = inside[index];
        if (character == '[') {
          depth++;
        } else if (character == ']') {
          depth--;
        }
        if (character != ',' || depth != 0) {
          continue;
        }
      }
      arguments.add(inside.substring(start, index).trim());
      start = index + 1;
    }
    for (final String argument in arguments) {
      if (!_isSingleLiteral(argument)) {
        return null;
      }
    }
    return arguments;
  }

  // Whether `text` is exactly one literal: a number or one matrix literal,
  // whose first bracket closes at its last character.
  static bool _isSingleLiteral(String text) {
    if (Literals.isNumber(text)) {
      return true;
    }
    if (!Literals.looksLikeMatrix(text)) {
      return false;
    }
    final int open = text.indexOf('[');
    int depth = 0;
    for (int index = open; index < text.length; index++) {
      if (text[index] == '[') {
        depth++;
      } else if (text[index] == ']') {
        depth--;
        if (depth == 0) {
          return index == text.length - 1;
        }
      }
    }
    return false;
  }

  // Builds the actionable error for a name found where infix expects a
  // number, matrix literal, operator or parenthesis (AC2, issue #51).
  // When `name` is already a registered RPN word or alias, the message
  // shows its RPN form when the call's arguments are all literals
  // (_literalCallArguments), or a generic, non-runnable description of
  // where the argument goes otherwise, rather than composing an RPN
  // command that would itself fail if the reader actually ran it.
  static ExpressionSyntaxError _buildInfixNameError(
    String expression,
    int start,
  ) {
    final String name = _scanName(expression, start);
    final int nameEnd = start + name.length;
    const String limitation =
        'infix accepts numbers, matrix literals, + - * / ^ and parentheses';

    final bool isRegistered =
        CalculatrixCommandRegistry.standard.lookup(name) != null;

    String message;
    if (isRegistered) {
      final List<String>? arguments = _literalCallArguments(
        expression,
        nameEnd,
      );
      message = arguments != null
          ? '$limitation; "$name" is an RPN word: '
                'cx eval rpn "${arguments.join(' ')} $name"'
          : '$limitation; "$name" is an RPN word; in RPN the argument '
                'comes first: x $name';
    } else {
      message = '$limitation; "$name" is a name, not a number.';
    }

    final ExpressionSyntaxError error = ExpressionSyntaxError(
      message,
      errorId: CalculatrixErrorId.syntaxError,
      token: name,
      position: start + 1,
    );
    error.name = name;
    return error;
  }

  // Scans a literal that starts with the approximate mark at `start`: a
  // number or a matrix literal, either with an optional sign (runbook
  // D56). Returns the index just past it.
  static int _scanMarkedLiteral(String source, int start) {
    int index = start + 1;
    if (index < source.length &&
        (source[index] == '-' || source[index] == '+')) {
      index++;
    }
    if (index < source.length && source[index] == '[') {
      return _scanBracketedLiteral(source, index);
    }
    if (index < source.length && _isNumberStart(source[index])) {
      return _scanNumber(source, index).nextIndex;
    }
    throw ExpressionSyntaxError(
      'The approximate mark must be followed by a number or a matrix '
      'literal.',
      errorId: CalculatrixErrorId.syntaxError,
      token: source.substring(start, index),
      position: start + 1,
    );
  }

  // A sign followed by the approximate mark in unary position ("-~0.1"):
  // the mark belongs to the literal, so it must come first ("~-0.1").
  static bool _isMisplacedMark(
    String source,
    int index,
    List<_PositionedToken> tokens,
  ) {
    final String sign = source[index];
    if (sign != '-' && sign != '+') {
      return false;
    }
    final bool unaryPosition = _isUnaryPosition(tokens);
    return unaryPosition &&
        index + 1 < source.length &&
        source[index + 1] == Literals.approximateMark;
  }

  // Where a sign is unary: at the start, or right after an operator, a
  // function, "(" or another unary minus.
  static bool _isUnaryPosition(List<_PositionedToken> tokens) =>
      tokens.isEmpty ||
      _isOperator(tokens.last.value) ||
      _isFunction(tokens.last.value) ||
      tokens.last.value == '(' ||
      tokens.last.value == infixUnaryMinus;

  // Whether the literal that ends at [index] is followed, past any
  // whitespace and postfix operators ("2%^2"), by "^".
  static bool _isFollowedByPower(String source, int index) {
    int next = index;
    while (next < source.length &&
        (source[next].trim().isEmpty || _isPostfixOperator(source[next]))) {
      next++;
    }
    return next < source.length && source[next] == '^';
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

    final bool unaryPosition = _isUnaryPosition(tokens);

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

    final bool unaryPosition = _isUnaryPosition(tokens);

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
  static const int _lowerACode = 97;
  static const int _lowerZCode = 122;
  static const int _upperACode = 65;
  static const int _upperZCode = 90;
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

// A compiled command paired with the original input token that produced
// it. For a primitive word this is a 1:1 pairing exactly like before; for
// a defined word (runbook D43) every command its definition expands to
// shares the same originating token, so an execution-time error is
// enriched with the word the user wrote (e.g. "inverse"), never with a
// word from inside its definition (e.g. "power") -- see
// Calculatrix._compilePositionedCommands.
class _PositionedCommand {
  const _PositionedCommand(this.command, this.token);

  final CalculatrixCommand command;
  final _PositionedToken token;
}

class _InfixValidationFrame {
  // A count, not a boolean, because consecutive prefix functions (e.g.
  // "√√(16)") stack more than one pending obligation on the same frame --
  // see the doc comment on [Calculatrix._validateInfixTokens].
  int pendingFunctionCount = 0;
  bool bareClosed = false;
}
