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
        if (_rpnDraft.startsWith('-')) {
          _rpnDraft = _rpnDraft.substring(1);
        } else {
          _rpnDraft = '-$_rpnDraft';
        }
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
    _memoryValue = null;
  }

  void memoryRecall() {
    final Matrix? memory = _memoryValue;
    if (memory == null) {
      return;
    }

    if (isRpnMode) {
      _machine.execute(PushMatrixCommand(memory));
      _rpnDraft = '';
      _clearError();
      _syncCommittedValueFromRpnStack(invalidateRepeatEquals: true);
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
    if (!isRpnMode || _rpnDraft.isEmpty) {
      return;
    }

    try {
      _machine.execute(PushMatrixCommand(_parseDraftOperand(_rpnDraft)));
      _rpnDraft = '';
      _clearError();
      _syncCommittedValueFromRpnStack(invalidateRepeatEquals: true);
    } on FormatException catch (error) {
      _lastError = error;
    } on CalculatrixError catch (error) {
      _lastError = error;
    }
  }

  void applyRpnBinary(RpnBinaryOperator operator) {
    if (!isRpnMode) {
      return;
    }

    _runRpnAction(() {
      _commitDraftIfNeeded();
      _machine.execute(_binaryCommand(operator));
    });
  }

  void applyRpnUnary(RpnUnaryOperator operator) {
    if (!isRpnMode) {
      return;
    }

    _runRpnAction(() {
      _commitDraftIfNeeded();
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
      _commitDraftIfNeeded();
      _machine.execute(command);
    });
  }

  void executeMacro(CalculatrixMacro macro) {
    if (!isRpnMode) {
      return;
    }

    _runRpnAction(() {
      _commitDraftIfNeeded();
      _machine.executeMacro(macro);
    });
  }

  Matrix _evaluateExpression(String expression) {
    final String normalized = _normalizeSessionPercentExpression(expression)
        .replaceAll('×', '*')
        .replaceAll('÷', '/');

    return Calculatrix.evaluateInfix(normalized);
  }

  void _saveLastOperation(String expression) {
    int depth = 0;
    int lastOperatorIndex = -1;

    for (int index = expression.length - 1; index >= 0; index--) {
      final String character = expression[index];
      if (character == ')') {
        depth++;
      }
      if (character == '(') {
        depth--;
      }
      if (depth == 0 &&
          (character == '+' ||
              character == '-' ||
              character == '×' ||
              character == '÷')) {
        if (character == '-' && index == 0) {
          break;
        }
        lastOperatorIndex = index;
        break;
      }
    }

    if (lastOperatorIndex > 0) {
      _lastOperator = expression[lastOperatorIndex];
      _lastOperand = expression.substring(lastOperatorIndex + 1);
    } else {
      _clearRepeatState();
    }
  }

  Matrix? _currentMemoryOperand() {
    final String currentExpression = expression;
    if (currentExpression.isNotEmpty) {
      return _tryEvaluateExpression(currentExpression);
    }

    return _currentValue;
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

    _machine.execute(PushMatrixCommand(_parseDraftOperand(_rpnDraft)));
    _rpnDraft = '';
  }

  void _runRpnAction(void Function() action) {
    if (!isRpnMode) {
      return;
    }

    try {
      action();
      _clearError();
      _syncCommittedValueFromRpnStack(invalidateRepeatEquals: true);
    } on FormatException catch (error) {
      _lastError = error;
      _rpnDraft = '';
    } on CalculatrixError catch (error) {
      _lastError = error;
      _rpnDraft = '';
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