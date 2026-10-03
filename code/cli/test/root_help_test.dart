// Coverage for issues #51 (acceptance 1) and #56: `cx --help`, `cx -h` and
// `cx help` print the same catalog, under `Usage: cx <command> [options]`
// (`modular_cli_sdk` 0.9.0). Issue #51 put the tagline, the command rows
// and the hints into the root route's description; issue #56 found that
// this broke the catalog table and listed every command twice. The root row
// now says only "Show the banner.", and the overview (runbook-agent-
// usability.md D64) and the hints are the help epilog (`modular_cli_sdk`
// 0.10.0), printed once after the global options.
import 'dart:convert';

import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:calculatrix_cli/src/banner/banner_render.dart';
import 'package:calculatrix_cli/src/banner/overview.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import 'support/memory_sink.dart';

Future<String> _help(List<String> args) async {
  final out = MemorySink();
  await buildCalculatrixCli().run(args, stdout: out, stderr: MemorySink());
  return out.output;
}

void main() {
  group('root help (issues #51, #56)', () {
    test('the root row says only "Show the banner." (issue #56)', () async {
      final help = await _help(['--help']);
      expect(
        help,
        matches(
          RegExp(r'^  \(no arguments\) +Show the banner\.$', multiLine: true),
        ),
      );
    });

    test('each command appears once in cx --help (issue #56)', () async {
      final help = await _help(['--help']);
      for (final cmd in bannerCommands) {
        final rows = RegExp(
          '^ +${RegExp.escape(cmd.name)}( |\$)',
          multiLine: true,
        ).allMatches(help);
        expect(rows.length, 1, reason: '"${cmd.name}" in:\n$help');
      }
    });

    test('the help ends with the overview and two hints, after the global '
        'options (issue #56, runbook-agent-usability.md D64)', () async {
      final help = await _help(['--help']);
      final epilog = <String>[
        ...cxOverviewLines,
        'Each command also takes its own --help, e.g.: cx eval rpn --help.',
        'A program that starts with "-" goes after --: '
            "cx -- '-1 2 +'.",
      ].join('\n');
      expect(help, endsWith('\n\n$epilog\n'));
      expect(help.indexOf('Global options:'), lessThan(help.indexOf(epilog)));
    });

    test('help --json carries the same epilog (issue #56)', () async {
      final json =
          jsonDecode(await _help(['help', '--json'])) as Map<String, dynamic>;
      expect(json['epilog'], startsWith(cxOverviewLines.first));
      expect(json['epilog'], endsWith("cx -- '-1 2 +'."));
    });

    test('the examples of the hints run (issue #56)', () async {
      for (final args in <List<String>>[
        ['--', '-1 2 +'],
        ['eval', 'rpn', '--help'],
      ]) {
        final code = await buildCalculatrixCli().run(
          args,
          stdout: MemorySink(),
          stderr: MemorySink(),
        );
        expect(code, ExitCode.ok, reason: args.join(' '));
      }
    });

    test('every command the banner prints has its row in cx --help, so the '
        'banner and the catalog cannot disagree (issue #56)', () async {
      final banner = await _help([]);
      final help = await _help(['--help']);
      final shown = bannerCommands
          .where((cmd) => banner.contains(bannerCommandRow(cmd)))
          .toList();
      expect(shown.map((cmd) => cmd.name), contains('eval rpn'));
      for (final cmd in shown) {
        expect(
          help,
          matches(
            RegExp('^ +${RegExp.escape(cmd.name)}( |\$)', multiLine: true),
          ),
          reason: '"${cmd.name}" is in the banner, not in cx --help',
        );
      }
    });

    test('every command the banner may list has its own example, none left '
        'to fall back to a bare name/description row (issue #51 acceptance '
        '1: commands list, doctor, upgrade, uninstall and version used to '
        'have none)', () {
      for (final cmd in bannerCommands) {
        expect(cmd.example, isNotNull, reason: '"${cmd.name}" has no example');
      }
    });

    test('every command row keeps at least a 2-space gap between every '
        'column (name, description, example), the same as the banner '
        '(issue #51 acceptance 7)', () async {
      var sawRowWithExample = false;
      for (final cmd in bannerCommands) {
        final line = bannerCommandRow(cmd);

        final nameEnd = line.indexOf(RegExp(r'  '), 4);
        expect(
          nameEnd,
          greaterThan(4),
          reason: 'no 2-space gap after the name column in: "$line"',
        );

        // The last "cx ", not the first: a description can itself contain
        // "cx" followed by padding spaces ("remove cx", issue #51 AC1,
        // once "uninstall" got its own example), and only the example
        // column, always the final thing on the line, is what this gap
        // check cares about.
        final exampleStart = line.lastIndexOf('cx ');
        if (exampleStart <= 0) continue;
        sawRowWithExample = true;
        expect(
          line.substring(exampleStart - 2, exampleStart),
          '  ',
          reason: 'no 2-space gap before the example in: "$line"',
        );
      }
      expect(sawRowWithExample, isTrue);
    });

    test('cx -h gives the exact same text as cx --help', () async {
      final outLong = MemorySink();
      final outShort = MemorySink();
      final err = MemorySink();
      final codeLong = await buildCalculatrixCli().run(
        ['--help'],
        stdout: outLong,
        stderr: err,
      );
      final codeShort = await buildCalculatrixCli().run(
        ['-h'],
        stdout: outShort,
        stderr: err,
      );

      expect(codeShort, codeLong);
      expect(outShort.output, outLong.output);
    });

    test('the Usage: line names cx', () async {
      final out = MemorySink();
      final err = MemorySink();
      final cli = buildCalculatrixCli();
      await cli.run(['--help'], stdout: out, stderr: err);
      expect(out.output, startsWith('Usage: cx <command> [options]\n'));
    });

    test('cx --help and cx help print the same text, with the same '
        '--json', () async {
      Future<String> text(List<String> args) async {
        final out = MemorySink();
        await buildCalculatrixCli().run(
          args,
          stdout: out,
          stderr: MemorySink(),
        );
        return out.output;
      }

      expect(await text(['--help']), await text(['help']));
      expect(await text(['--help', '--json']), await text(['help', '--json']));
    });

    test('cx --version answers like cx version', () async {
      Future<(int, String)> go(List<String> args) async {
        final out = MemorySink();
        final code = await buildCalculatrixCli().run(
          args,
          stdout: out,
          stderr: MemorySink(),
        );
        return (code, out.output);
      }

      final root = await go(['--version']);
      expect(root.$1, ExitCode.ok);
      expect(root, await go(['version']));
    });
  });
}
