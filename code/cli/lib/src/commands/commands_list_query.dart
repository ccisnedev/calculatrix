import 'package:calculatrix/calculatrix.dart';
import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'commands_support.dart';

/// `cx commands list [--category <name>]` (spec section 7; issue #41,
/// AC3). `category`, once present, is already one of
/// [commandCategoryCliNames]: the SDK's own `CliParam.enumeration`
/// rejected anything else before this ever ran.
class ListInput extends Input {
  ListInput({required this.category});

  factory ListInput.fromCliRequest(CliRequest req) =>
      ListInput(category: req.flagString('category'));

  final String? category;

  @override
  Map<String, dynamic> toJson() => {if (category != null) 'category': category};
}

class ListOutput extends Output {
  ListOutput(this.entries);

  final List<CalculatrixCommandEntry> entries;

  @override
  Map<String, dynamic> toJson() => {
    'commands': entries.map(commandEntryToJson).toList(),
  };

  // Grouped by category (AC3), in the registry enumeration's own order,
  // never a second, CLI-side list of category names.
  @override
  String toText() {
    final StringBuffer buffer = StringBuffer();
    bool first = true;
    for (final CalculatrixCommandCategory category
        in CalculatrixCommandCategory.values) {
      final List<CalculatrixCommandEntry> inCategory = entries
          .where((CalculatrixCommandEntry entry) => entry.category == category)
          .toList();
      if (inCategory.isEmpty) continue;
      if (!first) buffer.writeln();
      first = false;
      buffer.writeln('${categoryToCliName(category)}:');
      for (final CalculatrixCommandEntry entry in inCategory) {
        buffer.writeln('  ${commandEntrySummaryText(entry)}');
      }
    }
    return buffer.toString().trimRight();
  }

  @override
  int get exitCode => ExitCode.ok;
}

class ListQuery implements Query<ListInput, ListOutput> {
  ListQuery(this.input);

  @override
  final ListInput input;

  @override
  String? validate() => null;

  @override
  Future<ListOutput> execute() async {
    final String? category = input.category;
    final CalculatrixCommandCategory? filter = category == null
        ? null
        : categoryFromCliName(category);
    return ListOutput(<CalculatrixCommandEntry>[
      for (final CalculatrixCommandEntry entry
          in CalculatrixCommandRegistry.standard.entries)
        if (filter == null || entry.category == filter) entry,
    ]);
  }
}
