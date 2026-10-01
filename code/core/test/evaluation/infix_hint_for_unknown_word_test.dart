// A non-word RPN token that is actually an infix expression typed in the
// wrong place (e.g. "3.7^2.5" handed to evaluateRpn, or to the CLI's root
// shortcut, which both compile through the exact same RPN word compiler)
// still fails with unknown-word: this notation never falls back to infix.
// What changes is the message: it now hints at the right command instead
// of leaving the caller to guess. See Calculatrix.evaluateRpn /
// _compileWord.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('unknown-word hints when the token looks like infix', () {
    test('an operator sandwiched between operands hints at eval infix', () {
      try {
        Calculatrix.evaluateRpn(<String>['3.7^2.5']);
        fail('expected UnknownWordError');
      } on UnknownWordError catch (error) {
        expect(error.errorId, CalculatrixErrorId.unknownWord);
        expect(
          error.message,
          contains('this looks like an infix expression: cx eval infix'),
        );
        expect(error.message, contains('3.7^2.5'));
      }
    });

    test('an unbalanced parenthesis also hints at eval infix', () {
      try {
        Calculatrix.evaluateRpn(<String>['(3.7^2.5']);
        fail('expected UnknownWordError');
      } on UnknownWordError catch (error) {
        expect(
          error.message,
          contains('this looks like an infix expression: cx eval infix'),
        );
      }
    });

    test('an ordinary unknown word carries no infix hint', () {
      try {
        Calculatrix.evaluateRpn(<String>['bogus']);
        fail('expected UnknownWordError');
      } on UnknownWordError catch (error) {
        expect(error.message, isNot(contains('infix')));
      }
    });

    test('a plain negative number literal never reaches unknown-word, so '
        'it never carries the hint either', () {
      // "-5" parses as a literal; this just documents that the heuristic
      // is never even consulted for it.
      final result = Calculatrix.evaluateRpn(<String>['-5']);
      expect(result, Matrix.scalar(-5));
    });
  });
}
