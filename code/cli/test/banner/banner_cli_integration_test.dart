// Integration coverage for issue #26, tying the pure banner renderer back
// to the real CLI: the quickstart guard (scope 3) and the command-list
// guard (scope 4), both run against `buildCalculatrixCli()` so the banner
// and the CLI cannot silently drift apart, the same discipline `macss`
// applies to its own `quickstartCommand`
// (`code/cli/lib/modules/global/commands/tui.dart`).
import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:calculatrix_cli/src/banner/banner_render.dart'
    show bannerQuickstartCommand;
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import '../support/memory_sink.dart';

// The name column of a command row is 4 spaces of indent, then the command
// name padded to 16 characters (see `_nameColumnWidth` in
// `lib/src/banner/banner_render.dart`). Kept here, not imported, because
// this test exercises the real CLI's printed text end to end, the same way
// a person reading the terminal would.
const _indent = '    ';
const _nameColumnWidth = 16;

void main() {
  group('banner quickstart (issue #26 scope 3)', () {
    test("the quickstart command evaluates through the CLI and prints "
        "1: [[-1 0] [0 -1]] (i^2 = -1)", () async {
      final out = MemorySink();
      final err = MemorySink();
      final cli = buildCalculatrixCli();
      // The guard runs the advertised constant itself, so it follows any
      // change to it. The constant is `cx '<program>'`: the quotes are
      // shell quoting, not part of argv, so the program between them is
      // the single argument.
      const prefix = "cx '";
      expect(bannerQuickstartCommand, startsWith(prefix));
      expect(bannerQuickstartCommand, endsWith("'"));
      final program = bannerQuickstartCommand.substring(
        prefix.length,
        bannerQuickstartCommand.length - 1,
      );
      expect(program, isNot(contains("'")));
      final code = await cli.run([program], stdout: out, stderr: err);
      expect(code, ExitCode.ok);
      expect(out.output, contains('1: [[-1 0] [0 -1]]'));
    });
  });

  group('banner command list (issue #26 scope 4)', () {
    test('every command word the banner lists is a route the CLI actually '
        'registers', () async {
      final out = MemorySink();
      final err = MemorySink();
      final cli = buildCalculatrixCli();
      final code = await cli.run([], stdout: out, stderr: err);
      expect(code, ExitCode.ok);

      final registeredNames = cli.catalog.commands.map((c) => c.name).toSet();
      final commandLines = out.output
          .split('\n')
          .where((line) => line.startsWith(_indent) && line.trim().isNotEmpty);

      expect(commandLines, isNotEmpty);
      for (final line in commandLines) {
        final name = line
            .substring(_indent.length, _indent.length + _nameColumnWidth)
            .trim();
        expect(
          registeredNames,
          contains(name),
          reason: 'banner lists "$name" but the CLI has no such route',
        );
      }
    });

    test('S3 routes (doctor, upgrade, uninstall, version) are not listed until '
        'the CLI actually registers them (issue #26 scope 4, does not depend '
        'on #25)', () async {
      final out = MemorySink();
      final err = MemorySink();
      final cli = buildCalculatrixCli();
      final code = await cli.run([], stdout: out, stderr: err);
      expect(code, ExitCode.ok);

      final registeredNames = cli.catalog.commands.map((c) => c.name).toSet();
      for (final name in ['doctor', 'upgrade', 'uninstall', 'version']) {
        if (!registeredNames.contains(name)) {
          expect(
            out.output,
            isNot(contains('\n$_indent$name ')),
            reason: '"$name" is not registered; the banner must not list it',
          );
        }
      }
    });
  });
}
