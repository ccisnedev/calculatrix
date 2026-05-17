import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:calculatrix_app/main.dart';

const Duration _uiStep = Duration(milliseconds: 100);

Future<void> _pumpForUi(WidgetTester tester, {int steps = 6}) async {
  for (int i = 0; i < steps; i++) {
    await tester.pump(_uiStep);
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxSteps = 30,
}) async {
  for (int i = 0; i < maxSteps; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }

    await tester.pump(_uiStep);
  }

  expect(finder, findsOneWidget);
}

Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  int maxSteps = 30,
}) async {
  for (int i = 0; i < maxSteps; i++) {
    if (finder.evaluate().isEmpty) {
      return;
    }

    await tester.pump(_uiStep);
  }

  expect(finder, findsNothing);
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(CalculatrixApp(key: UniqueKey()));
  await _pumpForUi(tester);
  await tester.tap(find.text('Infix'));
  await _pumpForUi(tester);
}

Future<void> _tapEquals(WidgetTester tester) async {
  if (_button('=').evaluate().isEmpty) {
    await tester.tap(find.text('Infix'));
    await _pumpForUi(tester);
  }

  if (_button('=').evaluate().isEmpty) {
    await tester.drag(find.byType(PageView), const Offset(1000, 0));
    await _pumpUntilFound(tester, _button('='));
  }

  await tester.tap(_button('='));
  await _pumpForUi(tester, steps: 2);
}

Future<void> _switchMode(WidgetTester tester, String mode) async {
  await tester.tap(find.text(mode));
  await _pumpForUi(tester);
}

Future<void> _showInfixEditPage(WidgetTester tester) async {
  if (_button('MAT').evaluate().isNotEmpty) {
    return;
  }

  await tester.drag(find.byType(PageView), const Offset(-1000, 0));
  await _pumpUntilFound(tester, _button('MAT'));
}

Future<void> _showInfixPrimaryPage(WidgetTester tester) async {
  if (_button('=').evaluate().isNotEmpty) {
    return;
  }

  await tester.drag(find.byType(PageView), const Offset(1000, 0));
  await _pumpUntilFound(tester, _button('='));
}

Future<void> _showRpnStackPage(WidgetTester tester) async {
  if (_button('SWAP').evaluate().isNotEmpty) {
    return;
  }

  await tester.drag(find.byType(PageView), const Offset(-1000, 0));
  await _pumpUntilFound(tester, _button('SWAP'));
}

Future<void> _submitMatrix(
  WidgetTester tester,
  List<List<String>> values, {
  required String actionLabel,
}) async {
  await tester.tap(_button('MAT'));
  await _pumpUntilFound(
    tester,
    find.byKey(const ValueKey<String>('matrix-cell-0-0')),
  );

  for (int row = 0; row < values.length; row++) {
    for (int column = 0; column < values[row].length; column++) {
      final Finder cellFinder = find.byKey(
        ValueKey<String>('matrix-cell-$row-$column'),
      );
      final TextFormField field = tester.widget<TextFormField>(cellFinder);
      field.controller!.text = values[row][column];
      field.onChanged?.call(values[row][column]);
      await tester.pump();
    }
  }

  final Finder actionButton = find.widgetWithText(FilledButton, actionLabel);
  final FilledButton button = tester.widget<FilledButton>(actionButton);
  button.onPressed!.call();
  await _pumpUntilGone(tester, actionButton);
  await _pumpForUi(tester, steps: 2);
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

Finder _rpnStackCard(int register) {
  return find.byKey(ValueKey<String>('rpn-stack-card-$register'));
}

Finder _rpnStackText(int register, String value) {
  return find.descendant(of: _rpnStackCard(register), matching: find.text(value));
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

      await _showInfixEditPage(tester);
      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['1', '2'],
          <String>['3', '4'],
        ],
        actionLabel: 'Insert',
      );

      expect(_expressionText('[[1,2],[3,4]]'), findsOneWidget);
    });

    testWidgets('infix mode displays a non-scalar matrix result', (tester) async {
      await _pumpApp(tester);

      await _showInfixEditPage(tester);
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

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['3', '4'],
          <String>['5', '6'],
        ],
        actionLabel: 'Insert',
      );

      await _showInfixPrimaryPage(tester);
      await _tapEquals(tester);

      expect(_displayText('[3 4]\n[5 6]'), findsOneWidget);
    });

    testWidgets('infix mode multiplies a matrix by a scalar 1x1', (tester) async {
      await _pumpApp(tester);

      await _showInfixEditPage(tester);

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

    testWidgets('infix mode toggles the sign of a committed matrix', (tester) async {
      await _pumpApp(tester);

      await _showInfixEditPage(tester);

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['1', '2'],
          <String>['3', '4'],
        ],
        actionLabel: 'Insert',
      );

      await _tapEquals(tester);
      await tester.tap(_button('±'));
      await tester.pumpAndSettle();

      expect(_displayText('[-1 -2]\n[-3 -4]'), findsOneWidget);
    });

    testWidgets('infix mode rejects division by a non-scalar matrix denominator', (tester) async {
      await _pumpApp(tester);

      await _showInfixEditPage(tester);

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['3', '1'],
          <String>['7', '3'],
        ],
        actionLabel: 'Insert',
      );

      await tester.tap(_button('÷'));
      await tester.pump();

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['2', '1'],
          <String>['1', '1'],
        ],
        actionLabel: 'Insert',
      );

      await _tapEquals(tester);

      expect(_displayText('Error'), findsOneWidget);
    });

    testWidgets('infix mode computes the square root of a square matrix', (tester) async {
      await _pumpApp(tester);

      await _showInfixEditPage(tester);

      await tester.tap(_button('√'));
      await tester.pump();

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['5', '4'],
          <String>['4', '5'],
        ],
        actionLabel: 'Insert',
      );

      await _tapEquals(tester);

      expect(_displayText('[2 1]\n[1 2]'), findsOneWidget);
    });

    testWidgets('infix mode recalls matrix memory into the expression', (tester) async {
      await _pumpApp(tester);

      await _showInfixEditPage(tester);

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['1', '2'],
          <String>['3', '4'],
        ],
        actionLabel: 'Insert',
      );

      await _showInfixPrimaryPage(tester);
      await _tapEquals(tester);

      await tester.tap(_button('M+'));
      await _pumpForUi(tester);
      await tester.tap(_button('C'));
      await _pumpForUi(tester);
      await tester.tap(_button('MR'));
      await _pumpForUi(tester);

      expect(_expressionText('[[1,2],[3,4]]'), findsOneWidget);
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
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
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
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
    });

    testWidgets('rpn mode toggles the sign of the committed top matrix', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _showRpnStackPage(tester);

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['1', '2'],
          <String>['3', '4'],
        ],
        actionLabel: 'Push',
      );

      await tester.tap(_button('±'));
      await tester.pumpAndSettle();

      expect(_displayText('[-1 -2]\n[-3 -4]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
    });

    testWidgets('rpn mode recalls matrix memory onto the stack', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _showRpnStackPage(tester);

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['1', '2'],
          <String>['3', '4'],
        ],
        actionLabel: 'Push',
      );

      await tester.tap(_button('M+'));
      await tester.pumpAndSettle();
      await tester.tap(_button('MR'));
      await tester.pumpAndSettle();

      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(_displayText('[1 2]\n[3 4]'), findsOneWidget);
      expect(find.text('Stack 2'), findsOneWidget);
    });

    testWidgets('rpn mode shows the draft in X0 and the committed top in X1', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await tester.tap(_button('4'));
      await tester.pump();
      await tester.tap(_button('ENTER'));
      await tester.pumpAndSettle();
      await tester.tap(_button('7'));
      await tester.pump();

      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(_rpnStackText(0, '7'), findsOneWidget);
      expect(_rpnStackCard(1), findsOneWidget);
      expect(_rpnStackText(1, 'X1'), findsOneWidget);
      expect(_rpnStackText(1, '[[4]]'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('calculator-expression-text')), findsNothing);
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
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('calculator-expression-text')), findsNothing);
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
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('calculator-expression-text')), findsNothing);
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

      expect(_displayText('42'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);

      await _switchMode(tester, 'Infix');

      expect(_displayText('0'), findsOneWidget);
      expect(_expressionText(' '), findsOneWidget);

      await _switchMode(tester, 'RPN');

      expect(_displayText('42'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('calculator-expression-text')), findsNothing);
      expect(find.text('Stack 0'), findsOneWidget);
    });
  });
}

