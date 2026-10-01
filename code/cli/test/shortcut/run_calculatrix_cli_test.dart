// Integration coverage for issue #51 acceptance 4, tying the rewrite back
// to the real CLI entry point: `runCalculatrixCli`, the one function
// `bin/cx.dart` calls, instead of `buildCalculatrixCli().run(...)`
// directly.
import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import '../support/memory_sink.dart';

void main() {
  group('runCalculatrixCli (issue #51 acceptance 4)', () {
    test('an unquoted program gets the actionable message, the same id '
        'and exit code modular_cli_sdk already decided', () async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(
        ['5', '7', 'power'],
        stdout: out,
        stderr: err,
      );

      expect(code, ExitCode.invalidUsage);
      expect(
        err.output,
        startsWith(
          "Error: cx received 3 arguments; quote the program as one "
          "argument: cx '5 7 power' [extra-argument]",
        ),
      );
    });

    test('the program quoted as one argument still runs exactly as '
        'before', () async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(
        ["5 7 power"],
        stdout: out,
        stderr: err,
      );

      expect(code, ExitCode.ok);
      expect(out.output, contains('1: 78125'));
      expect(err.output, isEmpty);
    });

    test('a real route with its own extra-argument failure is reported '
        'unchanged: the rewrite never fires outside the bare shortcut', () async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(
        ['eval', 'rpn', '5', '7', 'power'],
        stdout: out,
        stderr: err,
      );

      expect(code, ExitCode.invalidUsage);
      expect(err.output, contains('[extra-argument]'));
      expect(err.output, isNot(contains('cx received')));
    });

    test('an unrelated failure on the shortcut, such as an unknown RPN '
        'word, is untouched', () async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(
        ['bogus'],
        stdout: out,
        stderr: err,
      );

      expect(code, isNot(ExitCode.ok));
      expect(err.output, contains('[unknown-word]'));
      expect(err.output, isNot(contains('cx received')));
    });
  });
}
