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
      expect(optionLikeValueIndex(['eval', 'rpn', '-2 3 +']), 2);
    });

    test('ignores short options, long options, a lone "-" and anything '
        'after --', () {
      expect(optionLikeValueIndex(['eval', '-qh']), -1);
      expect(optionLikeValueIndex(['--json', 'eval', 'infix', '1']), -1);
      expect(optionLikeValueIndex(['eval', 'infix', '-']), -1);
      expect(optionLikeValueIndex(['eval', 'infix', '--', '-sqrt(-1)']), -1);
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
