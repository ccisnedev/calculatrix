// Issue #73 (runbook-agent-usability.md D68, step U4b): the token `--`
// inside an RPN program raises `unknown-word`, with no suggestions and a
// message that names the exact form to type: `--` ends the options and goes
// before the quoted program.
import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

UnknownWordError _rpnError(String program) {
  try {
    Calculatrix.evaluateRpnStack(Calculatrix.tokenizeRpnLine(program));
  } on UnknownWordError catch (error) {
    return error;
  }
  fail('expected UnknownWordError for $program');
}

void main() {
  group('-- inside an RPN program (#73 b)', () {
    test('[[1 2] [0 1]] -- -3 ^ gives the program without the token', () {
      final error = _rpnError('[[1 2] [0 1]] -- -3 ^');
      expect(error.errorId, CalculatrixErrorId.unknownWord);
      expect(error.token, '--');
      expect(error.suggestions, isEmpty);
      expect(
        error.message,
        '"--" is not part of a program: it ends the options and goes before '
        "the quoted program: cx eval rpn '[[1 2] [0 1]] -3 ^'",
      );
    });

    test('a program that starts with - goes after -- in the form', () {
      final error = _rpnError('-- -1 2 +');
      expect(
        error.message,
        '"--" is not part of a program: it ends the options and goes before '
        "the quoted program: cx eval rpn -- '-1 2 +'",
      );
      expect(error.suggestions, isEmpty);
    });

    test('a trailing -- is removed with its adjacent space', () {
      final error = _rpnError('1 2 + --');
      expect(
        error.message,
        '"--" is not part of a program: it ends the options and goes before '
        "the quoted program: cx eval rpn '1 2 +'",
      );
    });

    test('the position of the token is reported', () {
      expect(_rpnError('1 2 + --').position, 7);
    });
  });
}
