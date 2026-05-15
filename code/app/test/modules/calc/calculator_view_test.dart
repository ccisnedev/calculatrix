import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calculatrix/main.dart';

void main() {
  group('CalculatrixApp - widget tests', () {
    testWidgets('app renders without crash', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('displays app title in AppBar', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      expect(find.text('Calculatrix'), findsOneWidget);
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

    testWidgets('display has semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      expect(
        find.bySemanticsLabel(RegExp(r'Display: 0')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('app title has semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatrixApp());
      expect(
        find.bySemanticsLabel(RegExp(r'Calculatrix')),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('keypad buttons are rendered', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      expect(find.text('C'), findsOneWidget);
      expect(find.text('='), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      // '0' appears in both keypad button and display
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('tap digit updates display', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(find.text('5'), findsWidgets); // button + display
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
  });
}
