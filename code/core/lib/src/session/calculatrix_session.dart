import '../errors/errors.dart';
import '../evaluation/calculatrix.dart';
import '../machine/calculatrix_command.dart';
import '../machine/calculatrix_machine.dart';
import '../machine/calculatrix_macro.dart';
import '../machine/commands.dart';
import '../matrix/matrix.dart';
import '../rpn/rpn_engine.dart';

enum CalculatrixMode { infix, rpn }

class CalculatrixSession {
  String _infixDraft = '';
  String _rpnDraft = '';
  String _lastOperator = '';
  String _lastOperand = '';
  CalculatrixMode _mode = CalculatrixMode.infix;
  final CalculatrixMachine _machine = CalculatrixMachine();
  Matrix? _currentValue;
  Matrix? _memoryValue;
  Object? _lastError;

  CalculatrixMode get mode => _mode;

  bool get isRpnMode => _mode == CalculatrixMode.rpn;

  String get infixDraft => _infixDraft;

  String get rpnDraft => _rpnDraft;

  String get expression => isRpnMode ? _rpnDraft : _infixDraft;

  Matrix? get currentValue => _currentValue;

  Matrix? get memoryValue => _memoryValue;

  bool get hasMemory => _memoryValue != null;

  Object? get lastError => _lastError;

  bool get hasError => _lastError != null;

  int get rpnStackDepth => _machine.depth;

  List<Matrix> get rpnStack => _machine.stackSnapshot;

  Matrix? get rpnTopValue => _machine.top;

  List<String> get rpnStackLiterals {
    return _machine.stackSnapshot
        .reversed
        .map(_serializeMatrix)
        .toList(growable: false);
  }

  String get rpnTopLiteral {
    final Matrix? topValue = rpnTopValue;
    if (topValue == null) {
      return '';
    }
    return _serializeMatrix(topValue);
  }

  void setMode(CalculatrixMode mode) {
    if (_mode == mode) {
      return;
    }

    _mode = mode;
    _clearError();

    if (isRpnMode) {
      _ensureRpnStackMatchesCommittedValue();
    } else {
      _syncCommittedValueFromRpnStack();
    }
  }

  void input(String value) {
    if (isRpnMode) {
      _clearError();
      _rpnDraft += value;
      return;
    }

    if (_handleImmediateInfixInput(value)) {
      return;
    }

    if (_showsCommittedValueInInfix) {
      if (_isOperator(value)) {
        _infixDraft = _expressionSeedFromCurrentValue() + value;
      } else {
        _infixDraft = value;
      }
      _clearError();
      return;
    }

    _clearError();
    _infixDraft += value;
  }

  void appendSpace() {
    if (!isRpnMode) {
      return;
    }

    if (_rpnDraft.isEmpty || _rpnDraft.endsWith(' ')) {
      return;
    }

    _clearError();
    _rpnDraft += ' ';
  }

  void insertMatrixLiteral(String literal) {
    final Matrix matrix = Calculatrix.evaluateInfix(literal);
    _clearError();

    if (!isRpnMode) {
      if (_showsCommittedValueInInfix) {
        _infixDraft = literal;
      } else {
        _infixDraft += literal;
      }
      return;
    }

    _machine.execute(PushMatrixCommand(matrix));
    _rpnDraft = '';
    _syncCommittedValueFromRpnStack(invalidateRepeatEquals: true);
  }

  void evaluate() {
    if (isRpnMode) {
      enter();
      return;
    }

    if (_infixDraft.isEmpty && _currentValue != null && _lastOperator.isNotEmpty) {
      _infixDraft =
          '${_expressionSeedFromCurrentValue()}$_lastOperator$_lastOperand';
    }

    if (_infixDraft.isEmpty) {
      return;
    }

    try {
      _saveLastOperation(_infixDraft);
      final Matrix value = _evaluateExpression(_infixDraft);
      _infixDraft = '';
      _clearError();
      _updateCommittedValueFromInfix(value);
    } on FormatException catch (error) {
      _lastError = error;
      _infixDraft = '';
    } on CalculatrixError catch (error) {
      _lastError = error;
      _infixDraft = '';
    }
  }

  void clear() {
    if (isRpnMode) {
      if (_rpnDraft.isNotEmpty) {
        _rpnDraft = '';
        _clearError();
      } else {
        _clearAllState();
      }
      return;
    }

    _clearAllState();
  }

  void backspace() {
    if (isRpnMode) {
      if (_rpnDraft.isNotEmpty) {
        _rpnDraft = _rpnDraft.substring(0, _rpnDraft.length - 1);
        _clearError();
      }
      return;
    }

    if (_showsCommittedValueInInfix) {
      clear();
      return;
    }

    if (_infixDraft.isNotEmpty) {
      _infixDraft = _infixDraft.substring(0, _infixDraft.length - 1);
      _clearError();
    }
  }

  void toggleSign() {
    if (isRpnMode) {
      if (_rpnDraft.isNotEmpty) {
        _rpnDraft = _toggleSignOfLastToken(_rpnDraft);
        return;
      }

      if (_currentValue != null) {
        _clearError();
        _replaceRpnTopWith(_negatedValue(_currentValue!));
        _syncCommittedValueFromRpnStack(invalidateRepeatEquals: true);
      }
      return;
    }

    if (_showsCommittedValueInInfix) {
      _clearError();
      _updateCommittedValueFromInfix(
        _negatedValue(_currentValue!),
        invalidateRepeatEquals: true,
      );
      return;
    }

    if (_infixDraft.isNotEmpty) {
      if (_infixDraft.startsWith('-')) {
        _infixDraft = _infixDraft.substring(1);
      } else {
        _infixDraft = '-$_infixDraft';
      }
      _clearError();
    }
  }

  void memoryClear() {
    if (isRpnMode) {
      _runRpnAction(() {
        _memoryValue = null;
      });
      return;
    }

    _memoryValue = null;
  }

  // In rpn mode MR is an action key like any other: _runRpnAction commits a
  // pending draft first, then this checks memory. Checking memory before
  // calling _runRpnAction (as this used to) would let "2 SPC 3 MR" leave the
  // line uncommitted whenever memory happened to be empty, silently
  // breaking the one declared action-key rule for that one case. Empty
  // memory after committing is a typed EmptyMemoryError, not a silent
  // no-op: the typed-error path already reports failed commits and invalid
  // operations the same way, so this keeps MR consistent with every other
  // action key rather than carving out a special case.
  void memoryRecall() {
    if (isRpnMode) {
      _runRpnAction(() {
        final Matrix? memory = _memoryValue;
        if (memory == null) {
          throw EmptyMemoryError('Memory is empty.');
        }
        _machine.execute(PushMatrixCommand(memory));
      });
      return;
    }

    final Matrix? memory = _memoryValue;
    if (memory == null) {
      return;
    }

    final String memoryLiteral = _expressionSeedFromValue(memory);
    if (_showsCommittedValueInInfix) {
      _infixDraft = memoryLiteral;
    } else {
      _infixDraft += memoryLiteral;
    }
    _clearError();
  }

  void memoryAdd() {
    final Matrix? operand = _currentMemoryOperand();
    if (operand == null) {
      return;
    }

    try {
      _memoryValue = _memoryValue == null ? operand : _memoryValue! + operand;
      _clearError();
    } on CalculatrixError catch (error) {
      _lastError = error;
    }
  }

  void memorySubtract() {
    final Matrix? operand = _currentMemoryOperand();
    if (operand == null) {
      return;
    }

    try {
      _memoryValue = _memoryValue == null ? operand.scale(-1) : _memoryValue! - operand;
      _clearError();
    } on CalculatrixError catch (error) {
      _lastError = error;
    }
  }

  void enter() {
    if (!isRpnMode) {
      return;
    }

    // HP 50g: ENTER with an empty command line duplicates level 1.
    if (_rpnDraft.isEmpty) {
      if (_machine.depth > 0) {
        dupRpn();
      }
      return;
    }

    // ENTER is the archetypal action key: committing the draft is the whole
    // action, so it has nothing further to do once _runRpnAction has
    // committed it.
    _runRpnAction(() {});
  }

  void applyRpnBinary(RpnBinaryOperator operator) {
    if (!isRpnMode) {
      return;
    }

    _runRpnAction(() {
      _machine.execute(_binaryCommand(operator));
    });
  }

  void applyRpnUnary(RpnUnaryOperator operator) {
    if (!isRpnMode) {
      return;
    }

    _runRpnAction(() {
      _machine.execute(_unaryCommand(operator));
    });
  }

  void dupRpn() {
    _runRpnAction(() => _machine.execute(const DupCommand()));
  }

  void dropRpn() {
    _runRpnAction(() => _machine.execute(const DropCommand()));
  }

  void swapRpn() {
    _runRpnAction(() => _machine.execute(const SwapCommand()));
  }

  void overRpn() {
    _runRpnAction(() => _machine.execute(const OverCommand()));
  }

  void rotRpn() {
    _runRpnAction(() => _machine.execute(const RotCommand()));
  }

  void executeCommand(CalculatrixCommand command) {
    if (!isRpnMode) {
      return;
    }

    _runRpnAction(() {
      _machine.execute(command);
    });
  }

  void executeMacro(CalculatrixMacro macro) {
    if (!isRpnMode) {
      return;
    }

    _runRpnAction(() {
      _machine.executeMacro(macro);
    });
  }

  Matrix _evaluateExpression(String expression) {
    final String normalized = _normalizeSessionPercentExpression(expression)
        .replaceAll('×', '*')
        .replaceAll('÷', '/');

    return Calculatrix.evaluateInfix(normalized);
  }

  // Repeat-equals ("=" pressed again with an empty draft) replays
  // "<committed value><lastOperator><lastOperand>". Finding the last
  // top-level binary operator and its right-hand operand must go through
  // Calculatrix's own tokenizer rather than a separate character scan: a
  // scan that does not know a sign right after an operator (or a
  // parenthesis, or the start of the expression) belongs to a signed
  // operand token mistakes that sign for the operator itself, as in
  // "2×-[[3]]" (the '-' belongs to "-[[3]]", not to '×') or
  // "[[1,-2]]+3" (the '-' is inside the bracket literal, not top-level at
  // all; a raw scan that does not even track bracket depth would find it
  // first).
  void _saveLastOperation(String expression) {
    final String normalized = expression.replaceAll('×', '*').replaceAll('÷', '/');

    List<String> tokens;
    try {
      tokens = Calculatrix.tokenizeInfixExpression(normalized);
    } on CalculatrixError {
      _clearRepeatState();
      return;
    }

    final int operatorIndex = _lastTopLevelOperatorTokenIndex(tokens);
    if (operatorIndex <= 0) {
      _clearRepeatState();
      return;
    }

    _lastOperator = _toDisplayOperator(tokens[operatorIndex]);
    _lastOperand = tokens.sublist(operatorIndex + 1).join();
  }

  // The tokenizer already collapsed every signed number and signed matrix
  // literal into one operand token (that decision lives in
  // Calculatrix._isSignedNumberStart / _isSignedBracketStart), so any '+',
  // '-', '*' or '/' token that survives on its own, outside parentheses, is
  // by construction a genuine binary operator, never a unary sign.
  int _lastTopLevelOperatorTokenIndex(List<String> tokens) {
    int parenDepth = 0;
    int lastIndex = -1;

    for (int index = 0; index < tokens.length; index++) {
      final String token = tokens[index];
      if (token == '(') {
        parenDepth++;
        continue;
      }
      if (token == ')') {
        parenDepth--;
        continue;
      }
      if (parenDepth == 0 && _isBareInfixOperatorToken(token)) {
        lastIndex = index;
      }
    }

    return lastIndex;
  }

  bool _isBareInfixOperatorToken(String token) {
    return token == '+' || token == '-' || token == '*' || token == '/';
  }

  String _toDisplayOperator(String normalizedOperator) {
    switch (normalizedOperator) {
      case '*':
        return '×';
      case '/':
        return '÷';
      default:
        return normalizedOperator;
    }
  }

  Matrix? _currentMemoryOperand() {
    if (isRpnMode) {
      return _currentRpnMemoryOperand();
    }

    final String currentExpression = expression;
    if (currentExpression.isNotEmpty) {
      return _tryEvaluateExpression(currentExpression);
    }

    return _currentValue;
  }

  // An rpn draft is never evaluated as an infix expression: "2 -3" is two
  // separate operands, not a subtraction. Any non-empty draft, whether it
  // holds one token or several, must first be committed exactly like ENTER
  // (parsing every token atomically, so an invalid token raises the typed
  // error, pushes nothing and leaves the draft as typed), and only then does
  // the memory operand come from the new top of the stack. This is a single
  // path regardless of token count: a lone token is not special-cased into a
  // read-only evaluation, so it is pushed onto the real stack just like a
  // multi-token draft is.
  Matrix? _currentRpnMemoryOperand() {
    if (_rpnDraft.isEmpty) {
      return _currentValue;
    }

    return _commitRpnDraftForMemoryOperand();
  }

  Matrix? _commitRpnDraftForMemoryOperand() {
    try {
      _commitDraftIfNeeded();
      _clearError();
      _syncCommittedValueFromRpnStack(invalidateRepeatEquals: true);
      return _machine.top;
    } on FormatException catch (error) {
      _lastError = error;
      return null;
    } on CalculatrixError catch (error) {
      _lastError = error;
      return null;
    }
  }

  bool get _showsCommittedValueInInfix {
    return !isRpnMode && _infixDraft.isEmpty && _currentValue != null;
  }

  bool _handleImmediateInfixInput(String value) {
    switch (value) {
      case '√':
        return _applyImmediateInfixUnary(_sqrtValue);
      case 'INV':
        return _applyImmediateInfixUnary(_invertValue);
      case 'CONJ':
        return _applyImmediateInfixUnary(_transposeValue);
      case '%':
        return _queueInfixPercent();
      default:
        return false;
    }
  }

  bool _applyImmediateInfixUnary(Matrix Function(Matrix value) transform) {
    if (_infixDraft.isNotEmpty) {
      if (_infixDraft.contains('%')) {
        final Matrix? resolved = _tryEvaluateExpression(_infixDraft);
        if (resolved == null) {
          return false;
        }

        return _rewriteInfixDraftValue(transform(resolved));
      }

      return _rewriteInfixDraftUnary(transform);
    }

    if (_showsCommittedValueInInfix) {
      return _rewriteCommittedInfixValue(transform);
    }

    return false;
  }

  bool _queueInfixPercent() {
    if (_showsCommittedValueInInfix) {
      _infixDraft = '${_expressionSeedFromCurrentValue()}%';
      _clearError();
      return true;
    }

    if (_infixDraft.isEmpty) {
      return false;
    }

    final String currentOperand = _currentInfixOperandExpression(_infixDraft);
    if (currentOperand.isEmpty || currentOperand.contains('%')) {
      return false;
    }

    if (_tryParseOperand(currentOperand) == null) {
      return false;
    }

    _infixDraft += '%';
    _clearError();
    return true;
  }

  bool _rewriteInfixDraftUnary(Matrix Function(Matrix value) transform) {
    final _InfixBinaryContext? context = _tryParseInfixBinaryContext(
      _infixDraft,
    );
    if (context != null) {
      final Matrix? rightValue = _tryParseOperand(context.rightExpression);
      if (rightValue == null) {
        return false;
      }

      try {
        final Matrix transformed = transform(rightValue);
        _infixDraft =
            '${context.leftExpression}${context.operator}${_expressionSeedFromValue(transformed)}';
        _clearError();
      } on FormatException catch (error) {
        _lastError = error;
      } on CalculatrixError catch (error) {
        _lastError = error;
      }

      return true;
    }

    final Matrix? operand = _tryParseOperand(_infixDraft);
    if (operand != null) {
      try {
        return _rewriteInfixDraftValue(transform(operand));
      } on FormatException catch (error) {
        _lastError = error;
      } on CalculatrixError catch (error) {
        _lastError = error;
      }
      return true;
    }

    return false;
  }

  bool _rewriteInfixDraftValue(Matrix value) {
    _infixDraft = _expressionSeedFromValue(value);
    _clearError();
    return true;
  }

  bool _rewriteCommittedInfixValue(Matrix Function(Matrix value) transform) {
    final Matrix? currentValue = _currentValue;
    if (currentValue == null) {
      return false;
    }

    try {
      _updateCommittedValueFromInfix(
        transform(currentValue),
        invalidateRepeatEquals: true,
      );
      _clearError();
    } on FormatException catch (error) {
      _lastError = error;
    } on CalculatrixError catch (error) {
      _lastError = error;
    }

    return true;
  }

  bool _isOperator(String value) {
    return value == '+' || value == '-' || value == '×' || value == '÷';
  }

  String _currentInfixOperandExpression(String expression) {
    final _InfixBinaryContext? context = _tryParseInfixBinaryContext(expression);
    return context?.rightExpression ?? expression;
  }

  _InfixBinaryContext? _tryParseInfixBinaryContext(String expression) {
    final int operatorIndex = _findLastTopLevelOperator(expression);
    if (operatorIndex <= 0 || operatorIndex >= expression.length - 1) {
      return null;
    }

    return _InfixBinaryContext(
      leftExpression: expression.substring(0, operatorIndex),
      operator: expression[operatorIndex],
      rightExpression: expression.substring(operatorIndex + 1),
    );
  }

  int _findLastTopLevelOperator(String expression) {
    int parenDepth = 0;
    int bracketDepth = 0;

    for (int index = expression.length - 1; index >= 0; index--) {
      final String character = expression[index];
      switch (character) {
        case ')':
          parenDepth++;
          continue;
        case '(':
          parenDepth--;
          continue;
        case ']':
          bracketDepth++;
          continue;
        case '[':
          bracketDepth--;
          continue;
      }

      if (parenDepth != 0 || bracketDepth != 0 || !_isOperator(character)) {
        continue;
      }

      if ((character == '+' || character == '-') &&
          _isUnarySignAt(expression, index)) {
        continue;
      }

      return index;
    }

    return -1;
  }

  bool _isUnarySignAt(String expression, int index) {
    if (index == 0) {
      return true;
    }

    final String previous = expression[index - 1];
    if (previous == 'e' || previous == 'E') {
      return true;
    }

    return _isOperator(previous) || previous == '(';
  }

  Matrix _parseDraftOperand(String expression) {
    final String normalized = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/');

    return Calculatrix.evaluateInfix(normalized);
  }

  // Token boundaries in an rpn line are shared with rpn programs: splitting
  // on every literal space would tear a matrix literal such as
  // "[[1 2] [3 4]]" apart, so this delegates to the same bracket-aware
  // tokenizer the core uses for RPN programs rather than a second one.
  List<Matrix> _parseDraftTokens(String draft) {
    return Calculatrix.tokenizeRpnLine(draft)
        .map(_parseDraftOperand)
        .toList(growable: false);
  }

  /// Toggles the sign of the last token in a multi-operand rpn draft,
  /// leaving every earlier token untouched. This is what makes
  /// `2 SPC 3 ±` negate the pending `3`, not the whole draft. The last
  /// token's boundary is found with Calculatrix.lastRpnTokenBoundary, the
  /// same bracket-aware, whitespace-agnostic rule tokenizeRpnLine uses to
  /// split the draft on commit (a tab or newline is a token boundary here
  /// exactly as it is there), so a matrix literal such as
  /// `2 SPC [[1 2] [3 4]]` is treated as one token and only that matrix is
  /// toggled.
  ///
  /// This never parses or re-serializes the token: it only ever adds or
  /// removes one leading `-` character on the raw text, so the digits the
  /// user typed (an exponent, 17 significant digits, HP-style spacing
  /// inside a matrix literal, ...) always round-trip exactly, including
  /// through a matrix literal. That is safe because the token grammar
  /// (Calculatrix._isSignedBracketStart) accepts a leading sign directly in
  /// front of a bracketed literal as a single signed-matrix-literal token,
  /// so a toggled `-[[1,2],[3,4]]` commits to the negated matrix like any
  /// other signed operand.
  ///
  /// When the draft ends with a trailing space (SPC was pressed but nothing
  /// has been typed for the next operand yet), the "last token" is empty;
  /// toggling it prepends a bare `-` as the start of that next operand,
  /// exactly as pressing ± before typing any digit would. Toggling again
  /// removes it, returning to the empty token. Committing a draft that
  /// still ends in a lone `-` fails to parse like any other invalid token:
  /// nothing is pushed and the typed error is surfaced, matching the
  /// existing atomic commit behavior; there is no silent fallback.
  // ± is a three-way toggle, not a two-way one: a leading '-' is removed
  // (back to positive), a leading '+' is replaced with '-' (an explicitly
  // positive token, e.g. left by a previous toggle, becomes negative rather
  // than gaining a second, invalid leading sign), and anything else gets a
  // '-' prepended. Applies uniformly to numeric and matrix tokens alike,
  // since both are toggled by this same textual prefix rule.
  String _toggleSignOfLastToken(String draft) {
    final int lastTokenStart = Calculatrix.lastRpnTokenBoundary(draft);
    final String prefix = draft.substring(0, lastTokenStart);
    final String lastToken = draft.substring(lastTokenStart);

    final String toggledToken;
    if (lastToken.startsWith('-')) {
      toggledToken = lastToken.substring(1);
    } else if (lastToken.startsWith('+')) {
      toggledToken = '-${lastToken.substring(1)}';
    } else {
      toggledToken = '-$lastToken';
    }

    return prefix + toggledToken;
  }

  Matrix? _tryParseOperand(String expression) {
    try {
      return _parseDraftOperand(expression);
    } on FormatException {
      return null;
    } on CalculatrixError {
      return null;
    }
  }

  Matrix? _tryEvaluateExpression(String expression) {
    try {
      return _evaluateExpression(expression);
    } on FormatException {
      return null;
    } on CalculatrixError {
      return null;
    }
  }

  void _commitDraftIfNeeded() {
    if (_rpnDraft.isEmpty) {
      return;
    }

    final List<Matrix> operands = _parseDraftTokens(_rpnDraft);
    for (final Matrix operand in operands) {
      _machine.execute(PushMatrixCommand(operand));
    }
    _rpnDraft = '';
  }

  // The one declared rule for every RPN key: a key is either an EDITING key
  // (digits, the decimal point, SPC, backspace, clear-entry, and toggling
  // the sign of the pending line) that only ever touches _rpnDraft, or an
  // ACTION key (ENTER, the arithmetic/unary operators, dup/drop/swap/over/
  // rot, any CalculatrixCommand or macro, and the memory keys MR/MRC/MC)
  // that operates on the real stack or memory. Every ACTION key commits the
  // pending line first, through this one shared choke point, exactly like
  // ENTER: an invalid pending token surfaces the typed error, pushes
  // nothing, keeps the draft as typed, and the action itself does not run.
  // This is enforced in one place, _runRpnAction, rather than re-implemented
  // per method, so no action key can be added later that forgets to commit.
  void _runRpnAction(void Function() action) {
    if (!isRpnMode) {
      return;
    }

    final int mutationCountBeforeAction = _machine.mutationCount;

    try {
      _commitDraftIfNeeded();
      action();
      _clearError();
      // Mirrors the two catch blocks below: repeat-equals is only
      // invalidated when the stack actually changed, whether from
      // committing a pending draft or from the action itself (e.g. MC's
      // action only clears memory, so "MC" with no pending draft must
      // leave repeat-equals intact, matching the empty-draft case there).
      _syncCommittedValueFromRpnStack(
        invalidateRepeatEquals: _machine.mutationCount != mutationCountBeforeAction,
      );
    } on FormatException catch (error) {
      _lastError = error;
      // The action may have already committed draft operands onto the real
      // stack before the failing step ran, so currentValue must still track
      // the new top even though the operation itself failed. Repeat-equals
      // state (_lastOperator/_lastOperand) is only invalidated when the
      // stack actually changed: a failing command is atomic and rolls
      // itself back, so the only way mutationCount can differ here is a
      // draft commit or an earlier macro step that already went through
      // before the failure. A no-op failure (e.g. an underflow on an
      // untouched stack) must leave repeat-equals intact. mutationCount is
      // used rather than depth because a command can mutate a matrix's
      // content in place without changing how many elements are on the
      // stack (e.g. negating the top), which depth alone cannot detect.
      _syncCommittedValueFromRpnStack(
        invalidateRepeatEquals: _machine.mutationCount != mutationCountBeforeAction,
      );
    } on CalculatrixError catch (error) {
      _lastError = error;
      _syncCommittedValueFromRpnStack(
        invalidateRepeatEquals: _machine.mutationCount != mutationCountBeforeAction,
      );
    }
  }

  void _updateCommittedValueFromInfix(
    Matrix value, {
    bool invalidateRepeatEquals = false,
  }) {
    _currentValue = value;
    _replaceRpnTopWith(value);
    if (invalidateRepeatEquals) {
      _clearRepeatState();
    }
  }

  void _syncCommittedValueFromRpnStack({
    bool invalidateRepeatEquals = false,
  }) {
    _currentValue = _machine.top;
    if (invalidateRepeatEquals) {
      _clearRepeatState();
    }
  }

  void _ensureRpnStackMatchesCommittedValue() {
    final Matrix? currentValue = _currentValue;
    if (currentValue == null) {
      return;
    }

    _replaceRpnTopWith(currentValue);
  }

  void _replaceRpnTopWith(Matrix value) {
    if (_machine.depth == 0) {
      _machine.execute(PushMatrixCommand(value));
      return;
    }

    _machine.execute(const DropCommand());
    _machine.execute(PushMatrixCommand(value));
  }

  void _clearAllState() {
    _infixDraft = '';
    _rpnDraft = '';
    _currentValue = null;
    _lastError = null;
    _machine.clear();
    _clearRepeatState();
  }

  CalculatrixCommand _binaryCommand(RpnBinaryOperator operator) {
    switch (operator) {
      case RpnBinaryOperator.add:
        return const AddCommand();
      case RpnBinaryOperator.subtract:
        return const SubtractCommand();
      case RpnBinaryOperator.multiply:
        return const MultiplyCommand();
      case RpnBinaryOperator.divide:
        return const DivideCommand();
    }
  }

  CalculatrixCommand _unaryCommand(RpnUnaryOperator operator) {
    switch (operator) {
      case RpnUnaryOperator.sqrt:
        return const SqrtCommand();
      case RpnUnaryOperator.percent:
        return const PercentCommand();
    }
  }

  void _clearRepeatState() {
    _lastOperator = '';
    _lastOperand = '';
  }

  void _clearError() {
    _lastError = null;
  }

  String _expressionSeedFromCurrentValue() {
    final Matrix? value = _currentValue;
    if (value == null) {
      return '';
    }

    return _expressionSeedFromValue(value);
  }

  String _expressionSeedFromValue(Matrix value) {
    if (!value.isScalar) {
      return _serializeMatrix(value);
    }

    return _formatScalarLiteral(value.scalarValue);
  }

  Matrix _negatedValue(Matrix value) {
    return value.scale(-1);
  }

  Matrix _sqrtValue(Matrix value) {
    return value.sqrt();
  }

  Matrix _invertValue(Matrix value) {
    return value.inverse();
  }

  Matrix _transposeValue(Matrix value) {
    return value.transpose();
  }

  String _normalizeSessionPercentExpression(String expression) {
    final _InfixBinaryContext? context = _tryParseInfixBinaryContext(expression);
    if (context != null) {
      final String normalizedLeft = _normalizeSessionPercentExpression(
        context.leftExpression,
      );
      final String normalizedRight = _normalizeRightOperandPercentExpression(
        operator: context.operator,
        normalizedLeftExpression: normalizedLeft,
        rightExpression: context.rightExpression,
      );
      return '$normalizedLeft${context.operator}$normalizedRight';
    }

    return _normalizeStandalonePercentExpression(expression);
  }

  String _normalizeRightOperandPercentExpression({
    required String operator,
    required String normalizedLeftExpression,
    required String rightExpression,
  }) {
    final _InfixPercentContext? percentContext =
        _tryParseInfixPercentContext(rightExpression);
    if (percentContext == null) {
      return _normalizeStandalonePercentExpression(rightExpression);
    }

    final String normalizedPercentLeft = _normalizeSessionPercentExpression(
      percentContext.leftExpression,
    );
    if (percentContext.rightExpression.isNotEmpty) {
      final String normalizedPercentRight = _normalizeSessionPercentExpression(
        percentContext.rightExpression,
      );
      return '(($normalizedPercentLeft)*($normalizedPercentRight)/100)';
    }

    switch (operator) {
      case '+':
      case '-':
        return '(($normalizedLeftExpression)*($normalizedPercentLeft)/100)';
      case '×':
      case '÷':
        return '(($normalizedPercentLeft)/100)';
      default:
        return '(($normalizedPercentLeft)/100)';
    }
  }

  String _normalizeStandalonePercentExpression(String expression) {
    final _InfixPercentContext? percentContext =
        _tryParseInfixPercentContext(expression);
    if (percentContext == null) {
      return expression;
    }

    final String normalizedLeft = _normalizeSessionPercentExpression(
      percentContext.leftExpression,
    );
    if (percentContext.rightExpression.isNotEmpty) {
      final String normalizedRight = _normalizeSessionPercentExpression(
        percentContext.rightExpression,
      );
      return '(($normalizedLeft)*($normalizedRight)/100)';
    }

    return '(($normalizedLeft)/100)';
  }

  _InfixPercentContext? _tryParseInfixPercentContext(String expression) {
    final int percentIndex = _findFirstTopLevelPercent(expression);
    if (percentIndex <= 0) {
      return null;
    }

    return _InfixPercentContext(
      leftExpression: expression.substring(0, percentIndex),
      rightExpression: expression.substring(percentIndex + 1),
    );
  }

  int _findFirstTopLevelPercent(String expression) {
    int parenDepth = 0;
    int bracketDepth = 0;

    for (int index = 0; index < expression.length; index++) {
      final String character = expression[index];
      switch (character) {
        case '(':
          parenDepth++;
          continue;
        case ')':
          parenDepth--;
          continue;
        case '[':
          bracketDepth++;
          continue;
        case ']':
          bracketDepth--;
          continue;
      }

      if (parenDepth == 0 && bracketDepth == 0 && character == '%') {
        return index;
      }
    }

    return -1;
  }

  String _serializeMatrix(Matrix matrix) {
    final StringBuffer buffer = StringBuffer('[');

    for (int rowIndex = 0; rowIndex < matrix.rowCount; rowIndex++) {
      if (rowIndex > 0) {
        buffer.write(',');
      }

      buffer.write('[');
      for (int columnIndex = 0; columnIndex < matrix.columnCount; columnIndex++) {
        if (columnIndex > 0) {
          buffer.write(',');
        }

        buffer.write(_formatMatrixNumber(matrix.at(rowIndex, columnIndex)));
      }
      buffer.write(']');
    }

    buffer.write(']');
    return buffer.toString();
  }

  String _formatMatrixNumber(double value) {
    if (value == value.toInt().toDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  String _formatScalarLiteral(double value) {
    if (value == 0) {
      return '0';
    }

    if (value == value.toInt().toDouble() && value.abs() < 1e12) {
      return value.toInt().toString();
    }

    String text = value.toStringAsPrecision(12);
    if (text.contains('.')) {
      text = text.replaceAll(RegExp(r'0+$'), '');
      text = text.replaceAll(RegExp(r'\.$'), '');
    }
    return text;
  }
}

class _InfixBinaryContext {
  const _InfixBinaryContext({
    required this.leftExpression,
    required this.operator,
    required this.rightExpression,
  });

  final String leftExpression;
  final String operator;
  final String rightExpression;
}

class _InfixPercentContext {
  const _InfixPercentContext({
    required this.leftExpression,
    required this.rightExpression,
  });

  final String leftExpression;
  final String rightExpression;
}