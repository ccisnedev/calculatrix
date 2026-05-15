import 'package:flutter/foundation.dart';
import 'models/tokenizer.dart';
import 'models/parser.dart';
import 'models/evaluator.dart';

/// Controller for the calculator.
///
/// Manages the current expression input and delegates to the
/// tokenizer/evaluator pipeline. Notifies listeners on state changes.
class CalculatorController extends ChangeNotifier {
  final _tokenizer = Tokenizer();
  final _parser = Parser();
  final _evaluator = Evaluator();

  String _expression = '';
  String _result = '';
  String _error = '';
  double _memory = 0;

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
    if (_expression.isEmpty) return;
    try {
      final tokens = _tokenizer.tokenize(_expression);
      final ast = _parser.parse(tokens);
      final value = _evaluator.evaluate(ast);
      _result = _formatResult(value);
      _error = '';
    } on FormatException catch (e) {
      _error = 'Error';
      _result = '';
      debugPrint('Eval error: $e');
    }
    notifyListeners();
  }

  /// Clears the entire expression and result.
  void clear() {
    _expression = '';
    _result = '';
    _error = '';
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
    if (value == value.toInt().toDouble()) {
      return value.toInt().toString();
    }
    // Limit to 10 decimal places, remove trailing zeros
    var str = value.toStringAsFixed(10);
    str = str.replaceAll(RegExp(r'0+$'), '');
    str = str.replaceAll(RegExp(r'\.$'), '');
    return str;
  }

  bool _isOperator(String value) {
    return value == '+' || value == '-' || value == '×' || value == '÷';
  }
}
