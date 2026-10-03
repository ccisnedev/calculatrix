// Issue #72 (runbook-agent-usability.md D64): one overview text, defined
// once in code, shown by the banner and by the install scripts. Every
// example in it must run.
import 'dart:io';

import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:calculatrix_cli/src/banner/banner_render.dart'
    show renderBanner;
import 'package:calculatrix_cli/src/banner/overview.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import '../support/memory_sink.dart';

void main() {
  group('cxOverviewLines (D64)', () {
    test('are exactly the four lines of the spec', () {
      expect(cxOverviewLines, <String>[
        "RPN:      cx '2 3 +'   (one quoted program; it can leave several "
            "results: cx '2 sqrt 1 3 /')",
        "Infix:    cx eval infix '2+3'",
        'Values:   every value is a matrix, exact (1/3, 0.1) or approximate, '
            'marked ~ (~1.41421356237)',
        'Discover: cx commands search <term>, cx commands show <word>; add '
            '--json for JSON output',
      ]);
    });

    test('are ASCII only', () {
      for (final line in cxOverviewLines) {
        expect(
          line.codeUnits.every((unit) => unit < 128),
          isTrue,
          reason: line,
        );
      }
    });

    test('the banner contains every line, indented two spaces, between the '
        'logo and Commands:', () async {
      final text = renderBanner(
        version: '0.16.0',
        color: false,
        registeredCommands: const {'eval rpn', 'eval infix'},
      );
      final lines = text.split('\n');
      final first = lines.indexOf('  ${cxOverviewLines.first}');
      expect(first, greaterThan(0));
      for (var i = 0; i < cxOverviewLines.length; i++) {
        expect(lines[first + i], '  ${cxOverviewLines[i]}');
      }
      expect(lines[first - 1], '', reason: 'one empty line after the logo');
      expect(lines[first + cxOverviewLines.length], '');
      expect(lines[first + cxOverviewLines.length + 1], '  Commands:');
    });

    test('the colored banner has the same overview text once the escapes '
        'are stripped', () {
      final colored = renderBanner(version: '0.16.0', color: true);
      final plain = renderBanner(version: '0.16.0', color: false);
      expect(colored.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), ''), plain);
    });

    for (final script in ['scripts/install.sh', 'scripts/install.ps1']) {
      test('$script contains every line verbatim, indented four spaces, '
          'then "More: cx --help"', () {
        final text = File(script).readAsStringSync().replaceAll('\r\n', '\n');
        for (final line in cxOverviewLines) {
          expect(text, contains('    $line'), reason: line);
        }
        expect(text, contains('    More: cx --help'));
        // After the "installed successfully" block.
        expect(
          text.indexOf('    ${cxOverviewLines.first}'),
          greaterThan(text.indexOf('installed successfully')),
        );
      });
    }
  });

  group('the examples of the overview run (exit 0)', () {
    Future<(int, String)> run(List<String> args) async {
      final out = MemorySink();
      final err = MemorySink();
      final code = await runCalculatrixCli(args, stdout: out, stderr: err);
      expect(err.output, isEmpty);
      return (code, out.output);
    }

    test("cx '2 3 +'", () async {
      final (code, out) = await run(['2 3 +']);
      expect(code, ExitCode.ok);
      expect(out, contains('1: 5'));
    });

    test("cx '2 sqrt 1 3 /' prints 2: ~1.41421356237 and 1: 1/3", () async {
      final (code, out) = await run(['2 sqrt 1 3 /']);
      expect(code, ExitCode.ok);
      expect(out, contains('2: ~1.41421356237'));
      expect(out, contains('1: 1/3'));
    });

    test("cx eval infix '2+3'", () async {
      final (code, out) = await run(['eval', 'infix', '2+3']);
      expect(code, ExitCode.ok);
      expect(out, contains('1: 5'));
    });
  });
}
