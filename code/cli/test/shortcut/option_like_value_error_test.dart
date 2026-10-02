// Tests for issue #66: a value that starts with "-" and looks like an
// expression, such as `cx eval infix '-sqrt(-1)'`, is read by
// `modular_cli_sdk` as short options and rejected as `invalid-short-option`.
// The error stays (POSIX: "--" ends the options), but its message now says
// so and gives the command with "--" in place.
import 'dart:convert';

import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:calculatrix_cli/src/shortcut/option_like_value_error.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import '../support/memory_sink.dart';

void main() {
  group('optionLikeValueIndex (issue #66)', () {
    test('finds an argument that starts with "-" and looks like an '
        'expression', () {
      expect(optionLikeValueIndex(['eval', 'infix', '-sqrt(-1)']), 2);
      expect(optionLikeValueIndex(['-x 2 +']), 0);
      expect(optionLikeValueIndex(['eval', 'infix', '-q', '-e^2']), 3);
    });

    test('ignores short options, long options, a lone "-", values the SDK '
        'already accepts and anything after --', () {
      expect(optionLikeValueIndex(['eval', '-qh']), -1);
      expect(optionLikeValueIndex(['eval', 'rpn', '-2 3 +']), -1);
      expect(optionLikeValueIndex(['eval', 'infix', '-(2+3)']), -1);
      expect(optionLikeValueIndex(['--json', 'eval', 'infix', '1']), -1);
      expect(optionLikeValueIndex(['eval', 'infix', '-']), -1);
      expect(optionLikeValueIndex(['eval', 'infix', '--', '-sqrt(-1)']), -1);
    });

    test('names only the argument the SDK rejects: the first option-like '
        'one', () {
      expect(optionLikeValueIndex(['eval', 'infix', '-qh', '-e^2']), -1);
      expect(optionLikeValueIndex(['eval', 'infix', '-e^2', '-qh']), 2);
    });
  });

  group('runCalculatrixCli on a value read as options (issue #66)', () {
    test('the text error keeps its id and exit code and suggests --', () async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(
        ['eval', 'infix', '-sqrt(-1)'],
        stdout: out,
        stderr: err,
      );

      expect(code, ExitCode.validationFailed);
      expect(
        err.output,
        startsWith(
          'Error: -sqrt(-1) starts with "-", so it was read as options; to '
          "pass it as a value, end the options with --: cx eval infix -- "
          "'-sqrt(-1)' [invalid-short-option]",
        ),
      );
    });

    test('the --json error object gets the same message', () async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(
        ['--json', 'eval', 'infix', '-sqrt(-1)'],
        stdout: out,
        stderr: err,
      );

      expect(code, ExitCode.validationFailed);
      final error =
          (jsonDecode(err.output) as Map<String, dynamic>)['error']
              as Map<String, dynamic>;
      expect(error['id'], 'invalid-short-option');
      expect(error['exitCode'], ExitCode.validationFailed);
      expect(
        error['message'],
        contains(
          "end the options with --: cx --json eval infix -- "
          "'-sqrt(-1)'",
        ),
      );
    });

    test('the suggested command runs', () async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(
        ['eval', 'infix', '--', '-(2+3)'],
        stdout: out,
        stderr: err,
      );

      expect(code, ExitCode.ok);
      expect(out.output, contains('-5'));
    });

    test('options after the value stay before --, and the suggested '
        'command runs', () async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(
        ['commands', 'search', '-matrix literal', '--json'],
        stdout: out,
        stderr: err,
      );

      expect(code, ExitCode.validationFailed);
      expect(
        err.output,
        contains(
          "end the options with --: cx commands search --json -- "
          "'-matrix literal'",
        ),
      );

      final suggestedOut = MemorySink();
      final suggestedCode = await runCalculatrixCli(
        ['commands', 'search', '--json', '--', '-matrix literal'],
        stdout: suggestedOut,
        stderr: MemorySink(),
      );
      expect(suggestedCode, ExitCode.ok);
      expect(jsonDecode(suggestedOut.output), {'matches': <dynamic>[]});
    });

    test('a short-option mistake before an expression keeps the SDK '
        'message', () async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(
        ['eval', 'infix', '-qh', '-2'],
        stdout: out,
        stderr: err,
      );

      expect(code, ExitCode.validationFailed);
      expect(err.output, startsWith('Error: short options stand alone'));
      expect(err.output, isNot(contains('end the options with --')));
    });

    test('a real short-option mistake keeps the SDK message', () async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(
        ['eval', '-qh'],
        stdout: out,
        stderr: err,
      );

      expect(code, ExitCode.validationFailed);
      expect(err.output, contains('[invalid-short-option]'));
      expect(err.output, isNot(contains('end the options with --')));
    });
  });
}
