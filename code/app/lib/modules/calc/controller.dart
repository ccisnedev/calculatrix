import 'package:flutter/foundation.dart';
import 'package:calculatrix/calculatrix.dart';

enum CalculatorMode { infix, rpn }

/// Controller for the calculator.
///
/// Manages the current expression input and delegates to the
/// tokenizer/evaluator pipeline. Notifies listeners on state changes.
class CalculatorController extends ChangeNotifier {
  String _expression = '';
  String _result = '';
  String _error = '';
  double _memory = 0;
  String _lastOperator = '';
  String _lastOperand = '';
  CalculatorMode _mode = CalculatorMode.infix;
  final RpnEngine _rpnEngine = RpnEngine();
  Matrix? _displayMatrix;

  CalculatorMode get mode => _mode;

  /// The current expression being composed.
  String get expression => _expression;

  /// The computed result (empty until equals is pressed).
  String get result => _result;

  /// Error message if evaluation failed (empty otherwise).
  String get error => _error;

  Matrix? get displayMatrix => _displayMatrix;

  /// Whether memory contains a non-zero value.
  bool get hasMemory => _memory != 0;

  bool get isRpnMode => _mode == CalculatorMode.rpn;

  int get rpnStackDepth => _rpnEngine.depth;

  List<String> get rpnStackLiterals {
    return _rpnEngine.stack
        .reversed
        .map(_serializeMatrix)
        .toList(growable: false);
  }

  List<Matrix> get rpnStackValues {
    return List<Matrix>.unmodifiable(_rpnEngine.stack.reversed);
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
    if (isRpnMode) {
      if (_expression.isNotEmpty) return _expression;
      if (_result.isNotEmpty) return _result;
      return '0';
    }
    if (_result.isNotEmpty) return _result;
    return _expression.isEmpty ? '0' : _expression;
  }

  void setMode(CalculatorMode mode) {
    if (_mode == mode) {
      return;
    }

    _mode = mode;
    _expression = '';
    _error = '';
    _displayMatrix = isRpnMode && _rpnEngine.depth > 0 ? _rpnEngine.peek() : null;
    _result = isRpnMode ? rpnTopLiteral : '';
    notifyListeners();
  }

  void insertMatrixLiteral(String literal) {
    final Matrix matrix = Calculatrix.evaluateInfix(literal);

    _error = '';
    if (_mode == CalculatorMode.infix) {
      _displayMatrix = null;
      if (_result.isNotEmpty) {
        _expression = literal;
        _result = '';
      } else {
        _expression += literal;
      }
      notifyListeners();
      return;
    }

    _rpnEngine.push(matrix);
    _expression = '';
    _displayMatrix = matrix;
    _result = _serializeMatrix(matrix);
    notifyListeners();
  }

  /// Appends a character (digit, operator, paren) to the expression.
  void input(String value) {
    if (isRpnMode) {
      if (_result.isNotEmpty && _expression.isEmpty) {
        _result = '';
      }
      _displayMatrix = null;
      _error = '';
      _expression += value;
      notifyListeners();
      return;
    }

    // If showing result, start new expression with operators, or replace with digits
    if (_result.isNotEmpty) {
      if (_isOperator(value)) {
        _expression = _expressionSeedFromResult() + value;
      } else {
        _expression = value;
      }
      _result = '';
      _displayMatrix = null;
      _error = '';
    } else {
      _displayMatrix = null;
      _error = '';
      _expression += value;
    }
    notifyListeners();
  }

  /// Evaluates the current expression.
  void evaluate() {
    if (isRpnMode) {
      enter();
      return;
    }

    if (_expression.isEmpty && _result.isNotEmpty && _lastOperator.isNotEmpty) {
      // Repeat last operation: result op lastOperand
      _expression = '$_result$_lastOperator$_lastOperand';
    }
    if (_expression.isEmpty) return;
    try {
      // Save the last operator and operand for repeat
      _saveLastOperation(_expression);
      final Matrix value = _evaluateExpression(_expression);
      _displayMatrix = value.isScalar ? null : value;
      _result = value.isScalar
          ? _formatResult(value.scalarValue)
          : MatrixDisplayFormatter.compact(value);
      _expression = '';
      _error = '';
    } on FormatException catch (e) {
      _error = 'Error';
      _result = '';
      _displayMatrix = null;
      _expression = '';
      debugPrint('Eval error: $e');
    } on CalculatrixError catch (e) {
      _error = 'Error';
      _result = '';
      _displayMatrix = null;
      _expression = '';
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
      if (_expression.isNotEmpty) {
        _expression = '';
        _displayMatrix = _rpnEngine.depth > 0 ? _rpnEngine.peek() : null;
        _error = '';
      } else {
        _rpnEngine.clear();
        _result = '';
        _displayMatrix = null;
        _error = '';
      }
      notifyListeners();
      return;
    }

    _expression = '';
    _result = '';
  _displayMatrix = null;
    _error = '';
    _lastOperator = '';
    _lastOperand = '';
    notifyListeners();
  }

  /// Deletes the last character from the expression.
  void backspace() {
    if (isRpnMode) {
      if (_expression.isNotEmpty) {
        _expression = _expression.substring(0, _expression.length - 1);
        _displayMatrix = null;
        _error = '';
        notifyListeners();
      }
      return;
    }

    if (_result.isNotEmpty) {
      // After result, clear all
      clear();
      return;
    }
    if (_expression.isNotEmpty) {
      _expression = _expression.substring(0, _expression.length - 1);
      _displayMatrix = null;
      _error = '';
      notifyListeners();
    }
  }

  /// Toggles the sign of the current value.
  void toggleSign() {
    if (isRpnMode) {
      if (_expression.isNotEmpty) {
        if (_expression.startsWith('-')) {
          _expression = _expression.substring(1);
        } else {
          _expression = '-$_expression';
        }
        _displayMatrix = null;
        notifyListeners();
      }
      return;
    }

    if (_result.isNotEmpty) {
      final value = double.tryParse(_result);
      if (value != null) {
        _result = _formatResult(-value);
        _displayMatrix = Matrix.scalar(-value);
        notifyListeners();
      }
      return;
    }
    if (_expression.isNotEmpty) {
      if (_expression.startsWith('-')) {
        _expression = _expression.substring(1);
      } else {
        _expression = '-$_expression';
      }
      _displayMatrix = null;
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
      _expression = '';
      _error = '';
      _syncRpnDisplay();
      notifyListeners();
      return;
    }

    final memStr = _formatResult(_memory);
    if (_result.isNotEmpty) {
      _expression = memStr;
      _result = '';
      _displayMatrix = null;
      _error = '';
    } else {
      _displayMatrix = null;
      _expression += memStr;
    }
    notifyListeners();
  }

  /// Adds current display value to memory.
  void memoryAdd() {
    final value = _currentNumericValue();
    if (value != null) {
      _memory += value;
      notifyListeners();
      return;
    }

    if (isRpnMode && _rpnEngine.depth > 0) {
      _error = 'Error';
      notifyListeners();
    }
  }

  /// Subtracts current display value from memory.
  void memorySubtract() {
    final value = _currentNumericValue();
    if (value != null) {
      _memory -= value;
      notifyListeners();
      return;
    }

    if (isRpnMode && _rpnEngine.depth > 0) {
      _error = 'Error';
      notifyListeners();
    }
  }

  void enter() {
    if (!isRpnMode || _expression.isEmpty) {
      return;
    }

    try {
      _rpnEngine.push(_parseDraftOperand(_expression));
      _expression = '';
      _error = '';
      _syncRpnDisplay();
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
      if (_expression.isNotEmpty) {
        return double.tryParse(_expression);
      }

      if (_rpnEngine.depth == 0) {
        return null;
      }

      final Matrix value = _rpnEngine.peek();
      if (value.isScalar) {
        return value.scalarValue;
      }

      return null;
    }

    if (_result.isNotEmpty) return double.tryParse(_result);
    if (_expression.isNotEmpty) return double.tryParse(_expression);
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

  bool _isOperator(String value) {
    return value == '+' || value == '-' || value == '×' || value == '÷';
  }

  Matrix _parseDraftOperand(String expression) {
    final String normalized = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/');

    return Calculatrix.evaluateInfix(normalized);
  }

  void _commitDraftIfNeeded() {
    if (_expression.isEmpty) {
      return;
    }

    _rpnEngine.push(_parseDraftOperand(_expression));
    _expression = '';
  }

  void _runRpnAction(void Function() action) {
    if (!isRpnMode) {
      return;
    }

    try {
      action();
      _error = '';
      _syncRpnDisplay();
    } on FormatException catch (error) {
      _error = 'Error';
      _result = '';
      _displayMatrix = null;
      _expression = '';
      debugPrint('Eval error: $error');
    } on CalculatrixError catch (error) {
      _error = 'Error';
      _result = '';
      _displayMatrix = null;
      _expression = '';
      debugPrint('Eval error: $error');
    }

    notifyListeners();
  }

  void _syncRpnDisplay() {
    _displayMatrix = _rpnEngine.depth > 0 ? _rpnEngine.peek() : null;
    _result = rpnTopLiteral;
  }

  String _expressionSeedFromResult() {
    final Matrix? matrix = _displayMatrix;
    if (matrix != null && !matrix.isScalar) {
      return _serializeMatrix(matrix);
    }

    return _result;
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
