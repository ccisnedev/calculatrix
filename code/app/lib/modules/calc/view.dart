import 'dart:math' as math;

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

class _KeypadPageDef {
  final String title;
  final List<_ButtonDef> buttons;

  const _KeypadPageDef(this.title, this.buttons);
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
  final PageController _pageController = PageController();

  static const int _columnCount = 4;
  static const int _rowCount = 6;
  static const double _shellMaxWidth = 420;
  static const double _displayFraction = 0.38196601125;
  static const double _pagePadding = 12;
  static const double _gridSpacing = 8;
  static const double _pageHeaderHeight = 28;
  static const double _pageIndicatorHeight = 20;

  int _currentPage = 0;

  static const _primaryButtons = [
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

  static const _editingButtons = [
    _ButtonDef('(', _ButtonCategory.function),
    _ButtonDef(')', _ButtonCategory.function),
    _ButtonDef('⌫', _ButtonCategory.function),
    _ButtonDef('C', _ButtonCategory.function),
    _ButtonDef('7', _ButtonCategory.number),
    _ButtonDef('8', _ButtonCategory.number),
    _ButtonDef('9', _ButtonCategory.number),
    _ButtonDef('÷', _ButtonCategory.operator),
    _ButtonDef('4', _ButtonCategory.number),
    _ButtonDef('5', _ButtonCategory.number),
    _ButtonDef('6', _ButtonCategory.number),
    _ButtonDef('×', _ButtonCategory.operator),
    _ButtonDef('1', _ButtonCategory.number),
    _ButtonDef('2', _ButtonCategory.number),
    _ButtonDef('3', _ButtonCategory.number),
    _ButtonDef('-', _ButtonCategory.operator),
    _ButtonDef('±', _ButtonCategory.function),
    _ButtonDef('0', _ButtonCategory.number),
    _ButtonDef('.', _ButtonCategory.number),
    _ButtonDef('+', _ButtonCategory.operator),
    _ButtonDef('MC', _ButtonCategory.function),
    _ButtonDef('MR', _ButtonCategory.function),
    _ButtonDef('M-', _ButtonCategory.function),
    _ButtonDef('M+', _ButtonCategory.function),
  ];

  static const List<_KeypadPageDef> _infixPages = <_KeypadPageDef>[
    _KeypadPageDef('Primary', _primaryButtons),
    _KeypadPageDef('Edit', _editingButtons),
  ];

  @override
  void dispose() {
    _pageController.dispose();
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
            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double shellWidth = math.min(
                  constraints.maxWidth,
                  _shellMaxWidth,
                );
                final double displayHeight = constraints.maxHeight *
                    _displayFraction;
                final double keypadHeight =
                    constraints.maxHeight - displayHeight;

                return Center(
                  child: SizedBox(
                    width: shellWidth,
                    child: Column(
                      children: [
                        SizedBox(
                          height: displayHeight,
                          child: _buildDisplay(),
                        ),
                        SizedBox(
                          height: keypadHeight,
                          child: _buildKeypad(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModeSwitch(),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          // Expression line
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                const Spacer(),
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
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    final List<_KeypadPageDef> pages = _pagesForMode(_controller.mode);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableWidth = constraints.maxWidth - (_pagePadding * 2);
        final double availableHeight = constraints.maxHeight -
            (_pagePadding * 2) -
            _pageHeaderHeight -
            _pageIndicatorHeight;
        final double keyWidth =
            (availableWidth - (_gridSpacing * (_columnCount - 1))) /
                _columnCount;
        final double keyHeight =
            (availableHeight - (_gridSpacing * (_rowCount - 1))) / _rowCount;
        final double keySize = math.max(32, math.min(keyWidth, keyHeight));

        return Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _pageHeaderHeight,
                child: Center(
                  child: Text(
                    pages[_currentPage].title,
                    style: const TextStyle(
                      color: Color(0xFF8A8FA3),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemBuilder: (BuildContext context, int index) {
                    return _buildKeypadPage(
                      page: pages[index],
                      keySize: keySize,
                    );
                  },
                ),
              ),
              SizedBox(
                height: _pageIndicatorHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: i == _currentPage ? 20 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? const Color(0xFF4FC3F7)
                              : const Color(0xFF2D2D44),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeypadPage({
    required _KeypadPageDef page,
    required double keySize,
  }) {
    final List<List<_ButtonDef>> rows = <List<_ButtonDef>>[];
    for (int i = 0; i < page.buttons.length; i += _columnCount) {
      rows.add(page.buttons.sublist(i, i + _columnCount));
    }

    final double gridWidth =
        (keySize * _columnCount) + (_gridSpacing * (_columnCount - 1));
    final double gridHeight =
        (keySize * _rowCount) + (_gridSpacing * (_rowCount - 1));

    return Center(
      child: SizedBox(
        width: gridWidth,
        height: gridHeight,
        child: Column(
          children: [
            for (int rowIndex = 0; rowIndex < rows.length; rowIndex++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: rowIndex < rows.length - 1 ? _gridSpacing : 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < rows[rowIndex].length; i++) ...[
                      _buildButton(rows[rowIndex][i], keySize),
                      if (i < rows[rowIndex].length - 1)
                        const SizedBox(width: _gridSpacing),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(_ButtonDef btn, double keySize) {
    final colors = _getButtonColors(btn.category);
    final semanticName = _semanticLabel(btn.label);
    return SizedBox.square(
      dimension: keySize,
      child: Tooltip(
        message: semanticName,
        child: Material(
          key: ValueKey<String>('calculator-button-${btn.label}'),
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

  List<_KeypadPageDef> _pagesForMode(CalculatorMode mode) {
    return _infixPages;
  }

  Widget _buildModeSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2940),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              mode: CalculatorMode.infix,
              label: 'Infix',
            ),
          ),
          Expanded(
            child: _buildModeButton(
              mode: CalculatorMode.rpn,
              label: 'RPN',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required CalculatorMode mode,
    required String label,
  }) {
    final bool selected = _controller.mode == mode;
    return Semantics(
      label: '$label mode',
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          _controller.setMode(mode);
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
          setState(() {
            _currentPage = 0;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4FC3F7) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? const Color(0xFF16213E) : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
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
