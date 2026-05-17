import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calculatrix_app/main.dart';

Finder _matrixCell(int row, int column) {
  return find.byKey(ValueKey<String>('matrix-cell-$row-$column'));
}

EditableText _matrixEditableText(WidgetTester tester, int row, int column) {
  return tester.widget<EditableText>(
    find.descendant(
      of: _matrixCell(row, column),
      matching: find.byType(EditableText),
    ),
  );
}

Future<void> _openMatrixEditor(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-500, 0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('MAT'));
  await tester.pumpAndSettle();
}

Future<void> _enterMatrixCell(
  WidgetTester tester,
  int row,
  int column,
  String value,
) async {
  final Finder cell = _matrixCell(row, column);
  await tester.tap(cell);
  await tester.pumpAndSettle();
  await tester.enterText(cell, value);
  await tester.pumpAndSettle();
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

    testWidgets('keypad has all buttons', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      final expected = [
        'MC', 'MR', 'M-', 'M+',
        'C', '√', '%', '÷',
        '7', '8', '9', '×',
        '4', '5', '6', '-',
        '1', '2', '3', '+',
        '±', '.', '=',
      ];
      for (final label in expected) {
        expect(find.text(label), findsOneWidget,
            reason: 'Button "$label" not found');
      }
      // '0' appears in both display and button
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('tap digit updates expression', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp(r'Expression: 5')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('tap equals evaluates expression', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('+'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.tap(find.text('='));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 7')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('clear button resets display', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.tap(find.text('C'));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 0')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('sqrt button works', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await tester.tap(find.text('√'));
      await tester.pump();
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.tap(find.text('='));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 3')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('operator buttons work', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      await tester.tap(find.text('8'));
      await tester.pump();
      await tester.tap(find.text('×'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('='));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 16')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('percent button works', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      // 50% = 0.5
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('%'));
      await tester.pump();
      await tester.tap(find.text('='));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 0\.5')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('display has expression semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      expect(
        find.bySemanticsLabel(RegExp(r'Expression: ')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('shows visible notation mode switch', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      expect(find.text('Infix'), findsOneWidget);
      expect(find.text('RPN'), findsOneWidget);
    });

    testWidgets('supports horizontal keypad paging', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      expect(find.text('('), findsNothing);

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('('), findsOneWidget);
      expect(find.text('⌫'), findsOneWidget);
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

      expect(find.text('Matrix editor'), findsOneWidget);
      expect(find.text('2x2'), findsOneWidget);
      expect(find.text('3x3'), findsOneWidget);
      expect(find.text('4x4'), findsOneWidget);
      expect(find.text('Zeros'), findsOneWidget);
      expect(find.text('Identity'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Preview unavailable until valid'), findsOneWidget);
      expect(find.text('Rows'), findsNothing);
      expect(find.text('Columns'), findsNothing);
    });

    testWidgets('matrix editor inserts serialized matrix into infix expression', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '2');
      await _enterMatrixCell(tester, 1, 0, '3');
      await _enterMatrixCell(tester, 1, 1, '4');

      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Expression: \[\[1,2\],\[3,4\]\]')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('matrix editor cancel keeps expression unchanged', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp(r'Display: 0')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('matrix editor shows validation error for incomplete matrix', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      await _enterMatrixCell(tester, 0, 0, '1');
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a value for r1 c2'), findsOneWidget);
    });

    testWidgets('matrix editor identity preset and order switch preserve hidden values', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);

      await tester.tap(find.text('4x4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Identity'));
      await tester.pumpAndSettle();

      expect(
        find.text('Preview: [[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]'),
        findsOneWidget,
      );

      await tester.tap(find.text('2x2'));
      await tester.pumpAndSettle();
      expect(find.text('Preview: [[1,0],[0,1]]'), findsOneWidget);

      await tester.tap(find.text('4x4'));
      await tester.pumpAndSettle();
      expect(
        find.text('Preview: [[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]'),
        findsOneWidget,
      );
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

    testWidgets('matrix editor keeps actions usable while editing a 4x4 draft', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await tester.tap(find.text('4x4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zeros'));
      await tester.pumpAndSettle();
      await _enterMatrixCell(tester, 3, 3, '9');

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Insert'), findsOneWidget);

      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          RegExp(
            r'Expression: \[\[0,0,0,0\],\[0,0,0,0\],\[0,0,0,0\],\[0,0,0,9\]\]',
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('switching to rpn relabels the primary action to ENTER', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await tester.tap(find.text('RPN'));
      await tester.pumpAndSettle();

      expect(find.text('ENTER'), findsOneWidget);
      expect(find.text('='), findsNothing);
    });

    testWidgets('rpn mode renders the committed top as X0 without duplicating the display', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await tester.tap(find.text('RPN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('ENTER'));
      await tester.pumpAndSettle();

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

    testWidgets('rpn mode shows the draft in X0 and the committed top in X1', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await tester.tap(find.text('RPN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.tap(find.text('ENTER'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7'));
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('rpn-stack-card-0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('rpn-stack-card-1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('rpn-stack-card-0')),
          matching: find.text('X0'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('rpn-stack-card-0')),
          matching: find.text('7'),
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
          of: find.byKey(const ValueKey<String>('rpn-stack-card-1')),
          matching: find.text('[[4]]'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<String>('rpn-stack-card-1'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey<String>('rpn-stack-card-0'))).dy),
      );
      expect(find.byKey(const ValueKey<String>('calculator-expression-text')), findsNothing);
      handle.dispose();
    });

    testWidgets('rpn mode exposes a stack actions page', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());

      await tester.tap(find.text('RPN'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('DUP'), findsOneWidget);
      expect(find.text('DROP'), findsOneWidget);
      expect(find.text('SWAP'), findsOneWidget);
    });

    testWidgets('infix mode renders non-scalar matrix results in the display', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());

      await _openMatrixEditor(tester);
      await _enterMatrixCell(tester, 0, 0, '1');
      await _enterMatrixCell(tester, 0, 1, '0');
      await _enterMatrixCell(tester, 1, 0, '0');
      await _enterMatrixCell(tester, 1, 1, '1');
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('×'));
      await tester.pump();

      await tester.tap(find.text('MAT'));
      await tester.pumpAndSettle();
      await _enterMatrixCell(tester, 0, 0, '3');
      await _enterMatrixCell(tester, 0, 1, '4');
      await _enterMatrixCell(tester, 1, 0, '5');
      await _enterMatrixCell(tester, 1, 1, '6');
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[3, 4\], \[5, 6\]\]')),
        findsOneWidget,
      );
      expect(find.text('[3 4]\n[5 6]'), findsOneWidget);
      handle.dispose();
    });
  });
}

