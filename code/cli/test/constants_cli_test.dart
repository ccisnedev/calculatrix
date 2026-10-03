// Issue #70 (runbook-agent-usability.md D66, D67, step U5): the constants
// pi, e and i through `cx`: evaluation, discovery in the registry commands,
// and the suggestion for a near miss.
import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import 'support/memory_sink.dart';

void main() {
  late MemorySink out;
  late MemorySink err;

  setUp(() {
    out = MemorySink();
    err = MemorySink();
  });

  Future<int> run(List<String> args) =>
      runCalculatrixCli(args, stdout: out, stderr: err);

  group('evaluation', () {
    test("cx 'pi' prints 1: ~3.14159265359", () async {
      expect(await run(['pi']), ExitCode.ok);
      expect(out.output, '1: ~3.14159265359\n');
    });

    test("cx 'π' prints the same", () async {
      expect(await run(['π']), ExitCode.ok);
      expect(out.output, '1: ~3.14159265359\n');
    });

    test("cx 'e' prints 1: ~2.71828182846", () async {
      expect(await run(['e']), ExitCode.ok);
      expect(out.output, '1: ~2.71828182846\n');
    });

    test("cx 'i' prints 1: [[0 -1] [1 0]], exact", () async {
      expect(await run(['i']), ExitCode.ok);
      expect(out.output, '1: [[0 -1] [1 0]]\n');
    });

    test("cx '3 4 i * +' prints 1: [[3 -4] [4 3]]", () async {
      expect(await run(['3 4 i * +']), ExitCode.ok);
      expect(out.output, '1: [[3 -4] [4 3]]\n');
    });

    test("cx eval infix 'e^(i*pi)' is -1 as a matrix", () async {
      expect(await run(['eval', 'infix', 'e^(i*pi)']), ExitCode.ok);
      expect(out.output, startsWith('1: ~[[-1 '));
    });

    test("cx eval infix '2*pi' prints 1: ~6.28318530718", () async {
      expect(await run(['eval', 'infix', '2*pi']), ExitCode.ok);
      expect(out.output, '1: ~6.28318530718\n');
    });

    test("cx -- '-pi' says how to negate, exit 65", () async {
      expect(await run(['--', '-pi']), 65);
      expect(
        out.output + err.output,
        contains('"-" is not part of a name; to negate it: pi negate'),
      );
    });

    test("cx '~pi' says how to make it approximate, exit 65", () async {
      expect(await run(['~pi']), 65);
      expect(
        out.output + err.output,
        contains(
          '"~" marks numeric literals only; to make it approximate: pi approx',
        ),
      );
    });

    test("cx '[[pi 0] [0 1]]' names the constant, exit 65", () async {
      expect(await run(['[[pi 0] [0 1]]']), 65);
      expect(
        out.output + err.output,
        contains(
          'Invalid matrix literal: [[pi 0] [0 1]]; entries must be numbers, '
          '"pi" is a constant',
        ),
      );
    });
  });

  group('discovery', () {
    test(
      'cx commands show pi and cx commands show π print the entry',
      () async {
        for (final name in ['pi', 'π']) {
          out = MemorySink();
          err = MemorySink();
          expect(await run(['commands', 'show', name]), ExitCode.ok);
          expect(out.output, startsWith('pi (π)\n'));
          expect(out.output, contains('Category: constants'));
          expect(out.output, contains('HP 50g reference: π'));
          expect(out.output, contains('  pi -> ~3.14159265359'));
        }
      },
    );

    test('cx commands show i lists its three examples', () async {
      expect(await run(['commands', 'show', 'i']), ExitCode.ok);
      expect(out.output, contains('  i -> [[0 -1] [1 0]]'));
      expect(out.output, contains('  i dup * -> [[-1 0] [0 -1]]'));
      expect(out.output, contains('  3 4 i * + -> [[3 -4] [4 3]]'));
    });

    test('cx commands search constant finds pi, e and i', () async {
      expect(await run(['commands', 'search', 'constant']), ExitCode.ok);
      expect(out.output, contains('pi (π):'));
      expect(out.output, contains('\ne:'));
      expect(out.output, contains('\ni:'));
    });

    test('cx commands list shows a constants group', () async {
      expect(await run(['commands', 'list']), ExitCode.ok);
      expect(out.output, contains('\nconstants:\n'));
    });

    test(
      'cx commands list --category constants lists only the three',
      () async {
        expect(
          await run(['commands', 'list', '--category', 'constants']),
          ExitCode.ok,
        );
        expect(out.output, contains('pi (π):'));
        expect(out.output, isNot(contains('power')));
      },
    );

    test("cx 'pii' suggests pi", () async {
      expect(await run(['pii']), 65);
      expect(out.output + err.output, contains('"pi"'));
    });
  });
}
