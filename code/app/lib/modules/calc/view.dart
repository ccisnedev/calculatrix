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

enum _StructuralAxis { row, column }

class _StructuralDragData {
  const _StructuralDragData.row(this.index) : axis = _StructuralAxis.row;

  const _StructuralDragData.column(this.index)
    : axis = _StructuralAxis.column;

  final _StructuralAxis axis;
  final int index;
}

class _KeypadDeckDef {
  final String label;
  final List<_ButtonDef> buttons;

  const _KeypadDeckDef(this.label, this.buttons);
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
  final GlobalKey<_MatrixEditorDialogState> _matrixEditorKey =
      GlobalKey<_MatrixEditorDialogState>();

  static const int _columnCount = 5;
  static const int _rowCount = 6;
  static const double _shellMaxWidth = 480;
  static const double _displayFraction = 0.38196601125;
  static const double _pagePadding = 12;
  static const double _gridSpacing = 8;
  static const double _deckSelectorHeight = 48;

  String _infixDeckLabel = 'MAIN';
  String _rpnDeckLabel = 'MAIN';
  String _matrixDeckLabel = 'EDIT';

  static const List<_ButtonDef> _fixedBottomButtons = <_ButtonDef>[
    _ButtonDef('7', _ButtonCategory.number),
    _ButtonDef('8', _ButtonCategory.number),
    _ButtonDef('9', _ButtonCategory.number),
    _ButtonDef('÷', _ButtonCategory.operator),
    _ButtonDef('INV', _ButtonCategory.function),
    _ButtonDef('4', _ButtonCategory.number),
    _ButtonDef('5', _ButtonCategory.number),
    _ButtonDef('6', _ButtonCategory.number),
    _ButtonDef('×', _ButtonCategory.operator),
    _ButtonDef('√', _ButtonCategory.function),
    _ButtonDef('1', _ButtonCategory.number),
    _ButtonDef('2', _ButtonCategory.number),
    _ButtonDef('3', _ButtonCategory.number),
    _ButtonDef('-', _ButtonCategory.operator),
    _ButtonDef('⌫', _ButtonCategory.function),
    _ButtonDef('0', _ButtonCategory.number),
    _ButtonDef('.', _ButtonCategory.number),
    _ButtonDef('±', _ButtonCategory.function),
    _ButtonDef('+', _ButtonCategory.operator),
    _ButtonDef('ENTER', _ButtonCategory.equals),
  ];

  static const List<_KeypadDeckDef> _infixDecks = <_KeypadDeckDef>[
    _KeypadDeckDef('MAIN', <_ButtonDef>[
      _ButtonDef('MAT', _ButtonCategory.function),
      _ButtonDef('C', _ButtonCategory.function),
      _ButtonDef('%', _ButtonCategory.function),
      _ButtonDef('(', _ButtonCategory.function),
      _ButtonDef(')', _ButtonCategory.function),
      _ButtonDef('MC', _ButtonCategory.function),
      _ButtonDef('MR', _ButtonCategory.function),
      _ButtonDef('M-', _ButtonCategory.function),
      _ButtonDef('M+', _ButtonCategory.function),
      _ButtonDef('ID', _ButtonCategory.function),
    ]),
  ];

  static const List<_KeypadDeckDef> _rpnDecks = <_KeypadDeckDef>[
    _KeypadDeckDef('MAIN', <_ButtonDef>[
      _ButtonDef('MAT', _ButtonCategory.function),
      _ButtonDef('C', _ButtonCategory.function),
      _ButtonDef('%', _ButtonCategory.function),
      _ButtonDef('MR', _ButtonCategory.function),
      _ButtonDef('M+', _ButtonCategory.function),
      _ButtonDef('DUP', _ButtonCategory.function),
      _ButtonDef('DROP', _ButtonCategory.function),
      _ButtonDef('SWAP', _ButtonCategory.function),
      _ButtonDef('OVER', _ButtonCategory.function),
      _ButtonDef('ROT', _ButtonCategory.function),
    ]),
    _KeypadDeckDef('STACK', <_ButtonDef>[
      _ButtonDef('DUP', _ButtonCategory.function),
      _ButtonDef('DROP', _ButtonCategory.function),
      _ButtonDef('SWAP', _ButtonCategory.function),
      _ButtonDef('OVER', _ButtonCategory.function),
      _ButtonDef('ROT', _ButtonCategory.function),
      _ButtonDef('NEG', _ButtonCategory.function),
      _ButtonDef('MC', _ButtonCategory.function),
      _ButtonDef('M-', _ButtonCategory.function),
      _ButtonDef('M+', _ButtonCategory.function),
      _ButtonDef('MR', _ButtonCategory.function),
    ]),
    _KeypadDeckDef('MATRIX', <_ButtonDef>[
      _ButtonDef('T', _ButtonCategory.function),
      _ButtonDef('DET', _ButtonCategory.function),
      _ButtonDef('ZEROS', _ButtonCategory.function),
      _ButtonDef('ONES', _ButtonCategory.function),
      _ButtonDef('AROW', _ButtonCategory.function),
      _ButtonDef('ACOL', _ButtonCategory.function),
      _ButtonDef('MAT', _ButtonCategory.function),
      _ButtonDef('NEG', _ButtonCategory.function),
      _ButtonDef('MC', _ButtonCategory.function),
      _ButtonDef('M-', _ButtonCategory.function),
    ]),
    _KeypadDeckDef('FACT', <_ButtonDef>[
      _ButtonDef('LU', _ButtonCategory.function),
      _ButtonDef('QR', _ButtonCategory.function),
      _ButtonDef('RREF', _ButtonCategory.function),
      _ButtonDef('EIG', _ButtonCategory.function),
      _ButtonDef('DIAG', _ButtonCategory.function),
      _ButtonDef('COF', _ButtonCategory.function),
      _ButtonDef('ADJ', _ButtonCategory.function),
      _ButtonDef('TR', _ButtonCategory.function),
      _ButtonDef('NORM', _ButtonCategory.function),
      _ButtonDef('SNORM', _ButtonCategory.function),
    ]),
    _KeypadDeckDef('PROP', <_ButtonDef>[
      _ButtonDef('DET', _ButtonCategory.function),
      _ButtonDef('RANK', _ButtonCategory.function),
      _ButtonDef('NORM', _ButtonCategory.function),
      _ButtonDef('SNORM', _ButtonCategory.function),
      _ButtonDef('TR', _ButtonCategory.function),
      _ButtonDef('EIG', _ButtonCategory.function),
      _ButtonDef('COF', _ButtonCategory.function),
      _ButtonDef('ADJ', _ButtonCategory.function),
      _ButtonDef('DOT', _ButtonCategory.function),
      _ButtonDef('CROSS', _ButtonCategory.function),
    ]),
    _KeypadDeckDef('VEC', <_ButtonDef>[
      _ButtonDef('DOT', _ButtonCategory.function),
      _ButtonDef('CROSS', _ButtonCategory.function),
      _ButtonDef('NORM', _ButtonCategory.function),
      _ButtonDef('T', _ButtonCategory.function),
      _ButtonDef('DUP', _ButtonCategory.function),
      _ButtonDef('SWAP', _ButtonCategory.function),
      _ButtonDef('NEG', _ButtonCategory.function),
      _ButtonDef('MAT', _ButtonCategory.function),
      _ButtonDef('RANK', _ButtonCategory.function),
      _ButtonDef('DET', _ButtonCategory.function),
    ]),
  ];

  static const List<_KeypadDeckDef> _matrixDecks = <_KeypadDeckDef>[
    _KeypadDeckDef('EDIT', <_ButtonDef>[
      _ButtonDef('MAT', _ButtonCategory.function),
      _ButtonDef('C', _ButtonCategory.function),
      _ButtonDef('2x2', _ButtonCategory.function),
      _ButtonDef('3x3', _ButtonCategory.function),
      _ButtonDef('4x4', _ButtonCategory.function),
      _ButtonDef('CLR', _ButtonCategory.function),
      _ButtonDef('AROW', _ButtonCategory.function),
      _ButtonDef('ACOL', _ButtonCategory.function),
      _ButtonDef('I', _ButtonCategory.function),
      _ButtonDef('J', _ButtonCategory.function),
    ]),
    _KeypadDeckDef('BUILD', <_ButtonDef>[
      _ButtonDef('ZEROS', _ButtonCategory.function),
      _ButtonDef('ONES', _ButtonCategory.function),
      _ButtonDef('ID', _ButtonCategory.function),
      _ButtonDef('T', _ButtonCategory.function),
      _ButtonDef('DET', _ButtonCategory.function),
      _ButtonDef('AROW', _ButtonCategory.function),
      _ButtonDef('ACOL', _ButtonCategory.function),
      _ButtonDef('NEG', _ButtonCategory.function),
      _ButtonDef('MAT', _ButtonCategory.function),
      _ButtonDef('CLR', _ButtonCategory.function),
    ]),
    _KeypadDeckDef('FACT', <_ButtonDef>[
      _ButtonDef('LU', _ButtonCategory.function),
      _ButtonDef('QR', _ButtonCategory.function),
      _ButtonDef('T', _ButtonCategory.function),
      _ButtonDef('EIG', _ButtonCategory.function),
      _ButtonDef('DET', _ButtonCategory.function),
      _ButtonDef('ZEROS', _ButtonCategory.function),
      _ButtonDef('ONES', _ButtonCategory.function),
      _ButtonDef('ID', _ButtonCategory.function),
      _ButtonDef('MAT', _ButtonCategory.function),
      _ButtonDef('CLR', _ButtonCategory.function),
    ]),
    _KeypadDeckDef('MEM', <_ButtonDef>[
      _ButtonDef('MC', _ButtonCategory.function),
      _ButtonDef('MR', _ButtonCategory.function),
      _ButtonDef('M-', _ButtonCategory.function),
      _ButtonDef('M+', _ButtonCategory.function),
      _ButtonDef('MAT', _ButtonCategory.function),
      _ButtonDef('C', _ButtonCategory.function),
      _ButtonDef('CLR', _ButtonCategory.function),
      _ButtonDef('2x2', _ButtonCategory.function),
      _ButtonDef('3x3', _ButtonCategory.function),
      _ButtonDef('4x4', _ButtonCategory.function),
    ]),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
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
                final double displayHeight =
                    constraints.maxHeight * _displayFraction;
                final double keypadHeight =
                    constraints.maxHeight - displayHeight;

                return Center(
                  child: SizedBox(
                    width: shellWidth,
                    child: Column(
                      children: [
                        SizedBox(
                          key: const ValueKey<String>('calculator-display-shell'),
                          height: displayHeight,
                          child: _buildDisplay(),
                        ),
                        SizedBox(
                          key: const ValueKey<String>('calculator-keypad-shell'),
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool showDisplayStatus = _controller.hasMemory || _controller.isRpnMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModeSwitch(),
          const SizedBox(height: 12),
          if (showDisplayStatus) ...[
            Row(
              children: [
                if (_controller.hasMemory)
                  Semantics(
                    label: 'Memory indicator',
                    child: Text(
                      'M',
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: cs.primary,
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
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: _controller.isMatrixMode
                ? _buildMatrixModeBody()
                : _controller.isRpnMode
                    ? _buildRpnDisplayBody()
                    : _buildInfixDisplayBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfixDisplayBody() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Semantics(
          liveRegion: true,
          label: 'Expression: ${_controller.expression}',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              key: const ValueKey<String>('calculator-expression-text'),
              _controller.expression.isEmpty
                  ? ' '
                  : _controller.expression,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                color: cs.outline,
                fontFamily: 'monospace',
                fontSize: 20,
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isPrimary = slot.register == 0;

    return AnimatedContainer(
      key: ValueKey<String>('rpn-stack-card-${slot.register}'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      constraints: BoxConstraints(minHeight: isPrimary ? 72 : 44),
      padding: EdgeInsets.all(isPrimary ? 12 : 8),
      decoration: BoxDecoration(
        color: isPrimary ? cs.surfaceContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary
              ? cs.primary.withAlpha(80)
              : cs.outlineVariant,
        ),
      ),
      child: isPrimary
          ? _buildPrimaryRpnStackCard()
          : _buildSecondaryRpnStackCard(slot),
    );
  }

  Widget _buildPrimaryRpnStackCard() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Entry register X0',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(
              'X0',
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildDisplayValue(fontSize: 28),
        ],
      ),
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
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                literal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
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
    final ColorScheme cs = Theme.of(context).colorScheme;
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
          liveRegion: true,
          label: 'Display: ${_controller.display}',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              key: const ValueKey<String>('calculator-display-text'),
              _controller.display,
              style: Theme.of(context).textTheme.displaySmall!.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.w300,
                color: cs.onSurface,
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
            liveRegion: true,
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
                  style: Theme.of(context).textTheme.displaySmall!.copyWith(
                    fontSize: useExpanded ? fontSize * 0.78 : fontSize,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurface,
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
    final List<_KeypadDeckDef> decks = _decksForCurrentMode();
    final String selectedDeckLabel = _selectedDeckLabelForCurrentMode();
    final _KeypadDeckDef activeDeck = decks.firstWhere(
      (_KeypadDeckDef deck) => deck.label == selectedDeckLabel,
      orElse: () => decks.first,
    );
    final String enterLabel = _controller.isRpnEntryMode ? 'ENTER' : '=';
    final List<_ButtonDef> buttons = <_ButtonDef>[
      ...activeDeck.buttons,
      ..._fixedBottomButtons.map((_ButtonDef b) =>
          b.label == 'ENTER' ? _ButtonDef(enterLabel, b.category) : b),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableWidth = constraints.maxWidth - (_pagePadding * 2);
        final double availableHeight = constraints.maxHeight -
            (_pagePadding * 2) -
            _deckSelectorHeight;
        final double keyWidth =
            (availableWidth - (_gridSpacing * (_columnCount - 1))) /
                _columnCount;
        final double keyHeight =
            (availableHeight - (_gridSpacing * (_rowCount - 1))) / _rowCount;
        final double keySize = math.min(keyWidth, keyHeight);

        return Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildKeypadDeckSelectorRow(
                decks: decks,
                activeDeckLabel: activeDeck.label,
              ),
              Expanded(
                child: _buildKeypadGrid(
                  buttons: buttons,
                  keySize: keySize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeypadDeckSelectorRow({
    required List<_KeypadDeckDef> decks,
    required String activeDeckLabel,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: _deckSelectorHeight,
      child: Row(
        children: [
          for (int index = 0; index < decks.length; index++) ...[
            Expanded(
              child: Semantics(
                button: true,
                selected: decks[index].label == activeDeckLabel,
                label: '${_deckDescription(decks[index].label)} deck',
                excludeSemantics: true,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectDeck(decks[index].label),
                    hoverColor: (decks[index].label == activeDeckLabel
                            ? cs.onSecondaryContainer
                            : cs.onSurfaceVariant)
                        .withAlpha(20),
                    focusColor: (decks[index].label == activeDeckLabel
                            ? cs.onSecondaryContainer
                            : cs.onSurfaceVariant)
                        .withAlpha(25),
                    child: AnimatedContainer(
                      key: ValueKey<String>(
                        'calculator-keypad-deck-${decks[index].label}',
                      ),
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.only(
                        right: index < decks.length - 1 ? 8 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: decks[index].label == activeDeckLabel
                            ? cs.secondaryContainer
                            : cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: decks[index].label == activeDeckLabel
                              ? cs.secondary
                              : cs.outlineVariant,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        decks[index].label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium!.copyWith(
                          color: decks[index].label == activeDeckLabel
                              ? cs.onSecondaryContainer
                              : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeypadGrid({
    required List<_ButtonDef> buttons,
    required double keySize,
  }) {
    final List<List<_ButtonDef>> rows = <List<_ButtonDef>>[];
    for (int i = 0; i < buttons.length; i += _columnCount) {
      rows.add(buttons.sublist(i, i + _columnCount));
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
    return Semantics(
      button: true,
      label: semanticName,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: keySize,
        child: Tooltip(
          message: semanticName,
          child: Material(
            key: ValueKey<String>('calculator-button-${btn.label}'),
            color: colors.$1,
            borderRadius: BorderRadius.circular(16),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              splashColor: colors.$2.withAlpha(50),
              highlightColor: colors.$2.withAlpha(30),
              hoverColor: colors.$2.withAlpha(20),
              focusColor: colors.$2.withAlpha(25),
              onTap: () => _onButtonPressed(btn.label),
              child: Center(
                child: Text(
                  btn.label,
                  style: (btn.label.length > 1
                          ? Theme.of(context).textTheme.titleMedium!
                          : Theme.of(context).textTheme.titleLarge!)
                      .copyWith(
                    fontSize: btn.label.length > 1 ? 18 : 28,
                    fontWeight: FontWeight.w500,
                    color: colors.$2,
                  ),
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    return switch (category) {
      _ButtonCategory.number => (cs.surfaceContainer, cs.onSurface),
      _ButtonCategory.operator => (cs.primaryContainer, cs.onPrimaryContainer),
      _ButtonCategory.function => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      _ButtonCategory.equals => (cs.tertiaryContainer, cs.onTertiaryContainer),
    };
  }

  List<_KeypadDeckDef> _decksForCurrentMode() {
    if (_controller.isMatrixMode) {
          return _controller.isRpnEntryMode
              ? _matrixDecks
              : _matrixDecks.where((_KeypadDeckDef deck) => deck.label != 'FACT').toList(growable: false);
    }

    return _controller.isRpnMode ? _rpnDecks : _infixDecks;
  }

  String _selectedDeckLabelForCurrentMode() {
    if (_controller.isMatrixMode) {
      return _matrixDeckLabel;
    }

    return _controller.isRpnMode ? _rpnDeckLabel : _infixDeckLabel;
  }

  void _selectDeck(String deckLabel) {
    setState(() {
      if (_controller.isMatrixMode) {
        _matrixDeckLabel = deckLabel;
      } else if (_controller.isRpnMode) {
        _rpnDeckLabel = deckLabel;
      } else {
        _infixDeckLabel = deckLabel;
      }
    });
  }

  Widget _buildModeSwitch() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
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
          Expanded(
            child: _buildModeButton(
              mode: CalculatorMode.matrix,
              label: 'Matrix',
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool selected = _controller.mode == mode;
    return Semantics(
      label: '$label mode',
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _activateMode(mode),
          hoverColor: selected
              ? cs.onPrimary.withAlpha(20)
              : cs.onSurface.withAlpha(20),
          focusColor: selected
              ? cs.onPrimary.withAlpha(25)
              : cs.onSurface.withAlpha(25),
          splashColor: selected
              ? cs.onPrimary.withAlpha(30)
              : cs.onSurface.withAlpha(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: selected ? cs.onPrimary : cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _activateMode(CalculatorMode mode) {
    _controller.setMode(mode);
    setState(() {});
  }

  void _onButtonPressed(String label) {
    if (_controller.isMatrixMode) {
      final _MatrixEditorDialogState? editor = _matrixEditorKey.currentState;
      if (editor == null) {
        return;
      }

      switch (label) {
        case 'MAT':
          editor._cancel();
        case '=':
        case 'ENTER':
          editor._submit();
        case '2x2':
          editor._selectOrder(2);
        case '3x3':
          editor._selectOrder(3);
        case '4x4':
          editor._selectOrder(4);
        case 'I':
          editor._fillSpecialMatrix(Matrix.identity(2));
        case 'J':
          editor._fillSpecialMatrix(Matrix.i);
        case 'ZEROS':
          editor._fillZerosThroughCore();
        case 'ONES':
          editor._fillOnesThroughCore();
        case 'ID':
          if (editor._draft.rowCount == editor._draft.columnCount) {
            editor._fillIdentityThroughCore();
          }
        case 'CLR':
          editor._clearVisibleCells();
        case 'AROW':
          editor._appendRow();
        case 'ACOL':
          editor._appendColumn();
        case 'T':
          editor._transposeThroughCore();
        case 'INV':
          editor._inverseThroughCore();
        case 'DET':
          editor._determinantThroughCore();
        case 'LU':
          editor._executeStackExpandingThroughRpn(
            const LuDecompositionCommand(),
            actionName: 'LU',
          );
        case 'QR':
          editor._executeStackExpandingThroughRpn(
            const QrDecompositionCommand(),
            actionName: 'QR',
          );
        case 'MC':
          _controller.memoryClear();
        case 'MR':
          _controller.memoryRecall();
        case 'M+':
          _controller.memoryAdd();
        case 'M-':
          _controller.memorySubtract();
        default:
          editor._handleAppKey(label);
      }
      return;
    }

    if (_controller.isRpnMode) {
      switch (label) {
        case 'MAT':
          _activateMode(CalculatorMode.matrix);
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
        case 'T':
          _controller.executeRpnCommand(const TransposeCommand());
        case 'INV':
          _controller.executeRpnCommand(const InverseCommand());
        case 'DET':
          _controller.executeRpnCommand(const DeterminantCommand());
        case 'EIG':
          _controller.executeRpnCommand(const EigenvaluesCommand());
        case 'DIAG':
          _controller.executeRpnCommand(const DiagonalizationCommand());
        case 'TR':
          _controller.executeRpnCommand(const TraceCommand());
        case 'NORM':
          _controller.executeRpnCommand(const NormCommand());
        case 'RANK':
          _controller.executeRpnCommand(const RankCommand());
        case 'COF':
          _controller.executeRpnCommand(const CofactorMatrixCommand());
        case 'ADJ':
          _controller.executeRpnCommand(const AdjugateCommand());
        case 'DOT':
          _controller.executeRpnCommand(const DotProductCommand());
        case 'CROSS':
          _controller.executeRpnCommand(const CrossProductCommand());
        case 'RREF':
          _controller.executeRpnCommand(const RrefCommand());
        case 'SNORM':
          _controller.executeRpnCommand(const SpectralNormCommand());
        case 'LU':
          _controller.executeRpnCommand(const LuDecompositionCommand());
        case 'QR':
          _controller.executeRpnCommand(const QrDecompositionCommand());
        case 'NEG':
          _controller.executeRpnCommand(const NegateCommand());
        case 'ZEROS':
          _controller.executeRpnMacro(const FillZerosLikeTopMacro());
        case 'ONES':
          _controller.executeRpnMacro(const FillOnesLikeTopMacro());
        case 'AROW':
          _controller.executeRpnMacro(const AppendZeroRowMacro());
        case 'ACOL':
          _controller.executeRpnMacro(const AppendZeroColumnMacro());
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
        _activateMode(CalculatorMode.matrix);
      case 'C':
        _controller.clear();
      case '⌫':
        _controller.backspace();
      case 'ENTER':
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
      'MAT' => 'Matrix mode',
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
      'T' => 'Transpose top matrix',
      'INV' => 'Invert top matrix',
      'DET' => 'Determinant of top matrix',
      'EIG' => 'Eigenvalues of top matrix',
      'DIAG' => 'Diagonalize top matrix',
      'LU' => 'LU decomposition of top matrix',
      'QR' => 'QR decomposition of top matrix',
      'RREF' => 'Reduced Row Echelon Form',
      'SNORM' => 'Spectral norm of top matrix',
      'TR' => 'Trace of top matrix',
      'RANK' => 'Rank of top matrix',
      'NORM' => 'Frobenius norm of top matrix',
      'COF' => 'Cofactor matrix of top matrix',
      'ADJ' => 'Adjugate of top matrix',
      'DOT' => 'Dot product of top two vectors',
      'CROSS' => 'Cross product of top two vectors',
      'NEG' => 'Negate top matrix',
      'ZEROS' => 'Fill zeros like top matrix',
      'ONES' => 'Fill ones like top matrix',
      'ID' => 'Create identity matrix',
      'I' => 'Identity matrix 2 by 2',
      'J' => 'Imaginary unit matrix',
      'CLR' => 'Clear visible matrix cells',
      '2x2' => 'Set matrix order to 2 by 2',
      '3x3' => 'Set matrix order to 3 by 3',
      '4x4' => 'Set matrix order to 4 by 4',
      'AROW' => 'Append zero row to top matrix',
      'ACOL' => 'Append zero column to top matrix',
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

  String _deckDescription(String label) {
    return switch (label) {
      'MAIN' => 'Main functions',
      'MEM' => 'Memory operations',
      'STACK' => 'Stack operations',
      'MATRIX' => 'Matrix operations',
      'FACT' => 'Factorizations',
      'PROP' => 'Properties',
      'VEC' => 'Vector operations',
      'EDIT' => 'Edit matrix',
      'BUILD' => 'Build matrix',
      _ => label,
    };
  }

  Widget _buildMatrixModeBody() {
    return _MatrixEditorDialog(
      key: _matrixEditorKey,
      isRpnMode: _controller.isRpnEntryMode,
      embedded: true,
      onCancel: _controller.exitMatrixMode,
      onSubmitted: (String literal) {
        _controller.insertMatrixLiteral(literal);
        _controller.exitMatrixMode();
      },
      onStackExpandingCommand:
          _controller.isRpnEntryMode
              ? (String literal, CalculatrixCommand command) {
                  _controller.insertMatrixLiteral(literal);
                  _controller.executeRpnCommand(command);
                  _controller.exitMatrixMode();
                }
              : null,
    );
  }
}

class _MatrixEditorDialog extends StatefulWidget {
  const _MatrixEditorDialog({
    super.key,
    required this.isRpnMode,
    this.embedded = false,
    this.onCancel,
    this.onSubmitted,
    this.onStackExpandingCommand,
  });

  final bool isRpnMode;
  final bool embedded;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onSubmitted;
  final void Function(String literal, CalculatrixCommand command)?
      onStackExpandingCommand;

  @override
  State<_MatrixEditorDialog> createState() => _MatrixEditorDialogState();
}

class _MatrixEditorDialogState extends State<_MatrixEditorDialog> {
  final MatrixEditorDraft _draft = MatrixEditorDraft();
  String? _error;
  late List<List<TextEditingController>> _controllers;
  late List<List<FocusNode>> _focusNodes;
  late List<FocusNode> _rowTabFocusNodes;
  late List<FocusNode> _columnTabFocusNodes;
  int _selectedRow = 0;
  int _selectedColumn = 0;
  int? _editingRow;
  int? _editingColumn;
  String? _editingStartValue;
  int? _openRowActions;
  int? _openColumnActions;
  int? _draggingRow;
  int? _draggingColumn;

  static const List<int> _supportedOrders = <int>[2, 3, 4];
  static const double _rowRailWidth = 48;
  static const double _matrixGridSpacing = 6;
  static const double _matrixCellHeight = 48;
  static const double _matrixColumnHeaderHeight = 28;
  static const double _matrixRowHandleWidth = 18;
  static const double _matrixRowHandleHeight = 28;
  static const double _matrixColumnHandleWidth = 28;
  static const double _matrixColumnHandleHeight = 18;
  static const double _matrixAddButtonSize = 20;
  static const double _matrixActionButtonSize = 28;

  @override
  void initState() {
    super.initState();
    _controllers = _buildControllers();
    _focusNodes = _buildFocusNodes();
    _rowTabFocusNodes = _buildTabFocusNodes(_draft.rowCount, 'matrix-row-tab');
    _columnTabFocusNodes = _buildTabFocusNodes(
      _draft.columnCount,
      'matrix-column-tab',
    );
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
    _disposeTabFocusNodes(_rowTabFocusNodes);
    _disposeTabFocusNodes(_columnTabFocusNodes);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = SizedBox(
      width: widget.embedded ? double.infinity : 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.embedded) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _supportedOrders.map((int order) {
                  final bool isSelected =
                      _draft.rowCount == order && _draft.columnCount == order;
                  return ChoiceChip(
                    label: Text('${order}x$order'),
                    selected: isSelected,
                    onSelected: (_) => _selectOrder(order),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 8),
              Text(
                'Shape: ${_draft.rowCount}x${_draft.columnCount}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _fillZerosThroughCore,
                    child: const Text('Zeros'),
                  ),
                  OutlinedButton(
                    onPressed: _fillOnesThroughCore,
                    child: const Text('Ones'),
                  ),
                  OutlinedButton(
                    onPressed: _draft.rowCount == _draft.columnCount
                        ? _fillIdentityThroughCore
                        : null,
                    child: const Text('Identity'),
                  ),
                  OutlinedButton(
                    onPressed: _transposeThroughCore,
                    child: const Text('Transpose'),
                  ),
                  OutlinedButton(
                    onPressed: _draft.rowCount == _draft.columnCount
                        ? _inverseThroughCore
                        : null,
                    child: const Text('Inverse'),
                  ),
                  OutlinedButton(
                    onPressed: _draft.rowCount == _draft.columnCount
                        ? _determinantThroughCore
                        : null,
                    child: const Text('Determinant'),
                  ),
                  OutlinedButton(
                    onPressed: _clearVisibleCells,
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            CallbackShortcuts(
              bindings: _shortcutBindings(),
              child: _buildMatrixGrid(),
            ),
            if (!widget.embedded) ...[
              const SizedBox(height: 12),
              Text(
                _buildPreviewText(),
                key: const ValueKey<String>('matrix-preview-text'),
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final List<Widget> actions = <Widget>[
      TextButton(
        onPressed: _cancel,
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.isRpnMode ? 'Push' : 'Insert'),
      ),
    ];

    if (widget.embedded) {
      return Material(
        key: const ValueKey<String>('matrix-mode-panel'),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        elevation: 0,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
          ),
          child: content,
        ),
      );
    }

    return AlertDialog(
      title: const Text('Matrix editor'),
      content: content,
      actions: actions,
    );
  }

  Widget _buildMatrixGrid() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildColumnTabsRow(),
        const SizedBox(height: _matrixGridSpacing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _rowRailWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int row = 0; row < _draft.rowCount; row++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            row < _draft.rowCount - 1 ? _matrixGridSpacing : 0,
                      ),
                      child: _buildRowTab(row),
                    ),
                  if (_canAddRow) _buildAddRowPlaceholder(),
                ],
              ),
            ),
            const SizedBox(width: _matrixGridSpacing),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int row = 0; row < _draft.rowCount; row++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            row < _draft.rowCount - 1 ? _matrixGridSpacing : 0,
                      ),
                      child: Row(
                        children: [
                          for (int column = 0;
                              column < _draft.columnCount;
                              column++) ...[
                            Expanded(
                              child: _buildMatrixCell(row, column),
                            ),
                            if (column < _draft.columnCount - 1)
                              const SizedBox(width: _matrixGridSpacing),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool get _canAddRow => _draft.rowCount < 4;

  bool get _canAddColumn => _draft.columnCount < 4;

  Widget _buildColumnTabsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: _rowRailWidth + 18),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int column = 0; column < _draft.columnCount; column++) ...[
                Expanded(child: _buildColumnTab(column)),
                if (column < _draft.columnCount - 1)
                  const SizedBox(width: _matrixGridSpacing),
              ],
              if (_canAddColumn)
                ...<Widget>[
                  const SizedBox(width: _matrixGridSpacing),
                  _buildAddColumnPlaceholder(),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColumnTab(int column) {
    final bool isOpen = _openColumnActions == column;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DragTarget<_StructuralDragData>(
          onWillAcceptWithDetails: (
            DragTargetDetails<_StructuralDragData> details,
          ) {
            return details.data.axis == _StructuralAxis.column &&
                details.data.index != column;
          },
          onAcceptWithDetails: (DragTargetDetails<_StructuralDragData> details) {
            _moveColumnUnit(details.data.index, column, focusTab: true);
          },
          builder: (
            BuildContext context,
            List<_StructuralDragData?> candidateData,
            List<dynamic> rejectedData,
          ) {
            final Widget marker = _buildColumnMarker(
              column,
              highlighted: candidateData.isNotEmpty,
            );
            return Draggable<_StructuralDragData>(
              data: _StructuralDragData.column(column),
              affinity: Axis.horizontal,
              axis: Axis.horizontal,
              feedback: _buildColumnDragFeedback(column),
              onDragStarted: () => _startColumnDrag(column),
              onDragEnd: (_) => _endStructuralDrag(),
              onDraggableCanceled: (velocity, offset) => _endStructuralDrag(),
              onDragCompleted: _endStructuralDrag,
              childWhenDragging: Opacity(opacity: 0.35, child: marker),
              child: marker,
            );
          },
        ),
        if (isOpen)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Duplicate column',
                  onPressed: _draft.columnCount < 4
                      ? () => _duplicateColumn(column)
                      : null,
                  icon: const Icon(Icons.copy, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: _matrixActionButtonSize,
                    height: _matrixActionButtonSize,
                  ),
                  splashRadius: 16,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Delete column',
                  onPressed: _draft.columnCount > 1
                      ? () => _deleteColumn(column)
                      : null,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: _matrixActionButtonSize,
                    height: _matrixActionButtonSize,
                  ),
                  splashRadius: 16,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRowTab(int row) {
    final bool isOpen = _openRowActions == row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DragTarget<_StructuralDragData>(
          onWillAcceptWithDetails: (
            DragTargetDetails<_StructuralDragData> details,
          ) {
            return details.data.axis == _StructuralAxis.row &&
                details.data.index != row;
          },
          onAcceptWithDetails: (
            DragTargetDetails<_StructuralDragData> details,
          ) {
            _moveRowUnit(details.data.index, row, focusTab: true);
          },
          builder: (
            BuildContext context,
            List<_StructuralDragData?> candidateData,
            List<dynamic> rejectedData,
          ) {
            final Widget marker = _buildRowMarker(
              row,
              highlighted: candidateData.isNotEmpty,
            );
            return Draggable<_StructuralDragData>(
              data: _StructuralDragData.row(row),
              affinity: Axis.vertical,
              axis: Axis.vertical,
              feedback: _buildRowDragFeedback(row),
              onDragStarted: () => _startRowDrag(row),
              onDragEnd: (_) => _endStructuralDrag(),
              onDraggableCanceled: (velocity, offset) => _endStructuralDrag(),
              onDragCompleted: _endStructuralDrag,
              childWhenDragging: Opacity(opacity: 0.35, child: marker),
              child: marker,
            );
          },
        ),
        if (isOpen)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Duplicate row',
                  onPressed: _draft.rowCount < 4 ? () => _duplicateRow(row) : null,
                  icon: const Icon(Icons.copy, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: _matrixActionButtonSize,
                    height: _matrixActionButtonSize,
                  ),
                  splashRadius: 16,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Delete row',
                  onPressed: _draft.rowCount > 1 ? () => _deleteRow(row) : null,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: _matrixActionButtonSize,
                    height: _matrixActionButtonSize,
                  ),
                  splashRadius: 16,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRowMarker(int row, {bool highlighted = false}) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true):
            () => _moveRowUnit(row, row - 1, focusTab: true),
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true):
            () => _moveRowUnit(row, row + 1, focusTab: true),
      },
      child: Focus(
        focusNode: _rowTabFocusNodes[row],
        child: SizedBox(
          height: _matrixCellHeight,
          child: Center(
            child: SizedBox(
              key: ValueKey<String>('matrix-row-handle-$row'),
              width: _matrixRowHandleWidth,
              height: _matrixRowHandleHeight,
              child: IconButton(
                key: ValueKey<String>('matrix-row-tab-$row'),
                tooltip: 'Row ${row + 1}, drag to reorder',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.expand(),
                style: IconButton.styleFrom(
                  backgroundColor: highlighted
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLowest,
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  side: BorderSide(
                    color: highlighted
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  _rowTabFocusNodes[row].requestFocus();
                  _toggleRowActions(row);
                },
                icon: const Icon(Icons.drag_indicator, size: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColumnMarker(int column, {bool highlighted = false}) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
            () => _moveColumnUnit(column, column - 1, focusTab: true),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
            () => _moveColumnUnit(column, column + 1, focusTab: true),
      },
      child: Focus(
        focusNode: _columnTabFocusNodes[column],
        child: SizedBox(
          height: _matrixColumnHeaderHeight,
          child: Center(
            child: SizedBox(
              key: ValueKey<String>('matrix-column-handle-$column'),
              width: _matrixColumnHandleWidth,
              height: _matrixColumnHandleHeight,
              child: IconButton(
                key: ValueKey<String>('matrix-column-tab-$column'),
                tooltip: 'Column ${column + 1}, drag to reorder',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.expand(),
                style: IconButton.styleFrom(
                  backgroundColor: highlighted
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLowest,
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  side: BorderSide(
                    color: highlighted
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  _columnTabFocusNodes[column].requestFocus();
                  _toggleColumnActions(column);
                },
                icon: const Icon(Icons.drag_indicator, size: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatrixCell(int row, int column) {
    if (_draggingRow == row || _draggingColumn == column) {
      return _buildSkeletonCell();
    }

    return TextFormField(
      key: ValueKey<String>('matrix-cell-$row-$column'),
      controller: _controllers[row][column],
      focusNode: _focusNodes[row][column],
      keyboardType: TextInputType.none,
      readOnly: !_isEditingCell(row, column),
      showCursor: _isEditingCell(row, column),
      textInputAction: _isLastVisibleCell(row, column)
          ? TextInputAction.done
          : TextInputAction.next,
      textAlign: TextAlign.end,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        constraints: const BoxConstraints(minHeight: _matrixCellHeight),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.4),
        ),
        labelText: 'Row ${row + 1}, Column ${column + 1}',
        labelStyle: Theme.of(context).textTheme.labelSmall,
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
    );
  }

  Widget _buildSkeletonCell() {
    return Container(
      height: _matrixCellHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }

  Widget _buildAddPlaceholderChrome(Key key) {
    return SizedBox(
      key: key,
      width: _matrixAddButtonSize,
      height: _matrixAddButtonSize,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          shape: CircleBorder(
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Center(
          child: Icon(Icons.add, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildAddRowPlaceholder() {
    return SizedBox(
      height: _matrixCellHeight,
      child: IconButton(
          key: const ValueKey<String>('matrix-add-row-placeholder'),
          tooltip: 'Add row',
          onPressed: _appendRow,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.expand(),
          splashRadius: _matrixCellHeight / 2,
          visualDensity: VisualDensity.compact,
          icon: _buildAddPlaceholderChrome(
            const ValueKey<String>('matrix-add-row-button'),
          ),
        ),
    );
  }

  Widget _buildAddColumnPlaceholder() {
    return SizedBox(
      width: _matrixColumnHandleWidth,
      height: _matrixColumnHeaderHeight,
      child: IconButton(
          key: const ValueKey<String>('matrix-add-column-placeholder'),
          tooltip: 'Add column',
          onPressed: _appendColumn,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.expand(),
          splashRadius: _matrixColumnHandleWidth / 2,
          visualDensity: VisualDensity.compact,
          icon: _buildAddPlaceholderChrome(
            const ValueKey<String>('matrix-add-column-button'),
          ),
        ),
    );
  }

  Widget _buildRowDragFeedback(int row) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        key: ValueKey<String>('matrix-row-drag-feedback-$row'),
        width: 360,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          children: [
            Expanded(flex: 2, child: _buildDragMarkerHandle()),
            const SizedBox(width: 8),
            for (int column = 0; column < _draft.columnCount; column++) ...[
              Expanded(child: _buildDragValueBox(_draft.cellValue(row, column))),
              if (column < _draft.columnCount - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColumnDragFeedback(int column) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        key: ValueKey<String>('matrix-column-drag-feedback-$column'),
        width: 96,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragMarkerHandle(),
            const SizedBox(height: 8),
            for (int row = 0; row < _draft.rowCount; row++) ...[
              _buildDragValueBox(_draft.cellValue(row, column)),
              if (row < _draft.rowCount - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDragMarkerHandle() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: Icon(Icons.drag_indicator, size: 18)),
    );
  }

  Widget _buildDragValueBox(String value) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Center(child: Text(value.isEmpty ? ' ' : value)),
    );
  }

  void _toggleRowActions(int row) {
    setState(() {
      _openRowActions = _openRowActions == row ? null : row;
      _openColumnActions = null;
      _draggingRow = null;
      _draggingColumn = null;
      _resetEditingState();
      _error = null;
    });
  }

  void _toggleColumnActions(int column) {
    setState(() {
      _openColumnActions = _openColumnActions == column ? null : column;
      _openRowActions = null;
      _draggingRow = null;
      _draggingColumn = null;
      _resetEditingState();
      _error = null;
    });
  }

  void _startRowDrag(int row) {
    setState(() {
      _draggingRow = row;
      _draggingColumn = null;
      _closeStructuralActions();
      _resetEditingState();
    });
  }

  void _startColumnDrag(int column) {
    setState(() {
      _draggingColumn = column;
      _draggingRow = null;
      _closeStructuralActions();
      _resetEditingState();
    });
  }

  void _endStructuralDrag() {
    if (_draggingRow == null && _draggingColumn == null) {
      return;
    }

    setState(() {
      _draggingRow = null;
      _draggingColumn = null;
    });
  }

  void _appendRow() {
    setState(() {
      _resetEditingState();
      _closeStructuralActions();
      _draggingRow = null;
      _draggingColumn = null;
      final Matrix? matrix = _tryBuildMatrixOrNull();
      if (matrix != null) {
        _replaceDraftWithMatrix(
          _executeMacroWithSeed(const AppendZeroRowMacro(), seed: matrix),
        );
      } else if (_draft.appendRow()) {
        _rebuildInputs();
      }
      _error = null;
    });
  }

  void _appendColumn() {
    setState(() {
      _resetEditingState();
      _closeStructuralActions();
      _draggingRow = null;
      _draggingColumn = null;
      final Matrix? matrix = _tryBuildMatrixOrNull();
      if (matrix != null) {
        _replaceDraftWithMatrix(
          _executeMacroWithSeed(const AppendZeroColumnMacro(), seed: matrix),
        );
      } else if (_draft.appendColumn()) {
        _rebuildInputs();
      }
      _error = null;
    });
  }

  void _duplicateRow(int row) {
    setState(() {
      _resetEditingState();
      _draggingRow = null;
      _draggingColumn = null;
      final Matrix? matrix = _tryBuildMatrixOrNull();
      if (matrix != null) {
        _replaceDraftWithMatrix(
          _executeCommandsOnMatrix(matrix, <CalculatrixCommand>[
            DuplicateRowCommand(row),
          ]),
        );
        _openRowActions = row + 1;
        _openColumnActions = null;
      } else if (_draft.duplicateRow(row)) {
        _openRowActions = row + 1;
        _openColumnActions = null;
        _rebuildInputs();
      }
      _error = null;
    });
  }

  void _duplicateColumn(int column) {
    setState(() {
      _resetEditingState();
      _draggingRow = null;
      _draggingColumn = null;
      final Matrix? matrix = _tryBuildMatrixOrNull();
      if (matrix != null) {
        _replaceDraftWithMatrix(
          _executeCommandsOnMatrix(matrix, <CalculatrixCommand>[
            DuplicateColumnCommand(column),
          ]),
        );
        _openColumnActions = column + 1;
        _openRowActions = null;
      } else if (_draft.duplicateColumn(column)) {
        _openColumnActions = column + 1;
        _openRowActions = null;
        _rebuildInputs();
      }
      _error = null;
    });
  }

  void _deleteRow(int row) {
    setState(() {
      _resetEditingState();
      _draggingRow = null;
      _draggingColumn = null;
      final Matrix? matrix = _tryBuildMatrixOrNull();
      if (matrix != null) {
        _replaceDraftWithMatrix(
          _executeCommandsOnMatrix(matrix, <CalculatrixCommand>[
            DeleteRowCommand(row),
          ]),
        );
        _openRowActions = row < _draft.rowCount ? row : _draft.rowCount - 1;
        _openColumnActions = null;
      } else if (_draft.deleteRow(row)) {
        _openRowActions = row < _draft.rowCount ? row : _draft.rowCount - 1;
        _openColumnActions = null;
        _rebuildInputs();
      }
      _error = null;
    });
  }

  void _deleteColumn(int column) {
    setState(() {
      _resetEditingState();
      _draggingRow = null;
      _draggingColumn = null;
      final Matrix? matrix = _tryBuildMatrixOrNull();
      if (matrix != null) {
        _replaceDraftWithMatrix(
          _executeCommandsOnMatrix(matrix, <CalculatrixCommand>[
            DeleteColumnCommand(column),
          ]),
        );
        _openColumnActions =
            column < _draft.columnCount ? column : _draft.columnCount - 1;
        _openRowActions = null;
      } else if (_draft.deleteColumn(column)) {
        _openColumnActions =
            column < _draft.columnCount ? column : _draft.columnCount - 1;
        _openRowActions = null;
        _rebuildInputs();
      }
      _error = null;
    });
  }

  void _moveRowUnit(int from, int to, {bool focusTab = false}) {
    if (to < 0 || to >= _draft.rowCount) {
      return;
    }

    setState(() {
      _resetEditingState();
      final Matrix? matrix = _tryBuildMatrixOrNull();
      if (matrix != null) {
        _replaceDraftWithMatrix(
          _executeCommandsOnMatrix(matrix, <CalculatrixCommand>[
            MoveRowCommand(from, to),
          ]),
        );
        _selectedRow = _remapIndexAfterMove(_selectedRow, from, to);
        if (_openRowActions != null) {
          _openRowActions = _remapIndexAfterMove(_openRowActions!, from, to);
        }
        _error = null;
      } else if (_draft.moveRow(from, to)) {
        _syncControllersFromDraft();
        _selectedRow = _remapIndexAfterMove(_selectedRow, from, to);
        if (_openRowActions != null) {
          _openRowActions = _remapIndexAfterMove(_openRowActions!, from, to);
        }
        _error = null;
      }
    });

    if (focusTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _requestRowTabFocus(to);
      });
    }
  }

  void _moveColumnUnit(int from, int to, {bool focusTab = false}) {
    if (to < 0 || to >= _draft.columnCount) {
      return;
    }

    setState(() {
      _resetEditingState();
      final Matrix? matrix = _tryBuildMatrixOrNull();
      if (matrix != null) {
        _replaceDraftWithMatrix(
          _executeCommandsOnMatrix(matrix, <CalculatrixCommand>[
            MoveColumnCommand(from, to),
          ]),
        );
        _selectedColumn = _remapIndexAfterMove(_selectedColumn, from, to);
        if (_openColumnActions != null) {
          _openColumnActions = _remapIndexAfterMove(
            _openColumnActions!,
            from,
            to,
          );
        }
        _error = null;
      } else if (_draft.moveColumn(from, to)) {
        _syncControllersFromDraft();
        _selectedColumn = _remapIndexAfterMove(_selectedColumn, from, to);
        if (_openColumnActions != null) {
          _openColumnActions = _remapIndexAfterMove(
            _openColumnActions!,
            from,
            to,
          );
        }
        _error = null;
      }
    });

    if (focusTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _requestColumnTabFocus(to);
      });
    }
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

  List<FocusNode> _buildTabFocusNodes(int count, String prefix) {
    return List<FocusNode>.generate(
      count,
      (int index) => FocusNode(debugLabel: '$prefix-$index'),
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

  void _disposeTabFocusNodes(List<FocusNode> focusNodes) {
    for (final FocusNode focusNode in focusNodes) {
      focusNode.dispose();
    }
  }

  void _rebuildInputs() {
    _disposeControllers();
    _disposeFocusNodes();
    _disposeTabFocusNodes(_rowTabFocusNodes);
    _disposeTabFocusNodes(_columnTabFocusNodes);
    _controllers = _buildControllers();
    _focusNodes = _buildFocusNodes();
    _rowTabFocusNodes = _buildTabFocusNodes(_draft.rowCount, 'matrix-row-tab');
    _columnTabFocusNodes = _buildTabFocusNodes(
      _draft.columnCount,
      'matrix-column-tab',
    );
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

  void _fillZerosThroughCore() {
    setState(() {
      _resetEditingState();
      _closeStructuralActions();
      _replaceDraftWithMatrix(
        _executeMacroWithSeed(
          const FillZerosLikeTopMacro(),
          seed:
              _tryBuildMatrixOrNull() ??
              Matrix.zeros(_draft.rowCount, _draft.columnCount),
        ),
      );
    });
  }

  void _fillOnesThroughCore() {
    setState(() {
      _resetEditingState();
      _closeStructuralActions();
      _replaceDraftWithMatrix(
        _executeMacroWithSeed(
          const FillOnesLikeTopMacro(),
          seed:
              _tryBuildMatrixOrNull() ??
              Matrix.zeros(_draft.rowCount, _draft.columnCount),
        ),
      );
    });
  }

  void _fillIdentityThroughCore() {
    setState(() {
      _resetEditingState();
      _closeStructuralActions();
      _replaceDraftWithMatrix(
        _executeMacroWithSeed(CreateIdentityMacro(_draft.rowCount)),
      );
    });
  }

  void _fillSpecialMatrix(Matrix matrix) {
    setState(() {
      _resetEditingState();
      _closeStructuralActions();
      _replaceDraftWithMatrix(matrix);
    });
  }

  void _transposeThroughCore() {
    setState(() {
      _resetEditingState();
      _closeStructuralActions();
      final Matrix? matrix = _tryBuildMatrixOrNull();
      if (matrix == null) {
        _error =
            _draft.validationError() ?? 'Transpose requires a valid matrix.';
        return;
      }

      _replaceDraftWithMatrix(
        _executeCommandsOnMatrix(matrix, const <CalculatrixCommand>[
          TransposeCommand(),
        ]),
      );
    });
  }

  void _inverseThroughCore() {
    setState(() {
      _resetEditingState();
      _closeStructuralActions();
      final Matrix? matrix = _tryBuildMatrixOrNull();
      if (matrix == null) {
        _error = _draft.validationError() ?? 'Inverse requires a valid matrix.';
        return;
      }

      try {
        _replaceDraftWithMatrix(
          _executeCommandsOnMatrix(matrix, const <CalculatrixCommand>[
            InverseCommand(),
          ]),
        );
      } on CalculatrixError catch (error) {
        _error = error.message;
      }
    });
  }

  void _determinantThroughCore() {
    setState(() {
      _resetEditingState();
      _closeStructuralActions();
      final Matrix? matrix = _tryBuildMatrixOrNull();
      if (matrix == null) {
        _error =
            _draft.validationError() ?? 'Determinant requires a valid matrix.';
        return;
      }

      try {
        _replaceDraftWithMatrix(
          _executeCommandsOnMatrix(matrix, const <CalculatrixCommand>[
            DeterminantCommand(),
          ]),
        );
      } on CalculatrixError catch (error) {
        _error = error.message;
      }
    });
  }

  Matrix? _tryBuildMatrixOrNull() {
    try {
      _syncDraftFromControllers();
      return Calculatrix.evaluateInfix(_draft.buildLiteral());
    } on FormatException {
      return null;
    } on CalculatrixError {
      return null;
    }
  }

  Matrix _executeCommandsOnMatrix(
    Matrix matrix,
    List<CalculatrixCommand> commands,
  ) {
    final CalculatrixMachine machine = CalculatrixMachine();
    machine.execute(PushMatrixCommand(matrix));
    machine.executeAll(commands);
    return machine.top!;
  }

  Matrix _executeMacroWithSeed(
    CalculatrixMacro macro, {
    Matrix? seed,
  }) {
    final CalculatrixMachine machine = CalculatrixMachine();
    if (seed != null) {
      machine.execute(PushMatrixCommand(seed));
    }
    machine.executeMacro(macro);
    return machine.top!;
  }

  void _replaceDraftWithMatrix(Matrix matrix) {
    _draft.resize(rowCount: matrix.rowCount, columnCount: matrix.columnCount);
    for (int row = 0; row < matrix.rowCount; row++) {
      for (int column = 0; column < matrix.columnCount; column++) {
        _draft.setCell(row, column, _formatMatrixCellValue(matrix.at(row, column)));
      }
    }

    _rebuildInputs();
    _error = null;
  }

  void _executeStackExpandingThroughRpn(
    CalculatrixCommand command, {
    required String actionName,
  }) {
    String? literal;

    setState(() {
      _resetEditingState();
      _closeStructuralActions();

      final Matrix? matrix = _tryBuildMatrixOrNull();
      if (matrix == null) {
        _error =
            _draft.validationError() ?? '$actionName requires a valid matrix.';
        return;
      }

      if (!widget.isRpnMode || widget.onStackExpandingCommand == null) {
        _error = '$actionName requires RPN mode.';
        return;
      }

      literal = _draft.buildLiteral();
      _error = null;
    });

    if (literal == null) {
      return;
    }

    widget.onStackExpandingCommand!(literal!, command);
  }

  String _formatMatrixCellValue(double value) {
    if (value == value.toInt().toDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
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

  void _selectOrder(int order) {
    setState(() {
      _draft.setOrder(order);
      _resetEditingState();
      _closeStructuralActions();
      _rebuildInputs();
      _error = null;
    });
  }

  void _clearVisibleCells() {
    setState(() {
      _resetEditingState();
      _closeStructuralActions();
      _draft.clearVisible();
      _syncControllersFromDraft();
      _error = null;
    });
  }

  void _handleAppKey(String label) {
    switch (label) {
      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9':
      case '.':
      case '+':
      case '-':
        _appendToSelectedCell(label);
      case '⌫':
        _backspaceSelectedCell();
      case '±':
        _toggleSelectedCellSign();
      case 'C':
        _clearSelectedCell();
      default:
        return;
    }
  }

  void _appendToSelectedCell(String fragment) {
    setState(() {
      _editingRow = _selectedRow;
      _editingColumn = _selectedColumn;
      final TextEditingController controller =
          _controllers[_selectedRow][_selectedColumn];
      final String nextValue = controller.text + fragment;
      controller.text = nextValue;
      controller.selection = TextSelection.collapsed(offset: nextValue.length);
      _draft.setCell(_selectedRow, _selectedColumn, nextValue);
      _error = null;
    });

    _requestCellFocus(_selectedRow, _selectedColumn);
  }

  void _backspaceSelectedCell() {
    setState(() {
      _editingRow = _selectedRow;
      _editingColumn = _selectedColumn;
      final TextEditingController controller =
          _controllers[_selectedRow][_selectedColumn];
      final String currentValue = controller.text;
      final String nextValue = currentValue.isEmpty
          ? ''
          : currentValue.substring(0, currentValue.length - 1);
      controller.text = nextValue;
      controller.selection = TextSelection.collapsed(offset: nextValue.length);
      _draft.setCell(_selectedRow, _selectedColumn, nextValue);
      _error = null;
    });

    _requestCellFocus(_selectedRow, _selectedColumn);
  }

  void _clearSelectedCell() {
    setState(() {
      _editingRow = _selectedRow;
      _editingColumn = _selectedColumn;
      _controllers[_selectedRow][_selectedColumn].clear();
      _draft.setCell(_selectedRow, _selectedColumn, '');
      _error = null;
    });

    _requestCellFocus(_selectedRow, _selectedColumn);
  }

  void _toggleSelectedCellSign() {
    setState(() {
      _editingRow = _selectedRow;
      _editingColumn = _selectedColumn;
      final TextEditingController controller =
          _controllers[_selectedRow][_selectedColumn];
      final String currentValue = controller.text;
      final String nextValue;
      if (currentValue.startsWith('-')) {
        nextValue = currentValue.substring(1);
      } else if (currentValue.isEmpty) {
        nextValue = '-';
      } else {
        nextValue = '-$currentValue';
      }
      controller.text = nextValue;
      controller.selection = TextSelection.collapsed(offset: nextValue.length);
      _draft.setCell(_selectedRow, _selectedColumn, nextValue);
      _error = null;
    });

    _requestCellFocus(_selectedRow, _selectedColumn);
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

    final Map<ShortcutActivator, VoidCallback> bindings =
        <ShortcutActivator, VoidCallback>{
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

    if (_openRowActions != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true)] =
          () => _moveRowUnit(_openRowActions!, _openRowActions! - 1, focusTab: true);
      bindings[
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true)
      ] = () => _moveRowUnit(_openRowActions!, _openRowActions! + 1, focusTab: true);
    }

    if (_openColumnActions != null) {
      bindings[
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true)
      ] = () => _moveColumnUnit(
            _openColumnActions!,
            _openColumnActions! - 1,
            focusTab: true,
          );
      bindings[
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true)
      ] = () => _moveColumnUnit(
            _openColumnActions!,
            _openColumnActions! + 1,
            focusTab: true,
          );
    }

    return bindings;
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
      _closeStructuralActions();
      _error = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _requestCellFocus(row, column, selectAll: true);
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
    });
  }

  void _resetEditingState() {
    _editingRow = null;
    _editingColumn = null;
    _editingStartValue = null;
  }

  void _closeStructuralActions() {
    _openRowActions = null;
    _openColumnActions = null;
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

  void _requestRowTabFocus(int row) {
    final FocusNode focusNode = _rowTabFocusNodes[row];
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }

  void _requestColumnTabFocus(int column) {
    final FocusNode focusNode = _columnTabFocusNodes[column];
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }

  int _remapIndexAfterMove(int current, int from, int to) {
    if (current == from) {
      return to;
    }

    if (from < to && current > from && current <= to) {
      return current - 1;
    }

    if (from > to && current >= to && current < from) {
      return current + 1;
    }

    return current;
  }

  int _clampIndex(int value, int upperBound) {
    return math.max(0, math.min(value, upperBound));
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    if (widget.embedded) {
      widget.onCancel?.call();
      return;
    }

    Navigator.of(context).pop();
  }

  void _submit() {
    try {
      _syncDraftFromControllers();
      final String literal = _draft.buildLiteral();
      FocusScope.of(context).unfocus();
      if (widget.embedded) {
        widget.onSubmitted?.call(literal);
        return;
      }

      Navigator.of(context).pop(literal);
    } on FormatException catch (error) {
      setState(() {
        _error = error.message;
      });
    }
  }
}
