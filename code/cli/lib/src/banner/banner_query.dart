import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

/// `cx` (no route): prints a short banner and exits 0 (spec section 4, D4).
///
/// Registered at the root (`''`) so a bare invocation resolves to this query
/// instead of the SDK's generic help catalog, and so `cx <word>` for a
/// reserved word (once one is registered, e.g. `version` in a later stage)
/// resolves to that word's own route rather than falling through to the
/// `eval rpn` shortcut (G3).
class BannerQuery implements Query<BannerInput, BannerOutput> {
  BannerQuery(this.input);

  @override
  final BannerInput input;

  @override
  String? validate() => null;

  @override
  Future<BannerOutput> execute() async => BannerOutput();
}

class BannerInput extends Input {
  BannerInput();

  factory BannerInput.fromCliRequest(CliRequest req) => BannerInput();

  @override
  Map<String, dynamic> toJson() => {};
}

class BannerOutput extends Output {
  BannerOutput();

  static const String _tagline =
      'A matrix-first RPN and infix calculator, on the command line.';

  @override
  Map<String, dynamic> toJson() => {'name': 'calculatrix', 'tagline': _tagline};

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() =>
      'calculatrix\n'
      '$_tagline\n'
      "Try: cx '1 2 +', cx eval rpn '1 2 +', cx eval infix '2+3*4'.";
}
