import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:calculatrix_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Calculator integration tests', () {
    testWidgets('notation mode switch is visible and interactive', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Infix mode'), findsOneWidget);
      expect(find.bySemanticsLabel('RPN mode'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('RPN mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Infix mode'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp(r'Display: 0')), findsOneWidget);
    });

    testWidgets('3 + 4 = 7', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('3'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Plus'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('4'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Equals'));
      await tester.pump();

      expect(
        find.bySemanticsLabel(RegExp(r'Display: 7')),
        findsOneWidget,
      );
    });

    testWidgets('precedence: 2 + 3 × 4 = 14', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('2'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Plus'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('3'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Multiply'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('4'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Equals'));
      await tester.pump();

      expect(
        find.bySemanticsLabel(RegExp(r'Display: 14')),
        findsOneWidget,
      );
    });

    testWidgets('clear resets after calculation', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('5'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Multiply'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('5'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Equals'));
      await tester.pump();

      expect(find.bySemanticsLabel(RegExp(r'Display: 25')), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Clear'));
      await tester.pump();

      expect(find.bySemanticsLabel(RegExp(r'Display: 0')), findsOneWidget);
    });

    testWidgets('chaining: result + new operation', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await tester.pumpAndSettle();

      // 6 × 7 = 42
      await tester.tap(find.bySemanticsLabel('6'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Multiply'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('7'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Equals'));
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp(r'Display: 42')), findsOneWidget);

      // 42 + 8 = 50
      await tester.tap(find.bySemanticsLabel('Plus'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('8'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Equals'));
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp(r'Display: 50')), findsOneWidget);
    });

    testWidgets('parentheses: (2 + 3) × 4 = 20', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Left parenthesis'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('2'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Plus'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('3'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Right parenthesis'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Multiply'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('4'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Equals'));
      await tester.pump();

      expect(find.bySemanticsLabel(RegExp(r'Display: 20')), findsOneWidget);
    });

    testWidgets('decimal: 1 ÷ 4 = 0.25', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('1'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Divide'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('4'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Equals'));
      await tester.pump();

      expect(find.bySemanticsLabel(RegExp(r'Display: 0\.25')), findsOneWidget);
    });

    testWidgets('matrix editor inserts a matrix literal into infix input', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Matrix editor'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-0-0')), '1');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-0-1')), '2');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-1-0')), '3');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-1-1')), '4');
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Expression: \[\[1,2\],\[3,4\]\]')),
        findsOneWidget,
      );
    });

    testWidgets('infix mode displays a non-scalar matrix result', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Matrix editor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-0-0')), '1');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-0-1')), '0');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-1-0')), '0');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-1-1')), '1');
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Multiply'));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Matrix editor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-0-0')), '3');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-0-1')), '4');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-1-0')), '5');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-1-1')), '6');
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Equals'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Display: \[\[3, 4\], \[5, 6\]\]')),
        findsOneWidget,
      );
    });

    testWidgets('rpn mode commits with ENTER and applies binary addition', (tester) async {
      await tester.pumpWidget(const CalculatrixApp());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('RPN mode'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('4'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('2'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Enter'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('8'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Enter'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Plus'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp(r'Display: \[\[50\]\]')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Stack depth: 1')), findsOneWidget);
    });
  });
}

