import 'package:flutter/material.dart';
import '../controllers/calculator_controller.dart';

/// The main calculator screen.
///
/// Displays the current expression and provides a minimal placeholder UI.
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
                  child: Semantics(
                    label: 'Display: ${_controller.display}',
                    child: Text(
                      _controller.display,
                      style: Theme.of(context).textTheme.displayMedium,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ),
              // Minimal keypad placeholder for v0.1.0
              Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  label: 'Calculator keypad',
                  child: const Text(
                    'Keypad coming in v0.3.0',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
