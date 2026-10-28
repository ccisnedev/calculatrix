// An unbalanced matrix literal is a syntax-error that names the token it
// starts and its 1-based position, like every other syntax error.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

Matcher _unbalanced(String token, int position) => throwsA(
  isA<ExpressionSyntaxError>()
      .having(
        (CalculatrixError e) => e.errorId,
        'errorId',
        CalculatrixErrorId.syntaxError,
      )
      .having((CalculatrixError e) => e.token, 'token', token)
      .having((CalculatrixError e) => e.position, 'position', position),
);

void main() {
  test('an RPN line that is only an open literal', () {
    expect(
      () => Calculatrix.tokenizeRpnLine('[[1 2]'),
      _unbalanced('[[1 2]', 1),
    );
  });

  test('an open literal after other tokens', () {
    expect(
      () => Calculatrix.tokenizeRpnLine('1 2 [[1 2] [3 4]'),
      _unbalanced('[[1 2] [3 4]', 5),
    );
  });

  test('an open literal in infix', () {
    expect(
      () => Calculatrix.evaluateInfix('1 + [[1 2]'),
      _unbalanced('[[1 2]', 5),
    );
  });
}
