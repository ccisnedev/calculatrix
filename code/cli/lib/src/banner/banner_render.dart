/// Pure rendering of the branded `cx` banner (issue #26): the
/// `[[0 -1][1 0]]` logo (the imaginary unit as a 2x2 rotation matrix,
/// `code/design/logo.svg`), name and version, tagline, the command list and
/// a quickstart line.
///
/// No side effects: [BannerQuery] (`banner_query.dart`) is the only caller
/// that ever touches the real terminal, stdin/stdout or the process
/// environment. This function only turns already-resolved facts (version,
/// update notice, whether to color, which routes exist) into text, so a
/// test exercises the exact layout without faking a console.
library;

/// The tagline printed next to the logo, and returned as `tagline` in JSON
/// mode: a single source of truth for both (issue #26 scope 6).
const String bannerTagline =
    'Calculatrix: matrix-first RPN and infix calculator';

/// The command the banner tells a new user to run, and the exact stack line
/// it must print (issue #26 scope 3). A constant so the banner and the test
/// that runs it through the CLI cannot disagree, the same discipline
/// `macss`'s `quickstartCommand` follows
/// (`code/cli/lib/modules/global/commands/tui.dart`).
///
/// `i` (the imaginary unit) as the 2x2 rotation matrix `[[0,-1],[1,0]]`,
/// squared, is minus the identity (i^2 = -1). When a later stage adds
/// space-separated matrix literals (D6, D13) this may switch to
/// `[[0 -1][1 0]]`.
const String bannerQuickstartCommand = "cx '[[0,-1],[1,0]] 2 ^'";

/// One row of the "Commands:" section: a name, what it does, and, for the
/// two commands already shipped, the exact invocation from the issue's
/// design.
class BannerCommand {
  const BannerCommand(this.name, this.description, [this.example]);

  /// Matched against a registered route's [CommandContract.name] (from
  /// `modular_cli_sdk`'s `CommandCatalog`), not just printed.
  final String name;
  final String description;
  final String? example;
}

/// Every command the banner may list, in the order the design fixes.
///
/// Not every one is printed on every build: [renderBanner] keeps only the
/// entries named in `registeredCommands` (issue #26 scope 4), so `doctor`,
/// `upgrade`, `uninstall` and `version`, registered only once #25's
/// `InstallationPlugin`/`VersionPlugin`/`DoctorPlugin` wiring lands, appear
/// only once the CLI actually serves them. This PR does not depend on #25.
const List<BannerCommand> bannerCommands = [
  BannerCommand('eval rpn', 'evaluate an RPN program', "cx eval rpn '1 2 +'"),
  BannerCommand(
    'eval infix',
    'evaluate an expression',
    'cx eval infix "2^0.5"',
  ),
  BannerCommand('doctor', 'verify local installation'),
  BannerCommand('upgrade', 'update to latest version'),
  BannerCommand('uninstall', 'remove cx'),
  BannerCommand('version', 'print version'),
];

const int _nameColumnWidth = 13;
const int _descriptionColumnWidth = 28;

const String _reset = '\x1B[0m';
const String _bold = '\x1B[1m';
const String _dim = '\x1B[2m';
const String _white = '\x1B[97m';
const String _cyan = '\x1B[36m';

/// `#2EF2C3`, the icon's glow color (`code/design/logo.svg`), as a 24-bit
/// ANSI foreground escape (User decision, 2026-09-29, issue #26), used when
/// the terminal advertises truecolor.
const String _glowTrueColor = '\x1B[38;2;46;242;195m';

/// The nearest 16-color fallback for [_glowTrueColor]: bright cyan (ANSI 96).
const String _glowFallback = '\x1B[96m';

/// Renders the `cx` banner (issue #26): the logo, name and version, the
/// tagline, the "Commands:" list (only entries in [registeredCommands]) and
/// the quickstart line. Pure: the same arguments always give the same text.
///
/// [color] decides whether ANSI escapes are emitted at all; stripping them
/// from a colored render always yields the render with `color: false` for
/// the same other arguments. [trueColor] picks the 24-bit glow over its
/// ANSI 96 fallback and only matters when [color] is on.
String renderBanner({
  String? version,
  String? updateNotice,
  required bool color,
  bool trueColor = false,
  Set<String> registeredCommands = const {'eval rpn', 'eval infix'},
}) {
  String c(String code, String text) => color ? '$code$text$_reset' : text;
  final glow = trueColor ? _glowTrueColor : _glowFallback;

  final versionSuffix = version == null ? '' : ' v$version';
  final logo =
      '  ${c(_white, '⎡')} ${c(glow, '●')}  ${c(_white, '━━')} '
      '${c(_white, '⎤')}   ${c(_bold, 'cx')}$versionSuffix\n'
      '  ${c(_white, '⎣')} ${c(_white, '┃')}   ${c(_white, '●')} '
      '${c(_white, '⎦')}   ${c(_dim, bannerTagline)}';

  final rows = bannerCommands
      .where((cmd) => registeredCommands.contains(cmd.name))
      .map((cmd) => _commandRow(cmd, c))
      .join('\n');

  final commands = '  ${c(_dim, 'Commands:')}\n$rows';

  final quickstart = '  ${c(_dim, 'Quickstart:')}  $bannerQuickstartCommand';

  final buffer = StringBuffer()
    ..write(logo)
    ..write('\n\n')
    ..write(commands)
    ..write('\n\n')
    ..write(quickstart);

  if (updateNotice != null) {
    buffer
      ..write('\n\n  ')
      ..write(c(_dim, 'Update available:'))
      ..write(' $updateNotice');
  }

  return buffer.toString();
}

String _commandRow(BannerCommand cmd, String Function(String, String) c) {
  final name = c(_cyan, cmd.name.padRight(_nameColumnWidth));
  if (cmd.example == null) {
    return '    $name${cmd.description}';
  }
  final description = cmd.description.padRight(_descriptionColumnWidth);
  return '    $name$description${cmd.example}';
}
