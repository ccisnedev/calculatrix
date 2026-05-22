import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:calculatrix_app/main.dart';

const Duration _uiStep = Duration(milliseconds: 100);

const List<String> _keypadDeckLabels = <String>[
  'MAIN',
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

Future<void> _pumpForUi(WidgetTester tester, {int steps = 6}) async {
  for (int i = 0; i < steps; i++) {
    await tester.pump(_uiStep);
  }
}

Future<void> _pumpUntilSettled(
  WidgetTester tester, {
  int maxSteps = 30,
}) async {
  for (int i = 0; i < maxSteps; i++) {
    await tester.pump(_uiStep);
    if (!tester.binding.hasScheduledFrame) {
      return;
    }
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
  await _switchMode(tester, 'Infix');
}

bool _isInfixEditorVisible() {
  return find.byKey(const ValueKey<String>('calculator-expression-text')).evaluate().isNotEmpty;
}

Future<void> _tapEquals(WidgetTester tester) async {
  if (!_isInfixEditorVisible()) {
    await _switchMode(tester, 'Infix');
  }

  await _tapCalculatorButton(tester, '=');
}

Future<void> _switchMode(WidgetTester tester, String mode) async {
  switch (mode) {
    case 'RPN':
      if (_isInfixEditorVisible() ||
          find.byKey(const ValueKey<String>('matrix-mode-panel')).evaluate().isNotEmpty) {
        await _tapCalculatorButton(tester, 'CANCEL');
      }
      return;
    case 'Infix':
      if (!_isInfixEditorVisible()) {
        await _tapFinderCenter(tester, _deckSelector('EDIT'));
        await _tapCalculatorButton(tester, 'INFIX');
      }
      return;
    case 'Matrix':
      if (find.byKey(const ValueKey<String>('matrix-mode-panel')).evaluate().isEmpty) {
        await _tapFinderCenter(tester, _deckSelector('EDIT'));
        await _tapCalculatorButton(tester, 'MATRIX');
      }
      return;
  }

  fail('Unsupported shell mode request: $mode');
}

Future<void> _showRpnStackPage(WidgetTester tester) async {
  await _switchMode(tester, 'RPN');
  await _tapFinderCenter(tester, _deckSelector('STACK'));
  await _ensureButtonVisible(tester, 'SWAP');
}

Future<void> _submitMatrix(
  WidgetTester tester,
  List<List<String>> values, {
  required String actionLabel,
  int? order,
}) async {
  await _openMatrixEditorDialog(tester);

  if (order != null) {
    await _selectMatrixOrder(tester, order);
  }

  for (int row = 0; row < values.length; row++) {
    for (int column = 0; column < values[row].length; column++) {
      await _setMatrixCell(tester, row, column, values[row][column]);
    }
  }

  await _confirmMatrixDialog(tester, actionLabel);
  await _pumpUntilGone(
    tester,
    find.byKey(const ValueKey<String>('matrix-mode-panel')),
  );
  await _pumpForUi(tester, steps: 2);
}

Future<void> _ensureButtonVisible(WidgetTester tester, String label) async {
  final Finder button = _button(label);
  if (button.evaluate().isNotEmpty) {
    return;
  }

  for (final String deckLabel in _keypadDeckLabels) {
    final Finder selector = _deckSelector(deckLabel);
    if (selector.evaluate().isEmpty) {
      continue;
    }

    await _tapFinderCenter(tester, selector);
    if (button.evaluate().isNotEmpty) {
      return;
    }
  }

  expect(button, findsOneWidget);
}

Future<void> _openMatrixEditorDialog(WidgetTester tester) async {
  await _switchMode(tester, 'Matrix');
  await _pumpUntilFound(
    tester,
    find.byKey(const ValueKey<String>('matrix-cell-0-0')),
  );
}

Future<void> _setMatrixCell(
  WidgetTester tester,
  int row,
  int column,
  String value,
) async {
  final Finder cellFinder = find.byKey(
    ValueKey<String>('matrix-cell-$row-$column'),
  );
  final TextFormField field = tester.widget<TextFormField>(cellFinder);
  field.controller!.text = value;
  field.onChanged?.call(value);
  await tester.pump();
}

Finder _matrixRowTab(int row) {
  return find.byKey(ValueKey<String>('matrix-row-tab-$row'));
}

Finder _matrixColumnTab(int column) {
  return find.byKey(ValueKey<String>('matrix-column-tab-$column'));
}

Finder _matrixAddRowPlaceholder() {
  return find.byKey(const ValueKey<String>('matrix-add-row-placeholder'));
}

Finder _matrixAddColumnPlaceholder() {
  return find.byKey(const ValueKey<String>('matrix-add-column-placeholder'));
}

String _matrixKeyLabel(String label) {
  return switch (label) {
    'Identity' => 'ID',
    'Zeros' => 'ZEROS',
    'Ones' => 'ONES',
    'Transpose' => 'T',
    'Inverse' => 'INV',
    'Determinant' => 'DET',
    'Insert' => 'ENTER',
    'Push' => 'ENTER',
    'Cancel' => 'CANCEL',
    _ => label,
  };
}

Future<void> _tapFinderCenter(WidgetTester tester, Finder finder) async {
  await tester.tapAt(tester.getCenter(finder, warnIfMissed: false));
  await _pumpForUi(tester, steps: 2);
}

Future<void> _tapCalculatorButton(WidgetTester tester, String label) async {
  await _ensureButtonVisible(tester, label);
  await tester.ensureVisible(_button(label));
  await _tapFinderCenter(tester, _button(label));
}

Future<void> _tapMatrixStructuralControl(
  WidgetTester tester,
  String tooltip,
) async {
  final Finder control = find.byTooltip(tooltip);
  await tester.ensureVisible(control);
  await tester.tap(control);
  await _pumpForUi(tester, steps: 2);
}

Future<void> _reorderMatrixRow(
  WidgetTester tester,
  int from,
  int to,
) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(_matrixRowTab(from)),
  );
  await gesture.moveTo(tester.getCenter(_matrixRowTab(to)));
  await gesture.up();
  await _pumpForUi(tester, steps: 2);
}

Future<void> _selectMatrixOrder(WidgetTester tester, int order) async {
  final String orderLabel = '${order}x$order';
  if (_button(orderLabel).evaluate().isNotEmpty) {
    await _tapCalculatorButton(tester, orderLabel);
    return;
  }

  for (int size = 2; size < order; size++) {
    await tester.ensureVisible(_matrixAddRowPlaceholder());
    await _tapFinderCenter(tester, _matrixAddRowPlaceholder());
    await tester.ensureVisible(_matrixAddColumnPlaceholder());
    await _tapFinderCenter(tester, _matrixAddColumnPlaceholder());
  }
}

Future<void> _confirmMatrixDialog(
  WidgetTester tester,
  String actionLabel,
) async {
  final String keypadLabel = _matrixKeyLabel(actionLabel);
  await _tapCalculatorButton(tester, keypadLabel);
}

Finder _button(String label) {
  if (label == 'INFIX') {
    return find.byWidgetPredicate((Widget widget) {
      final Key? key = widget.key;
      return key == const ValueKey<String>('calculator-button-INFIX') ||
          key == const ValueKey<String>('calculator-button-INFIX-edit');
    }).hitTestable();
  }

  return find.byKey(ValueKey<String>('calculator-button-$label')).hitTestable();
}

Finder _deckSelector(String label) {
  return find.byKey(ValueKey<String>('calculator-keypad-deck-$label')).hitTestable();
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

Finder _rpnDraftCard() {
  return find.byKey(const ValueKey<String>('rpn-draft-card'));
}

Finder _rpnStackText(int register, String value) {
  return find.descendant(of: _rpnStackCard(register), matching: find.text(value));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Calculator integration tests', () {
    testWidgets('INFIX opens the editor and ENTER commits the result to the shell', (tester) async {
      await _pumpApp(tester);

      await tester.tap(_button('3'));
      await tester.pump();
      await tester.tap(_button('+'));
      await tester.pump();
      await tester.tap(_button('4'));
      await tester.pump();
      await _tapEquals(tester);
      await _tapCalculatorButton(tester, 'ENTER');

      expect(_displayText('[[7]]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
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

    testWidgets('rpn mode commits with ENTER and applies binary addition', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');

      await tester.tap(_button('4'));
      await tester.pump();
      await tester.tap(_button('2'));
      await tester.pump();
      await tester.tap(_button('ENTER'));
      await _pumpUntilSettled(tester);

      await tester.tap(_button('8'));
      await tester.pump();
      await tester.tap(_button('ENTER'));
      await _pumpUntilSettled(tester);

      await tester.tap(_button('+'));
      await _pumpUntilSettled(tester);

      expect(_displayText('[[50]]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('calculator-stack-depth')), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
    });

    testWidgets('rpn mode pushes a 3x3 matrix from the matrix editor', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _showRpnStackPage(tester);

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['1', '2', '3'],
          <String>['4', '5', '6'],
          <String>['7', '8', '9'],
        ],
        actionLabel: 'Push',
        order: 3,
      );

      expect(_displayText('[1 2 3]\n[4 5 6]\n[7 8 9]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
    });

    testWidgets('rpn mode pushes a reordered 2x2 matrix from the structural tabs', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _showRpnStackPage(tester);
      await _openMatrixEditorDialog(tester);

      await _setMatrixCell(tester, 0, 0, '1');
      await _setMatrixCell(tester, 0, 1, '2');
      await _setMatrixCell(tester, 1, 0, '3');
      await _setMatrixCell(tester, 1, 1, '4');
      await _reorderMatrixRow(tester, 0, 1);

      await _confirmMatrixDialog(tester, 'Push');
      await _pumpUntilGone(tester, find.byKey(const ValueKey<String>('matrix-mode-panel')));

      expect(_displayText('[3 4]\n[1 2]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
    });

    testWidgets('matrix editor keeps the dialog open until an invalid cell is corrected', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _showRpnStackPage(tester);
      await _openMatrixEditorDialog(tester);

      await _setMatrixCell(tester, 0, 0, '1');
      await _confirmMatrixDialog(tester, 'Push');

      expect(find.text('Enter a value for r1 c2'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('matrix-mode-panel')), findsOneWidget);

      await _setMatrixCell(tester, 0, 1, '2');
      await _setMatrixCell(tester, 1, 0, '3');
      await _setMatrixCell(tester, 1, 1, '4');
      await _confirmMatrixDialog(tester, 'Push');
      await _pumpUntilGone(tester, find.byKey(const ValueKey<String>('matrix-mode-panel')));

      expect(_displayText('[1 2]\n[3 4]'), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
    });

    testWidgets('matrix editor deletes a column before push and confirms the reduced literal', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _showRpnStackPage(tester);
      await _openMatrixEditorDialog(tester);
      await tester.tap(_matrixAddColumnPlaceholder());
      await _pumpForUi(tester, steps: 2);

      await _setMatrixCell(tester, 0, 0, '1');
      await _setMatrixCell(tester, 0, 1, '2');
      await _setMatrixCell(tester, 0, 2, '3');
      await _setMatrixCell(tester, 1, 0, '4');
      await _setMatrixCell(tester, 1, 1, '5');
      await _setMatrixCell(tester, 1, 2, '6');

      await tester.tap(_matrixColumnTab(1));
      await _pumpForUi(tester, steps: 2);
      await _tapMatrixStructuralControl(tester, 'Delete column');

      await _confirmMatrixDialog(tester, 'Push');
      await _pumpUntilGone(tester, find.byKey(const ValueKey<String>('matrix-mode-panel')));

      expect(_displayText('[1 3]\n[4 6]'), findsOneWidget);
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
      await _pumpUntilSettled(tester);

      expect(_displayText('[-1 -2]\n[-3 -4]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
    });

    testWidgets('rpn mode applies determinant to the committed top matrix', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _showRpnStackPage(tester);

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['4', '7'],
          <String>['2', '6'],
        ],
        actionLabel: 'Push',
      );

      await _tapCalculatorButton(tester, 'DET');

      expect(_displayText('[[10]]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
    });

    testWidgets('rpn mode applies LU decomposition to the committed top matrix', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _showRpnStackPage(tester);

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['2', '1', '1'],
          <String>['4', '-6', '0'],
          <String>['-2', '7', '2'],
        ],
        actionLabel: 'Push',
        order: 3,
      );

      await _tapCalculatorButton(tester, 'LU');

      expect(_displayText('[4 -6 0]\n[0  4 1]\n[0  0 1]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 3'), findsOneWidget);
    });

    testWidgets('rpn mode applies QR decomposition to the committed top matrix', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _showRpnStackPage(tester);

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['1', '0'],
          <String>['0', '2'],
        ],
        actionLabel: 'Push',
      );

      await _tapCalculatorButton(tester, 'QR');

      expect(_displayText('[1 0]\n[0 2]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 2'), findsOneWidget);
    });

    testWidgets('rpn mode applies eigenvalues to the committed top matrix', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _showRpnStackPage(tester);

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['2', '0'],
          <String>['0', '3'],
        ],
        actionLabel: 'Push',
      );

      await _tapCalculatorButton(tester, 'EIG');

      expect(_displayText('[3]\n[2]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);
    });

    testWidgets('matrix mode entered from RPN can factorize the draft with LU and return to the stack', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _openMatrixEditorDialog(tester);
      await _tapCalculatorButton(tester, '3x3');

      await _setMatrixCell(tester, 0, 0, '2');
      await _setMatrixCell(tester, 0, 1, '1');
      await _setMatrixCell(tester, 0, 2, '1');
      await _setMatrixCell(tester, 1, 0, '4');
      await _setMatrixCell(tester, 1, 1, '-6');
      await _setMatrixCell(tester, 1, 2, '0');
      await _setMatrixCell(tester, 2, 0, '-2');
      await _setMatrixCell(tester, 2, 1, '7');
      await _setMatrixCell(tester, 2, 2, '2');

      await _tapFinderCenter(tester, _deckSelector('FACT'));
      await _tapCalculatorButton(tester, 'LU');

      await _pumpUntilGone(
        tester,
        find.byKey(const ValueKey<String>('matrix-mode-panel')),
      );

      expect(_displayText('[4 -6 0]\n[0  4 1]\n[0  0 1]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 3'), findsOneWidget);
    });

    testWidgets('matrix creation, macro expansion, QR, and notation switching stay coherent end-to-end', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await _showRpnStackPage(tester);

      await _submitMatrix(
        tester,
        <List<String>>[
          <String>['1', '0'],
          <String>['0', '2'],
        ],
        actionLabel: 'Push',
      );

      await _tapCalculatorButton(tester, 'AROW');

      expect(_displayText('[1 0]\n[0 2]\n[0 0]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 1'), findsOneWidget);

      await _tapCalculatorButton(tester, 'QR');

      expect(_displayText('[1 0]\n[0 2]'), findsOneWidget);
      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(find.text('Stack 2'), findsOneWidget);

      await _switchMode(tester, 'Infix');

      expect(_displayText('[1 0]\n[0 2]'), findsOneWidget);
      expect(_expressionText(' '), findsOneWidget);
    });

    testWidgets('rpn shell keeps the committed top in X0 and the draft separate', (tester) async {
      await _pumpApp(tester);

      await _switchMode(tester, 'RPN');
      await tester.tap(_button('4'));
      await tester.pump();
      await tester.tap(_button('ENTER'));
      await _pumpUntilSettled(tester);
      await tester.tap(_button('7'));
      await tester.pump();

      expect(_rpnStackCard(0), findsOneWidget);
      expect(_rpnStackText(0, 'X0'), findsOneWidget);
      expect(_rpnStackText(0, '[[4]]'), findsOneWidget);
      expect(_rpnDraftCard(), findsOneWidget);
      expect(find.descendant(of: _rpnDraftCard(), matching: find.text('7')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('calculator-expression-text')), findsNothing);
    });
  });
}

