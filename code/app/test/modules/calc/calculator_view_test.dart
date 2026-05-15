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
      await tester.pumpWidget(const CalculatrixApp());
      expect(find.text('0'), findsOneWidget);
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
  });
}
