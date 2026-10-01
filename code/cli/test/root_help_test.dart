// Coverage for issue #51 acceptance 1: `cx --help`/`cx -h` used to print
// an empty "Usage: " line, "Print a short banner." and the global options,
// telling a reader nothing about what cx is, what it can do, or how to run
// a calculation without naming a command at all. The root route's own
// description (`_rootHelpDescription` in `lib/src/cli_builder.dart`) now
// answers all three, reusing the exact rows `banner_render.dart` renders
// for the bare `cx` banner so the two can never disagree.
//
// The empty "Usage: " line itself stays empty: `modular_cli_sdk`'s
// `HelpRenderer` builds it from the route pattern alone, with no seam for
// a program name, and this package does not patch, vendor or work around
// the SDK to add one.
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

    test(
      'the "Usage: " line stays empty: this is a modular_cli_sdk '
      'limitation (no program-name seam on the root route), not something '
      'calculatrix code can fix without patching the SDK',
      () async {
        final out = MemorySink();
        final err = MemorySink();
        final cli = buildCalculatrixCli();
        await cli.run(['--help'], stdout: out, stderr: err);
        expect(out.output, startsWith('Usage: \n'));
      },
    );

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
