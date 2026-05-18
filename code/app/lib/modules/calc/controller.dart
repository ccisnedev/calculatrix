import 'package:flutter/foundation.dart';
import 'package:calculatrix/calculatrix.dart';

enum CalculatorMode { infix, rpn, matrix }

/// Controller for the calculator.
///
/// Manages the current expression input and delegates evaluation to the
/// shared core package. Notifies listeners on state changes.
class CalculatorController extends ChangeNotifier {
  CalculatorController({CalculatrixSession? session})
      : _session = session ?? CalculatrixSession() {
    _syncPresentation();
  }

  final CalculatrixSession _session;
  CalculatorMode _mode = CalculatorMode.infix;
  CalculatorMode _lastNonMatrixMode = CalculatorMode.infix;
  String _result = '';
  String _error = '';
  Matrix? _displayMatrix;

  CalculatorMode get mode => _mode;

  /// The current expression being composed.
  String get expression => _session.expression;

  /// The computed result (empty until equals is pressed).
  String get result => _result;

  /// Error message if evaluation failed (empty otherwise).
  String get error => _error;

  Matrix? get displayMatrix => _displayMatrix;

  /// Whether memory contains a non-zero value.
  bool get hasMemory => _session.hasMemory;

  bool get isRpnMode => mode == CalculatorMode.rpn;

  bool get isMatrixMode => mode == CalculatorMode.matrix;

  bool get isRpnEntryMode => _session.mode == CalculatrixMode.rpn;

  int get rpnStackDepth => _session.rpnStackDepth;

  List<String> get rpnStackLiterals => _session.rpnStackLiterals;

  String get rpnTopLiteral => _session.rpnTopLiteral;

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

    _mutate(() {
      _mode = mode;
      if (mode == CalculatorMode.matrix) {
        return;
      }

      _lastNonMatrixMode = mode;
      _session.setMode(
        mode == CalculatorMode.rpn
            ? CalculatrixMode.rpn
            : CalculatrixMode.infix,
      );
    });
  }

  void exitMatrixMode() {
    if (_mode != CalculatorMode.matrix) {
      return;
    }

    setMode(_lastNonMatrixMode);
  }

  void insertMatrixLiteral(String literal) {
    _mutate(() => _session.insertMatrixLiteral(literal));
  }

  /// Appends a character (digit, operator, paren) to the expression.
  void input(String value) {
    _mutate(() => _session.input(value));
  }

  /// Evaluates the current expression.
  void evaluate() {
    _mutate(_session.evaluate);
  }

  /// Clears the entire expression and result.
  void clear() {
    _mutate(_session.clear);
  }

  /// Deletes the last character from the expression.
  void backspace() {
    _mutate(_session.backspace);
  }

  /// Toggles the sign of the current value.
  void toggleSign() {
    _mutate(_session.toggleSign);
  }

  /// Clears memory.
  void memoryClear() {
    _mutate(_session.memoryClear);
  }

  /// Recalls memory value into expression.
  void memoryRecall() {
    _mutate(_session.memoryRecall);
  }

  /// Adds current display value to memory.
  void memoryAdd() {
    _mutate(_session.memoryAdd);
  }

  /// Subtracts current display value from memory.
  void memorySubtract() {
    _mutate(_session.memorySubtract);
  }

  void enter() {
    _mutate(_session.enter);
  }

  void applyRpnBinary(RpnBinaryOperator operator) {
    _mutate(() => _session.applyRpnBinary(operator));
  }

  void applyRpnUnary(RpnUnaryOperator operator) {
    _mutate(() => _session.applyRpnUnary(operator));
  }

  void dupRpn() {
    _mutate(_session.dupRpn);
  }

  void dropRpn() {
    _mutate(_session.dropRpn);
  }

  void swapRpn() {
    _mutate(_session.swapRpn);
  }

  void overRpn() {
    _mutate(_session.overRpn);
  }

  void rotRpn() {
    _mutate(_session.rotRpn);
  }

  void executeRpnCommand(CalculatrixCommand command) {
    _mutate(() => _session.executeCommand(command));
  }

  void executeRpnMacro(CalculatrixMacro macro) {
    _mutate(() => _session.executeMacro(macro));
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

  void _mutate(void Function() action) {
    action();
    if (_session.hasError) {
      debugPrint('Eval error: ${_session.lastError}');
    }
    _syncPresentation();
    notifyListeners();
  }

  void _syncPresentation() {
    if (_session.hasError) {
      _error = 'Error';
      _result = '';
      _displayMatrix = null;
      return;
    }

    _error = '';

    if (_session.expression.isNotEmpty) {
      _result = '';
      _displayMatrix = null;
      return;
    }

    final Matrix? currentValue = _session.currentValue;
    if (currentValue == null) {
      _result = '';
      _displayMatrix = null;
      return;
    }

    if (_session.mode == CalculatrixMode.rpn) {
      _displayMatrix = currentValue;
      _result = _session.rpnTopLiteral;
      return;
    }

    _displayMatrix = currentValue.isScalar ? null : currentValue;
    _result = currentValue.isScalar
        ? _formatResult(currentValue.scalarValue)
        : MatrixDisplayFormatter.compact(currentValue);
  }
}
