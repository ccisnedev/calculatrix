import 'package:calculatrix/calculatrix.dart';
import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'commands_support.dart';

/// `cx commands search <text>` (spec section 7; issue #41, AC2).
class SearchInput extends Input {
  SearchInput({required this.text});

  factory SearchInput.fromCliRequest(CliRequest req) =>
      SearchInput(text: req.param('text')!);

  final String text;

  @override
  Map<String, dynamic> toJson() => {'text': text};
}

class SearchOutput extends Output {
  SearchOutput(this.matches);

  final List<CalculatrixCommandEntry> matches;

  @override
  Map<String, dynamic> toJson() => {
    'matches': matches.map(commandEntryToJson).toList(),
  };

  @override
  String toText() => matches.isEmpty
      ? 'No matches.'
      : matches.map(commandEntrySummaryText).join('\n');

  // No match is an empty list, exit 0 (AC2): there is nothing wrong with
  // the invocation or the registry, the text just named nothing.
  @override
  int get exitCode => ExitCode.ok;
}

class SearchQuery implements Query<SearchInput, SearchOutput> {
  SearchQuery(this.input);

  @override
  final SearchInput input;

  @override
  String? validate() => null;

  @override
  Future<SearchOutput> execute() async =>
      SearchOutput(<CalculatrixCommandEntry>[
        for (final CalculatrixCommandEntry entry
            in CalculatrixCommandRegistry.standard.entries)
          if (commandEntryMatchesSearch(entry, input.text)) entry,
      ]);
}
