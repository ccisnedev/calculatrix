import 'package:calculatrix/calculatrix.dart';
import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../eval/eval_support.dart';
import 'commands_support.dart';

/// `cx commands show <name>` (spec section 7; issue #41, AC1).
class ShowInput extends Input {
  ShowInput({required this.name});

  factory ShowInput.fromCliRequest(CliRequest req) =>
      ShowInput(name: req.param('name')!);

  final String name;

  @override
  Map<String, dynamic> toJson() => {'name': name};
}

class ShowOutput extends Output {
  ShowOutput(this.entry);

  final CalculatrixCommandEntry entry;

  @override
  Map<String, dynamic> toJson() => commandEntryToJson(entry);

  @override
  String toText() => commandEntryToText(entry);

  @override
  int get exitCode => ExitCode.ok;
}

class ShowQuery implements Query<ShowInput, ShowOutput> {
  ShowQuery(this.input);

  @override
  final ShowInput input;

  @override
  String? validate() => null;

  @override
  Future<ShowOutput> execute() async {
    final CalculatrixCommandEntry? entry = CalculatrixCommandRegistry.standard
        .lookup(input.name);
    if (entry == null) {
      // A search term (never a word of the language, spec section 7) or
      // any other unresolvable spelling is unknown-word here exactly as it
      // would be in an RPN program (AC1: "show hcat" is unknown-word
      // suggesting "append-cols"), reusing the same core message and the
      // same JSON shape `toCommandException` already gives `eval`'s own
      // unknown-word error (issue #41, AC5).
      throw toCommandException(
        UnknownWordError(
          input.name,
          suggestions: CalculatrixCommandRegistry.standard.suggest(input.name),
        ),
      );
    }
    return ShowOutput(entry);
  }
}
