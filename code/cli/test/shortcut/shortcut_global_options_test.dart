// Issue #68 (runbook-agent-usability.md D63, spec G4): the `cx <program>`
// shortcut accepts the global output options `--json` and `--quiet`/`-q`,
// before or after the program, exactly as `cx eval rpn` does, and rejects
// the options only `eval rpn` has (`--file`, `--stdin`) with the full
// spelling to type.
import 'dart:convert';

import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import '../support/memory_sink.dart';

class _Run {
  _Run(this.code, this.out, this.err);
  final int code;
  final String out;
  final String err;
}

Future<_Run> _run(List<String> args) async {
  final out = MemorySink();
  final err = MemorySink();
  final code = await runCalculatrixCli(args, stdout: out, stderr: err);
  return _Run(code, out.output, err.output);
}

void main() {
  group('global options on the shortcut (#68)', () {
    test('cx --json \'1 3 /\' is identical to cx eval rpn --json', () async {
      final shortcut = await _run(['--json', '1 3 /']);
      final eval = await _run(['eval', 'rpn', '--json', '1 3 /']);
      expect(shortcut.code, ExitCode.ok);
      expect(shortcut.out, eval.out);
      expect(shortcut.out, contains('"value": "1/3"'));
      expect(shortcut.err, isEmpty);
    });

    test(
      'cx \'1 3 /\' --json is identical to cx eval rpn \'1 3 /\' --json',
      () async {
        final shortcut = await _run(['1 3 /', '--json']);
        final eval = await _run(['eval', 'rpn', '1 3 /', '--json']);
        expect(shortcut.code, ExitCode.ok);
        expect(shortcut.out, eval.out);
        expect(shortcut.err, isEmpty);
      },
    );

    test('-q and --quiet are identical to cx eval rpn -q', () async {
      final eval = await _run(['eval', 'rpn', '-q', '1 3 /']);
      final short = await _run(['-q', '1 3 /']);
      final long = await _run(['--quiet', '1 3 /']);
      expect(short.code, ExitCode.ok);
      expect(long.code, ExitCode.ok);
      expect(short.out, eval.out);
      expect(long.out, eval.out);
      expect(short.err, isEmpty);
      expect(long.err, isEmpty);
    });

    test('--max-digits stays accepted', () async {
      final result = await _run(['--max-digits', '5', '1 3 /']);
      expect(result.code, ExitCode.ok);
      expect(result.out, contains('1: 1/3'));
    });

    test('cx --json with no program is still the banner JSON', () async {
      final result = await _run(['--json']);
      expect(result.code, ExitCode.ok);
      expect(jsonDecode(result.out), isA<Map<String, dynamic>>());
      expect(result.out, contains('"name"'));
    });

    test('cx --file p.txt is rejected, 7, unknown-option, naming '
        'cx eval rpn --file p.txt', () async {
      final result = await _run(['--file', 'p.txt']);
      expect(result.code, 7);
      expect(
        result.err,
        startsWith(
          'Error: --file is not accepted by the shortcut; use: '
          'cx eval rpn --file p.txt [unknown-option]',
        ),
      );
    });

    test("cx '1 2 +' --stdin is rejected, 7, unknown-option, in the same "
        'order and with the program quoted', () async {
      final result = await _run(['1 2 +', '--stdin']);
      expect(result.code, 7);
      expect(
        result.err,
        startsWith(
          "Error: --stdin is not accepted by the shortcut; use: "
          "cx eval rpn '1 2 +' --stdin [unknown-option]",
        ),
      );
    });

    test("cx '1 2 +' --file p.txt gives the message of the spec", () async {
      final result = await _run(['1 2 +', '--file', 'p.txt']);
      expect(result.code, 7);
      expect(
        result.err,
        startsWith(
          "Error: --file is not accepted by the shortcut; use: "
          "cx eval rpn '1 2 +' --file p.txt [unknown-option]",
        ),
      );
    });

    test('the same message in JSON, error.message, shape unchanged', () async {
      final result = await _run(['--json', '1 2 +', '--file', 'p.txt']);
      expect(result.code, 7);
      final decoded = jsonDecode(result.err.trim()) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      expect(error['id'], 'unknown-option');
      expect(error['exitCode'], 7);
      expect(
        error['message'],
        "--file is not accepted by the shortcut; use: "
        "cx eval rpn --json '1 2 +' --file p.txt",
      );
    });

    test('arguments with shell characters are single-quoted in the '
        'suggestion, plain ones are not', () async {
      final result = await _run(['[[1 2] [3 4]] inverse', '-f', 'a.txt']);
      expect(result.code, 7);
      expect(
        result.err,
        startsWith(
          "Error: -f is not accepted by the shortcut; use: "
          "cx eval rpn '[[1 2] [3 4]] inverse' -f a.txt [unknown-option]",
        ),
      );
    });

    test('eval rpn itself is unchanged: --file still works there', () async {
      final result = await _run(['eval', 'rpn', '--file', 'nope-missing.txt']);
      expect(result.err, isNot(contains('shortcut')));
    });
  });
}
