import 'package:flutter/foundation.dart';
import 'package:calculatrix/calculatrix.dart';

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

  /// The current expression being composed.
  String get expression => _expression;

  /// The computed result (empty until equals is pressed).
  String get result => _result;

  /// Error message if evaluation failed (empty otherwise).
  String get error => _error;

  /// Whether memory contains a non-zero value.
  bool get hasMemory => _memory != 0;

  /// The display text shown to the user.
  String get display {
    if (_error.isNotEmpty) return _error;
    if (_result.isNotEmpty) return _result;
    return _expression.isEmpty ? '0' : _expression;
  }

  /// Appends a character (digit, operator, paren) to the expression.
  void input(String value) {
    // If showing result, start new expression with operators, or replace with digits
    if (_result.isNotEmpty) {
      if (_isOperator(value)) {
        _expression = _result + value;
      } else {
        _expression = value;
      }
      _result = '';
      _error = '';
    } else {
      _error = '';
      _expression += value;
    }
    notifyListeners();
  }

  /// Evaluates the current expression.
  void evaluate() {
    if (_expression.isEmpty && _result.isNotEmpty && _lastOperator.isNotEmpty) {
      // Repeat last operation: result op lastOperand
      _expression = '$_result$_lastOperator$_lastOperand';
    }
    if (_expression.isEmpty) return;
    try {
      // Save the last operator and operand for repeat
      _saveLastOperation(_expression);
      final double value = _evaluateExpression(_expression);
      _result = _formatResult(value);
      _expression = '';
      _error = '';
    } on FormatException catch (e) {
      _error = 'Error';
      _result = '';
      _expression = '';
      debugPrint('Eval error: $e');
    } on CalculatrixError catch (e) {
      _error = 'Error';
      _result = '';
      _expression = '';
      debugPrint('Eval error: $e');
    }
    notifyListeners();
  }

  double _evaluateExpression(String expression) {
    final String normalized = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/');

    final Matrix value = Calculatrix.evaluateInfix(normalized);
    return value.scalarValue;
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
    _expression = '';
    _result = '';
    _error = '';
    _lastOperator = '';
    _lastOperand = '';
    notifyListeners();
  }

  /// Deletes the last character from the expression.
  void backspace() {
    if (_result.isNotEmpty) {
      // After result, clear all
      clear();
      return;
    }
    if (_expression.isNotEmpty) {
      _expression = _expression.substring(0, _expression.length - 1);
      _error = '';
      notifyListeners();
    }
  }

  /// Toggles the sign of the current value.
  void toggleSign() {
    if (_result.isNotEmpty) {
      final value = double.tryParse(_result);
      if (value != null) {
        _result = _formatResult(-value);
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
    final memStr = _formatResult(_memory);
    if (_result.isNotEmpty) {
      _expression = memStr;
      _result = '';
      _error = '';
    } else {
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
    }
  }

  /// Subtracts current display value from memory.
  void memorySubtract() {
    final value = _currentNumericValue();
    if (value != null) {
      _memory -= value;
      notifyListeners();
    }
  }

  double? _currentNumericValue() {
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
}
