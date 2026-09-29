import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'banner_render.dart';

/// `cx` (no route): prints a short, branded banner and exits 0 (spec
/// section 4, D4; branding per issue #26).
///
/// Registered at the root (`''`) so a bare invocation resolves to this query
/// instead of the SDK's generic help catalog, and so `cx <word>` for a
/// reserved word (once one is registered, e.g. `version` in a later stage)
/// resolves to that word's own route rather than falling through to the
/// `eval rpn` shortcut (G3).
///
/// The actual layout is [renderBanner], a pure function: this class only
/// resolves the facts it needs (version, update notice, whether the output
/// stream can take color, which routes the CLI registers) and hands them
/// over. [hasTerminal], [supportsAnsiEscapes] and [readEnvironmentVariable]
/// default to the real `stdout` and process environment, and exist only so
/// a test can inject a fake console instead (issue #26 rule).
class BannerQuery implements Query<BannerInput, BannerOutput> {
  BannerQuery(
    this.input, {
    String? version,
    String? updateNotice,
    Set<String> registeredCommands = const {},
    bool Function()? hasTerminal,
    bool Function()? supportsAnsiEscapes,
    String? Function(String name)? readEnvironmentVariable,
  }) : _version = version,
       _updateNotice = updateNotice,
       _registeredCommands = registeredCommands,
       _hasTerminal = hasTerminal ?? (() => stdout.hasTerminal),
       _supportsAnsiEscapes =
           supportsAnsiEscapes ?? (() => stdout.supportsAnsiEscapes),
       _readEnvironmentVariable =
           readEnvironmentVariable ?? ((name) => Platform.environment[name]);

  @override
  final BannerInput input;

  final String? _version;
  final String? _updateNotice;
  final Set<String> _registeredCommands;
  final bool Function() _hasTerminal;
  final bool Function() _supportsAnsiEscapes;
  final String? Function(String name) _readEnvironmentVariable;

  @override
  String? validate() => null;

  /// Color only on a real terminal that supports ANSI escapes, and only
  /// when `NO_COLOR` is unset: per https://no-color.org, the presence of
  /// `NO_COLOR`, regardless of its value (including empty), disables color.
  bool get _color =>
      _readEnvironmentVariable('NO_COLOR') == null &&
      _hasTerminal() &&
      _supportsAnsiEscapes();

  /// Whether the terminal advertises 24-bit color through `COLORTERM`
  /// (`truecolor` or `24bit`); otherwise the glow uses its ANSI 96 fallback.
  bool get _trueColor {
    final colorTerm = _readEnvironmentVariable('COLORTERM')?.toLowerCase();
    return colorTerm == 'truecolor' || colorTerm == '24bit';
  }

  @override
  Future<BannerOutput> execute() async => BannerOutput(
    version: _version,
    text: renderBanner(
      version: _version,
      updateNotice: _updateNotice,
      color: _color,
      trueColor: _trueColor,
      registeredCommands: _registeredCommands,
    ),
  );
}

class BannerInput extends Input {
  BannerInput();

  factory BannerInput.fromCliRequest(CliRequest req) => BannerInput();

  @override
  Map<String, dynamic> toJson() => {};
}

class BannerOutput extends Output {
  BannerOutput({this.version, required String text}) : _text = text;

  /// Known only once [BannerQuery] was given one (issue #26 scope 5): the
  /// version constant and the `cli-v*` release check are wired after #25.
  final String? version;

  final String _text;

  @override
  Map<String, dynamic> toJson() => {
    'name': 'cx',
    'tagline': bannerTagline,
    if (version != null) 'version': version,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => _text;
}
