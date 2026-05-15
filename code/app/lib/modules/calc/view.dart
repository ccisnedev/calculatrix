import 'package:flutter/material.dart';
import 'controller.dart';

/// Button category for visual differentiation.
enum _ButtonCategory { number, operator, function, equals }

/// Definition of a calculator button.
class _ButtonDef {
  final String label;
  final _ButtonCategory category;

  const _ButtonDef(this.label, this.category);
}

/// The Casio HL-820LV inspired calculator layout.
///
/// 5 rows × 4 columns grid with expression + result display.
class CalculatorView extends StatefulWidget {
  const CalculatorView({super.key});

  @override
  State<CalculatorView> createState() => _CalculatorViewState();
}

class _CalculatorViewState extends State<CalculatorView> {
  final _controller = CalculatorController();

  static const _buttons = [
    // Row 1: memory keys
    _ButtonDef('MC', _ButtonCategory.function),
    _ButtonDef('MR', _ButtonCategory.function),
    _ButtonDef('M-', _ButtonCategory.function),
    _ButtonDef('M+', _ButtonCategory.function),
    // Row 2: function keys
    _ButtonDef('C', _ButtonCategory.function),
    _ButtonDef('√', _ButtonCategory.function),
    _ButtonDef('%', _ButtonCategory.function),
    _ButtonDef('÷', _ButtonCategory.operator),
    // Row 3
    _ButtonDef('7', _ButtonCategory.number),
    _ButtonDef('8', _ButtonCategory.number),
    _ButtonDef('9', _ButtonCategory.number),
    _ButtonDef('×', _ButtonCategory.operator),
    // Row 4
    _ButtonDef('4', _ButtonCategory.number),
    _ButtonDef('5', _ButtonCategory.number),
    _ButtonDef('6', _ButtonCategory.number),
    _ButtonDef('-', _ButtonCategory.operator),
    // Row 5
    _ButtonDef('1', _ButtonCategory.number),
    _ButtonDef('2', _ButtonCategory.number),
    _ButtonDef('3', _ButtonCategory.number),
    _ButtonDef('+', _ButtonCategory.operator),
    // Row 6
    _ButtonDef('±', _ButtonCategory.function),
    _ButtonDef('0', _ButtonCategory.number),
    _ButtonDef('.', _ButtonCategory.number),
    _ButtonDef('=', _ButtonCategory.equals),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
              children: [
                // Display area
                _buildDisplay(context),
                // Keypad
                Expanded(
                  child: _buildKeypad(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDisplay(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Indicators row
          Row(
            children: [
              if (_controller.hasMemory)
                Semantics(
                  label: 'Memory indicator',
                  child: const Text(
                    'M',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4FC3F7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 4),
          // Expression line
          Semantics(
            label: 'Expression: ${_controller.expression}',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Text(
                _controller.expression.isEmpty
                    ? ' '
                    : _controller.expression,
                style: const TextStyle(
                  fontSize: 20,
                  color: Color(0xFF8A8FA3),
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Result line
          Semantics(
            label: 'Display: ${_controller.display}',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Text(
                _controller.display,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    // 5 rows of 4 buttons each
    final rows = <List<_ButtonDef>>[];
    for (var i = 0; i < _buttons.length; i += 4) {
      rows.add(_buttons.sublist(i, i + 4));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          for (final row in rows)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    for (final btn in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildButton(btn),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButton(_ButtonDef btn) {
    final colors = _getButtonColors(btn.category);
    final semanticName = _semanticLabel(btn.label);
    return Tooltip(
      message: semanticName,
      child: Material(
        color: colors.$1,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: colors.$2.withAlpha(50),
          highlightColor: colors.$2.withAlpha(30),
          onTap: () => _onButtonPressed(btn.label),
          child: Center(
            child: Text(
              btn.label,
              style: TextStyle(
                fontSize: btn.label.length > 1 ? 18 : 28,
                fontWeight: FontWeight.w500,
                color: colors.$2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  (Color background, Color foreground) _getButtonColors(
      _ButtonCategory category) {
    return switch (category) {
      _ButtonCategory.number => (const Color(0xFF1F2940), Colors.white),
      _ButtonCategory.operator => (const Color(0xFF0F3460), const Color(0xFF4FC3F7)),
      _ButtonCategory.function => (const Color(0xFF2D2D44), const Color(0xFFADB5BD)),
      _ButtonCategory.equals => (const Color(0xFF533483), Colors.white),
    };
  }

  void _onButtonPressed(String label) {
    switch (label) {
      case 'C':
        _controller.clear();
      case '⌫':
        _controller.backspace();
      case '=':
        _controller.evaluate();
      case '±':
        _controller.toggleSign();
      case 'MC':
        _controller.memoryClear();
      case 'MR':
        _controller.memoryRecall();
      case 'M+':
        _controller.memoryAdd();
      case 'M-':
        _controller.memorySubtract();
      default:
        _controller.input(label);
    }
  }

  String _semanticLabel(String label) {
    return switch (label) {
      'C' => 'Clear',
      '⌫' => 'Backspace',
      '=' => 'Equals',
      '+' => 'Plus',
      '-' => 'Minus',
      '×' => 'Multiply',
      '÷' => 'Divide',
      '(' => 'Left parenthesis',
      ')' => 'Right parenthesis',
      '.' => 'Decimal point',
      '√' => 'Square root',
      '%' => 'Percent',
      '±' => 'Toggle sign',
      'MC' => 'Memory clear',
      'MR' => 'Memory recall',
      'M+' => 'Memory add',
      'M-' => 'Memory subtract',
      _ => label,
    };
  }
}
