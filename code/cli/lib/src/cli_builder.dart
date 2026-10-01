import 'dart:io' as io;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'banner/banner_query.dart';
import 'banner/banner_render.dart';
import 'buffering_sink.dart';
import 'commands/commands_contracts.dart';
import 'commands/commands_list_query.dart';
import 'commands/commands_search_query.dart';
import 'commands/commands_show_query.dart';
import 'doctor/binary_on_path_check.dart';
import 'eval/eval_contracts.dart';
import 'eval/eval_infix_query.dart';
import 'eval/eval_output.dart';
import 'eval/eval_rpn_query.dart';
import 'shortcut/program_shortcut_query.dart';
import 'shortcut/route_suggestion.dart';
import 'shortcut/unquoted_program_error.dart';
import 'stdin_reader.dart';

/// What `cx --help`, `cx -h` and `cx help` all show for the root route (the
/// bare `cx`, with nothing else typed): what the program is, every command
/// it has with a one-line description and, where there is one, the exact
/// invocation that runs it, and how to run a program directly without
/// naming a command at all. Built once, from [bannerCommands], the same
/// list the banner itself renders, through [bannerCommandRow] (colorless:
/// help text is not a terminal banner), so the two can never say different
/// things about what `cx` can do.
///
/// `modular_cli_sdk` prints this single string for `cx --help`, `cx -h` and
/// this route's own row in the full catalog (`cx help`): all three show the
/// same catalog, under a `Usage: cx <command> [options]` line (0.9.0).
/// Deliberately not headed "Commands:" the way the banner heads its own
/// copy of these same rows:
/// `cx help` already prints a real "Commands:"/"Queries:" heading of its
/// own right after this text, and a second, identical-looking heading one
/// line above it would read as a mistake rather than as the list it is.
String get _rootHelpDescription {
  final String commandRows = bannerCommands.map(bannerCommandRow).join('\n');
  return <String>[
    bannerTagline,
    '',
    'What each command does, with an example where one helps:',
    commandRows,
    '',
    'Run a calculation directly by quoting it as one argument, without '
        "naming a command at all, e.g.: cx '5 7 power'.",
    'Each command also takes its own --help, e.g.: cx eval rpn --help.',
  ].join('\n');
}

/// `cx <program>`'s own contract (spec section 4, G4): one required
/// positional and `--max-digits` (runbook D55), not even the global options
/// (`globals: false` where this is registered). Not [EvalContracts.rpn],
/// which declares `--file`/`--stdin` and an optional `program`: those
/// belong to the full `eval rpn` route, never to this shorter spelling of
/// it.
final CliContract _programShortcutContract = CliContract(
  options: [EvalContracts.maxDigits],
  positionals: [CliPositional.string('program', required: true)],
);

/// `cx`'s own version, reported by `cx version`, `cx doctor` and
/// `cx upgrade` (spec section 8.7: `VersionPlugin` and `ModularCli` are
/// required to agree). ADR 0002 section 2 lets a shell version
/// independently of the core package; this is not the core's version.
const cxVersion = '0.13.1';

/// `owner/repo` on GitHub `cx upgrade`, `cx uninstall` and `cx doctor` look
/// releases up in (runbook D26, D31; spec 8.3, 8.7). The same repository
/// also hosts the app's own `vX.Y.Z` releases, which is why [cxTagPrefix]
/// exists: without it, a release lookup here could not tell the two apart.
const cxRepository = 'ccisnedev/calculatrix';

/// The prefix this CLI's own release tags carry. Runbook D31/issue #25: the
/// app already tags its releases `vX.Y.Z`, so `cx`'s own tags are
/// `cli-vX.Y.Z`, and the release lookup only ever considers tags starting
/// with this prefix, never `GET .../releases/latest` (which would be
/// ambiguous in a repository with two tag families).
const cxTagPrefix = 'cli-v';

/// [Platform.operatingSystem] -> release asset name, matching what
/// `.github/workflows/cli-release.yml` (runbook S3) builds and uploads for
/// each platform `cx` ships a compiled binary for.
const cxAssets = {
  'windows': 'cx-windows-x64.zip',
  'linux': 'cx-linux-x64.tar.gz',
};

/// How tolerant a "did you mean" suggestion is, for both `ModularCli`'s own
/// route vocabulary and [tightenRouteSuggestion]'s re-check of the whole
/// route it points to (issue #51, AC6): the two must agree, or tightening
/// could reject at a stricter distance than the SDK used to find the word
/// in the first place.
const _suggestionDistance = 2;

/// Builds the `cx` CLI (spec section 4; runbook stages S2 and S3): the bare
/// banner, `eval rpn`, `eval infix`, the `cx <program>` RPN shortcut (G3),
/// and the standard plugins `version`, `doctor`, `upgrade` and `uninstall`
/// (spec 8.7; runbook D26, D31, D33).
///
/// [readStdin] is the injection seam a test needs for standard input: the
/// real process's standard input has no clean fake, so production code
/// reaches it only through this one indirection (see [StdinReader]).
/// [releaseSource] and [platformOps] are the equivalent seams for
/// `InstallationPlugin` (its own release lookup and OS-specific shell
/// operations); [pathLookup] is the seam for [BinaryOnPathDoctorPlugin]'s
/// own `PATH` search. All three default to the real thing and exist only so
/// a test can supply a fake, exactly as `modular_cli_sdk`'s own test suite
/// does (`test/plugins/installation_doubles.dart`).
///
/// User decision (2026-09-29, issue #22): the executable is named `cx`,
/// with no alias of any kind. A `.cmd`/`.bat` alias shim runs through
/// cmd.exe, which consumes `^` while parsing the command line before the
/// shim body ever runs, so it silently mangled `cx eval infix '2^0.5'`.
/// Naming the program itself `cx` means the shell that invokes it passes
/// its argv straight through, with nothing in between.
ModularCli buildCalculatrixCli({
  StdinReader readStdin = readAllStdin,
  CliReleaseSource? releaseSource,
  PlatformOps? platformOps,
  PathLookup? pathLookup,
}) {
  final cli = ModularCli(
    name: 'cx',
    version: cxVersion,
    suggestionDistance: _suggestionDistance,
  );

  cli.query<BannerInput, BannerOutput>(
    '',
    // The version and the registered-command names are read off [cli]
    // itself at call time, once every module below has been registered
    // (issue #26 scope 4 and 5): this is the CLI's own record of what it
    // serves, not a separate list to keep in sync by hand.
    (req) => BannerQuery(
      BannerInput.fromCliRequest(req),
      version: cli.hostMetadata?.version,
      registeredCommands: cli.catalog.commands.map((c) => c.name).toSet(),
    ),
    globals: true,
    contract: CliContract.none,
    description: _rootHelpDescription,
  );

  cli.plugin(VersionPlugin(version: cxVersion));
  cli.plugin(const DoctorPlugin());
  cli.plugin(
    BinaryOnPathDoctorPlugin(executable: 'cx', pathLookup: pathLookup),
  );
  cli.plugin(
    InstallationPlugin(
      config: const CliInstallationConfig(
        repository: cxRepository,
        tagPrefix: cxTagPrefix,
        executable: 'cx',
        assets: cxAssets,
      ),
      releaseSource: releaseSource,
      platformOps: platformOps,
    ),
  );

  cli.module('eval', (m) {
    m.query<EvalRpnInput, EvalOutput>(
      'rpn [<program>]',
      (req) =>
          EvalRpnQuery(EvalRpnInput.fromCliRequest(req), readStdin: readStdin),
      globals: true,
      contract: EvalContracts.rpn,
      description: 'Evaluate an RPN program.',
    );

    m.query<EvalInfixInput, EvalOutput>(
      'infix [<expression>]',
      (req) => EvalInfixQuery(
        EvalInfixInput.fromCliRequest(req),
        readStdin: readStdin,
      ),
      globals: true,
      contract: EvalContracts.infix,
      description: 'Evaluate an infix expression.',
    );
  });

  cli.module('commands', (m) {
    m.query<ShowInput, ShowOutput>(
      'show <name>',
      (req) => ShowQuery(ShowInput.fromCliRequest(req)),
      globals: true,
      contract: CommandsContracts.show,
      description: 'Show a command of the registry.',
    );

    m.query<SearchInput, SearchOutput>(
      'search <text>',
      (req) => SearchQuery(SearchInput.fromCliRequest(req)),
      globals: true,
      contract: CommandsContracts.search,
      description: 'Search the registry.',
    );

    m.query<ListInput, ListOutput>(
      'list',
      (req) => ListQuery(ListInput.fromCliRequest(req)),
      globals: true,
      contract: CommandsContracts.list,
      description: 'List the registry, grouped by category.',
    );
  });

  // Not `cli.shortcut('<program>', target: 'eval rpn', ...)`: a shortcut
  // dispatches through the exact same body as its target, with no seam to
  // add a route suggestion to this path alone (issue #41, AC6; see
  // ProgramShortcutQuery). `eval rpn` above stays the one and only
  // registration of its own body.
  //
  // `cli.suggest(word)` alone can name a bare fragment of a multi-word
  // route (`show`, from `commands show`) as if it were a command by
  // itself; `tightenRouteSuggestion` re-checks the whole route it came
  // from before trusting it (issue #51, AC6).
  cli.query<EvalRpnInput, EvalOutput>(
    '<program>',
    (req) => ProgramShortcutQuery(
      EvalRpnQuery(EvalRpnInput.fromCliRequest(req), readStdin: readStdin),
      routeSuggest: (String word) => tightenRouteSuggestion(
        word,
        cli.suggest(word),
        cli.catalog.commands,
        maxDistance: _suggestionDistance,
      ),
    ),
    globals: false,
    contract: _programShortcutContract,
    description: 'Shortcut for "eval rpn <program>".',
  );

  return cli;
}

/// Runs the `cx` CLI exactly as [buildCalculatrixCli] plus [ModularCli.run]
/// would, except for one case: an unquoted program typed as several shell
/// words (`cx 5 7 power`, issue #51 acceptance 4), where `modular_cli_sdk`
/// itself can only report `extra-argument` with a generic, SDK-worded
/// message. That one message is rewritten into something actionable
/// ("quote the program as one argument") before it ever reaches [stderr];
/// its id and the process exit code are both left exactly as
/// `modular_cli_sdk` decided them.
///
/// This is the one call `bin/cx.dart` makes, instead of building the CLI
/// and calling [ModularCli.run] itself, so the rewrite applies the same
/// way in production as it does under test.
Future<int> runCalculatrixCli(
  List<String> args, {
  io.IOSink? stdout,
  io.IOSink? stderr,
  StdinReader readStdin = readAllStdin,
  CliReleaseSource? releaseSource,
  PlatformOps? platformOps,
  PathLookup? pathLookup,
}) async {
  final cli = buildCalculatrixCli(
    readStdin: readStdin,
    releaseSource: releaseSource,
    platformOps: platformOps,
    pathLookup: pathLookup,
  );
  final io.IOSink realOut = stdout ?? io.stdout;
  final io.IOSink realErr = stderr ?? io.stderr;

  // Only an invocation that could possibly be an unquoted program is worth
  // the extra buffering at all: everything else is written straight to
  // the real stream, exactly as a plain `cli.run` call would.
  if (!looksLikeUnquotedProgram(args)) {
    return cli.run(args, stdout: realOut, stderr: realErr);
  }

  final BufferingSink bufferedErr = BufferingSink();
  final int exitCode = await cli.run(args, stdout: realOut, stderr: bufferedErr);
  realErr.write(rewriteUnquotedProgramError(bufferedErr.text, args));
  return exitCode;
}
