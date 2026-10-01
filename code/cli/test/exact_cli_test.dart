// Exact numbers through `cx` (runbook-trust.md, steps T2 to T5): the
// output of D54, the approximate mark as input (D56), fraction literals
// (D59), contagion (D51), the exact linear algebra words, roots and
// eigenvalues (D53) and the size limit with --max-digits (D55).
import 'dart:convert';

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

  Future<int> run(List<String> args, {String stdin = ''}) {
    final cli = buildCalculatrixCli(readStdin: () => stdin);
    return cli.run(args, stdout: out, stderr: err, environment: const {});
  }

  Map<String, dynamic> errorOf() =>
      (jsonDecode(out.output + err.output) as Map)['error']
          as Map<String, dynamic>;

  group('text output (D54)', () {
    for (final (String program, String expected) in [
      ('0.1 0.2 +', '1: 0.3\n'),
      ('1 3 /', '1: 1/3\n'),
      ('1 1024 /', '1: 0.0009765625\n'),
      ('1 1073741824 /', '1: 1/1073741824\n'),
      ('3 40 ^', '1: 12157665459056928801\n'),
      ('2 -1 ^', '1: 0.5\n'),
      ('[[1 2] [3 4]] 2 ^', '1: [[7 10] [15 22]]\n'),
      ('[[1 2] [3 4]] inverse', '1: [[-2 1] [1.5 -0.5]]\n'),
      ('[[1 2] [3 4]] -1 ^', '1: [[-2 1] [1.5 -0.5]]\n'),
      ('[[2 1] [1 3]] 3 / inverse', '1: [[1.8 -0.6] [-0.6 1.2]]\n'),
      ('[[1 2] [3 4]] determinant', '1: -2\n'),
      ('[[1 2 3] [4 5 6] [7 8 10]] 3 / determinant', '1: -1/9\n'),
      ('[[1 2] [2 4]] rank', '1: 1\n'),
      ('[[2 4 6] [1 3 5]] rref', '1: [[1 0 -1] [0 1 2]]\n'),
      ('[[1] [2] [3]] 7 / [[4] [5] [6]] dot', '1: 32/7\n'),
      ('[[1 2] [3 4]] ~1 * inverse', '1: ~[[-2 1] [1.5 -0.5]]\n'),
      ('1 3 / approx', '1: ~0.333333333333\n'),
      ('~0.1 0.2 +', '1: ~0.3\n'),
      ('~-0.1 0.1 +', '1: ~0\n'),
      ('[[1 ~2]]', '1: ~[[1 2]]\n'),
      ('0.1 approx exact', '1: 0.1\n'),
      ('1 3 / approx exact', '1: 1/3\n'),
      ('5 1 3 /', '2: 5\n1: 1/3\n'),
      ('4 sqrt', '1: 2\n'),
      ('2 sqrt', '1: ~1.41421356237\n'),
      ('-4 sqrt', '1: [[0 -2] [2 0]]\n'),
      ('27 8 / 2 3 / ^', '1: 2.25\n'),
      ('[[5 4] [4 5]] sqrt', '1: [[2 1] [1 2]]\n'),
      ('[[3 -4] [4 3]] sqrt', '1: [[2 -1] [1 2]]\n'),
      ('[[2 1] [1 2]] eigenvalues', '1: [[3] [1]]\n'),
      (
        '[[1 2] [3 4]] eigenvalues',
        '1: ~[[5.37228132327] [-0.372281323269]]\n',
      ),
      ('[[3 4]] frobenius-norm', '1: 5\n'),
      ('[[0 0] [0 0]] exp', '1: [[1 0] [0 1]]\n'),
      ('1 exp', '1: ~2.71828182846\n'),
    ]) {
      test("cx '$program'", () async {
        final code = await run([program]);
        expect(code, ExitCode.ok, reason: err.output);
        expect(out.output, expected);
      });
    }

    test("cx eval infix '1/3+1/6' is exact", () async {
      final code = await run(['eval', 'infix', '1/3+1/6']);
      expect(code, ExitCode.ok);
      expect(out.output, '1: 0.5\n');
    });

    test("cx eval infix '~1/3' is approximate", () async {
      final code = await run(['eval', 'infix', '~1/3']);
      expect(code, ExitCode.ok);
      expect(out.output, '1: ~0.333333333333\n');
    });
  });

  group('JSON output (D54)', () {
    test(
      'each level says whether it is exact; exact numbers are strings',
      () async {
        final code = await run([
          'eval',
          'rpn',
          '--json',
          '1 3 / ~2 [[1 2]] 3 40 ^',
        ]);
        expect(code, ExitCode.ok);
        expect(jsonDecode(out.output), {
          'stack': [
            {'level': 4, 'exact': true, 'value': '1/3'},
            {'level': 3, 'exact': false, 'value': 2},
            {
              'level': 2,
              'exact': true,
              'value': [
                ['1', '2'],
              ],
            },
            {'level': 1, 'exact': true, 'value': '12157665459056928801'},
          ],
        });
      },
    );

    test('an approximate number keeps the full double', () async {
      final code = await run(['eval', 'rpn', '--json', '1 3 / approx']);
      expect(code, ExitCode.ok);
      final level = ((jsonDecode(out.output) as Map)['stack'] as List).single;
      expect(level, {'level': 1, 'exact': false, 'value': 1 / 3});
    });
  });

  group('the approximate mark as input (D56)', () {
    test("cx '-~0.1' is syntax-error and shows ~-0.1", () async {
      final code = await run(['eval', 'rpn', '--json', '-~0.1']);
      expect(code, ExitCode.dataError);
      final error = errorOf();
      expect(error['id'], 'syntax-error');
      expect(error['message'], contains('~-0.1'));
    });

    test("cx eval infix '1+-~0.1' is syntax-error and shows ~-0.1", () async {
      final code = await run(['eval', 'infix', '--json', '1+-~0.1']);
      expect(code, ExitCode.dataError);
      final error = errorOf();
      expect(error['id'], 'syntax-error');
      expect(error['message'], contains('~-0.1'));
    });
  });

  group('fraction literals (D59)', () {
    for (final (String program, String expected) in [
      ('1/3 3 *', '1: 1\n'),
      ('-5/3 1/3 +', '1: -4/3\n'),
      ('[[1/3 2] [3 4]] inverse', '1: [[-6/7 3/7] [9/14 -1/14]]\n'),
      ('~1/3', '1: ~0.333333333333\n'),
    ]) {
      test("cx '$program'", () async {
        final code = await run([program]);
        expect(code, ExitCode.ok, reason: err.output);
        expect(out.output, expected);
      });
    }

    test('every exact output types back to the same value', () async {
      for (final String program in <String>[
        '1 3 /',
        '[[1 2] [3 4]] 3 / inverse',
        '10 30 ^ 7 /',
      ]) {
        out = MemorySink();
        expect(await run([program]), ExitCode.ok);
        final String printed = out.output.substring('1: '.length).trim();
        out = MemorySink();
        expect(await run([printed]), ExitCode.ok, reason: printed);
        expect(out.output, '1: $printed\n', reason: program);
      }
    });

    test("cx '1/0' is non-finite", () async {
      final code = await run(['eval', 'rpn', '--json', '1/0']);
      expect(code, ExitCode.dataError);
      expect(errorOf()['id'], 'non-finite');
    });

    test("cx '1.5/2' is no literal, so an unknown word", () async {
      final code = await run(['eval', 'rpn', '--json', '1.5/2']);
      expect(code, ExitCode.dataError);
      expect(errorOf()['id'], 'unknown-word');
    });

    test("cx '[[1 1.5/2]]' is syntax-error", () async {
      final code = await run(['eval', 'rpn', '--json', '[[1 1.5/2]]']);
      expect(code, ExitCode.dataError);
      expect(errorOf()['id'], 'syntax-error');
    });
  });

  group('size limit (D55)', () {
    test(
      'a power over the limit is limit-exceeded, 65, with the next step',
      () async {
        final code = await run(['eval', 'rpn', '--json', '3 1000000 ^']);
        expect(code, ExitCode.dataError);
        final error = errorOf();
        expect(error['id'], 'limit-exceeded');
        expect(error['details'], {
          'token': '^',
          'position': 11,
          'limit': 10000,
          'estimated': 477122,
        });
        expect(
          error['message'],
          '3^1000000 has about 477122 digits, over the limit of 10000; for an '
          "approximate result: cx '3 1000000 approx ^', or raise the limit "
          'with --max-digits.',
        );
      },
    );

    test('the suggested program runs, and is approximate', () async {
      final code = await run([
        'eval',
        'rpn',
        '--json',
        '--max-digits',
        '5',
        '10 6 ^',
      ]);
      expect(code, ExitCode.dataError);
      expect(errorOf()['message'], contains("cx '10 6 approx ^'"));
      out = MemorySink();
      err = MemorySink();
      final rerun = await run(['10 6 approx ^']);
      expect(rerun, ExitCode.ok);
      expect(out.output, '1: ~1000000\n');
    });

    test('an exact determinant over the limit suggests approx', () async {
      final code = await run([
        'eval',
        'rpn',
        '--json',
        '--max-digits',
        '50',
        '[[1e30 1] [1 1e30]] determinant',
      ]);
      expect(code, ExitCode.dataError);
      final error = errorOf();
      expect(error['id'], 'limit-exceeded');
      expect(error['details']['estimated'], 61);
      expect(
        error['message'],
        'The exact determinant could have up to 61 digits (Hadamard bound), '
        'over the limit of 50; for an approximate result: '
        "cx '[[1e30 1] [1 1e30]] approx determinant', or raise the limit with "
        '--max-digits.',
      );
      out = MemorySink();
      err = MemorySink();
      expect(
        await run(['[[1e30 1] [1 1e30]] approx determinant']),
        ExitCode.ok,
      );
      expect(out.output, startsWith('1: ~'));
    });

    test('exact eigenvalues over the limit suggest approx', () async {
      final code = await run([
        'eval',
        'rpn',
        '--json',
        '--max-digits',
        '50',
        '[[1e30 1] [1 1e30]] eigenvalues',
      ]);
      expect(code, ExitCode.dataError);
      final error = errorOf();
      expect(error['id'], 'limit-exceeded');
      expect(error['details']['estimated'], 62);
      expect(
        error['message'],
        'The exact characteristic polynomial could have up to 62 digits '
        '(norm bound), over the limit of 50; for an approximate result: '
        "cx '[[1e30 1] [1 1e30]] approx eigenvalues', or raise the limit "
        'with --max-digits.',
      );
    });

    test('complex eigenvalues are complex-result (D60)', () async {
      final code = await run([
        'eval',
        'rpn',
        '--json',
        '[[0 -1] [1 0]] eigenvalues',
      ]);
      expect(code, ExitCode.dataError);
      final error = errorOf();
      expect(error['id'], 'complex-result');
      expect(
        error['message'],
        'The eigenvalues of this matrix are complex, and cx has no complex '
        'columns yet.',
      );
    });

    test('a literal over the limit suggests the mark ~', () async {
      final code = await run(['eval', 'rpn', '--json', '1 1e20000 +']);
      expect(code, ExitCode.dataError);
      final error = errorOf();
      expect(error['id'], 'limit-exceeded');
      expect(error['message'], contains("cx '1 ~1e20000 +'"));
      expect(error['details']['limit'], 10000);
      expect(error['details']['estimated'], 20001);
    });

    test('an infix literal over the limit suggests the mark ~', () async {
      final code = await run(['eval', 'infix', '--json', '1e20000+1']);
      expect(code, ExitCode.dataError);
      expect(errorOf()['message'], contains("cx eval infix '~1e20000+1'"));
    });

    test('an infix power over the limit says to mark a number', () async {
      final code = await run(['eval', 'infix', '--json', '3^1000000']);
      expect(code, ExitCode.dataError);
      final error = errorOf();
      expect(error['id'], 'limit-exceeded');
      expect(error['message'], contains('mark one of its numbers with ~'));
    });

    test('--max-digits raises the limit on eval rpn', () async {
      final code = await run([
        'eval',
        'rpn',
        '--max-digits',
        '20000',
        '3 20000 ^',
      ]);
      expect(code, ExitCode.ok, reason: err.output);
      // 3^20000 has 9543 digits; within the default limit too. 3^30000 has
      // 14314, over the default and within 20000.
      final big = await run([
        'eval',
        'rpn',
        '--max-digits',
        '20000',
        '3 30000 ^',
      ]);
      expect(big, ExitCode.ok, reason: err.output);
    });

    test('--max-digits lowers the limit on eval infix', () async {
      final code = await run([
        'eval',
        'infix',
        '--json',
        '--max-digits',
        '5',
        '10^6',
      ]);
      expect(code, ExitCode.dataError);
      expect(errorOf()['details']['limit'], 5);
    });

    test('--max-digits works on the cx <program> shortcut', () async {
      final code = await run(['--max-digits', '3', '10 3 ^']);
      expect(code, ExitCode.dataError);
      expect(err.output, contains('limit-exceeded'));
    });

    test('--max-digits 0 is validation-failed', () async {
      final code = await run(['eval', 'rpn', '--max-digits', '0', '1']);
      expect(code, ExitCode.validationFailed);
    });
  });
}
