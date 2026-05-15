import 'package:flutter/foundation.dart';

/// Controller for the calculator.
///
/// Manages the current expression input and delegates to the
/// tokenizer/evaluator pipeline. Notifies listeners on state changes.
class CalculatorController extends ChangeNotifier {
  String _expression = '';

  /// The current expression being composed.
  String get expression => _expression;

  /// The display text shown to the user.
  String get display => _expression.isEmpty ? '0' : _expression;

  /// Appends a character (digit, operator, paren) to the expression.
  void input(String value) {
    _expression += value;
    notifyListeners();
  }

  /// Clears the entire expression.
  void clear() {
    _expression = '';
    notifyListeners();
  }

  /// Deletes the last character from the expression.
  void backspace() {
    if (_expression.isNotEmpty) {
      _expression = _expression.substring(0, _expression.length - 1);
      notifyListeners();
    }
  }
}
