// The trap set of the benchmark through `cx` (issue #54, acceptance 2;
// runbook-trust.md T6). Each trap of `benchmark/trap-set.json` must give
// its exact value, or its own error id when `cx` has no correct value to
// give (D60), in RPN and, where the trap has one, in infix.
import 'dart:convert';
import 'dart:io';

import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import 'support/memory_sink.dart';

final String _benchmark = '../../benchmark';

void main() {
  final List<Map<String, dynamic>> traps =
      (jsonDecode(File('$_benchmark/trap-set.json').readAsStringSync())
              as List<dynamic>)
          .cast<Map<String, dynamic>>();

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

  test('the set has the 8 tasks of tasks-traps.txt, in order', () {
    final List<String> tasks = File(
      '$_benchmark/tasks-traps.txt',
    ).readAsLinesSync().where((String line) => line.trim().isNotEmpty).toList();
    expect(tasks, hasLength(8));
    expect(traps.map((Map<String, dynamic> trap) => trap['task']).toList(), [
      for (final (int i, String line) in tasks.indexed)
        line.replaceFirst('${i + 1}. ', ''),
    ]);
  });

  for (final (int i, Map<String, dynamic> trap) in traps.indexed) {
    final String name = 'trap ${i + 1}: ${trap['task']}';
    for (final (String mode, String? program) in [
      ('rpn', trap['rpn'] as String),
      ('infix', trap['infix'] as String?),
    ]) {
      if (program == null) {
        continue;
      }
      test('$name ($mode)', () async {
        final String? error = trap['error'] as String?;
        if (error == null) {
          final int code = await run(['eval', mode, program]);
          expect(err.output, isEmpty);
          expect(code, ExitCode.ok);
          expect(out.output, '${trap['cx']}\n');
        } else {
          final int code = await run(['eval', mode, '--json', program]);
          expect(code, ExitCode.dataError);
          final Map<String, dynamic> body =
              jsonDecode(out.output + err.output) as Map<String, dynamic>;
          expect((body['error'] as Map<String, dynamic>)['id'], error);
        }
      });
    }
  }
}
