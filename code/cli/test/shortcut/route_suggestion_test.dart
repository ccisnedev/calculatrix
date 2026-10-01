// Tests for issue #51, AC6: `ModularCli.suggest` can return a bare word
// that is only a fragment of a multi-word route (`show`, from the real
// route `commands show`), not a command by itself. `tightenRouteSuggestion`
// re-checks the whole route a fragment came from before trusting it, and
// drops the suggestion entirely when no such whole route is genuinely
// close to what was actually typed, rather than composing an invalid `cx
// <fragment>` command.
import 'package:calculatrix_cli/src/shortcut/route_suggestion.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

void main() {
  CommandContract route(String name) => CommandContract(
    route: name,
    module: '',
    contract: CliContract.none,
    globals: true,
  );

  final commands = [
    route('commands show <name>'),
    route('commands search <text>'),
    route('commands list'),
    route('version'),
  ];

  group('tightenRouteSuggestion (issue #51, AC6)', () {
    test('no raw suggestion means no suggestion', () {
      expect(tightenRouteSuggestion('pow', null, commands), isNull);
    });

    test('a raw suggestion that already names a real, standalone route is '
        'returned unchanged', () {
      expect(
        tightenRouteSuggestion('verison', 'version', commands),
        'version',
      );
    });

    test('a raw suggestion that is only a fragment of a multi-word route '
        'is dropped when the whole route it came from is nowhere near '
        'what was actually typed ("pow" used to suggest the bare word '
        '"show", a fragment of "commands show", not a command by itself)',
        () {
          expect(tightenRouteSuggestion('pow', 'show', commands), isNull);
        });

    test('a raw suggestion that is a fragment of a multi-word route is '
        'widened to that whole route when the whole route is itself '
        'genuinely close to what was typed', () {
      expect(
        tightenRouteSuggestion('commandslist', 'list', commands),
        'commands list',
      );
    });

    test('a fragment with no route it could plausibly belong to suggests '
        'nothing', () {
      expect(
        tightenRouteSuggestion('zzz', 'zzz-not-in-any-route', commands),
        isNull,
      );
    });
  });
}
