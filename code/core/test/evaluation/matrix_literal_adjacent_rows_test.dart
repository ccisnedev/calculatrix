// Tests for issue #29: matrix literals whose rows touch with no whitespace
// between them, `[[0 -1][1 0]]` (the logo's form, code/design/logo.svg, and
// the HP 50g's own notation), mean the same as the spaced form
// `[[0 -1] [1 0]]`.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

Matrix _rpn(String line) =>
    Calculatrix.evaluateRpn(Calculatrix.tokenizeRpnLine(line));

// The error a line raises, or null: compares the adjacent form's failure
// with the spaced form's, so criterion 6 pins "unchanged" rather than a
// particular message.
Object? _rpnError(String line) {
  try {
    _rpn(line);
    return null;
  } on CalculatrixError catch (error) {
    return (error.runtimeType, error.errorId);
  }
}

final Matcher _syntaxError = throwsA(
  isA<ExpressionSyntaxError>().having(
    (ExpressionSyntaxError error) => error.errorId,
    'errorId',
    CalculatrixErrorId.syntaxError,
  ),
);

void main() {
  final Matrix minusIdentity = Matrix(<List<double>>[
    <double>[-1, 0],
    <double>[0, -1],
  ]);

  group('RPN, adjacent rows (issue #29)', () {
    test('[[0 -1][1 0]] is the same matrix as [[0 -1] [1 0]]', () {
      expect(_rpn('[[0 -1][1 0]]'), _rpn('[[0 -1] [1 0]]'));
    });

    test('[[0 -1][1 0]] 2 ^ is minus the identity (i^2 = -1)', () {
      expect(_rpn('[[0 -1][1 0]] 2 ^'), minusIdentity);
    });

    test('more than two rows: [[1][2][3]]', () {
      expect(_rpn('[[1][2][3]]'), _rpn('[[1] [2] [3]]'));
    });

    test('mixed with spaces: [[1 2][3 4] [5 6]]', () {
      expect(_rpn('[[1 2][3 4] [5 6]]'), _rpn('[[1 2] [3 4] [5 6]]'));
    });

    test('a signed literal is negated: -[[1 2][3 4]]', () {
      expect(_rpn('-[[1 2][3 4]]'), _rpn('-[[1 2] [3 4]]'));
      expect(_rpn('-[[1 2][3 4]]'), _rpn('[[1 2] [3 4]]').scale(-1));
    });
  });

  group('Infix, adjacent rows (issue #29)', () {
    test('[[0 -1][1 0]]^2 matches RPN', () {
      expect(Calculatrix.evaluateInfix('[[0 -1][1 0]]^2'), minusIdentity);
    });
  });

  group('Existing forms are unchanged (issue #29)', () {
    final Matrix expected = Matrix(<List<double>>[
      <double>[1, 2],
      <double>[3, 4],
    ]);

    for (final String literal in <String>[
      '[[1 2] [3 4]]',
      '[[1,2],[3,4]]',
      '[[1, 2], [3, 4]]',
    ]) {
      test(literal, () {
        expect(_rpn(literal), expected);
      });
    }
  });

  group('Invalid input is still rejected (issue #29)', () {
    test('two top-level literals written together: [1 2][3 4]', () {
      expect(() => _rpn('[1 2][3 4]'), _syntaxError);
    });

    test('ragged rows fail as the spaced form does: [[1 2][3]]', () {
      final Object? spaced = _rpnError('[[1 2] [3]]');
      expect(spaced, isNotNull);
      expect(_rpnError('[[1 2][3]]'), spaced);
    });
  });
}
