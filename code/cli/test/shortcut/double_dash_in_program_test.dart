// Issue #73 (runbook-agent-usability.md D68, step U4b) through the CLI: the
// token `--` inside a program, in the shortcut and in `eval rpn`.
import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:test/test.dart';

import '../support/memory_sink.dart';

void main() {
  const form =
      '"--" is not part of a program: it ends the options and goes before '
      'the quoted program: ';

  for (final prefix in [
    <String>[],
    <String>['eval', 'rpn'],
  ]) {
    final name = prefix.isEmpty ? 'shortcut' : 'eval rpn';

    test('$name: a -- inside the program names the form to type', () async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(
        [...prefix, '[[1 2] [0 1]] -- -3 ^'],
        stdout: out,
        stderr: err,
      );
      expect(code, 65);
      expect(
        err.output,
        startsWith(
          "Error: ${form}cx eval rpn '[[1 2] [0 1]] -3 ^' "
          '[unknown-word]',
        ),
      );
      expect(err.output, isNot(contains('Did you mean')));
    });

    test('$name: a program that starts with - goes after --', () async {
      final err = MemorySink();
      final code = await runCalculatrixCli(
        [...prefix, '-- -1 2 +'],
        stdout: MemorySink(),
        stderr: err,
      );
      expect(code, 65);
      expect(
        err.output,
        startsWith("Error: ${form}cx eval rpn -- '-1 2 +' [unknown-word]"),
      );
    });

    test('$name: a trailing -- is dropped from the form', () async {
      final err = MemorySink();
      final code = await runCalculatrixCli(
        [...prefix, '1 2 + --'],
        stdout: MemorySink(),
        stderr: err,
      );
      expect(code, 65);
      expect(
        err.output,
        startsWith("Error: ${form}cx eval rpn '1 2 +' [unknown-word]"),
      );
    });
  }
}
