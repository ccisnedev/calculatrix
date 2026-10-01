import 'package:calculatrix/calculatrix.dart' show restrictedEditDistance;
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

/// Tightens `ModularCli.suggest`'s own route "did you mean" so it never
/// names something that is not itself a real command (issue #51, AC6).
///
/// `CommandCatalog.suggest` (inside `modular_cli_sdk`) scores every single
/// *word* that appears anywhere across the catalog's route names, so a
/// multi-word route such as `commands show` contributes `commands` and
/// `show` as two separate, unrelated candidates; it returns whichever bare
/// word is closest to the typo, ties broken by registration order rather
/// than by how close the *route* that word came from actually is. For a
/// typo such as `pow`, that can return `show`, even though `show` on its
/// own is not a command at all (the real route is `commands show`): `cx
/// show` would fail exactly the way `cx pow` just did, telling the reader
/// nothing. `modular_cli_sdk` has no seam to score whole routes instead of
/// single words, and does not say which full route a suggested word came
/// from, so this is not something calculatrix can fix by patching the SDK
/// (tracked as `modular_cli_sdk#46`); instead, this re-derives the full
/// route from [commands] and re-checks that full route, not the bare word,
/// against [word] before trusting it at all.
///
/// Returns [rawSuggestion] unchanged when it already names a real,
/// standalone route (`cx $rawSuggestion` is exactly what a reader would
/// type, e.g. `version`). Otherwise [rawSuggestion] is only a fragment of
/// one or more multi-word routes; this looks up every full route name it
/// could have come from and keeps the closest one, but only when that
/// whole route is within [maxDistance] of [word] by the same restricted
/// edit distance `CalculatrixCommandRegistry.suggest` itself uses (one
/// implementation, `restrictedEditDistance`, reused rather than
/// reimplemented). A fragment whose only matching routes are all farther
/// than that from what was actually typed (`show` is nowhere near `pow`
/// once scored as the full route `commands show`) suggests nothing at all,
/// rather than a route that does not exist as typed.
String? tightenRouteSuggestion(
  String word,
  String? rawSuggestion,
  List<CommandContract> commands, {
  int maxDistance = 2,
}) {
  if (rawSuggestion == null) return null;

  if (commands.any((CommandContract c) => c.name == rawSuggestion)) {
    return rawSuggestion;
  }

  final Set<String> candidateRoutes = <String>{
    for (final CommandContract c in commands)
      if (c.name.split(' ').contains(rawSuggestion)) c.name,
  };

  String? best;
  int bestDistance = maxDistance + 1;
  for (final String route in candidateRoutes) {
    final int distance = restrictedEditDistance(word, route);
    if (distance < bestDistance) {
      bestDistance = distance;
      best = route;
    }
  }
  return bestDistance <= maxDistance ? best : null;
}
