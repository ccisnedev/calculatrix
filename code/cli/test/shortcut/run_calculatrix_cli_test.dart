// Integration coverage tying the rewrite back
// to the real CLI entry point: `runCalculatrixCli`, the one function
// `bin/cx.dart` calls, instead of `buildCalculatrixCli().run(...)`
// directly.
import 'dart:convert';

import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import '../support/memory_sink.dart';

void main() {
  group('runCalculatrixCli', () {
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

  group('runCalculatrixCli: reported errors', () {
    Future<(int, String, String)> run(List<String> args) async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(args, stdout: out, stderr: err);
      return (code, out.output, err.output);
    }

    test('an unbalanced matrix literal is a syntax-error, 65, not a crash',
        () async {
      final (code, _, err) = await run(['[[1 2]']);
      expect(code, ExitCode.dataError);
      expect(err, contains('[syntax-error]'));
      expect(err, isNot(contains('Unhandled')));
    });

    test('a syntax-error is JSON under --json, for rpn and infix', () async {
      for (final args in [
        ['--json', '[[1 2]'],
        ['eval', 'rpn', '--json', '[[1 2]'],
        ['eval', 'infix', '--json', '(1+'],
      ]) {
        final (code, _, err) = await run(args);
        expect(code, ExitCode.dataError, reason: '$args');
        final error = jsonDecode(err)['error'] as Map<String, dynamic>;
        expect(error['id'], 'syntax-error', reason: '$args');
      }
    });

    test('an unquoted program keeps the quoting hint under --json and -q',
        () async {
      final (jsonCode, _, jsonErr) = await run(['--json', '1', '2', '+']);
      expect(jsonCode, ExitCode.invalidUsage);
      final error = jsonDecode(jsonErr)['error'] as Map<String, dynamic>;
      expect(error['id'], 'extra-argument');
      expect(error['message'], "cx received 3 arguments; quote the program "
          "as one argument: cx '1 2 +'");

      final (quietCode, _, quietErr) = await run(['-q', '1', '2', '+']);
      expect(quietCode, ExitCode.invalidUsage);
      expect(quietErr, startsWith("Error: cx received 3 arguments; quote the "
          "program as one argument: cx '1 2 +' [extra-argument]"));
    });

    test('eval rpn with no program names the options that exist', () async {
      final (code, _, err) = await run(['eval', 'rpn']);
      expect(code, ExitCode.validationFailed);
      expect(err, isNot(contains('--program')));
      expect(err, contains('<program>, --file or --stdin'));
    });

    test('an unknown help topic is a usage error with a suggestion', () async {
      final (code, out, err) = await run(['help', 'nope']);
      expect(code, ExitCode.invalidUsage);
      expect(out, isEmpty);
      expect(err, contains("unknown help topic 'nope'"));

      final (_, _, near) = await run(['help', 'verison']);
      expect(near, contains("Did you mean 'cx help version'?"));

      final (okCode, _, _) = await run(['help', 'eval', 'rpn']);
      expect(okCode, ExitCode.ok);
    });
  });
}
