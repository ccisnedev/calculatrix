import 'dart:convert';
import 'dart:io' as io;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'banner/banner_query.dart';
import 'banner/overview.dart';
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
import 'shortcut/option_like_value_error.dart';
import 'shortcut/program_shortcut_query.dart';
import 'shortcut/route_suggestion.dart';
import 'shortcut/shortcut_option_error.dart';
import 'shortcut/unquoted_program_error.dart';
import 'stdin_reader.dart';

/// The text `cx --help`, `cx -h` and `cx help` print after the global
/// options (`modular_cli_sdk` `helpEpilog`): the overview
/// the banner and the install scripts also show, then two hints. It used to be the root route's description, which
/// the catalog prints as one cell of its table: the table broke, and every
/// command was listed twice.
final String _helpEpilog = <String>[
  ...cxOverviewLines,
  'Each command also takes its own --help, e.g.: cx eval rpn --help.',
  'A program that starts with "-" goes after --: '
      "cx -- '-1 2 +'.",
].join('\n');

/// `cx <program>`'s own contract: one required
/// positional and `--max-digits`, plus the global output
/// options `--json` and `--quiet`/`-q` (`globals: true` where this is
/// registered). Not [EvalContracts.rpn],
/// which declares `--file`/`--stdin` and an optional `program`: those
/// belong to the full `eval rpn` route, never to this shorter spelling of
/// it.
final CliContract _programShortcutContract = CliContract(
  options: [EvalContracts.maxDigits],
  positionals: [CliPositional.string('program', required: true)],
);

/// `cx`'s own version, reported by `cx version`, `cx doctor` and
/// `cx upgrade` (`VersionPlugin` and `ModularCli` must agree). A shell
/// versions independently of the core package; this is not the core's version.
const cxVersion = '0.16.3';

/// `owner/repo` on GitHub `cx upgrade`, `cx uninstall` and `cx doctor` look
/// releases up in. The same repository
/// also hosts the app's own `vX.Y.Z` releases, which is why [cxTagPrefix]
/// exists: without it, a release lookup here could not tell the two apart.
const cxRepository = 'ccisnedev/calculatrix';

/// The prefix this CLI's own release tags carry: the
/// app already tags its releases `vX.Y.Z`, so `cx`'s own tags are
/// `cli-vX.Y.Z`, and the release lookup only ever considers tags starting
/// with this prefix, never `GET .../releases/latest` (which would be
/// ambiguous in a repository with two tag families).
const cxTagPrefix = 'cli-v';

/// [Platform.operatingSystem] -> release asset name, matching what
/// `.github/workflows/cli-release.yml` builds and uploads for
/// each platform `cx` ships a compiled binary for.
const cxAssets = {
  'windows': 'cx-windows-x64.zip',
  'linux': 'cx-linux-x64.tar.gz',
};

/// How tolerant a "did you mean" suggestion is, for both `ModularCli`'s own
/// route vocabulary and [tightenRouteSuggestion]'s re-check of the whole
/// route it points to: the two must agree, or tightening
/// could reject at a stricter distance than the SDK used to find the word
/// in the first place.
const _suggestionDistance = 2;

/// Builds the `cx` CLI: the bare
/// banner, `eval rpn`, `eval infix`, the `cx <program>` RPN shortcut,
/// and the standard plugins `version`, `doctor`, `upgrade` and `uninstall`.
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
/// The executable is named `cx`, with no alias of any kind. A `.cmd`/`.bat` alias shim runs through
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
    helpEpilog: _helpEpilog,
  );

  cli.query<BannerInput, BannerOutput>(
    '',
    // The version and the registered-command names are read off [cli]
    // itself at call time, once every module below has been registered
    // itself: this is the CLI's own record of what it
    // serves, not a separate list to keep in sync by hand.
    (req) => BannerQuery(
      BannerInput.fromCliRequest(req),
      version: cli.hostMetadata?.version,
      registeredCommands: cli.catalog.commands.map((c) => c.name).toSet(),
    ),
    globals: true,
    contract: CliContract.none,
    description: 'Show the banner.',
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
  // add a route suggestion to this path alone (see
  // ProgramShortcutQuery). `eval rpn` above stays the one and only
  // registration of its own body.
  //
  // `cli.suggest(word)` alone can name a bare fragment of a multi-word
  // route (`show`, from `commands show`) as if it were a command by
  // itself; `tightenRouteSuggestion` re-checks the whole route it came
  // from before trusting it.
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
    globals: true,
    contract: _programShortcutContract,
    description: 'Shortcut for "eval rpn <program>".',
  );

  return cli;
}

/// Runs the `cx` CLI exactly as [buildCalculatrixCli] plus [ModularCli.run]
/// would, except for two cases where `modular_cli_sdk` itself can only
/// report a generic, SDK-worded message: an unquoted program typed as
/// several shell words (`cx 5 7 power`, reported
/// as `extra-argument`), and a value that starts with "-" read as short
/// options (`cx eval infix '-(2+3)'`, reported as
/// `invalid-short-option`). Those messages are rewritten into something
/// actionable ("quote the program as one argument", "end the options with
/// --") before they ever reach [stderr]; the id and the process exit code
/// are both left exactly as `modular_cli_sdk` decided them.
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

  final int? helpExit = _rejectUnknownHelpTopic(cli, args, realErr);
  if (helpExit != null) return helpExit;

  // Only an invocation that could possibly be an unquoted program, or
  // carries a value that would be read as options, is worth
  // the extra buffering at all: everything else is written straight to
  // the real stream, exactly as a plain `cli.run` call would.
  if (!looksLikeUnquotedProgram(args) &&
      optionLikeValueIndex(args) < 0 &&
      shortcutRejectedOption(args) == null) {
    return cli.run(args, stdout: realOut, stderr: realErr);
  }

  final BufferingSink bufferedErr = BufferingSink();
  final int exitCode = await cli.run(
    args,
    stdout: realOut,
    stderr: bufferedErr,
  );
  realErr.write(
    rewriteShortcutOptionError(
      rewriteOptionLikeValueError(
        rewriteUnquotedProgramError(bufferedErr.text, args),
        args,
      ),
      args,
    ),
  );
  return exitCode;
}

/// `cx help <topic>` where no command or module is named `<topic>` is a
/// usage error, not the root help: writes it to [err] and returns the usage
/// exit code, or returns null when [args] is not an unknown help topic.
int? _rejectUnknownHelpTopic(ModularCli cli, List<String> args, io.IOSink err) {
  if (args.length < 2 || args.first != 'help') return null;
  final List<String> topic = args
      .skip(1)
      .takeWhile((String a) => !a.startsWith('-'))
      .toList();
  if (topic.isEmpty) return null;
  final String name = topic.join(' ');
  cli.buildPlugins();
  final List<CommandContract> commands = cli.catalog.commands;
  if (name == 'help' ||
      commands.any((c) => c.name == name || c.name.startsWith('$name '))) {
    return null;
  }

  final String? near = tightenRouteSuggestion(
    topic.first,
    cli.suggest(topic.first),
    commands,
    maxDistance: _suggestionDistance,
  );
  final String hint = near == null ? '' : ". Did you mean 'cx help $near'?";
  final String message = "unknown help topic '$name'$hint";
  if (args.contains('--json')) {
    err.writeln(
      jsonEncode({
        'error': {
          'id': 'unknown-help-topic',
          'message': message,
          'exitCode': ExitCode.invalidUsage,
        },
      }),
    );
  } else {
    err.writeln('Error: $message [unknown-help-topic]');
  }
  return ExitCode.invalidUsage;
}
