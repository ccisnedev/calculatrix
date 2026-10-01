// Coverage for issue #51 acceptance 4: `cx 5 7 power` used to fail with
// "Error: unexpected argument '7' [extra-argument]", an SDK-worded message
// that never says the actual problem (the program was typed as separate
// shell words instead of one quoted string). The id and exit code stay
// exactly what `modular_cli_sdk` decided; only the message is rebuilt from
// the arguments the invocation actually received.
import 'package:calculatrix_cli/src/shortcut/unquoted_program_error.dart';
import 'package:test/test.dart';

void main() {
  group('looksLikeUnquotedProgram', () {
    test('more than one bare word, none of them a registered command, '
        'looks like an unquoted program', () {
      expect(looksLikeUnquotedProgram(['5', '7', 'power']), isTrue);
    });

    test('a single argument is never an unquoted program: it is exactly '
        'what the <program> shortcut\'s own contract accepts', () {
      expect(looksLikeUnquotedProgram(['5 7 power']), isFalse);
      expect(looksLikeUnquotedProgram(['power']), isFalse);
    });

    test('a known top-level command word as the first argument is a real '
        'route, not an unquoted program', () {
      expect(looksLikeUnquotedProgram(['eval', 'rpn', '1', '2', '+']), isFalse);
      expect(looksLikeUnquotedProgram(['commands', 'show', 'dup']), isFalse);
      expect(looksLikeUnquotedProgram(['version']), isFalse);
      expect(looksLikeUnquotedProgram(['help']), isFalse);
    });

    test('an option as the first argument is never an unquoted program', () {
      expect(looksLikeUnquotedProgram(['--json', '5', '7']), isFalse);
    });

    test('no arguments at all is never an unquoted program', () {
      expect(looksLikeUnquotedProgram([]), isFalse);
    });
  });

  group('rewriteUnquotedProgramError', () {
    test('rewrites the extra-argument line, naming the argument count and '
        'the program quoted back together, keeping the id', () {
      final rewritten = rewriteUnquotedProgramError(
        "Error: unexpected argument '7' [extra-argument]\n\n"
        'Usage:  <program>\n',
        ['5', '7', 'power'],
      );

      expect(
        rewritten,
        "Error: cx received 3 arguments; quote the program as one "
        "argument: cx '5 7 power' [extra-argument]\n\n"
        'Usage:  <program>\n',
      );
    });

    test('leaves the text untouched when the arguments do not look like '
        'an unquoted program, even if the line still says extra-argument', () {
      const text = "Error: unexpected argument '7' [extra-argument]\n";
      expect(
        rewriteUnquotedProgramError(text, ['eval', 'rpn', '5', '7']),
        text,
      );
    });

    test('leaves the text untouched when the recorded error is not '
        'actually extra-argument', () {
      const text = 'Error: Unknown word: bogus. [unknown-word]\n';
      expect(rewriteUnquotedProgramError(text, ['5', '7', 'power']), text);
    });

    test('leaves everything after the first line exactly as it was, '
        'including a usage block modular_cli_sdk appended', () {
      const text =
          "Error: unexpected argument '7' [extra-argument]\n"
          '\n'
          'Usage:  <program>\n'
          '\n'
          'Shortcut for "eval rpn <program>".\n'
          '\n'
          'Positional arguments:\n'
          '  <program>  (required)\n';
      final rewritten = rewriteUnquotedProgramError(text, ['5', '7', 'power']);
      final rest = rewritten.substring(rewritten.indexOf('\n'));
      final originalRest = text.substring(text.indexOf('\n'));
      expect(rest, originalRest);
    });
  });
}
