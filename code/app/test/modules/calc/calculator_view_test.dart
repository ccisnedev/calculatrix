import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calculatrix_app/main.dart';

Finder _matrixCell(int row, int column) {
  return find.byKey(ValueKey<String>('matrix-cell-$row-$column'));
}

Finder _rowTab(int row) {
  return find.byKey(ValueKey<String>('matrix-row-tab-$row'));
}

Finder _columnTab(int column) {
  return find.byKey(ValueKey<String>('matrix-column-tab-$column'));
}

Finder _addRowPlaceholder() {
  return find.byKey(const ValueKey<String>('matrix-add-row-placeholder'));
}

Finder _addColumnPlaceholder() {
  return find.byKey(const ValueKey<String>('matrix-add-column-placeholder'));
}

Finder _displayShell() {
  return find.byKey(const ValueKey<String>('calculator-display-shell'));
}

Finder _keypadShell() {
  return find.byKey(const ValueKey<String>('calculator-keypad-shell'));
}

Finder _rowHandle(int row) {
  return find.byKey(ValueKey<String>('matrix-row-handle-$row'));
}

Finder _columnHandle(int column) {
  return find.byKey(ValueKey<String>('matrix-column-handle-$column'));
}

Finder _addRowButton() {
  return find.byKey(const ValueKey<String>('matrix-add-row-button'));
}

Finder _addColumnButton() {
  return find.byKey(const ValueKey<String>('matrix-add-column-button'));
}

EditableText _matrixEditableText(WidgetTester tester, int row, int column) {
  return tester.widget<EditableText>(
    find.descendant(
      of: _matrixCell(row, column),
      matching: find.byType(EditableText),
    ),
  );
}

Finder _calculatorButton(String label) {
  if (label == 'INFIX') {
    return find.byWidgetPredicate((Widget widget) {
      final Key? key = widget.key;
      return key == const ValueKey<String>('calculator-button-INFIX') ||
          key == const ValueKey<String>('calculator-button-INFIX-edit');
    });
  }

  return find.byKey(ValueKey<String>('calculator-button-$label'));
}

Finder _calculatorButtonLabel(String keyLabel, String visibleLabel) {
  return find.descendant(
    of: _calculatorButton(keyLabel),
    matching: find.text(visibleLabel),
  );
}

Finder _rpnStackCard(int register) {
  return find.byKey(ValueKey<String>('rpn-stack-card-$register'));
}

Finder _rpnDraftCard() {
  return find.byKey(const ValueKey<String>('rpn-draft-card'));
}

Finder _keypadDeckSelector(String label) {
  return find.byKey(ValueKey<String>('calculator-keypad-deck-$label'));
}

const List<String> _keypadDeckLabels = <String>[
  'BASIC',
  'EDIT',
  'STACK',
  'MATH',
  'MATRIX',
  'VECTOR',
  'FACT',
  'PROP',
  'BUILD',
  'MEM',
];

Future<void> _ensureCalculatorButtonVisible(
  WidgetTester tester,
  String label,
) async {
  final Finder button = _calculatorButton(label);
  if (button.evaluate().isNotEmpty) {
    return;
  }

  for (final String deckLabel in _keypadDeckLabels) {
    final Finder selector = _keypadDeckSelector(deckLabel);
    if (selector.evaluate().isEmpty) {
      continue;
    }

    await tester.tap(selector);
    await tester.pumpAndSettle();
    if (button.evaluate().isNotEmpty) {
      return;
    }
  }

  expect(button, findsOneWidget);
}

Future<void> _tapCalculatorButton(WidgetTester tester, String label) async {
  await _ensureCalculatorButtonVisible(tester, label);
  final Finder button = _calculatorButton(label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _expectSingleLineButtonLabel(
  WidgetTester tester, {
  required String keyLabel,
  required String visibleLabel,
}) async {
  await _ensureCalculatorButtonVisible(tester, keyLabel);
  final Finder label = _calculatorButtonLabel(keyLabel, visibleLabel);
  expect(label, findsOneWidget);
  expect(
    find.ancestor(of: label, matching: find.byType(FittedBox)),
    findsAtLeastNWidgets(1),
  );

  final Text text = tester.widget<Text>(label);
  expect(text.maxLines, 1);
  expect(text.softWrap, isFalse);
}

Future<void> _tapFinderCenter(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tapAt(tester.getCenter(finder, warnIfMissed: false));
  await tester.pumpAndSettle();
}

Future<void> _activateMatrixControl(WidgetTester tester, Finder control) async {
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();

  final Widget widget = tester.widget<Widget>(control);
  if (widget case final IconButton button when button.onPressed != null) {
    button.onPressed!.call();
    await tester.pumpAndSettle();
    return;
  }

  await tester.tap(control, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _openMatrixEditor(WidgetTester tester) async {
  await _tapFinderCenter(tester, _keypadDeckSelector('EDIT'));
  await _tapCalculatorButton(tester, 'MATRIX');
}

Future<void> _openInfixEditor(WidgetTester tester) async {
  await _tapFinderCenter(tester, _keypadDeckSelector('EDIT'));
  await _tapCalculatorButton(tester, 'INFIX');
}

Future<void> _enterMatrixCell(
  WidgetTester tester,
  int row,
  int column,
  String value,
) async {
  final Finder cell = _matrixCell(row, column);
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  await tester.tap(cell);
  await tester.pumpAndSettle();
  await tester.enterText(cell, value);
  await tester.pumpAndSettle();
}

Future<void> _tapMatrixAction(WidgetTester tester, String label) async {
  switch (label) {
    case 'Insert':
    case 'Push':
      await _tapCalculatorButton(tester, 'ENTER');
      return;
    case 'Cancel':
      await _tapCalculatorButton(tester, 'CANCEL');
      return;
    default:
      await _tapCalculatorButton(tester, label);
  }
}

void main() {
  group('CalculatorView - widget tests', () {
    testWidgets('app renders without crash', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('displays initial value "0"', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 0')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('keypad keeps the stable shell buttons visible', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      final expected = [
        'MRC', 'M-', 'M+', 'AC', 'C', '%', 'SQRT', 'INV', 'i',
        '7', '8', '9', '÷',
        '4', '5', '6', '×', 'DELETE',
        '1', '2', '3', '-', '=',
        '0', '.', '±', '+', 'ENTER',
      ];
      for (final label in expected) {
        await _ensureCalculatorButtonVisible(tester, label);
        expect(_calculatorButton(label), findsOneWidget,
            reason: 'Button "$label" not found');
      }
    });

    testWidgets('tap digit updates expression', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await _openInfixEditor(tester);
      await _tapCalculatorButton(tester, '5');
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp(r'Expression: 5')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('equals evaluates inside the infix editor without committing to stack', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await _openInfixEditor(tester);
      await _tapCalculatorButton(tester, '3');
      await _tapCalculatorButton(tester, '+');
      await _tapCalculatorButton(tester, '4');
      await _tapCalculatorButton(tester, '=');
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 7')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('calculator-stack-depth')), findsNothing);
      handle.dispose();
    });

    testWidgets('clear button resets display', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await _openInfixEditor(tester);
      await _tapCalculatorButton(tester, '9');
      await _tapCalculatorButton(tester, 'C');
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 0')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('infix mode shows memory state and animates add/subtract operations', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await _openInfixEditor(tester);

      expect(find.text('MEM: empty'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('calculator-infix-controls-hint')),
        findsNothing,
      );
      final double draftLeft = tester.getRect(_rpnDraftCard()).left;
      final double memoryLeft = tester
          .getRect(find.byKey(const ValueKey<String>('calculator-infix-memory-status')))
          .left;
      expect(memoryLeft - draftLeft, greaterThanOrEqualTo(16.0));

      final Rect statusRailRect = tester.getRect(
        find.byKey(const ValueKey<String>('calculator-infix-status-rail')),
      );
      final Rect expressionViewportRect = tester.getRect(
        find.byKey(const ValueKey<String>('calculator-infix-expression-viewport')),
      );
      final Rect draftLabelRect = tester.getRect(
        find.descendant(of: _rpnDraftCard(), matching: find.text('DRAFT')),
      );
      final Rect memoryStatusRect = tester.getRect(
        find.byKey(const ValueKey<String>('calculator-infix-memory-status')),
      );

      expect(statusRailRect.height, lessThan(40.0));
      expect(
        (draftLabelRect.center.dy - memoryStatusRect.center.dy).abs(),
        lessThanOrEqualTo(2.0),
      );
      expect(expressionViewportRect.height, greaterThan(statusRailRect.height * 2));
      expect(
        tester.widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('calculator-infix-memory-status')),
            matching: find.byType(Text),
          ),
        ).maxLines,
        1,
      );

      await _tapCalculatorButton(tester, '7');
      await _tapCalculatorButton(tester, 'M+');

      expect(find.text('MEM: 0 + 7'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
      expect(find.text('MEM: 7'), findsOneWidget);

      await _tapCalculatorButton(tester, 'C');
      await _tapCalculatorButton(tester, '2');
      await _tapCalculatorButton(tester, 'M-');

      expect(find.text('MEM: 7 - 2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
      expect(find.text('MEM: 5'), findsOneWidget);

      await _tapCalculatorButton(tester, 'MRC');
      expect(find.text('MEM: 5'), findsOneWidget);
    });

    testWidgets('sqrt button applies immediately in infix mode', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await _openInfixEditor(tester);
      await _tapCalculatorButton(tester, '9');
      await _tapCalculatorButton(tester, 'SQRT');
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 3')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('sqrt of negative number leaves an honest matrix literal in the expression', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await _openInfixEditor(tester);
      await _tapCalculatorButton(tester, '1');
      await _tapCalculatorButton(tester, '±');
      await _tapCalculatorButton(tester, 'SQRT');
      expect(
        find.bySemanticsLabel(RegExp(r'Expression: \[\[0,-1\],\[1,0\]\]')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('operator buttons work', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await _openInfixEditor(tester);
      await _tapCalculatorButton(tester, '8');
      await _tapCalculatorButton(tester, '×');
      await _tapCalculatorButton(tester, '2');
      await _tapCalculatorButton(tester, '=');
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 16')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('percent button evaluates a bare operand on equals in infix mode', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await _openInfixEditor(tester);
      await _tapCalculatorButton(tester, '5');
      await _tapCalculatorButton(tester, '0');
      await _tapCalculatorButton(tester, '%');
      await _tapCalculatorButton(tester, '=');
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 0\.5')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('percent button supports casio-style x percent y infix flow', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await _openInfixEditor(tester);
      await _tapCalculatorButton(tester, '1');
      await _tapCalculatorButton(tester, '2');
      await _tapCalculatorButton(tester, '%');
      await _tapCalculatorButton(tester, '5');
      await _tapCalculatorButton(tester, '0');
      await _tapCalculatorButton(tester, '=');
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 6')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('percent button supports calculator-style additive infix flow', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await _openInfixEditor(tester);
      await _tapCalculatorButton(tester, '5');
      await _tapCalculatorButton(tester, '0');
      await _tapCalculatorButton(tester, '+');
      await _tapCalculatorButton(tester, '1');
      await _tapCalculatorButton(tester, '2');
      await _tapCalculatorButton(tester, '%');
      await _tapCalculatorButton(tester, '=');
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 56')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('display has expression semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await _openInfixEditor(tester);
      expect(
        find.bySemanticsLabel(RegExp(r'Expression: ')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('starts in the persistent rpn shell without a visible mode switch', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      expect(find.text('Infix'), findsNothing);
      expect(find.text('RPN'), findsNothing);
      expect(find.text('Matrix'), findsNothing);
      expect(find.byKey(const ValueKey<String>('calculator-stack-depth')), findsOneWidget);
      expect(find.text('Stack 0'), findsOneWidget);
    });

    testWidgets('edit module exposes infix and matrix editor entry points', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await tester.tap(_keypadDeckSelector('EDIT'));
      await tester.pumpAndSettle();

      expect(_calculatorButton('INFIX'), findsOneWidget);
      expect(_calculatorButton('MATRIX'), findsOneWidget);
    });

    testWidgets('module bar promotes EDIT immediately after BASIC', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      const List<String> modules = <String>[
        'BASIC',
        'EDIT',
        'STACK',
        'MATH',
        'MATRIX',
        'VECTOR',
        'FACT',
        'PROP',
        'BUILD',
        'MEM',
      ];

      for (final String module in modules) {
        expect(_keypadDeckSelector(module), findsOneWidget);
      }

      expect(
        tester.getTopLeft(_keypadDeckSelector('EDIT')).dx,
        lessThan(tester.getTopLeft(_keypadDeckSelector('STACK')).dx),
      );
    });

    testWidgets('basic module exposes the 0.7.1 seed map', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      for (final String label in <String>['MRC', 'M-', 'M+', 'AC', 'C', '%', 'SQRT', 'INV', 'i']) {
        expect(_calculatorButton(label), findsOneWidget);
      }

      expect(find.text('√'), findsOneWidget);
      expect(find.text('SQRT'), findsNothing);

      expect(_calculatorButton('>'), findsNothing);
      expect(_calculatorButton('<'), findsNothing);
    });

    testWidgets('fixed keypad leaves the infix slot empty and keeps long captions on one line',
        (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      expect(_calculatorButton('INFIX'), findsNothing);
      await _expectSingleLineButtonLabel(
        tester,
        keyLabel: '=',
        visibleLabel: 'EVAL',
      );
      await _expectSingleLineButtonLabel(
        tester,
        keyLabel: 'ENTER',
        visibleLabel: 'ENTER',
      );

      await _tapFinderCenter(tester, _keypadDeckSelector('MATRIX'));
      await _expectSingleLineButtonLabel(
        tester,
        keyLabel: 'ZEROS',
        visibleLabel: 'ZEROS',
      );

      await _tapFinderCenter(tester, _keypadDeckSelector('VECTOR'));
      await _expectSingleLineButtonLabel(
        tester,
        keyLabel: 'CROSS',
        visibleLabel: 'CROSS',
      );

      await _tapFinderCenter(tester, _keypadDeckSelector('FACT'));
      await _expectSingleLineButtonLabel(
        tester,
        keyLabel: 'SNORM',
        visibleLabel: 'SNORM',
      );
    });

    testWidgets('button captions use the math mono family', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      final Text eval = tester.widget<Text>(_calculatorButtonLabel('=', 'EVAL'));
      expect(eval.style?.fontFamily, 'JetBrainsMono');
    });

    testWidgets('only overflowing modules expose paging arrows', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      expect(_calculatorButton('>'), findsNothing);
      expect(_calculatorButton('<'), findsNothing);

      await _tapFinderCenter(tester, _keypadDeckSelector('MATRIX'));

      expect(_calculatorButton('>'), findsOneWidget);
      expect(_calculatorButton('<'), findsNothing);

      await _tapCalculatorButton(tester, '>');

      expect(_calculatorButton('<'), findsOneWidget);
      expect(_calculatorButton('TR'), findsOneWidget);
      expect(_calculatorButton('T'), findsNothing);
    });

    testWidgets('delete key semantics switch between draft editing and drop', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      expect(
        find.ancestor(
          of: _calculatorButton('DELETE'),
          matching: find.bySemanticsLabel('Drop top'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: _calculatorButton('DELETE'),
          matching: find.bySemanticsLabel('Delete draft'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('infix editor enter pushes the draft result and returns to rpn', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await tester.tap(_keypadDeckSelector('EDIT'));
      await tester.pumpAndSettle();
      await _tapCalculatorButton(tester, 'INFIX');

      expect(find.byKey(const ValueKey<String>('calculator-stack-depth')), findsNothing);

      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('+'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('calculator-stack-depth')), findsNothing);

      await tester.tap(find.text('ENTER'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('calculator-stack-depth')), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
      expect(find.descendant(
        of: _rpnStackCard(0),
        matching: find.byKey(const ValueKey<String>('calculator-display-text')),
      ), findsOneWidget);
      expect(find.text('7'), findsAtLeastNWidgets(1));
    });

    testWidgets('matrix editor cancel discards the draft and returns to rpn', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await tester.tap(_keypadDeckSelector('EDIT'));
      await tester.pumpAndSettle();
      await _tapCalculatorButton(tester, 'MATRIX');

      expect(find.byKey(const ValueKey<String>('matrix-mode-panel')), findsOneWidget);

      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');

      await _tapCalculatorButton(tester, 'CANCEL');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('matrix-mode-panel')), findsNothing);
      expect(find.text('Stack 0'), findsOneWidget);
      expect(_rpnStackCard(1), findsNothing);
      expect(_rpnDraftCard(), findsNothing);
    });

    testWidgets('matrix editor enter pushes the matrix and returns to rpn', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await tester.tap(_keypadDeckSelector('EDIT'));
      await tester.pumpAndSettle();
      await _tapCalculatorButton(tester, 'MATRIX');

      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 1, 0, '3');
      await _enterMatrixCell(tester, 1, 1, '4');

      await tester.tap(find.text('ENTER'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('matrix-mode-panel')), findsNothing);
      expect(find.text('Stack 1'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Display: \[\[1, 2\], \[3, 4\]\]')), findsOneWidget);
    });

    testWidgets('matrix editor opens from the explicit EDIT entry point', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      expect(find.byKey(const ValueKey<String>('matrix-mode-panel')), findsOneWidget);
      expect(find.text('Matrix editor'), findsNothing);
      expect(_keypadDeckSelector('EDIT'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('matrix editor preserves the same display and keypad shell sizes', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      final Size infixDisplaySize = tester.getSize(_displayShell());
      final Size infixKeypadSize = tester.getSize(_keypadShell());

      await _openMatrixEditor(tester);

      final Size matrixDisplaySize = tester.getSize(_displayShell());
      final Size matrixKeypadSize = tester.getSize(_keypadShell());

      expect((matrixDisplaySize.width - infixDisplaySize.width).abs(), lessThanOrEqualTo(1.0));
      expect((matrixDisplaySize.height - infixDisplaySize.height).abs(), lessThanOrEqualTo(1.0));
      expect((matrixKeypadSize.width - infixKeypadSize.width).abs(), lessThanOrEqualTo(1.0));
      expect((matrixKeypadSize.height - infixKeypadSize.height).abs(), lessThanOrEqualTo(1.0));
    });

    testWidgets('matrix editor hides stack depth chrome while active', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _tapCalculatorButton(tester, '4');
      await _tapCalculatorButton(tester, 'ENTER');

      expect(find.byKey(const ValueKey<String>('calculator-stack-depth')), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);

      await _openMatrixEditor(tester);

      expect(find.byKey(const ValueKey<String>('matrix-mode-panel')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('calculator-stack-depth')), findsNothing);
      expect(find.text('Stack 1'), findsNothing);
    });

    testWidgets('basic module and fixed keypad expose the stable Stage 7 controls', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      expect(_calculatorButton('7'), findsOneWidget);
      expect(_calculatorButton('='), findsOneWidget);
      expect(_calculatorButton('MRC'), findsOneWidget);
      expect(_calculatorButton('AC'), findsOneWidget);
      expect(_calculatorButton('SQRT'), findsOneWidget);
      expect(_calculatorButton('DELETE'), findsOneWidget);
      expect(find.text('⌫'), findsOneWidget);
      expect(_calculatorButton('INV'), findsOneWidget);
    });

    testWidgets('EVAL commits the rpn draft while ENTER remains available',
        (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _tapCalculatorButton(tester, '4');
      await _tapCalculatorButton(tester, '=');

      expect(_rpnDraftCard(), findsNothing);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
      expect(find.text('ENTER'), findsOneWidget);
    });

    testWidgets('RPN shows complex-form values directly as matrices', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      expect(find.text('EVAL'), findsOneWidget);
      expect(find.text('='), findsNothing);

      await _tapCalculatorButton(tester, 'i');
      await _tapCalculatorButton(tester, '1');
      await _tapCalculatorButton(tester, 'ENTER');
      await _tapCalculatorButton(tester, '+');

      expect(find.text('1 + i'), findsNothing);
      expect(
        find.bySemanticsLabel(
          RegExp(r'Display: \[\[1, -1\], \[1, 1\]\]\. Matrix 2 by 2'),
        ),
        findsOneWidget,
      );

      await _tapCalculatorButton(tester, '=');

      expect(
        find.bySemanticsLabel(
          RegExp(r'Display: \[\[1, -1\], \[1, 1\]\]\. Matrix 2 by 2'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('stack module exposes stack actions', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _tapFinderCenter(tester, _keypadDeckSelector('STACK'));

      expect(find.text('DUP'), findsOneWidget);
      expect(find.text('DROP'), findsOneWidget);
      expect(find.text('SWAP'), findsOneWidget);
      expect(find.text('ROT'), findsOneWidget);
      expect(_calculatorButton('7'), findsOneWidget);
      expect(_calculatorButton('ENTER'), findsOneWidget);
    });

    testWidgets('active rpn draft occupies the primary slot below committed X0', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _tapCalculatorButton(tester, '4');
      await _tapCalculatorButton(tester, 'ENTER');

      await _tapCalculatorButton(tester, '2');

      expect(_rpnDraftCard(), findsOneWidget);
      expect(find.descendant(of: _rpnDraftCard(), matching: find.text('2')), findsOneWidget);
      expect(find.descendant(of: _rpnStackCard(0), matching: find.text('X0')), findsOneWidget);
      expect(find.descendant(
        of: _rpnStackCard(0),
        matching: find.text('[[4]]'),
      ), findsOneWidget);
      expect(_rpnStackCard(1), findsNothing);
      expect(
        tester.getTopLeft(_rpnDraftCard()).dy,
        greaterThan(tester.getTopLeft(_rpnStackCard(0)).dy),
      );
      expect(
        tester.getSize(_rpnDraftCard()).height,
        greaterThan(tester.getSize(_rpnStackCard(0)).height),
      );
    });

    testWidgets('infix mode expands the draft card instead of replacing it with a separate surface',
        (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _tapCalculatorButton(tester, '2');
      final Size rpnDraftSize = tester.getSize(_rpnDraftCard());

      await _openInfixEditor(tester);

      expect(_rpnDraftCard(), findsOneWidget);
      expect(
        find.descendant(
          of: _rpnDraftCard(),
          matching: find.byKey(const ValueKey<String>('calculator-expression-text')),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(_rpnDraftCard()).height, greaterThan(rpnDraftSize.height));
    });

    testWidgets('matrix mode expands the draft card and hosts the embedded editor inside it',
        (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _tapCalculatorButton(tester, '2');
      final Size rpnDraftSize = tester.getSize(_rpnDraftCard());

      await _openMatrixEditor(tester);

      expect(_rpnDraftCard(), findsOneWidget);
      expect(
        find.descendant(
          of: _rpnDraftCard(),
          matching: find.byKey(const ValueKey<String>('matrix-mode-panel')),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(_rpnDraftCard()).height, greaterThan(rpnDraftSize.height));
    });

    testWidgets('uses square calculator keys', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      final Finder buttonMaterial = find.ancestor(
        of: find.text('7'),
        matching: find.byType(Material),
      ).first;

      final Size size = tester.getSize(buttonMaterial);
      expect((size.width - size.height).abs(), lessThanOrEqualTo(1.0));
    });

    testWidgets('matrix editor opens from MAT key', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      expect(find.text('Matrix editor'), findsNothing);
      expect(find.byKey(const ValueKey<String>('matrix-mode-panel')), findsOneWidget);
      expect(_calculatorButton('='), findsOneWidget);
      expect(_rowTab(0), findsOneWidget);
      expect(_rowTab(1), findsOneWidget);
      expect(_columnTab(0), findsOneWidget);
      expect(_columnTab(1), findsOneWidget);
      expect(_addRowPlaceholder(), findsOneWidget);
      expect(_addColumnPlaceholder(), findsOneWidget);
      expect(find.text('Preview unavailable until valid'), findsNothing);
      expect(find.text('Rows'), findsNothing);
      expect(find.text('Columns'), findsNothing);
      expect(find.text('['), findsNothing);
      expect(find.text(']'), findsNothing);
    });

    testWidgets('matrix editor inherits the current matrix draft content', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openInfixEditor(tester);
      await _tapCalculatorButton(tester, 'i');

      expect(
        find.bySemanticsLabel(RegExp(r'Expression: \[\[0,-1\],\[1,0\]\]')),
        findsOneWidget,
      );

      await _openMatrixEditor(tester);

      expect(_matrixEditableText(tester, 0, 0).controller.text, '0');
      expect(_matrixEditableText(tester, 0, 1).controller.text, '-1');
      expect(_matrixEditableText(tester, 1, 0).controller.text, '1');
      expect(_matrixEditableText(tester, 1, 1).controller.text, '0');
    });

    testWidgets('matrix editor uses compact structural affordances instead of cell-sized chrome', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      final Size cellSize = tester.getSize(_matrixCell(0, 0));
      final Size rowHandleSize = tester.getSize(_rowHandle(0));
      final Size columnHandleSize = tester.getSize(_columnHandle(0));
      final Size addRowButtonSize = tester.getSize(_addRowButton());
      final Size addColumnButtonSize = tester.getSize(_addColumnButton());

      expect(rowHandleSize.width, lessThan(cellSize.width * 0.45));
      expect(rowHandleSize.height, lessThan(cellSize.height * 0.75));
      expect(columnHandleSize.width, lessThan(cellSize.width * 0.45));
      expect(columnHandleSize.height, lessThan(cellSize.height * 0.45));
      expect(addRowButtonSize.width, lessThan(cellSize.width * 0.45));
      expect(addRowButtonSize.height, lessThan(cellSize.height * 0.75));
      expect(addColumnButtonSize.width, lessThan(cellSize.width * 0.45));
      expect(addColumnButtonSize.height, lessThan(cellSize.height * 0.45));
    });

    testWidgets('matrix editor add placeholders expose larger tap targets than their compact chrome', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      final Size addRowButtonSize = tester.getSize(_addRowButton());
      final Size addColumnButtonSize = tester.getSize(_addColumnButton());
      final Size addRowHitTargetSize = tester.getSize(_addRowPlaceholder());
      final Size addColumnHitTargetSize = tester.getSize(_addColumnPlaceholder());

      expect(addRowHitTargetSize.width, greaterThan(addRowButtonSize.width));
      expect(addRowHitTargetSize.height, greaterThan(addRowButtonSize.height));
      expect(addColumnHitTargetSize.width, greaterThan(addColumnButtonSize.width));
      expect(addColumnHitTargetSize.height, greaterThan(addColumnButtonSize.height));

      await _tapFinderCenter(tester, _addRowPlaceholder());
      expect(_matrixCell(2, 0), findsOneWidget);

      await _tapFinderCenter(tester, _addColumnPlaceholder());
      expect(_matrixCell(0, 2), findsOneWidget);
    });

    testWidgets('matrix editor drags a full row feedback instead of only the row marker', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(_rowHandle(0)),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();

      final Finder feedback = find.byKey(
        const ValueKey<String>('matrix-row-drag-feedback-0'),
      );
      expect(feedback, findsOneWidget);
      expect(find.descendant(of: feedback, matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: feedback, matching: find.text('2')), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('matrix editor drags a full column feedback instead of only the column marker', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 1, 0, '3');

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(_columnHandle(0)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(64, 0));
      await tester.pump();

      final Finder feedback = find.byKey(
        const ValueKey<String>('matrix-column-drag-feedback-0'),
      );
      expect(feedback, findsOneWidget);
      expect(find.descendant(of: feedback, matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: feedback, matching: find.text('3')), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    }, skip: true);

    testWidgets('matrix editor row and column tabs reveal contextual duplicate and delete actions', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      await _activateMatrixControl(tester, _rowTab(0));

      expect(find.byTooltip('Duplicate row'), findsOneWidget);
      expect(find.byTooltip('Delete row'), findsOneWidget);
      expect(find.byTooltip('Duplicate column'), findsNothing);

      await _activateMatrixControl(tester, _columnTab(1));

      expect(find.byTooltip('Duplicate row'), findsNothing);
      expect(find.byTooltip('Delete row'), findsNothing);
      expect(find.byTooltip('Duplicate column'), findsOneWidget);
      expect(find.byTooltip('Delete column'), findsOneWidget);
    });

    testWidgets('matrix editor duplicate row pushes the reordered matrix to the stack', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 1, 0, '3');
      await _enterMatrixCell(tester, 1, 1, '4');

      await _activateMatrixControl(tester, _rowTab(0));
      await tester.tap(find.byTooltip('Duplicate row'));
      await tester.pumpAndSettle();

      expect(_matrixCell(2, 0), findsOneWidget);
      expect(_matrixEditableText(tester, 0, 0).controller.text, '1');
      expect(_matrixEditableText(tester, 0, 1).controller.text, '2');
      expect(_matrixEditableText(tester, 1, 0).controller.text, '1');
      expect(_matrixEditableText(tester, 1, 1).controller.text, '2');
      expect(_matrixEditableText(tester, 2, 0).controller.text, '3');
      expect(_matrixEditableText(tester, 2, 1).controller.text, '4');

      await _tapMatrixAction(tester, 'Insert');

      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[1, 2\], \[1, 2\], \[3, 4\]\]')),
        findsOneWidget,
      );
      expect(find.text('Stack 1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('matrix editor delete column pushes the reduced matrix to the stack', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _activateMatrixControl(tester, _addColumnPlaceholder());

      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 0, 2, '3');
      await _enterMatrixCell(tester, 1, 0, '4');
      await _enterMatrixCell(tester, 1, 1, '5');
      await _enterMatrixCell(tester, 1, 2, '6');

      await _activateMatrixControl(tester, _columnTab(1));
      await tester.tap(find.byTooltip('Delete column'));
      await tester.pumpAndSettle();

      expect(_matrixCell(0, 2), findsNothing);
      expect(_matrixEditableText(tester, 0, 0).controller.text, '1');
      expect(_matrixEditableText(tester, 0, 1).controller.text, '3');
      expect(_matrixEditableText(tester, 1, 0).controller.text, '4');
      expect(_matrixEditableText(tester, 1, 1).controller.text, '6');

      await _tapMatrixAction(tester, 'Insert');

      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[1, 3\], \[4, 6\]\]')),
        findsOneWidget,
      );
      expect(find.text('Stack 1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('matrix editor keyboard fallback reorders rows from a focused row tab', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 1, 0, '3');
      await _enterMatrixCell(tester, 1, 1, '4');

      await _activateMatrixControl(tester, _rowTab(0));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(_matrixEditableText(tester, 0, 0).controller.text, '3');
      expect(_matrixEditableText(tester, 0, 1).controller.text, '4');
      expect(_matrixEditableText(tester, 1, 0).controller.text, '1');
      expect(_matrixEditableText(tester, 1, 1).controller.text, '2');
    });

    testWidgets('matrix editor keyboard fallback reorders columns from a focused column tab', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _activateMatrixControl(tester, _addColumnPlaceholder());
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 0, 2, '3');
      await _enterMatrixCell(tester, 1, 0, '4');
      await _enterMatrixCell(tester, 1, 1, '5');
      await _enterMatrixCell(tester, 1, 2, '6');

      await _activateMatrixControl(tester, _columnTab(0));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(_matrixEditableText(tester, 0, 0).controller.text, '2');
      expect(_matrixEditableText(tester, 0, 1).controller.text, '1');
      expect(_matrixEditableText(tester, 0, 2).controller.text, '3');
      expect(_matrixEditableText(tester, 1, 0).controller.text, '5');
      expect(_matrixEditableText(tester, 1, 1).controller.text, '4');
      expect(_matrixEditableText(tester, 1, 2).controller.text, '6');
    });

    testWidgets('matrix editor drag reorders rows', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 1, 0, '3');
      await _enterMatrixCell(tester, 1, 1, '4');

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(_rowHandle(0)),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(_rowHandle(1)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_matrixEditableText(tester, 0, 0).controller.text, '3');
      expect(_matrixEditableText(tester, 0, 1).controller.text, '4');
      expect(_matrixEditableText(tester, 1, 0).controller.text, '1');
      expect(_matrixEditableText(tester, 1, 1).controller.text, '2');
    }, skip: true);

    testWidgets('matrix editor drag reorders columns', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _activateMatrixControl(tester, _addColumnPlaceholder());
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 0, 2, '3');
      await _enterMatrixCell(tester, 1, 0, '4');
      await _enterMatrixCell(tester, 1, 1, '5');
      await _enterMatrixCell(tester, 1, 2, '6');

      final Offset from = tester.getCenter(_columnHandle(0));
      final Offset to = tester.getCenter(_columnHandle(1));
      await tester.dragFrom(from, Offset(to.dx - from.dx, 0));
      await tester.pumpAndSettle();

      expect(_matrixEditableText(tester, 0, 0).controller.text, '2');
      expect(_matrixEditableText(tester, 0, 1).controller.text, '1');
      expect(_matrixEditableText(tester, 0, 2).controller.text, '3');
      expect(_matrixEditableText(tester, 1, 0).controller.text, '5');
      expect(_matrixEditableText(tester, 1, 1).controller.text, '4');
      expect(_matrixEditableText(tester, 1, 2).controller.text, '6');
    }, skip: true);

    testWidgets('matrix editor pushes a 3x2 matrix after adding a row', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      await _activateMatrixControl(tester, _addRowPlaceholder());

      expect(_matrixCell(2, 0), findsOneWidget);
      expect(_matrixCell(2, 1), findsOneWidget);

      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 1, 0, '3');
      await _enterMatrixCell(tester, 1, 1, '4');
      await _enterMatrixCell(tester, 2, 0, '5');
      await _enterMatrixCell(tester, 2, 1, '6');

      await _tapMatrixAction(tester, 'Insert');

      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[1, 2\], \[3, 4\], \[5, 6\]\]')),
        findsOneWidget,
      );
      expect(find.text('Stack 1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('matrix editor pushes the serialized matrix onto the stack', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 1, 0, '3');
      await _enterMatrixCell(tester, 1, 1, '4');

      await _tapMatrixAction(tester, 'Insert');

      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[1, 2\], \[3, 4\]\]')),
        findsOneWidget,
      );
      expect(find.text('Stack 1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('matrix editor cancel keeps the rpn shell unchanged', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      await _tapMatrixAction(tester, 'Cancel');

      expect(find.bySemanticsLabel(RegExp(r'Display: 0')), findsOneWidget);
      expect(find.text('Stack 0'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('matrix editor shows validation error for incomplete matrix', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      await _enterMatrixCell(tester, 0, 0, '1');
      await _tapMatrixAction(tester, 'Insert');

      expect(find.text('Enter a value for r1 c2'), findsOneWidget);
    });

    testWidgets('matrix editor identity preset and order switch preserve hidden values', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      await _tapCalculatorButton(tester, '4x4');
      await _tapCalculatorButton(tester, 'ID');

      expect(_matrixEditableText(tester, 0, 0).controller.text, '1');
      expect(_matrixEditableText(tester, 1, 1).controller.text, '1');
      expect(_matrixEditableText(tester, 3, 3).controller.text, '1');

      await _tapCalculatorButton(tester, '2x2');
      expect(_matrixEditableText(tester, 0, 0).controller.text, '1');
      expect(_matrixEditableText(tester, 1, 1).controller.text, '1');
      expect(find.byKey(const ValueKey<String>('matrix-cell-3-3')), findsNothing);

      await _tapCalculatorButton(tester, '4x4');
      expect(_matrixEditableText(tester, 0, 0).controller.text, '1');
      expect(_matrixEditableText(tester, 3, 3).controller.text, '1');
    });

    testWidgets('matrix editor ones preset fills the visible draft', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _tapCalculatorButton(tester, 'ONES');

      expect(_matrixEditableText(tester, 0, 0).controller.text, '1');
      expect(_matrixEditableText(tester, 0, 1).controller.text, '1');
      expect(_matrixEditableText(tester, 1, 0).controller.text, '1');
    });

    testWidgets('matrix editor transpose rewrites a valid draft through the core command path', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 1, 0, '3');
      await _enterMatrixCell(tester, 1, 1, '4');

      await _tapCalculatorButton(tester, 'T');

      expect(_matrixEditableText(tester, 0, 0).controller.text, '1');
      expect(_matrixEditableText(tester, 0, 1).controller.text, '3');
      expect(_matrixEditableText(tester, 1, 0).controller.text, '2');
      expect(_matrixEditableText(tester, 1, 1).controller.text, '4');
    });

    testWidgets('memory strip keeps complex-form values in matrix form', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await _openInfixEditor(tester);

      await _tapCalculatorButton(tester, 'i');
      await _tapCalculatorButton(tester, 'M+');

      expect(find.text('MEM: 0 + [[0, -1], [1, 0]]'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
      expect(find.text('MEM: [[0, -1], [1, 0]]'), findsOneWidget);
      expect(find.text('MEM: i'), findsNothing);
      expect(find.text('MEM: 0 + i'), findsNothing);
    });

    testWidgets('matrix editor inverse rewrites a valid draft through the core command path', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '4');
      await _enterMatrixCell(tester, 0, 1, '7');
      await _enterMatrixCell(tester, 1, 0, '2');
      await _enterMatrixCell(tester, 1, 1, '6');

      await _tapCalculatorButton(tester, 'INV');

      expect(_matrixEditableText(tester, 0, 0).controller.text, startsWith('0.6'));
      expect(_matrixEditableText(tester, 0, 1).controller.text, startsWith('-0.7'));
      expect(_matrixEditableText(tester, 1, 0).controller.text, startsWith('-0.2'));
      expect(_matrixEditableText(tester, 1, 1).controller.text, startsWith('0.4'));
    });

    testWidgets('matrix editor determinant rewrites a valid draft through the core command path', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '4');
      await _enterMatrixCell(tester, 0, 1, '7');
      await _enterMatrixCell(tester, 1, 0, '2');
      await _enterMatrixCell(tester, 1, 1, '6');

      await _tapCalculatorButton(tester, 'DET');

      expect(_matrixCell(0, 0), findsOneWidget);
      expect(_matrixCell(0, 1), findsNothing);
      expect(_matrixCell(1, 0), findsNothing);
      expect(_matrixEditableText(tester, 0, 0).controller.text, '10');
    });

    testWidgets('matrix mode entered from RPN exposes a factorization deck and applies LU to the draft', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      expect(_keypadDeckSelector('FACT'), findsOneWidget);

      await _tapCalculatorButton(tester, '3x3');
      await _enterMatrixCell(tester, 0, 0, '2');
      await _enterMatrixCell(tester, 0, 1, '1');
      await _enterMatrixCell(tester, 0, 2, '1');
      await _enterMatrixCell(tester, 1, 0, '4');
      await _enterMatrixCell(tester, 1, 1, '-6');
      await _enterMatrixCell(tester, 1, 2, '0');
      await _enterMatrixCell(tester, 2, 0, '-2');
      await _enterMatrixCell(tester, 2, 1, '7');
      await _enterMatrixCell(tester, 2, 2, '2');

      await tester.tap(_keypadDeckSelector('FACT'));
      await tester.pumpAndSettle();
      await _tapCalculatorButton(tester, 'LU');

      expect(find.byKey(const ValueKey<String>('matrix-mode-panel')), findsNothing);
      expect(find.text('Stack 3'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('rpn-stack-card-0')), findsOneWidget);
      expect(find.text('[4 -6 0]\n[0  4 1]\n[0  0 1]'), findsOneWidget);
    });

    testWidgets('matrix mode entered from RPN applies QR to the draft and returns to the stack view', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '0');
      await _enterMatrixCell(tester, 1, 0, '0');
      await _enterMatrixCell(tester, 1, 1, '2');

      await tester.tap(_keypadDeckSelector('FACT'));
      await tester.pumpAndSettle();
      await _tapCalculatorButton(tester, 'QR');

      expect(find.byKey(const ValueKey<String>('matrix-mode-panel')), findsNothing);
      expect(find.text('Stack 2'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('rpn-stack-card-0')), findsOneWidget);
      expect(find.text('[1 0]\n[0 2]'), findsOneWidget);
    });

    testWidgets('matrix editor disables identity for non-square shapes', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _activateMatrixControl(tester, _addRowPlaceholder());

      await _tapCalculatorButton(tester, 'ID');

      expect(_matrixCell(2, 0), findsOneWidget);
      expect(_matrixCell(2, 1), findsOneWidget);
      expect(_matrixCell(0, 2), findsNothing);
    });

    testWidgets('matrix editor separates keyboard navigation from edit mode', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      expect(_matrixEditableText(tester, 0, 0).focusNode.hasFocus, isTrue);
      expect(_matrixEditableText(tester, 0, 0).readOnly, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(_matrixEditableText(tester, 0, 1).focusNode.hasFocus, isTrue);
      expect(_matrixEditableText(tester, 0, 1).readOnly, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(_matrixEditableText(tester, 0, 1).readOnly, isFalse);

      await tester.enterText(_matrixCell(0, 1), '7');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_matrixEditableText(tester, 0, 1).focusNode.hasFocus, isTrue);
      expect(_matrixEditableText(tester, 0, 1).readOnly, isTrue);
      expect(_matrixEditableText(tester, 0, 1).controller.text, isEmpty);
    });

    testWidgets('matrix editor tab commits the current cell and advances focus', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.enterText(_matrixCell(0, 0), '5');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(_matrixEditableText(tester, 0, 0).controller.text, '5');
      expect(_matrixEditableText(tester, 0, 0).readOnly, isTrue);
      expect(_matrixEditableText(tester, 0, 1).focusNode.hasFocus, isTrue);
      expect(_matrixEditableText(tester, 0, 1).readOnly, isTrue);
    });

    testWidgets('matrix editor keypad replaces selected cell on first key and appends afterwards', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '12');

      await _tapFinderCenter(tester, _matrixCell(0, 0));
      await _tapCalculatorButton(tester, '7');
      expect(_matrixEditableText(tester, 0, 0).controller.text, '7');

      await _tapCalculatorButton(tester, '8');
      expect(_matrixEditableText(tester, 0, 0).controller.text, '78');
    });

    testWidgets('matrix editor keypad normalizes a leading decimal point to 0.', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      await _tapFinderCenter(tester, _matrixCell(0, 0));
      await _tapCalculatorButton(tester, '.');

      expect(_matrixEditableText(tester, 0, 0).controller.text, '0.');
    });

    testWidgets('matrix editor keeps actions usable while editing a 4x4 draft', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _tapCalculatorButton(tester, '4x4');
      await _tapCalculatorButton(tester, 'ZEROS');
      await _enterMatrixCell(tester, 3, 3, '9');

      await _ensureCalculatorButtonVisible(tester, 'CANCEL');
      expect(_calculatorButton('CANCEL'), findsOneWidget);
      expect(_calculatorButton('='), findsOneWidget);

      await _tapMatrixAction(tester, 'Insert');

      expect(
        find.bySemanticsLabel(
          RegExp(
            r'Display: \[\[0, 0, 0, 0\], \[0, 0, 0, 0\], \[0, 0, 0, 0\], \[0, 0, 0, 9\]\]',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Stack 1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('shell keeps EVAL and ENTER visible in RPN and reuses the key as = in infix', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      expect(find.text('ENTER'), findsOneWidget);
      expect(find.text('EVAL'), findsOneWidget);
      expect(find.text('='), findsNothing);

      await _openInfixEditor(tester);

      expect(find.text('='), findsOneWidget);
      expect(find.text('EVAL'), findsNothing);
    });

    testWidgets('rpn mode renders the committed top as X0 without duplicating the display', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _tapCalculatorButton(tester, '4');
      await _tapCalculatorButton(tester, '2');
      await _tapCalculatorButton(tester, 'ENTER');

      expect(find.bySemanticsLabel(RegExp(r'Stack depth: 1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('rpn-stack-card-0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('rpn-stack-card-1')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('rpn-stack-card-0')),
          matching: find.text('X0'),
        ),
        findsOneWidget,
      );
      expect(find.text('[[42]]'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('calculator-expression-text')), findsNothing);
      handle.dispose();
    });

    testWidgets('when a draft exists X0 and X1 share the same stack styling', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _tapCalculatorButton(tester, '4');
      await _tapCalculatorButton(tester, 'ENTER');
      await _tapCalculatorButton(tester, '5');
      await _tapCalculatorButton(tester, 'ENTER');
      await _tapCalculatorButton(tester, '7');

      expect(find.byKey(const ValueKey<String>('rpn-stack-card-0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('rpn-stack-card-1')), findsOneWidget);
      expect(_rpnDraftCard(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('rpn-stack-card-0')),
          matching: find.text('X0'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('rpn-stack-card-1')),
          matching: find.text('X1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _rpnDraftCard(),
          matching: find.text('7'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(_rpnDraftCard()).dy,
        greaterThan(tester.getTopLeft(find.byKey(const ValueKey<String>('rpn-stack-card-0'))).dy),
      );
      expect(
        (tester.getSize(find.byKey(const ValueKey<String>('rpn-stack-card-0'))).height -
                tester.getSize(find.byKey(const ValueKey<String>('rpn-stack-card-1'))).height)
            .abs(),
        lessThanOrEqualTo(1.0),
      );
      expect(
        tester.getSize(_rpnDraftCard()).height,
        greaterThan(tester.getSize(find.byKey(const ValueKey<String>('rpn-stack-card-0'))).height),
      );
      expect(find.byKey(const ValueKey<String>('calculator-expression-text')), findsNothing);
      handle.dispose();
    });

    testWidgets('rpn mode exposes matrix command actions from the matrix deck', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _tapFinderCenter(tester, _keypadDeckSelector('MATRIX'));

      expect(find.text('T'), findsOneWidget);
      expect(find.text('INV'), findsOneWidget);
      expect(find.text('DET'), findsOneWidget);
      expect(find.text('AROW'), findsOneWidget);
      expect(find.text('ACOL'), findsOneWidget);
    });

    testWidgets('rpn mode exposes factorization actions from the factor deck', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _tapFinderCenter(tester, _keypadDeckSelector('FACT'));

      expect(find.text('LU'), findsOneWidget);
      expect(find.text('QR'), findsOneWidget);
      expect(find.text('EIG'), findsOneWidget);
      expect(find.text('DIAG'), findsOneWidget);
      expect(find.text('COF'), findsOneWidget);
      expect(find.text('ADJ'), findsOneWidget);
    });

    testWidgets('rpn mode exposes direct matrix command buttons and applies transpose', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 1, 0, '3');
      await _enterMatrixCell(tester, 1, 1, '4');
      await _tapMatrixAction(tester, 'Push');

      await _tapFinderCenter(tester, _keypadDeckSelector('MATRIX'));

      expect(find.text('T'), findsOneWidget);
      expect(find.text('ZEROS'), findsOneWidget);

      await tester.tap(find.text('T'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[1, 3\], \[2, 4\]\]')),
        findsOneWidget,
      );
    });

    testWidgets('rpn mode exposes determinant and applies it to the top matrix', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '4');
      await _enterMatrixCell(tester, 0, 1, '7');
      await _enterMatrixCell(tester, 1, 0, '2');
      await _enterMatrixCell(tester, 1, 1, '6');
      await _tapMatrixAction(tester, 'Push');

      await _tapFinderCenter(tester, _keypadDeckSelector('MATRIX'));
      await _tapCalculatorButton(tester, 'DET');

      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[10\]\]')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('rpn mode applies LU decomposition and expands the stack', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _tapCalculatorButton(tester, '3x3');
      await _enterMatrixCell(tester, 0, 0, '2');
      await _enterMatrixCell(tester, 0, 1, '1');
      await _enterMatrixCell(tester, 0, 2, '1');
      await _enterMatrixCell(tester, 1, 0, '4');
      await _enterMatrixCell(tester, 1, 1, '-6');
      await _enterMatrixCell(tester, 1, 2, '0');
      await _enterMatrixCell(tester, 2, 0, '-2');
      await _enterMatrixCell(tester, 2, 1, '7');
      await _enterMatrixCell(tester, 2, 2, '2');
      await _tapMatrixAction(tester, 'Push');

      await _tapFinderCenter(tester, _keypadDeckSelector('FACT'));
      await _tapCalculatorButton(tester, 'LU');

      expect(find.bySemanticsLabel(RegExp(r'Stack depth: 3')), findsOneWidget);
      expect(find.text('Stack 3'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[4, -6, 0\], \[0, 4, 1\], \[0, 0, 1\]\]')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('rpn mode applies QR decomposition and expands the stack', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '0');
      await _enterMatrixCell(tester, 1, 0, '0');
      await _enterMatrixCell(tester, 1, 1, '2');
      await _activateMatrixControl(tester, _addRowPlaceholder());
      await _enterMatrixCell(tester, 2, 0, '0');
      await _enterMatrixCell(tester, 2, 1, '0');
      await _tapMatrixAction(tester, 'Push');

      await _tapFinderCenter(tester, _keypadDeckSelector('FACT'));
      await _tapCalculatorButton(tester, 'QR');

      expect(find.bySemanticsLabel(RegExp(r'Stack depth: 2')), findsOneWidget);
      expect(find.text('Stack 2'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[1, 0\], \[0, 2\]\]')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('rpn mode applies eigenvalues to the committed top matrix', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '2');
      await _enterMatrixCell(tester, 0, 1, '0');
      await _enterMatrixCell(tester, 1, 0, '0');
      await _enterMatrixCell(tester, 1, 1, '3');
      await _tapMatrixAction(tester, 'Push');

      await _tapFinderCenter(tester, _keypadDeckSelector('FACT'));
      await _tapCalculatorButton(tester, 'EIG');

      expect(find.bySemanticsLabel(RegExp(r'Stack depth: 1')), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[3\], \[2\]\]')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('rpn mode reproduces append row and column workflows with direct matrix macros', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 1, 0, '3');
      await _enterMatrixCell(tester, 1, 1, '4');
      await _tapMatrixAction(tester, 'Push');

      await _tapFinderCenter(tester, _keypadDeckSelector('MATRIX'));

      await _ensureCalculatorButtonVisible(tester, 'AROW');
      expect(find.text('AROW'), findsOneWidget);
      expect(find.text('ACOL'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(find.text('INV'), findsOneWidget);
      expect(find.text('DET'), findsOneWidget);
      expect(find.text('ZEROS'), findsOneWidget);
      expect(find.text('ONES'), findsOneWidget);

      await _tapCalculatorButton(tester, 'AROW');

      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[1, 2\], \[3, 4\], \[0, 0\]\]')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'Stack depth: 1')), findsOneWidget);

      await _tapCalculatorButton(tester, 'ACOL');

      expect(
        find.bySemanticsLabel(
          RegExp(r'Display: \[\[1, 2, 0\], \[3, 4, 0\], \[0, 0, 0\]\]'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'Stack depth: 1')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('rpn shell renders non-scalar matrix results in the committed display', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '3');
      await _enterMatrixCell(tester, 0, 1, '4');
      await _enterMatrixCell(tester, 1, 0, '5');
      await _enterMatrixCell(tester, 1, 1, '6');
      await _tapMatrixAction(tester, 'Insert');

      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[3, 4\], \[5, 6\]\]')),
        findsOneWidget,
      );
      expect(find.text('[3 4]\n[5 6]'), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
      handle.dispose();
    });
  });
}

