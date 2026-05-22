import 'dart:async';

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
    _session.setMode(CalculatrixMode.rpn);
    _syncPresentation();
  }

  final CalculatrixSession _session;
  CalculatorMode _mode = CalculatorMode.rpn;
  String _result = '';
  String _error = '';
  Matrix? _displayMatrix;
  bool _mrcArmed = false;
  Timer? _infixMemoryStatusTimer;
  String? _transientInfixMemoryStatusText;
  String? _transientInfixMemoryStatusSemanticsText;

  static const Duration _infixMemoryStatusPreviewDuration = Duration(
    milliseconds: 900,
  );

  CalculatorMode get mode => _mode;

  /// The current expression being composed.
  String get expression => _session.expression;

  /// The computed result (empty until equals is pressed).
  String get result => _result;

  /// Error message if evaluation failed (empty otherwise).
  String get error => _error;

  Matrix? get displayMatrix => _displayMatrix;

  Matrix? get matrixEditorSeedMatrix {
    if (_error.isNotEmpty) {
      return null;
    }

    final String trimmed = expression.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('[[') || !trimmed.endsWith(']]')) {
      return null;
    }

    try {
      final Matrix matrix = Calculatrix.evaluateInfix(trimmed);
      if (matrix.rowCount > 4 || matrix.columnCount > 4) {
        return null;
      }

      return matrix;
    } on FormatException {
      return null;
    } on CalculatrixError {
      return null;
    }
  }

  /// Whether memory contains a non-zero value.
  bool get hasMemory => _session.hasMemory;

  String get infixMemoryStatusText {
    final String? transientStatus = _transientInfixMemoryStatusText;
    if (transientStatus != null) {
      return transientStatus;
    }

    final Matrix? memory = _session.memoryValue;
    if (memory == null) {
      return 'MEM: empty';
    }

    return 'MEM: ${_formatMemoryPreview(memory)}';
  }

  String get infixMemoryStatusSemanticsText {
    final String? transientStatus = _transientInfixMemoryStatusSemanticsText;
    if (transientStatus != null) {
      return transientStatus;
    }

    final Matrix? memory = _session.memoryValue;
    if (memory == null) {
      return 'Memory status: empty';
    }

    return 'Memory status: ${_formatMemoryPreview(memory)}';
  }

  bool get isRpnMode => mode == CalculatorMode.rpn;

  bool get isInfixMode => mode == CalculatorMode.infix;

  bool get isMatrixMode => mode == CalculatorMode.matrix;

  bool get isRpnEntryMode => _session.mode == CalculatrixMode.rpn;

  int get rpnStackDepth => _session.rpnStackDepth;

  List<String> get rpnStackLiterals => _session.rpnStackLiterals;

  String get rpnTopLiteral => _session.rpnTopLiteral;

  bool get hasDraftDisplay => _error.isNotEmpty || expression.isNotEmpty;

  bool get deleteWouldEditDraft =>
      isMatrixMode || isInfixMode || _error.isNotEmpty || expression.isNotEmpty;

  String get draftDisplay => _error.isNotEmpty ? _error : expression;

  String get committedRpnDisplay {
    final Matrix? currentValue = _session.currentValue;
    if (currentValue == null) {
      return '0';
    }

    return _session.rpnTopLiteral;
  }

  Matrix? get committedRpnDisplayMatrix {
    final Matrix? currentValue = _session.currentValue;
    if (currentValue == null || currentValue.isScalar) {
      return null;
    }

    return currentValue;
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

    _mutate(() {
      _mode = mode;
      switch (mode) {
        case CalculatorMode.rpn:
          _session.setMode(CalculatrixMode.rpn);
        case CalculatorMode.infix:
          _session.setMode(CalculatrixMode.infix);
        case CalculatorMode.matrix:
          return;
      }
    });
  }

  void openInfixEditor() {
    setMode(CalculatorMode.infix);
  }

  void openMatrixEditor() {
    setMode(CalculatorMode.matrix);
  }

  void cancelEditor() {
    if (_mode == CalculatorMode.rpn) {
      return;
    }

    setMode(CalculatorMode.rpn);
  }

  void exitMatrixMode() {
    if (_mode != CalculatorMode.matrix) {
      return;
    }

    cancelEditor();
  }

  void submitInfixEditor() {
    if (_mode != CalculatorMode.infix) {
      return;
    }

    _mutate(() {
      if (_session.expression.isNotEmpty) {
        _session.evaluate();
      }

      if (_session.hasError || _session.currentValue == null) {
        return;
      }

      _mode = CalculatorMode.rpn;
      _session.setMode(CalculatrixMode.rpn);
    });
  }

  void submitMatrixEditorLiteral(String literal) {
    _mutate(() {
      if (_session.mode != CalculatrixMode.rpn) {
        _session.setMode(CalculatrixMode.rpn);
      }

      _mode = CalculatorMode.rpn;
      _session.insertMatrixLiteral(literal);
    });
  }

  void submitMatrixEditorStackCommand(
    String literal,
    CalculatrixCommand command,
  ) {
    _mutate(() {
      if (_session.mode != CalculatrixMode.rpn) {
        _session.setMode(CalculatrixMode.rpn);
      }

      _mode = CalculatorMode.rpn;
      _session.insertMatrixLiteral(literal);
      _session.executeCommand(command);
    });
  }

  void insertMatrixLiteral(String literal) {
    _mutate(() => _session.insertMatrixLiteral(literal));
  }

  /// Inserts the imaginary unit J = [[0,-1],[1,0]] as a matrix literal.
  void insertImaginaryUnit() {
    insertMatrixLiteral('[[0,-1],[1,0]]');
  }

  /// Appends a character (digit, operator, paren) to the expression.
  void input(String value) {
    _mutate(() => _session.input(value));
  }

  /// Evaluates the current expression.
  void evaluate() {
    _mutate(_session.evaluate);
  }

  void revealCommittedRpnMatrixForm() {
    final Matrix? currentValue = _session.currentValue;
    if (!isRpnMode || currentValue == null || currentValue.isScalar) {
      return;
    }
  }

  /// Clears the entire expression and result.
  void clear() {
    _mutate(_session.clear);
  }

  void allClear() {
    _mutate(() {
      if (_session.mode == CalculatrixMode.infix) {
        _session.clear();
        _mode = CalculatorMode.rpn;
        _session.setMode(CalculatrixMode.rpn);
      }

      _session.clear();
      _session.clear();
      _session.memoryClear();
    });
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

  void memoryRecallClear() {
    _mutate(() {
      if (_mrcArmed) {
        _session.memoryClear();
        _mrcArmed = false;
        return;
      }

      _session.memoryRecall();
      _mrcArmed = true;
    }, resetMrcSequence: false);
  }

  /// Adds current display value to memory.
  void memoryAdd() {
    final _MemoryStatusPreview? preview = _buildMemoryStatusPreview('+');
    _mutate(() {
      _session.memoryAdd();
      if (!_session.hasError && preview != null) {
        _showTransientInfixMemoryStatus(preview);
      }
    }, clearTransientInfixMemoryStatus: preview == null);
  }

  /// Subtracts current display value from memory.
  void memorySubtract() {
    final _MemoryStatusPreview? preview = _buildMemoryStatusPreview('-');
    _mutate(() {
      _session.memorySubtract();
      if (!_session.hasError && preview != null) {
        _showTransientInfixMemoryStatus(preview);
      }
    }, clearTransientInfixMemoryStatus: preview == null);
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

  String _formatMemoryPreview(Matrix memory) {
    return _formatHonestValue(memory);
  }

  String _formatHonestValue(Matrix value) {
    if (value.isScalar) {
      return _formatResult(value.scalarValue);
    }

    return MatrixDisplayFormatter.compact(value);
  }

  _MemoryStatusPreview? _buildMemoryStatusPreview(String operatorSymbol) {
    if (!isInfixMode) {
      return null;
    }

    final Matrix? operand = _currentMemoryOperandForPreview();
    if (operand == null) {
      return null;
    }

    final Matrix? currentMemory = _session.memoryValue;
    final String leftOperand = currentMemory == null
        ? '0'
        : _formatMemoryPreview(currentMemory);
    final String rightOperand = _formatMemoryPreview(operand);
    final String operatorWord = operatorSymbol == '+' ? 'plus' : 'minus';

    return _MemoryStatusPreview(
      text: 'MEM: $leftOperand $operatorSymbol $rightOperand',
      semanticsText: 'Memory status: $leftOperand $operatorWord $rightOperand',
    );
  }

  Matrix? _currentMemoryOperandForPreview() {
    final String currentExpression = expression;
    if (currentExpression.isNotEmpty) {
      try {
        return Calculatrix.evaluateInfix(currentExpression);
      } on FormatException {
        return null;
      } on CalculatrixError {
        return null;
      }
    }

    return _session.currentValue;
  }

  void _showTransientInfixMemoryStatus(_MemoryStatusPreview preview) {
    _cancelInfixMemoryStatusPreview();
    _transientInfixMemoryStatusText = preview.text;
    _transientInfixMemoryStatusSemanticsText = preview.semanticsText;
    _infixMemoryStatusTimer = Timer(_infixMemoryStatusPreviewDuration, () {
      _transientInfixMemoryStatusText = null;
      _transientInfixMemoryStatusSemanticsText = null;
      notifyListeners();
    });
  }

  void _cancelInfixMemoryStatusPreview() {
    _infixMemoryStatusTimer?.cancel();
    _infixMemoryStatusTimer = null;
  }

  void _mutate(
    void Function() action, {
    bool resetMrcSequence = true,
    bool clearTransientInfixMemoryStatus = true,
  }) {
    if (resetMrcSequence) {
      _mrcArmed = false;
    }
    if (clearTransientInfixMemoryStatus) {
      _cancelInfixMemoryStatusPreview();
      _transientInfixMemoryStatusText = null;
      _transientInfixMemoryStatusSemanticsText = null;
    }

    action();
    if (_session.hasError) {
      debugPrint('Eval error: ${_session.lastError}');
    }
    _syncPresentation();
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelInfixMemoryStatusPreview();
    super.dispose();
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
      _displayMatrix = currentValue.isScalar ? null : currentValue;
      _result = currentValue.isScalar
        ? _formatResult(currentValue.scalarValue)
        : _session.rpnTopLiteral;
      return;
    }

    _displayMatrix = currentValue.isScalar ? null : currentValue;
    _result = currentValue.isScalar
        ? _formatResult(currentValue.scalarValue)
      : _formatHonestValue(currentValue);
  }
}

class _MemoryStatusPreview {
  const _MemoryStatusPreview({
    required this.text,
    required this.semanticsText,
  });

  final String text;
  final String semanticsText;
}
