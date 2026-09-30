import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../eval/eval_output.dart';
import '../eval/eval_rpn_query.dart';

/// Wraps [EvalRpnQuery] for the `<program>` root shortcut (spec section 7,
/// "Did you mean"; issue #41, AC6): the one behavior difference between
/// `cx <program>` and `cx eval rpn <program>` (spec section 11, risk 1,
/// "the one cost of the shortcut").
///
/// Both raise the very same core `unknown-word`, with the core's own
/// RPN-word suggestions (issue #41, AC5) already attached by
/// `toCommandException` regardless of which route is taken. Only here,
/// because a typo at the root is indistinguishable from an RPN program
/// until it fails ("a typo at the root is a program, because of the
/// shortcut"), does the CLI also try `routeSuggest` (`ModularCli.suggest`)
/// against the offending token and, when it finds a route close enough,
/// add that as a second, separate suggestion: `cx verison` still fails
/// with `unknown-word`, but also suggests `cx version` (AC6, "RPN and
/// route suggestions are listed apart", so the two are never merged into
/// one list).
///
/// A hand-rolled wrapper, not `ModularCli.shortcut`, because a shortcut
/// dispatches through the exact same body closure as its target route
/// (`eval rpn`'s own): there is no seam in that shared body to add
/// behavior to one call path and not the other. `eval rpn` itself is
/// registered completely unchanged; `cx eval rpn verison` still gets only
/// the core's own suggestion, never a route one.
class ProgramShortcutQuery implements Query<EvalRpnInput, EvalOutput> {
  ProgramShortcutQuery(this._inner, {required this.routeSuggest});

  final EvalRpnQuery _inner;

  /// `ModularCli.suggest`: the route vocabulary's own "did you mean".
  final String? Function(String word) routeSuggest;

  @override
  EvalRpnInput get input => _inner.input;

  @override
  String? validate() => _inner.validate();

  @override
  Future<EvalOutput> execute() async {
    try {
      return await _inner.execute();
    } on CommandException catch (error) {
      if (error.id != 'unknown-word') rethrow;

      final String? token = error.details?['token'] as String?;
      final String? routeSuggestion = token == null
          ? null
          : routeSuggest(token);
      if (routeSuggestion == null) rethrow;

      throw CommandException(
        id: error.id,
        message:
            "${error.message} Did you mean the command 'cx $routeSuggestion'?",
        exitCode: error.exitCode,
        details: <String, dynamic>{
          ...?error.details,
          'routeSuggestion': routeSuggestion,
        },
      );
    }
  }
}
