// Tests for runbook stage S4e (docs/runbook-cli-stage-0.md): `cx commands
// show`, `cx commands search`, `cx commands list` and the "did you mean"
// this stage adds (issue #41). Excluded from calculatrix_cli_test.dart's
// scope on purpose (see that file's own header comment).
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

  group('cx commands show (issue #41, AC1)', () {
    test(
      'show power prints name, aliases, category and stack effect',
      () async {
        final code = await run(['commands', 'show', 'power']);
        expect(code, ExitCode.ok);
        expect(out.output, contains('power'));
        expect(out.output, contains('pwr'));
        expect(out.output, contains('^'));
        expect(out.output, contains('Category: arithmetic'));
        expect(out.output, contains('Definition: primitive'));
        expect(out.output, contains('Stack effect:'));
      },
    );

    test('show ^ resolves the alias to power', () async {
      final code = await run(['commands', 'show', '^']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('power'));
    });

    test('show √ resolves sqrt with its definition', () async {
      final code = await run(['commands', 'show', '√']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('sqrt'));
      expect(out.output, contains('Definition: 0.5 power'));
    });

    test('show dup shows duplicate, defined as 1 pick', () async {
      final code = await run(['commands', 'show', 'dup']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('duplicate'));
      expect(out.output, contains('Definition: 1 pick'));
    });

    test('show power --json carries every field of the entry', () async {
      final code = await run(['commands', 'show', '--json', 'power']);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      expect(decoded['name'], 'power');
      expect(decoded['aliases'], containsAll(<String>['pwr', '^']));
      expect(decoded['category'], 'arithmetic');
      expect(decoded['primitive'], isTrue);
      expect(decoded['errors'], contains('dimension-mismatch'));
      expect(decoded['examples'], isNotEmpty);
    });

    test('show hcat (a search term, never a word) is unknown-word, '
        'suggesting append-cols (AC1, AC5)', () async {
      final code = await run(['commands', 'show', '--json', 'hcat']);
      expect(code, ExitCode.dataError);
      // The error envelope goes to stderr, never stdout
      // (`_renderRecordedError` in modular_cli_sdk writes only to `err`).
      final decoded = jsonDecode(err.output) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      expect(error['id'], 'unknown-word');
      expect(
        (error['details'] as Map<String, dynamic>)['suggestions'],
        contains('append-cols'),
      );
    });

    test('show, on a case-insensitive match, still resolves', () async {
      final code = await run(['commands', 'show', 'POWER']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('power'));
    });
  });

  group('cx commands search (issue #41, AC2)', () {
    test('search column finds append-cols and vector', () async {
      final code = await run(['commands', 'search', 'column']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('append-cols'));
      expect(out.output, contains('vector'));
    });

    test('search hcat finds append-cols', () async {
      final code = await run(['commands', 'search', 'hcat']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('append-cols'));
    });

    test('search FNORM finds frobenius-norm', () async {
      final code = await run(['commands', 'search', 'FNORM']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('frobenius-norm'));
    });

    test('no match is an empty list, exit 0', () async {
      final code = await run([
        'commands',
        'search',
        '--json',
        'zzzzzzzzzzzzzzzzzzzz',
      ]);
      expect(code, ExitCode.ok);
      expect(jsonDecode(out.output), {'matches': <dynamic>[]});
    });

    test('search --json returns full entries, not summaries', () async {
      final code = await run(['commands', 'search', '--json', 'hcat']);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final matches = decoded['matches'] as List<dynamic>;
      final appendCols = matches.cast<Map<String, dynamic>>().firstWhere(
        (m) => m['name'] == 'append-cols',
      );
      expect(appendCols['examples'], isNotEmpty);
      expect(appendCols['stackEffect'], isNotEmpty);
    });
  });

  group('cx commands list (issue #41, AC3)', () {
    test('list --category stack lists only the stack category', () async {
      final code = await run(['commands', 'list', '--category', 'stack']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('stack:'));
      expect(out.output, isNot(contains('arithmetic:')));
    });

    test('list with no filter groups every category', () async {
      final code = await run(['commands', 'list']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('arithmetic:'));
      expect(out.output, contains('stack:'));
      expect(out.output, contains('linear-algebra:'));
    });

    test('list --category bogus is the CLI usage error, exit 7, naming the '
        'valid categories', () async {
      final code = await run(['commands', 'list', '--category', 'bogus']);
      expect(code, ExitCode.validationFailed);
      expect(err.output, contains('arithmetic'));
      expect(err.output, contains('linear-algebra'));
    });

    test('list --json --category matrix returns full entries', () async {
      final code = await run([
        'commands',
        'list',
        '--json',
        '--category',
        'matrix',
      ]);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final commands = decoded['commands'] as List<dynamic>;
      expect(commands, isNotEmpty);
      for (final entry in commands.cast<Map<String, dynamic>>()) {
        expect(entry['category'], 'matrix');
      }
    });
  });

  group('cx help and the banner list commands (AC7)', () {
    test('the bare banner mentions the commands route', () async {
      final code = await run([]);
      expect(code, ExitCode.ok);
      expect(out.output, contains('commands'));
    });

    test(
      'cx help (the catalog-wide help query) lists the commands route',
      () async {
        // `cx --help` alone is the root query's own contract help, which
        // names only itself. The whole catalog is `cx help` (the literal
        // route, auto-registered by the SDK from `cli.catalog`), never a
        // second, hand-kept list (AC7).
        final code = await run(['help']);
        expect(code, ExitCode.ok);
        expect(out.output, contains('commands show'));
        expect(out.output, contains('commands search'));
        expect(out.output, contains('commands list'));
      },
    );
  });

  group('exactness and literals in the registry (issue #66)', () {
    test('show add prints its exact examples without ~', () async {
      final code = await run(['commands', 'show', 'add']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('2 3 + -> 5\n'));
      expect(out.output, isNot(contains('~')));
    });

    for (final String query in <String>['literal', 'fraction', 'decimal']) {
      test('search $query finds exact', () async {
        final code = await run(['commands', 'search', query]);
        expect(code, ExitCode.ok);
        expect(out.output, contains('exact: '));
      });
    }

    test('search literal also finds approx, which explains ~', () async {
      final code = await run(['commands', 'search', 'literal']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('put ~ in front of the literal'));
    });
  });
}
