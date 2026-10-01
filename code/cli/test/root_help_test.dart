// Coverage for issue #51 acceptance 1: `cx --help`/`cx -h` used to print
// an empty "Usage: " line, "Print a short banner." and the global options,
// telling a reader nothing about what cx is, what it can do, or how to run
// a calculation without naming a command at all. The root route's own
// description (`_rootHelpDescription` in `lib/src/cli_builder.dart`) now
// answers all three, reusing the exact rows `banner_render.dart` renders
// for the bare `cx` banner so the two can never disagree.
//
// Since `modular_cli_sdk` 0.9.0 the "Usage:" line names the program
// (`Usage: cx <command> [options]`), and `--help`/`-h` print the same
// catalog as `cx help`.
import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:calculatrix_cli/src/banner/banner_render.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import 'support/memory_sink.dart';

void main() {
  group('root help (issue #51 acceptance 1)', () {
    test('cx --help explains what cx is, lists commands with an example, '
        'and says how to pass a program', () async {
      final out = MemorySink();
      final err = MemorySink();
      final cli = buildCalculatrixCli();
      final code = await cli.run(['--help'], stdout: out, stderr: err);

      expect(code, ExitCode.ok);
      expect(out.output, contains(bannerTagline));
      for (final cmd in bannerCommands) {
        expect(out.output, contains(bannerCommandRow(cmd)));
      }
      expect(
        out.output,
        contains("quoting it as one argument"),
        reason: 'must explain how to pass a program as one quoted argument',
      );
      expect(out.output, contains("cx '5 7 power'"));
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

    test('cx help (the full catalog) stays consistent with the banner and '
        "with cx --help: it carries the same tagline and the same "
        'pass-a-program instruction, not a different story', () async {
      final out = MemorySink();
      final err = MemorySink();
      final cli = buildCalculatrixCli();
      final code = await cli.run(['help'], stdout: out, stderr: err);

      expect(code, ExitCode.ok);
      expect(out.output, contains(bannerTagline));
      expect(out.output, contains("cx '5 7 power'"));
    });
  });
}
