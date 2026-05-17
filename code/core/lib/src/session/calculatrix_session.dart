import '../errors/errors.dart';
import '../evaluation/calculatrix.dart';
import '../matrix/matrix.dart';
import '../rpn/rpn_engine.dart';

enum CalculatrixMode { infix, rpn }

class CalculatrixSession {
  String _infixDraft = '';
  String _rpnDraft = '';
  String _lastOperator = '';
  String _lastOperand = '';
  CalculatrixMode _mode = CalculatrixMode.infix;
  final RpnEngine _rpnEngine = RpnEngine();
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

  int get rpnStackDepth => _rpnEngine.depth;

  List<Matrix> get rpnStack => _rpnEngine.stack;

  Matrix? get rpnTopValue {
    if (_rpnEngine.depth == 0) {
      return null;
    }

    return _rpnEngine.peek();
  }

  List<String> get rpnStackLiterals {
    return _rpnEngine.stack
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

    _rpnEngine.push(matrix);
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
      _rpnEngine.push(memory);
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
      _rpnEngine.push(_parseDraftOperand(_rpnDraft));
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
      _rpnEngine.applyBinary(operator);
    });
  }

  void applyRpnUnary(RpnUnaryOperator operator) {
    if (!isRpnMode) {
      return;
    }

    _runRpnAction(() {
      _commitDraftIfNeeded();
      _rpnEngine.applyUnary(operator);
    });
  }

  void dupRpn() {
    _runRpnAction(_rpnEngine.dup);
  }

  void dropRpn() {
    _runRpnAction(_rpnEngine.drop);
  }

  void swapRpn() {
    _runRpnAction(_rpnEngine.swap);
  }

  void overRpn() {
    _runRpnAction(_rpnEngine.over);
  }

  void rotRpn() {
    _runRpnAction(_rpnEngine.rot);
  }

  Matrix _evaluateExpression(String expression) {
    final String normalized = expression
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
      return _tryParseOperand(currentExpression);
    }

    return _currentValue;
  }

  bool get _showsCommittedValueInInfix {
    return !isRpnMode && _infixDraft.isEmpty && _currentValue != null;
  }

  bool _isOperator(String value) {
    return value == '+' || value == '-' || value == '×' || value == '÷';
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

  void _commitDraftIfNeeded() {
    if (_rpnDraft.isEmpty) {
      return;
    }

    _rpnEngine.push(_parseDraftOperand(_rpnDraft));
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
    _currentValue = _rpnEngine.depth > 0 ? _rpnEngine.peek() : null;
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
    if (_rpnEngine.depth == 0) {
      _rpnEngine.push(value);
      return;
    }

    _rpnEngine.pop();
    _rpnEngine.push(value);
  }

  void _clearAllState() {
    _infixDraft = '';
    _rpnDraft = '';
    _currentValue = null;
    _lastError = null;
    _rpnEngine.clear();
    _clearRepeatState();
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