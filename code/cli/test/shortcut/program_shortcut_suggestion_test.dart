// "Did you mean" for routes. A typo at the root
// (`cx <program>`) runs as an RPN program through the shortcut, so it is
// unknown-word, the same as any other unrecognized word; ProgramShortcutQuery
// additionally tries the typo against the route vocabulary
// (`ModularCli.suggest`) and, when it finds a close route, adds that as a
// second, separate suggestion. `eval rpn` itself never gains this: only the
// shortcut has the ambiguity a typo at the root is a program, because of the shortcut.
import 'dart:convert';

import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import '../support/memory_sink.dart';

void main() {
  late MemorySink out;
  late MemorySink err;

  setUp(() {
    out = MemorySink();
    err = MemorySink();
  });

  Future<int> run(List<String> args) {
    final cli = buildCalculatrixCli(readStdin: () => '');
    return cli.run(args, stdout: out, stderr: err, environment: const {});
  }

  test(
    'cx verison is unknown-word and suggests the route "version"',
    () async {
      // Not `cx --json verison`: the shortcut takes no options, not even
      // the global ones, so `--json` is never available here; the
      // error envelope is always rendered as text, and always to stderr
      // (`_renderRecordedError` writes only to `err`, never `out`).
      final code = await run(['verison']);
      expect(code, ExitCode.dataError);
      expect(err.output, contains('unknown-word'));
      expect(err.output, contains("Did you mean the command 'cx version'?"));
      expect(err.output, contains('routeSuggestion: version'));
    },
  );

  test('cx eval rpn verison is unknown-word with no route suggestion '
      '(only the shortcut has the ambiguity)', () async {
    final code = await run(['eval', 'rpn', '--json', 'verison']);
    expect(code, ExitCode.dataError);
    final decoded = jsonDecode(err.output) as Map<String, dynamic>;
    final error = decoded['error'] as Map<String, dynamic>;
    expect(error['id'], 'unknown-word');
    expect(
      (error['details'] as Map<String, dynamic>?)?.containsKey(
        'routeSuggestion',
      ),
      isNot(true),
    );
  });

  test('cx commands shwo power uses the SDK route suggestion', () async {
    final code = await run(['commands', 'shwo', 'power']);
    expect(code, isNot(ExitCode.ok));
    final combined = out.output + err.output;
    expect(combined, contains('show'));
  });

  test(
    'cx pow is unknown-word and suggests only the word "power"; it does '
    'not also suggest the invalid command "cx show", a bare fragment of '
    'the real route "commands show" that ModularCli.suggest used to '
    'return for this typo',
    () async {
      final code = await run(['pow']);
      expect(code, ExitCode.dataError);
      expect(err.output, contains('unknown-word'));
      expect(err.output, contains('power'));
      expect(err.output, isNot(contains('routeSuggestion')));
      expect(err.output, isNot(contains('cx show')));
    },
  );
}
