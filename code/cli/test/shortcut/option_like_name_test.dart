// Tests for issue #82: a program that starts with "-" followed by a name
// (`cx -pi`, `cx -e`) is read as options. The message now points to "--"
// when the name is a registry word, alias or constant.
import 'dart:convert';

import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:calculatrix_cli/src/shortcut/option_like_value_error.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import '../support/memory_sink.dart';

String _hint(String value, String command) =>
    '$value starts with "-", so it was read as options; to pass it as a '
    'value, end the options with --: $command';

Future<(int, String)> _run(List<String> args) async {
  final out = MemorySink();
  final err = MemorySink();
  final code = await runCalculatrixCli(args, stdout: out, stderr: err);
  return (code, err.output);
}

void main() {
  group('optionLikeValueIndex on a dash and a name (issue #82)', () {
    test('finds a registry word, alias or constant', () {
      expect(optionLikeValueIndex(['-pi']), 0);
      expect(optionLikeValueIndex(['-PI']), 0);
      expect(optionLikeValueIndex(['-e']), 0);
      expect(optionLikeValueIndex(['-dup']), 0);
    });

    test('ignores declared short options and unknown names', () {
      expect(optionLikeValueIndex(['-qh']), -1);
      expect(optionLikeValueIndex(['-x']), -1);
      expect(optionLikeValueIndex(['-q']), -1);
      expect(optionLikeValueIndex(['-h']), -1);
    });
  });

  group('runCalculatrixCli on a dash and a name (issue #82)', () {
    test('cx -pi', () async {
      final (code, err) = await _run(['-pi']);
      expect(code, ExitCode.validationFailed);
      expect(
        err,
        startsWith(
          "Error: ${_hint('-pi', "cx -- '-pi'")} [invalid-short-option]",
        ),
      );
    });

    test('cx -PI', () async {
      final (_, err) = await _run(['-PI']);
      expect(err, startsWith("Error: ${_hint('-PI', "cx -- '-PI'")} "));
    });

    test('cx -dup', () async {
      final (_, err) = await _run(['-dup']);
      expect(err, startsWith("Error: ${_hint('-dup', "cx -- '-dup'")} "));
    });

    test('cx -e', () async {
      final (code, err) = await _run(['-e']);
      expect(code, ExitCode.validationFailed);
      expect(
        err,
        startsWith("Error: ${_hint('-e', "cx -- '-e'")} [unknown-option]"),
      );
    });

    test('cx -i', () async {
      final (_, err) = await _run(['-i']);
      expect(err, startsWith("Error: ${_hint('-i', "cx -- '-i'")} "));
    });

    test('cx eval rpn -pi', () async {
      final (_, err) = await _run(['eval', 'rpn', '-pi']);
      expect(
        err,
        startsWith("Error: ${_hint('-pi', "cx eval rpn -- '-pi'")} "),
      );
    });

    test('cx eval rpn -dup', () async {
      final (_, err) = await _run(['eval', 'rpn', '-dup']);
      expect(
        err,
        startsWith("Error: ${_hint('-dup', "cx eval rpn -- '-dup'")} "),
      );
    });

    test('cx --json -pi', () async {
      final (code, err) = await _run(['--json', '-pi']);
      expect(code, ExitCode.validationFailed);
      final error =
          (jsonDecode(err) as Map<String, dynamic>)['error']
              as Map<String, dynamic>;
      expect(error['id'], 'invalid-short-option');
      expect(error['exitCode'], ExitCode.validationFailed);
      expect(error['message'], _hint('-pi', "cx --json -- '-pi'"));
    });

    test('cx --json -e', () async {
      final (_, err) = await _run(['--json', '-e']);
      final error =
          (jsonDecode(err) as Map<String, dynamic>)['error']
              as Map<String, dynamic>;
      expect(error['id'], 'unknown-option');
      expect(error['message'], _hint('-e', "cx --json -- '-e'"));
    });

    test('cx -qh keeps its message', () async {
      final (_, err) = await _run(['-qh']);
      expect(err, isNot(contains('starts with "-"')));
    });

    test('cx -x keeps its message', () async {
      final (_, err) = await _run(['-x']);
      expect(err, startsWith("Error: unknown option '-x' [unknown-option]"));
    });

    test('cx program --file keeps the #68 message', () async {
      final (_, err) = await _run(['1 2 +', '--file', 'p.txt']);
      expect(err, contains('--file is not accepted by the shortcut'));
      expect(err, isNot(contains('starts with "-"')));
    });

    test('cx eval rpn -f program.rpn -e: -f is declared, so -e still gets '
        'the hint (Codex review on #83)', () async {
      expect(optionLikeValueIndex(['eval', 'rpn', '-f', 'p.rpn', '-e']), 4);
      final (code, err) = await _run(['eval', 'rpn', '-f', 'p.rpn', '-e']);
      expect(code, ExitCode.validationFailed);
      expect(err, contains(_hint('-e', "cx eval rpn -f p.rpn -- '-e'")));
    });

    test('cx -pi prints the hint and one line pointing to --help, not the '
        'whole catalog (modular_cli_sdk 0.11.0)', () async {
      final (code, err) = await _run(['-pi']);
      expect(code, ExitCode.validationFailed);
      expect(
        err,
        'Error: ${_hint('-pi', "cx -- '-pi'")} [invalid-short-option]\n'
        '\n'
        'Run "cx --help" to see every command.\n',
      );
    });

    test("cx -- '-pi' exits 65 and says how to negate", () async {
      final (code, err) = await _run(['--', '-pi']);
      expect(code, 65);
      expect(err, contains('pi negate'));
    });
  });
}
