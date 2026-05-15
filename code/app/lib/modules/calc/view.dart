import 'package:flutter/material.dart';
import 'controller.dart';

/// The main calculator screen.
///
/// Displays the expression and result, with a minimal keypad for v0.2.0 testing.
/// Full Casio layout will be implemented in v0.3.0.
class CalculatorView extends StatefulWidget {
  const CalculatorView({super.key});

  @override
  State<CalculatorView> createState() => _CalculatorViewState();
}

class _CalculatorViewState extends State<CalculatorView> {
  final _controller = CalculatorController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'Calculatrix',
          child: const Text('Calculatrix'),
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              // Display area
              Expanded(
                child: Container(
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Expression line
                      Semantics(
                        label: 'Expression: ${_controller.expression}',
                        child: Text(
                          _controller.expression.isEmpty
                              ? ' '
                              : _controller.expression,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.grey),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Result / display line
                      Semantics(
                        label: 'Display: ${_controller.display}',
                        child: Text(
                          _controller.display,
                          style: Theme.of(context).textTheme.displayMedium,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Minimal keypad for v0.2.0 functional testing
              Padding(
                padding: const EdgeInsets.all(8),
                child: Semantics(
                  label: 'Calculator keypad',
                  container: true,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final label in [
                        'C', '(', ')', '÷',
                        '7', '8', '9', '×',
                        '4', '5', '6', '-',
                        '1', '2', '3', '+',
                        '⌫', '0', '.', '=',
                      ])
                        _buildButton(label),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildButton(String label) {
    return Semantics(
      button: true,
      label: _semanticLabel(label),
      child: SizedBox(
        width: 72,
        height: 56,
        child: ElevatedButton(
          onPressed: () => _onButtonPressed(label),
          child: Text(label, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }

  void _onButtonPressed(String label) {
    switch (label) {
      case 'C':
        _controller.clear();
      case '⌫':
        _controller.backspace();
      case '=':
        _controller.evaluate();
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
      _ => label,
    };
  }
}
