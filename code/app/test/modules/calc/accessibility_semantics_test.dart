import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calculatrix_app/main.dart';

Finder _calculatorButton(String label) {
  return find.byKey(ValueKey<String>('calculator-button-$label'));
}

Finder _keypadDeckSelector(String label) {
  return find.byKey(ValueKey<String>('calculator-keypad-deck-$label'));
}

Future<void> _ensureDeck(WidgetTester tester, String deck) async {
  final Finder selector = _keypadDeckSelector(deck);
  if (selector.evaluate().isNotEmpty) {
    await tester.tap(selector);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Accessibility - Semantics labels', () {
    testWidgets('display has live region with initial value', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      expect(
        find.bySemanticsLabel(RegExp(r'Display: 0')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('expression area has live region', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await tester.tap(_calculatorButton('INFIX'));
      await tester.pumpAndSettle();
      await tester.tap(_calculatorButton('5'));
      await tester.pump();

      expect(
        find.bySemanticsLabel(RegExp(r'Expression: 5')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('keypad buttons have descriptive semantic labels',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      // Verify buttons visible in MAIN deck have semantic labels
      final expectations = <String, String>{
        'C': 'Clear',
        '√': 'Square root',
        '%': 'Percent',
        '÷': 'Divide',
        '+': 'Plus',
        '-': 'Minus',
        '×': 'Multiply',
        '±': 'Toggle sign',
        '.': 'Decimal point',
      };

      for (final entry in expectations.entries) {
        final button = _calculatorButton(entry.key);
        if (button.evaluate().isEmpty) continue;

        expect(
          find.ancestor(
            of: button,
            matching: find.bySemanticsLabel(entry.value),
          ),
          findsOneWidget,
          reason:
              'Button "${entry.key}" should have semantic label "${entry.value}"',
        );
      }
      handle.dispose();
    });

    testWidgets('editor entry buttons have descriptive semantic labels',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      expect(
        find.bySemanticsLabel('Open infix editor'),
        findsOneWidget,
      );
      await _ensureDeck(tester, 'EDIT');
      expect(
        find.bySemanticsLabel('Open matrix editor'),
        findsAtLeastNWidgets(1),
      );
      handle.dispose();
    });

    testWidgets('module selectors have descriptive labels', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      expect(
        find.bySemanticsLabel('Basic commands module'),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.bySemanticsLabel('Editor entry points module'),
        findsAtLeastNWidgets(1),
      );
      handle.dispose();
    });

    testWidgets('RPN function buttons have descriptive labels',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      // Check stack operations deck
      await _ensureDeck(tester, 'STACK');
      final stackButtons = <String, String>{
        'DUP': 'Duplicate top',
        'DROP': 'Drop top',
        'SWAP': 'Swap top two',
      };

      for (final entry in stackButtons.entries) {
        final button = _calculatorButton(entry.key);
        if (button.evaluate().isNotEmpty) {
          expect(
            find.ancestor(
              of: button,
              matching: find.bySemanticsLabel(entry.value),
            ),
            findsOneWidget,
            reason:
                'Button "${entry.key}" should have semantic label "${entry.value}"',
          );
        }
      }

      // Check matrix operations deck
      await _ensureDeck(tester, 'MATRIX');
      final matrixButtons = <String, String>{
        'RREF': 'Reduced Row Echelon Form',
        'DET': 'Determinant of top matrix',
        'INV': 'Invert top matrix',
        'T': 'Transpose top matrix',
      };

      for (final entry in matrixButtons.entries) {
        final button = _calculatorButton(entry.key);
        if (button.evaluate().isNotEmpty) {
          expect(
            find.ancestor(
              of: button,
              matching: find.bySemanticsLabel(entry.value),
            ),
            findsOneWidget,
            reason:
                'Button "${entry.key}" should have semantic label "${entry.value}"',
          );
        }
      }

      handle.dispose();
    });

    testWidgets('matrix editor cells have descriptive labels',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _ensureDeck(tester, 'EDIT');
      await tester.pumpAndSettle();

      final matButton = _calculatorButton('MATRIX');
      await tester.tap(matButton);
      await tester.pumpAndSettle();

      // Matrix cells should have "Row N, Column N" labels
      final cell = find.byKey(const ValueKey<String>('matrix-cell-0-0'));
      if (cell.evaluate().isNotEmpty) {
        final TextField tf = tester.widget<TextField>(
          find.descendant(of: cell, matching: find.byType(TextField)),
        );
        expect(tf.decoration?.labelText, 'Row 1, Column 1');
      }
      handle.dispose();
    });

    testWidgets('matrix editor handles have tooltips', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _ensureDeck(tester, 'EDIT');
      await tester.pumpAndSettle();

      final matButton = _calculatorButton('MATRIX');
      await tester.tap(matButton);
      await tester.pumpAndSettle();

      // Row handle (IconButton has key matrix-row-tab-0)
      final rowTab =
          find.byKey(const ValueKey<String>('matrix-row-tab-0'));
      if (rowTab.evaluate().isNotEmpty) {
        final IconButton ib = tester.widget<IconButton>(rowTab);
        expect(ib.tooltip, isNotNull);
        expect(ib.tooltip, contains('Row'));
      }

      // Column handle (IconButton has key matrix-column-tab-0)
      final colTab =
          find.byKey(const ValueKey<String>('matrix-column-tab-0'));
      if (colTab.evaluate().isNotEmpty) {
        final IconButton ib = tester.widget<IconButton>(colTab);
        expect(ib.tooltip, isNotNull);
        expect(ib.tooltip, contains('Column'));
      }
      handle.dispose();
    });
  });
}
