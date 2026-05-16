import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:calculatrix_app/main.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(CalculatrixApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Infix'));
  await tester.pumpAndSettle();
}

Future<void> _tapEquals(WidgetTester tester) async {
  if (_button('=').evaluate().isEmpty) {
    await tester.tap(find.text('Infix'));
    await tester.pumpAndSettle();
  }

  if (_button('=').evaluate().isEmpty) {
    await tester.drag(find.byType(PageView), const Offset(1000, 0));
    await tester.pumpAndSettle();
  }

  await tester.tap(_button('='));
  await tester.pump();
}

Future<void> _switchMode(WidgetTester tester, String mode) async {
  await tester.tap(find.text(mode));
  await tester.pumpAndSettle();
}

Future<void> _showRpnStackPage(WidgetTester tester) async {
  if (_button('SWAP').evaluate().isNotEmpty) {
    return;
  }

  await tester.drag(find.byType(PageView), const Offset(-1000, 0));
  await tester.pumpAndSettle();
}

Future<void> _submitMatrix(
  WidgetTester tester,
  List<List<String>> values, {
  required String actionLabel,
}) async {
  await tester.tap(_button('MAT'));
  await tester.pumpAndSettle();

  for (int row = 0; row < values.length; row++) {
    for (int column = 0; column < values[row].length; column++) {
      await tester.enterText(
        find.byKey(ValueKey<String>('matrix-cell-$row-$column')),
        values[row][column],
      );
    }
  }

  await tester.tap(find.text(actionLabel));
  await tester.pumpAndSettle();
}

Finder _button(String label) {
  if (label == '=') {
    return find.text('=');
  }

  return find.byKey(ValueKey<String>('calculator-button-$label'));
}

Finder _keyedText(String key, String value) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is Text &&
        widget.key == ValueKey<String>(key) &&
        widget.data == value,
  );
}

Finder _displayText(String value) {
  return _keyedText('calculator-display-text', value);
}

Finder _expressionText(String value) {
  return _keyedText('calculator-expression-text', value);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Calculator integration tests', () {
    testWidgets('notation mode switch is visible and interactive', (tester) async {
      await _pumpApp(tester);

      expect(find.text('Infix'), findsOneWidget);
      expect(find.text('RPN'), findsOneWidget);

      await tester.tap(find.text('RPN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Infix'));
      await tester.pumpAndSettle();

      expect(_displayText('0'), findsOneWidget);
    });

    testWidgets('3 + 4 = 7', (tester) async {
      await _pumpApp(tester);

      await tester.tap(_button('3'));
      await tester.pump();
      await tester.tap(_button('+'));
      await tester.pump();
      await tester.tap(_button('4'));
      await tester.pump();
      await _tapEquals(tester);

      expect(_displayText('7'), findsOneWidget);
    });

    testWidgets('precedence: 2 + 3 × 4 = 14', (tester) async {
      await _pumpApp(tester);

      await tester.tap(_button('2'));
      await tester.pump();
      await tester.tap(_button('+'));
      await tester.pump();
      await tester.tap(_button('3'));
      await tester.pump();
      await tester.tap(_button('×'));
      await tester.pump();
      await tester.tap(_button('4'));
      await tester.pump();
      await _tapEquals(tester);

      expect(_displayText('14'), findsOneWidget);
    });

    testWidgets('clear resets after calculation', (tester) async {
      await _pumpApp(tester);

      await tester.tap(_button('5'));
      await tester.pump();
      await tester.tap(_button('×'));
      await tester.pump();
      await tester.tap(_button('5'));
      await tester.pump();
      await _tapEquals(tester);

      expect(_displayText('25'), findsOneWidget);

      await tester.tap(_button('C'));
      await tester.pump();

      expect(_displayText('0'), findsOneWidget);
    });

    testWidgets('chaining: result + new operation', (tester) async {
      await _pumpApp(tester);

      // 6 × 7 = 42
      await tester.tap(_button('6'));
      await tester.pump();
      await tester.tap(_button('×'));
      await tester.pump();
      await tester.tap(_button('7'));
      await tester.pump();
      await _tapEquals(tester);
      expect(_displayText('42'), findsOneWidget);

      // 42 + 8 = 50
      await tester.tap(_button('+'));
      await tester.pump();
      await tester.tap(_button('8'));
      await tester.pump();
      await _tapEquals(tester);
      expect(_displayText('50'), findsOneWidget);
    });

    testWidgets('parentheses: (2 + 3) × 4 = 20', (tester) async {
      await _pumpApp(tester);

      await tester.drag(find.byType(PageView), const Offset(-1000, 0));
      await tester.pumpAndSettle();

      await tester.tap(_button('('));
      await tester.pump();
      await tester.tap(_button('2'));
      await tester.pump();
      await tester.tap(_button('+'));
      await tester.pump();
      await tester.tap(_button('3'));
      await tester.pump();
      await tester.tap(_button(')'));
      await tester.pump();
      await tester.tap(_button('×'));
      await tester.pump();
      await tester.tap(_button('4'));
      await tester.pump();
      await _tapEquals(tester);

      expect(_displayText('20'), findsOneWidget);
    });

    testWidgets('decimal: 1 ÷ 4 = 0.25', (tester) async {
      await _pumpApp(tester);

      await tester.tap(_button('1'));
      await tester.pump();
      await tester.tap(_button('÷'));
      await tester.pump();
      await tester.tap(_button('4'));
      await tester.pump();
      await _tapEquals(tester);

      expect(_displayText('0.25'), findsOneWidget);
    });

    testWidgets('matrix editor inserts a matrix literal into infix input', (tester) async {
      await _pumpApp(tester);

      await tester.drag(find.byType(PageView), const Offset(-1000, 0));
      await tester.pumpAndSettle();

      await tester.tap(_button('MAT'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-0-0')), '1');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-0-1')), '2');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-1-0')), '3');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-1-1')), '4');
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      expect(_expressionText('[[1,2],[3,4]]'), findsOneWidget);
    });

    testWidgets('infix mode displays a non-scalar matrix result', (tester) async {
      await _pumpApp(tester);

      await tester.drag(find.byType(PageView), const Offset(-1000, 0));
      await tester.pumpAndSettle();

      await tester.tap(_button('MAT'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-0-0')), '1');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-0-1')), '0');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-1-0')), '0');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-1-1')), '1');
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      await tester.tap(_button('×'));
      await tester.pump();

      await tester.tap(_button('MAT'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-0-0')), '3');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-0-1')), '4');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-1-0')), '5');
      await tester.enterText(find.byKey(const ValueKey<String>('matrix-cell-1-1')), '6');
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(1000, 0));
      await tester.pumpAndSettle();
      await _tapEquals(tester);

      expect(_displayText('[3 4]\n[5 6]'), findsOneWidget);
    });

    testWidgets('infix mode multiplies a matrix by a scalar 1x1', (tester) async {
      await _pumpApp(tester);

      await tester.drag(find.byType(PageView), const Offset(-1000, 0));
      await tester.pumpAndSettle();

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['1', '0'],
          <String>['0', '1'],
        ],
        actionLabel: 'Insert',
      );

      await tester.tap(_button('×'));
      await tester.pump();
      await tester.tap(_button('3'));
      await tester.pump();

      await _tapEquals(tester);

      expect(_displayText('[3 0]\n[0 3]'), findsOneWidget);
    });

    testWidgets('rpn mode commits with ENTER and applies binary addition', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');

      await tester.tap(_button('4'));
      await tester.pump();
      await tester.tap(_button('2'));
      await tester.pump();
      await tester.tap(_button('ENTER'));
      await tester.pumpAndSettle();

      await tester.tap(_button('8'));
      await tester.pump();
      await tester.tap(_button('ENTER'));
      await tester.pumpAndSettle();

      await tester.tap(_button('+'));
      await tester.pumpAndSettle();

      expect(_displayText('[[50]]'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('calculator-stack-depth')), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
    });

    testWidgets('rpn mode multiplies a matrix by a scalar 1x1', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _showRpnStackPage(tester);

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['1', '0'],
          <String>['0', '1'],
        ],
        actionLabel: 'Push',
      );

      await tester.tap(_button('3'));
      await tester.pump();
      await tester.tap(_button('×'));
      await tester.pumpAndSettle();

      expect(_displayText('[3 0]\n[0 3]'), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
    });

    testWidgets('switching to rpn preserves the committed infix result as X', (tester) async {
      await _pumpApp(tester);

      await tester.tap(_button('3'));
      await tester.pump();
      await tester.tap(_button('+'));
      await tester.pump();
      await tester.tap(_button('4'));
      await tester.pump();
      await _tapEquals(tester);

      await _switchMode(tester, 'RPN');

      expect(_displayText('[[7]]'), findsOneWidget);
      expect(_expressionText(' '), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
    });

    testWidgets('returning to infix continues from the current rpn top', (tester) async {
      await _pumpApp(tester);

      await tester.tap(_button('3'));
      await tester.pump();
      await tester.tap(_button('+'));
      await tester.pump();
      await tester.tap(_button('3'));
      await tester.pump();
      await _tapEquals(tester);

      await _switchMode(tester, 'RPN');
      await tester.tap(_button('5'));
      await tester.pump();
      await tester.tap(_button('ENTER'));
      await tester.pumpAndSettle();

      await _switchMode(tester, 'Infix');

      expect(_displayText('5'), findsOneWidget);

      await tester.tap(_button('+'));
      await tester.pump();
      await tester.tap(_button('3'));
      await tester.pump();
      await _tapEquals(tester);

      expect(_displayText('8'), findsOneWidget);
    });

    testWidgets('rpn mutation invalidates stale infix repeat equals state', (tester) async {
      await _pumpApp(tester);

      await tester.tap(_button('3'));
      await tester.pump();
      await tester.tap(_button('+'));
      await tester.pump();
      await tester.tap(_button('3'));
      await tester.pump();
      await _tapEquals(tester);
      await _tapEquals(tester);

      expect(_displayText('9'), findsOneWidget);

      await _switchMode(tester, 'RPN');
      await tester.tap(_button('5'));
      await tester.pump();
      await tester.tap(_button('ENTER'));
      await tester.pumpAndSettle();

      await _switchMode(tester, 'Infix');
      expect(_displayText('5'), findsOneWidget);

      await _tapEquals(tester);

      expect(_displayText('5'), findsOneWidget);
    });

    testWidgets('rpn stack reordering updates the infix current value', (tester) async {
      await _pumpApp(tester);

      await tester.tap(_button('3'));
      await tester.pump();
      await tester.tap(_button('+'));
      await tester.pump();
      await tester.tap(_button('3'));
      await tester.pump();
      await _tapEquals(tester);

      await _switchMode(tester, 'RPN');
      await tester.tap(_button('5'));
      await tester.pump();
      await tester.tap(_button('ENTER'));
      await tester.pumpAndSettle();

      await _showRpnStackPage(tester);
      await tester.tap(_button('SWAP'));
      await tester.pumpAndSettle();

      await _switchMode(tester, 'Infix');

      expect(_displayText('6'), findsOneWidget);
    });

    testWidgets('infix draft survives a round trip through rpn without being committed', (tester) async {
      await _pumpApp(tester);

      await tester.tap(_button('1'));
      await tester.pump();
      await tester.tap(_button('+'));
      await tester.pump();

      expect(_expressionText('1+'), findsOneWidget);

      await _switchMode(tester, 'RPN');

      expect(_displayText('0'), findsOneWidget);
      expect(_expressionText(' '), findsOneWidget);
      expect(find.text('Stack 0'), findsOneWidget);

      await _switchMode(tester, 'Infix');

      expect(_expressionText('1+'), findsOneWidget);
      expect(_displayText('1+'), findsOneWidget);
    });

    testWidgets('rpn draft survives a round trip through infix without being committed', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await tester.tap(_button('4'));
      await tester.pump();
      await tester.tap(_button('2'));
      await tester.pump();

      expect(_expressionText('42'), findsOneWidget);
      expect(_displayText('42'), findsOneWidget);

      await _switchMode(tester, 'Infix');

      expect(_displayText('0'), findsOneWidget);
      expect(_expressionText(' '), findsOneWidget);

      await _switchMode(tester, 'RPN');

      expect(_expressionText('42'), findsOneWidget);
      expect(_displayText('42'), findsOneWidget);
      expect(find.text('Stack 0'), findsOneWidget);
    });
  });
}

