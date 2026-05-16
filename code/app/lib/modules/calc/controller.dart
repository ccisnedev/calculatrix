import 'package:flutter/foundation.dart';
import 'package:calculatrix/calculatrix.dart';

enum CalculatorMode { infix, rpn }

/// Controller for the calculator.
///
/// Manages the current expression input and delegates evaluation to the
/// shared core package. Notifies listeners on state changes.
class CalculatorController extends ChangeNotifier {
  String _infixExpression = '';
  String _rpnDraft = '';
  String _result = '';
  String _error = '';
  double _memory = 0;
  String _lastOperator = '';
  String _lastOperand = '';
  CalculatorMode _mode = CalculatorMode.infix;
  final RpnEngine _rpnEngine = RpnEngine();
  Matrix? _displayMatrix;
  Matrix? _currentValue;

  CalculatorMode get mode => _mode;

  /// The current expression being composed.
  String get expression => isRpnMode ? _rpnDraft : _infixExpression;

  /// The computed result (empty until equals is pressed).
  String get result => _result;

  /// Error message if evaluation failed (empty otherwise).
  String get error => _error;

  Matrix? get displayMatrix => _displayMatrix;

  /// Whether memory contains a non-zero value.
  bool get hasMemory => _memory != 0;

  bool get isRpnMode => _mode == CalculatorMode.rpn;

  bool get _hasCommittedValue => _currentValue != null;

  bool get _showsCommittedValueInInfix {
    return !isRpnMode && _infixExpression.isEmpty && _hasCommittedValue;
  }

  int get rpnStackDepth => _rpnEngine.depth;

  List<String> get rpnStackLiterals {
    return _rpnEngine.stack
        .reversed
        .map(_serializeMatrix)
        .toList(growable: false);
  }

  String get rpnTopLiteral {
    if (_rpnEngine.depth == 0) {
      return '';
    }

    return _serializeMatrix(_rpnEngine.peek());
  }

  /// The display text shown to the user.
  String get display {
    if (_error.isNotEmpty) return _error;
    if (expression.isNotEmpty) return expression;
    if (_result.isNotEmpty) return _result;
    return '0';
  }

  void setMode(CalculatorMode mode) {
    if (_mode == mode) {
      return;
    }

    _mode = mode;
    _error = '';

    if (isRpnMode) {
      _ensureRpnStackMatchesCommittedValue();
    } else {
      _syncCommittedValueFromRpnStack();
    }

    _syncDisplayForMode();
    notifyListeners();
  }

  void insertMatrixLiteral(String literal) {
    final Matrix matrix = Calculatrix.evaluateInfix(literal);

    _error = '';
    if (!isRpnMode) {
      _displayMatrix = null;
      if (_showsCommittedValueInInfix) {
        _infixExpression = literal;
        _result = '';
      } else {
        _infixExpression += literal;
      }
      notifyListeners();
      return;
    }

    _rpnEngine.push(matrix);
    _rpnDraft = '';
    _error = '';
    _syncCommittedValueFromRpnStack(invalidateRepeatEquals: true);
    notifyListeners();
  }

  /// Appends a character (digit, operator, paren) to the expression.
  void input(String value) {
    if (isRpnMode) {
      if (_result.isNotEmpty && _rpnDraft.isEmpty) {
        _result = '';
      }
      _displayMatrix = null;
      _error = '';
      _rpnDraft += value;
      notifyListeners();
      return;
    }

    // If showing result, start new expression with operators, or replace with digits
    if (_showsCommittedValueInInfix) {
      if (_isOperator(value)) {
        _infixExpression = _expressionSeedFromCurrentValue() + value;
      } else {
        _infixExpression = value;
      }
      _result = '';
      _displayMatrix = null;
      _error = '';
    } else {
      _displayMatrix = null;
      _error = '';
      _infixExpression += value;
    }
    notifyListeners();
  }

  /// Evaluates the current expression.
  void evaluate() {
    if (isRpnMode) {
      enter();
      return;
    }

    if (_infixExpression.isEmpty && _hasCommittedValue && _lastOperator.isNotEmpty) {
      // Repeat last operation: result op lastOperand
      _infixExpression = '${_expressionSeedFromCurrentValue()}$_lastOperator$_lastOperand';
    }
    if (_infixExpression.isEmpty) return;
    try {
      // Save the last operator and operand for repeat
      _saveLastOperation(_infixExpression);
      final Matrix value = _evaluateExpression(_infixExpression);
      _infixExpression = '';
      _error = '';
      _updateCommittedValueFromInfix(value);
    } on FormatException catch (e) {
      _error = 'Error';
      _result = '';
      _displayMatrix = null;
      _infixExpression = '';
      debugPrint('Eval error: $e');
    } on CalculatrixError catch (e) {
      _error = 'Error';
      _result = '';
      _displayMatrix = null;
      _infixExpression = '';
      debugPrint('Eval error: $e');
    }
    notifyListeners();
  }

  Matrix _evaluateExpression(String expression) {
    final String normalized = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/');

    return Calculatrix.evaluateInfix(normalized);
  }

  void _saveLastOperation(String expr) {
    // Extract last binary operator and operand from expression
    // Look for the last +, -, ×, ÷ that is not inside parentheses
    var depth = 0;
    var lastOpIndex = -1;
    for (var i = expr.length - 1; i >= 0; i--) {
      final c = expr[i];
      if (c == ')') depth++;
      if (c == '(') depth--;
      if (depth == 0 && (c == '+' || c == '-' || c == '×' || c == '÷')) {
        // Don't count leading minus
        if (c == '-' && i == 0) break;
        lastOpIndex = i;
        break;
      }
    }
    if (lastOpIndex > 0) {
      _lastOperator = expr[lastOpIndex];
      _lastOperand = expr.substring(lastOpIndex + 1);
    } else {
      _lastOperator = '';
      _lastOperand = '';
    }
  }

  /// Clears the entire expression and result.
  void clear() {
    if (isRpnMode) {
      if (_rpnDraft.isNotEmpty) {
        _rpnDraft = '';
        _error = '';
        _syncDisplayForMode();
      } else {
        _clearAllState();
      }
      notifyListeners();
      return;
    }

    _clearAllState();
    notifyListeners();
  }

  /// Deletes the last character from the expression.
  void backspace() {
    if (isRpnMode) {
      if (_rpnDraft.isNotEmpty) {
        _rpnDraft = _rpnDraft.substring(0, _rpnDraft.length - 1);
        _displayMatrix = null;
        _error = '';
        if (_rpnDraft.isEmpty) {
          _syncDisplayForMode();
        }
        notifyListeners();
      }
      return;
    }

    if (_showsCommittedValueInInfix) {
      // After result, clear all
      clear();
      return;
    }
    if (_infixExpression.isNotEmpty) {
      _infixExpression = _infixExpression.substring(0, _infixExpression.length - 1);
      _displayMatrix = null;
      _error = '';
      if (_infixExpression.isEmpty) {
        _syncDisplayForMode();
      }
      notifyListeners();
    }
  }

  /// Toggles the sign of the current value.
  void toggleSign() {
    if (isRpnMode) {
      if (_rpnDraft.isNotEmpty) {
        if (_rpnDraft.startsWith('-')) {
          _rpnDraft = _rpnDraft.substring(1);
        } else {
          _rpnDraft = '-$_rpnDraft';
        }
        _displayMatrix = null;
        notifyListeners();
      }
      return;
    }

    if (_showsCommittedValueInInfix && _currentValue!.isScalar) {
      _error = '';
      _updateCommittedValueFromInfix(
        Matrix.scalar(-_currentValue!.scalarValue),
        invalidateRepeatEquals: true,
      );
      notifyListeners();
      return;
    }
    if (_infixExpression.isNotEmpty) {
      if (_infixExpression.startsWith('-')) {
        _infixExpression = _infixExpression.substring(1);
      } else {
        _infixExpression = '-$_infixExpression';
      }
      _displayMatrix = null;
      _error = '';
      notifyListeners();
    }
  }

  /// Clears memory.
  void memoryClear() {
    _memory = 0;
    notifyListeners();
  }

  /// Recalls memory value into expression.
  void memoryRecall() {
    if (_memory == 0) return;

    if (isRpnMode) {
      _rpnEngine.pushScalar(_memory);
      _rpnDraft = '';
      _error = '';
      _syncCommittedValueFromRpnStack(invalidateRepeatEquals: true);
      notifyListeners();
      return;
    }

    final memStr = _formatResult(_memory);
    if (_showsCommittedValueInInfix) {
      _infixExpression = memStr;
      _result = '';
      _displayMatrix = null;
      _error = '';
    } else {
      _displayMatrix = null;
      _error = '';
      _infixExpression += memStr;
    }
    notifyListeners();
  }

  /// Adds current display value to memory.
  void memoryAdd() {
    final value = _currentNumericValue();
    if (value != null) {
      _error = '';
      _memory += value;
      notifyListeners();
      return;
    }

    if (_hasNonScalarMemoryOperand()) {
      _error = 'Error';
      notifyListeners();
    }
  }

  /// Subtracts current display value from memory.
  void memorySubtract() {
    final value = _currentNumericValue();
    if (value != null) {
      _error = '';
      _memory -= value;
      notifyListeners();
      return;
    }

    if (_hasNonScalarMemoryOperand()) {
      _error = 'Error';
      notifyListeners();
    }
  }

  void enter() {
    if (!isRpnMode || _rpnDraft.isEmpty) {
      return;
    }

    try {
      _rpnEngine.push(_parseDraftOperand(_rpnDraft));
      _rpnDraft = '';
      _error = '';
      _syncCommittedValueFromRpnStack(invalidateRepeatEquals: true);
    } on FormatException catch (error) {
      _error = 'Error';
      _result = '';
      _displayMatrix = null;
      debugPrint('Eval error: $error');
    } on CalculatrixError catch (error) {
      _error = 'Error';
      _result = '';
      _displayMatrix = null;
      debugPrint('Eval error: $error');
    }

    notifyListeners();
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

  double? _currentNumericValue() {
    if (isRpnMode) {
      if (_rpnDraft.isNotEmpty) {
        return double.tryParse(_rpnDraft);
      }

      if (_currentValue?.isScalar ?? false) {
        return _currentValue!.scalarValue;
      }

      return null;
    }

    if (_infixExpression.isNotEmpty) return double.tryParse(_infixExpression);
    if (_currentValue?.isScalar ?? false) {
      return _currentValue!.scalarValue;
    }
    return null;
  }

  String _formatResult(double value) {
    if (value.isInfinite) return 'Error';
    if (value.isNaN) return 'Error';
    if (value == 0) return '0';
    if (value == value.toInt().toDouble() && value.abs() < 1e12) {
      return value.toInt().toString();
    }
    // Use 12 significant digits, remove trailing zeros
    var str = value.toStringAsPrecision(12);
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0+$'), '');
      str = str.replaceAll(RegExp(r'\.$'), '');
    }
    return str;
  }

  bool _hasNonScalarMemoryOperand() {
    if (expression.isNotEmpty) {
      final Matrix? draft = _tryParseOperand(expression);
      return draft != null && !draft.isScalar;
    }

    return _currentValue != null && !_currentValue!.isScalar;
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
      _error = '';
      _syncCommittedValueFromRpnStack(invalidateRepeatEquals: true);
    } on FormatException catch (error) {
      _error = 'Error';
      _result = '';
      _displayMatrix = null;
      _rpnDraft = '';
      debugPrint('Eval error: $error');
    } on CalculatrixError catch (error) {
      _error = 'Error';
      _result = '';
      _displayMatrix = null;
      _rpnDraft = '';
      debugPrint('Eval error: $error');
    }

    notifyListeners();
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
    _syncDisplayForMode();
  }

  void _syncCommittedValueFromRpnStack({
    bool invalidateRepeatEquals = false,
  }) {
    _currentValue = _rpnEngine.depth > 0 ? _rpnEngine.peek() : null;
    if (invalidateRepeatEquals) {
      _clearRepeatState();
    }
    _syncDisplayForMode();
  }

  void _ensureRpnStackMatchesCommittedValue() {
    if (_currentValue == null) {
      return;
    }

    _replaceRpnTopWith(_currentValue!);
  }

  void _replaceRpnTopWith(Matrix value) {
    if (_rpnEngine.depth == 0) {
      _rpnEngine.push(value);
      return;
    }

    _rpnEngine.pop();
    _rpnEngine.push(value);
  }

  void _syncDisplayForMode() {
    if (_currentValue == null) {
      _result = '';
      _displayMatrix = null;
      return;
    }

    if (isRpnMode) {
      _displayMatrix = _currentValue;
      _result = rpnTopLiteral;
      return;
    }

    _displayMatrix = _currentValue!.isScalar ? null : _currentValue;
    _result = _currentValue!.isScalar
        ? _formatResult(_currentValue!.scalarValue)
        : MatrixDisplayFormatter.compact(_currentValue!);
  }

  void _clearAllState() {
    _infixExpression = '';
    _rpnDraft = '';
    _result = '';
    _displayMatrix = null;
    _error = '';
    _currentValue = null;
    _rpnEngine.clear();
    _clearRepeatState();
  }

  void _clearRepeatState() {
    _lastOperator = '';
    _lastOperand = '';
  }

  String _expressionSeedFromCurrentValue() {
    final Matrix? matrix = _currentValue;
    if (matrix == null) {
      return '';
    }

    if (!matrix.isScalar) {
      return _serializeMatrix(matrix);
    }

    return _formatResult(matrix.scalarValue);
  }

  String _serializeMatrix(Matrix matrix) {
    final StringBuffer buffer = StringBuffer('[');

    for (int r = 0; r < matrix.rowCount; r++) {
      if (r > 0) {
        buffer.write(',');
      }

      buffer.write('[');
      for (int c = 0; c < matrix.columnCount; c++) {
        if (c > 0) {
          buffer.write(',');
        }

        buffer.write(_formatMatrixNumber(matrix.at(r, c)));
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
}
