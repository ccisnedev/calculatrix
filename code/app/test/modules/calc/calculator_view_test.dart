import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calculatrix_app/main.dart';

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
  });
}

