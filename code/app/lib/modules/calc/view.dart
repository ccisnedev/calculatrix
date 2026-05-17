import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controller.dart';
import 'matrix_editor_draft.dart';

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

class _RpnStackSlot {
  final int register;
  final String? literal;

  const _RpnStackSlot({required this.register, this.literal});
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
  final PageController _pageController = PageController(keepPage: false);

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

  static const _rpnPrimaryButtons = [
    _ButtonDef('MC', _ButtonCategory.function),
    _ButtonDef('MR', _ButtonCategory.function),
    _ButtonDef('M-', _ButtonCategory.function),
    _ButtonDef('M+', _ButtonCategory.function),
    _ButtonDef('C', _ButtonCategory.function),
    _ButtonDef('√', _ButtonCategory.function),
    _ButtonDef('%', _ButtonCategory.function),
    _ButtonDef('÷', _ButtonCategory.operator),
    _ButtonDef('7', _ButtonCategory.number),
    _ButtonDef('8', _ButtonCategory.number),
    _ButtonDef('9', _ButtonCategory.number),
    _ButtonDef('×', _ButtonCategory.operator),
    _ButtonDef('4', _ButtonCategory.number),
    _ButtonDef('5', _ButtonCategory.number),
    _ButtonDef('6', _ButtonCategory.number),
    _ButtonDef('-', _ButtonCategory.operator),
    _ButtonDef('1', _ButtonCategory.number),
    _ButtonDef('2', _ButtonCategory.number),
    _ButtonDef('3', _ButtonCategory.number),
    _ButtonDef('+', _ButtonCategory.operator),
    _ButtonDef('±', _ButtonCategory.function),
    _ButtonDef('0', _ButtonCategory.number),
    _ButtonDef('.', _ButtonCategory.number),
    _ButtonDef('ENTER', _ButtonCategory.equals),
  ];

  static const _editingButtons = [
    _ButtonDef('MAT', _ButtonCategory.function),
    _ButtonDef('(', _ButtonCategory.function),
    _ButtonDef(')', _ButtonCategory.function),
    _ButtonDef('⌫', _ButtonCategory.function),
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
    _ButtonDef('C', _ButtonCategory.function),
    _ButtonDef('MC', _ButtonCategory.function),
    _ButtonDef('MR', _ButtonCategory.function),
    _ButtonDef('M+', _ButtonCategory.function),
  ];

  static const List<_KeypadPageDef> _infixPages = <_KeypadPageDef>[
    _KeypadPageDef('Primary', _primaryButtons),
    _KeypadPageDef('Edit', _editingButtons),
  ];

  static const List<_KeypadPageDef> _rpnPages = <_KeypadPageDef>[
    _KeypadPageDef('RPN Entry', _rpnPrimaryButtons),
    _KeypadPageDef('RPN Stack', <_ButtonDef>[
      _ButtonDef('MAT', _ButtonCategory.function),
      _ButtonDef('DUP', _ButtonCategory.function),
      _ButtonDef('DROP', _ButtonCategory.function),
      _ButtonDef('SWAP', _ButtonCategory.function),
      _ButtonDef('OVER', _ButtonCategory.function),
      _ButtonDef('ROT', _ButtonCategory.function),
      _ButtonDef('√', _ButtonCategory.function),
      _ButtonDef('%', _ButtonCategory.function),
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
    ]),
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
              if (_controller.isRpnMode)
                Semantics(
                  label: 'Stack depth: ${_controller.rpnStackDepth}',
                  child: Text(
                    key: const ValueKey<String>('calculator-stack-depth'),
                    'Stack ${_controller.rpnStackDepth}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4FC3F7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _controller.isRpnMode
                ? _buildRpnDisplayBody()
                : _buildInfixDisplayBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfixDisplayBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Semantics(
          label: 'Expression: ${_controller.expression}',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              key: const ValueKey<String>('calculator-expression-text'),
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
        Expanded(child: _buildDisplayValue(fontSize: 40)),
      ],
    );
  }

  Widget _buildRpnDisplayBody() {
    final List<_RpnStackSlot> slots = _buildRpnDisplaySlots();
    final List<_RpnStackSlot> visualOrder = slots.reversed.toList(growable: false);

    return SingleChildScrollView(
      reverse: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int index = 0; index < visualOrder.length; index++) ...[
            _buildRpnStackCard(visualOrder[index]),
            if (index < visualOrder.length - 1) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  List<_RpnStackSlot> _buildRpnDisplaySlots() {
    final bool overlaysCommittedTop =
        _controller.expression.isNotEmpty || _controller.error.isNotEmpty;
    final Iterable<String> stackedLiterals = overlaysCommittedTop
        ? _controller.rpnStackLiterals
        : _controller.rpnStackLiterals.skip(1);
    final List<_RpnStackSlot> slots = <_RpnStackSlot>[
      const _RpnStackSlot(register: 0),
    ];

    int register = 1;
    for (final String literal in stackedLiterals) {
      slots.add(_RpnStackSlot(register: register, literal: literal));
      register += 1;
    }

    return slots;
  }

  Widget _buildRpnStackCard(_RpnStackSlot slot) {
    final bool isPrimary = slot.register == 0;

    return AnimatedContainer(
      key: ValueKey<String>('rpn-stack-card-${slot.register}'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      constraints: BoxConstraints(minHeight: isPrimary ? 72 : 44),
      padding: EdgeInsets.all(isPrimary ? 12 : 8),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF1F2940) : const Color(0xFF18243A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary
              ? const Color(0xFF4FC3F7).withAlpha(80)
              : const Color(0xFF2D2D44),
        ),
      ),
      child: isPrimary
          ? _buildPrimaryRpnStackCard()
          : _buildSecondaryRpnStackCard(slot),
    );
  }

  Widget _buildPrimaryRpnStackCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'X0',
          style: TextStyle(
            color: Color(0xFF4FC3F7),
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 8),
        _buildDisplayValue(fontSize: 28),
      ],
    );
  }

  Widget _buildSecondaryRpnStackCard(_RpnStackSlot slot) {
    final String literal = slot.literal!;

    return Semantics(
      container: true,
      label: 'Stack item ${slot.register}: $literal',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Text(
              'X${slot.register}',
              style: const TextStyle(
                color: Color(0xFF4FC3F7),
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                literal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayValue({required double fontSize}) {
    final Matrix? matrix = _controller.displayMatrix;
    final bool showMatrix = matrix != null &&
        !matrix.isScalar &&
        _controller.error.isEmpty &&
        _controller.expression.isEmpty &&
        _controller.result.isNotEmpty;

    if (!showMatrix) {
      return Align(
        alignment: Alignment.centerRight,
        child: Semantics(
          label: 'Display: ${_controller.display}',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              key: const ValueKey<String>('calculator-display-text'),
              _controller.display,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useExpanded = constraints.maxWidth >= 240 &&
            matrix.rowCount <= 4 &&
            matrix.columnCount <= 4;
        final String semanticValue = MatrixDisplayFormatter.compact(matrix);
        final String visualValue = useExpanded
            ? MatrixDisplayFormatter.expanded(matrix)
            : semanticValue;

        return Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            label:
                'Display: $semanticValue. Matrix ${matrix.rowCount} by ${matrix.columnCount}',
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: !useExpanded,
                child: Text(
                  key: const ValueKey<String>('calculator-display-text'),
                  visualValue,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: useExpanded ? fontSize * 0.78 : fontSize,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
    return mode == CalculatorMode.rpn ? _rpnPages : _infixPages;
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
    if (_controller.isRpnMode) {
      switch (label) {
        case 'MAT':
          _openMatrixEditor();
        case 'C':
          _controller.clear();
        case '⌫':
          _controller.backspace();
        case 'ENTER':
          _controller.enter();
        case '+':
          _controller.applyRpnBinary(RpnBinaryOperator.add);
        case '-':
          _controller.applyRpnBinary(RpnBinaryOperator.subtract);
        case '×':
          _controller.applyRpnBinary(RpnBinaryOperator.multiply);
        case '÷':
          _controller.applyRpnBinary(RpnBinaryOperator.divide);
        case '√':
          _controller.applyRpnUnary(RpnUnaryOperator.sqrt);
        case '%':
          _controller.applyRpnUnary(RpnUnaryOperator.percent);
        case 'DUP':
          _controller.dupRpn();
        case 'DROP':
          _controller.dropRpn();
        case 'SWAP':
          _controller.swapRpn();
        case 'OVER':
          _controller.overRpn();
        case 'ROT':
          _controller.rotRpn();
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
      return;
    }

    switch (label) {
      case 'MAT':
        _openMatrixEditor();
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
      'MAT' => 'Matrix editor',
      'C' => 'Clear',
      '⌫' => 'Backspace',
      '=' => 'Equals',
      'ENTER' => 'Enter',
      '+' => 'Plus',
      '-' => 'Minus',
      '×' => 'Multiply',
      '÷' => 'Divide',
      '(' => 'Left parenthesis',
      ')' => 'Right parenthesis',
      'DUP' => 'Duplicate top',
      'DROP' => 'Drop top',
      'SWAP' => 'Swap top two',
      'OVER' => 'Copy second to top',
      'ROT' => 'Rotate top three',
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

  Future<void> _openMatrixEditor() async {
    final String? literal = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return _MatrixEditorDialog(isRpnMode: _controller.isRpnMode);
      },
    );

    if (!mounted || literal == null) {
      return;
    }

    _controller.insertMatrixLiteral(literal);
  }
}

class _MatrixEditorDialog extends StatefulWidget {
  const _MatrixEditorDialog({required this.isRpnMode});

  final bool isRpnMode;

  @override
  State<_MatrixEditorDialog> createState() => _MatrixEditorDialogState();
}

class _MatrixEditorDialogState extends State<_MatrixEditorDialog> {
  final MatrixEditorDraft _draft = MatrixEditorDraft();
  String? _error;
  late List<List<TextEditingController>> _controllers;
  late List<List<FocusNode>> _focusNodes;
  int _selectedRow = 0;
  int _selectedColumn = 0;
  int? _editingRow;
  int? _editingColumn;
  String? _editingStartValue;

  static const List<int> _supportedOrders = <int>[2, 3, 4];

  @override
  void initState() {
    super.initState();
    _controllers = _buildControllers();
    _focusNodes = _buildFocusNodes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _requestCellFocus(_selectedRow, _selectedColumn);
    });
  }

  @override
  void dispose() {
    _disposeControllers();
    _disposeFocusNodes();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Matrix editor'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _supportedOrders.map((int order) {
                  final bool isSelected =
                      _draft.rowCount == order && _draft.columnCount == order;
                  return ChoiceChip(
                    label: Text('${order}x$order'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _draft.setOrder(order);
                        _resetEditingState();
                        _rebuildInputs();
                        _error = null;
                      });
                    },
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _resetEditingState();
                        _draft.fillZeros();
                        _syncControllersFromDraft();
                        _error = null;
                      });
                    },
                    child: const Text('Zeros'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _resetEditingState();
                        _draft.fillIdentity();
                        _syncControllersFromDraft();
                        _error = null;
                      });
                    },
                    child: const Text('Identity'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _resetEditingState();
                        _draft.clearVisible();
                        _syncControllersFromDraft();
                        _error = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CallbackShortcuts(
                bindings: _shortcutBindings(),
                child: _buildMatrixGrid(),
              ),
              const SizedBox(height: 12),
              Text(
                _buildPreviewText(),
                key: const ValueKey<String>('matrix-preview-text'),
                style: const TextStyle(color: Color(0xFFCFD8DC)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFE57373)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isRpnMode ? 'Push' : 'Insert'),
        ),
      ],
    );
  }

  Widget _buildMatrixGrid() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            '[',
            style: TextStyle(fontSize: 48, height: 1),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int row = 0; row < _draft.rowCount; row++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: row < _draft.rowCount - 1 ? 8 : 0,
                  ),
                  child: Row(
                    children: [
                      for (int column = 0; column < _draft.columnCount; column++) ...[
                        Expanded(
                          child: TextFormField(
                            key: ValueKey<String>('matrix-cell-$row-$column'),
                            controller: _controllers[row][column],
                            focusNode: _focusNodes[row][column],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            readOnly: !_isEditingCell(row, column),
                            showCursor: _isEditingCell(row, column),
                            textInputAction: _isLastVisibleCell(row, column)
                                ? TextInputAction.done
                                : TextInputAction.next,
                            textAlign: TextAlign.end,
                            decoration: InputDecoration(
                              isDense: true,
                              border: const OutlineInputBorder(),
                              labelText: 'r${row + 1}c${column + 1}',
                            ),
                            onTap: () {
                              _beginEditingCell(row, column);
                            },
                            onChanged: (String value) {
                              setState(() {
                                _draft.setCell(row, column, value);
                                _error = null;
                              });
                            },
                            onFieldSubmitted: (_) {
                              if (_isEditingCell(row, column)) {
                                _finishEditing();
                              }
                            },
                          ),
                        ),
                        if (column < _draft.columnCount - 1)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            ']',
            style: TextStyle(fontSize: 48, height: 1),
          ),
        ),
      ],
    );
  }

  List<List<TextEditingController>> _buildControllers() {
    return List<List<TextEditingController>>.generate(
      _draft.rowCount,
      (int row) => List<TextEditingController>.generate(
        _draft.columnCount,
        (int column) => TextEditingController(
          text: _draft.cellValue(row, column),
        ),
        growable: false,
      ),
      growable: false,
    );
  }

  List<List<FocusNode>> _buildFocusNodes() {
    return List<List<FocusNode>>.generate(
      _draft.rowCount,
      (int row) => List<FocusNode>.generate(
        _draft.columnCount,
        (int column) {
          final FocusNode node = FocusNode(
            debugLabel: 'matrix-cell-$row-$column',
          );
          node.addListener(() {
            if (!mounted || !node.hasFocus) {
              return;
            }

            if (_selectedRow == row && _selectedColumn == column) {
              return;
            }

            setState(() {
              _selectedRow = row;
              _selectedColumn = column;
            });
          });
          return node;
        },
        growable: false,
      ),
      growable: false,
    );
  }

  void _disposeControllers() {
    for (final List<TextEditingController> row in _controllers) {
      for (final TextEditingController controller in row) {
        controller.dispose();
      }
    }
  }

  void _disposeFocusNodes() {
    for (final List<FocusNode> row in _focusNodes) {
      for (final FocusNode focusNode in row) {
        focusNode.dispose();
      }
    }
  }

  void _rebuildInputs() {
    _disposeControllers();
    _disposeFocusNodes();
    _controllers = _buildControllers();
    _focusNodes = _buildFocusNodes();
    _selectedRow = _clampIndex(_selectedRow, _draft.rowCount - 1);
    _selectedColumn = _clampIndex(_selectedColumn, _draft.columnCount - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _requestCellFocus(_selectedRow, _selectedColumn);
    });
  }

  void _syncControllersFromDraft() {
    for (int row = 0; row < _draft.rowCount; row++) {
      for (int column = 0; column < _draft.columnCount; column++) {
        _controllers[row][column].text = _draft.cellValue(row, column);
      }
    }
  }

  void _syncDraftFromControllers() {
    for (int row = 0; row < _draft.rowCount; row++) {
      for (int column = 0; column < _draft.columnCount; column++) {
        _draft.setCell(row, column, _controllers[row][column].text);
      }
    }
  }

  String _buildPreviewText() {
    _syncDraftFromControllers();
    final String? error = _draft.validationError();
    if (error != null) {
      return 'Preview unavailable until valid';
    }

    return 'Preview: ${_draft.buildLiteral()}';
  }

  bool _isEditingCell(int row, int column) {
    return _editingRow == row && _editingColumn == column;
  }

  bool get _isEditing => _editingRow != null && _editingColumn != null;

  bool _isLastVisibleCell(int row, int column) {
    return row == _draft.rowCount - 1 && column == _draft.columnCount - 1;
  }

  Map<ShortcutActivator, VoidCallback> _shortcutBindings() {
    if (_isEditing) {
      return <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _cancelEditing,
        const SingleActivator(LogicalKeyboardKey.tab): _commitAndMoveNext,
        const SingleActivator(LogicalKeyboardKey.tab, shift: true):
            _commitAndMovePrevious,
      };
    }

    return <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.arrowLeft):
          () => _moveSelection(rowDelta: 0, columnDelta: -1),
      const SingleActivator(LogicalKeyboardKey.arrowRight):
          () => _moveSelection(rowDelta: 0, columnDelta: 1),
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          () => _moveSelection(rowDelta: -1, columnDelta: 0),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          () => _moveSelection(rowDelta: 1, columnDelta: 0),
      const SingleActivator(LogicalKeyboardKey.enter): _beginEditingSelectedCell,
      const SingleActivator(LogicalKeyboardKey.numpadEnter):
          _beginEditingSelectedCell,
    };
  }

  void _moveSelection({required int rowDelta, required int columnDelta}) {
    final int nextRow = _clampIndex(
      _selectedRow + rowDelta,
      _draft.rowCount - 1,
    );
    final int nextColumn = _clampIndex(
      _selectedColumn + columnDelta,
      _draft.columnCount - 1,
    );
    _requestCellFocus(nextRow, nextColumn);
  }

  void _beginEditingSelectedCell() {
    _beginEditingCell(_selectedRow, _selectedColumn);
  }

  void _beginEditingCell(int row, int column) {
    if (_isEditingCell(row, column)) {
      _requestCellFocus(row, column, selectAll: true);
      return;
    }

    setState(() {
      _selectedRow = row;
      _selectedColumn = column;
      _editingRow = row;
      _editingColumn = column;
      _editingStartValue = _draft.cellValue(row, column);
      _error = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _requestCellFocus(row, column, selectAll: true);
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  void _commitAndMoveNext() {
    _finishEditing(move: 1);
  }

  void _commitAndMovePrevious() {
    _finishEditing(move: -1);
  }

  void _cancelEditing() {
    if (!_isEditing) {
      return;
    }

    final int row = _editingRow!;
    final int column = _editingColumn!;
    final String originalValue = _editingStartValue ?? '';

    _controllers[row][column].text = originalValue;
    _draft.setCell(row, column, originalValue);

    setState(() {
      _resetEditingState();
      _error = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _requestCellFocus(row, column);
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    });
  }

  void _finishEditing({int move = 0}) {
    if (!_isEditing) {
      return;
    }

    final int row = _editingRow!;
    final int column = _editingColumn!;
    _draft.setCell(row, column, _controllers[row][column].text);

    final int nextIndex = _clampIndex(
      row * _draft.columnCount + column + move,
      _draft.rowCount * _draft.columnCount - 1,
    );
    final int nextRow = nextIndex ~/ _draft.columnCount;
    final int nextColumn = nextIndex % _draft.columnCount;

    setState(() {
      _selectedRow = nextRow;
      _selectedColumn = nextColumn;
      _resetEditingState();
      _error = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _requestCellFocus(nextRow, nextColumn);
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    });
  }

  void _resetEditingState() {
    _editingRow = null;
    _editingColumn = null;
    _editingStartValue = null;
  }

  void _requestCellFocus(int row, int column, {bool selectAll = false}) {
    _selectedRow = row;
    _selectedColumn = column;

    final FocusNode focusNode = _focusNodes[row][column];
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }

    final TextEditingController controller = _controllers[row][column];
    if (selectAll) {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      return;
    }

    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  int _clampIndex(int value, int upperBound) {
    return math.max(0, math.min(value, upperBound));
  }

  void _submit() {
    try {
      _syncDraftFromControllers();
      final String literal = _draft.buildLiteral();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      FocusScope.of(context).unfocus();
      Navigator.of(context).pop(literal);
    } on FormatException catch (error) {
      setState(() {
        _error = error.message;
      });
    }
  }
}
