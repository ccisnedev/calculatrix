import 'package:calculatrix/calculatrix.dart';

import '../eval/eval_support.dart';

/// `--category`'s kebab-case spelling of [CalculatrixCommandCategory]
/// (spec section 7, "the categories are an enumeration taken from the
/// registry"): every value but `linearAlgebra` already reads as one word;
/// `linearAlgebra` becomes `linear-algebra`, the one Dart camelCase name in
/// the enum (command line flags are conventionally kebab-case, never
/// camelCase).
String categoryToCliName(CalculatrixCommandCategory category) =>
    switch (category) {
      CalculatrixCommandCategory.arithmetic => 'arithmetic',
      CalculatrixCommandCategory.matrix => 'matrix',
      CalculatrixCommandCategory.stack => 'stack',
      CalculatrixCommandCategory.construction => 'construction',
      CalculatrixCommandCategory.structure => 'structure',
      CalculatrixCommandCategory.linearAlgebra => 'linear-algebra',
    };

/// The [categoryToCliName] every declared category renders as, in
/// [CalculatrixCommandCategory.values] order: the closed list `--category`
/// declares itself against (`CliParam.enumeration`), so an unknown value is
/// rejected by the SDK itself, naming these, before any query code runs
/// (issue #41, AC3).
final List<String> commandCategoryCliNames = CalculatrixCommandCategory.values
    .map(categoryToCliName)
    .toList();

/// The inverse of [categoryToCliName]. `name` is assumed already validated
/// against [commandCategoryCliNames] (by the `--category` contract), so
/// this never needs to report an error of its own.
CalculatrixCommandCategory categoryFromCliName(String name) =>
    CalculatrixCommandCategory.values.firstWhere(
      (CalculatrixCommandCategory category) =>
          categoryToCliName(category) == name,
    );

/// One example of a [CalculatrixCommandEntry], as JSON (spec section 7,
/// issue #41 AC4: "every field of the entry, examples with their expected
/// result"). The result is the full stack the example leaves, bottom to
/// top, each value shaped as a `"value"` of `eval`'s own `"stack"` (spec
/// section 6), without the level objects: most examples leave a single
/// value, so most of these are one-element arrays.
Map<String, dynamic> commandExampleToJson(CalculatrixCommandExample example) =>
    {
      'program': example.program,
      'result': example.expectedStack.map(matrixToJsonValue).toList(),
    };

/// One example of a [CalculatrixCommandEntry], as one line of text:
/// `"<program> -> <result>"`, the result rendered the same HP 50g style
/// `eval`'s own text output uses (spec section 6).
String commandExampleToText(CalculatrixCommandExample example) =>
    '${example.program} -> '
    '${example.expectedStack.map(matrixToText).join(' ')}';

/// A [CalculatrixCommandEntry], as JSON, with every field spec section 7
/// documents (issue #41, AC4). The CLI renders the registry and holds no
/// copy of any entry text (AC7): every value here is read straight off
/// `entry`, never duplicated as a CLI-side literal.
Map<String, dynamic> commandEntryToJson(CalculatrixCommandEntry entry) => {
  'name': entry.name,
  'aliases': entry.aliases,
  'searchTerms': entry.searchTerms,
  if (entry.hp50gReference != null) 'hp50gReference': entry.hp50gReference,
  'category': categoryToCliName(entry.category),
  'primitive': entry.isPrimitive,
  if (entry.definition != null) 'definition': entry.definition,
  'stackEffect': entry.stackEffect,
  if (entry.preconditions != null) 'preconditions': entry.preconditions,
  'description': entry.description,
  'examples': entry.examples.map(commandExampleToJson).toList(),
  'errors': entry.errors.map((CalculatrixErrorId id) => id.id).toList(),
  'seeAlso': entry.seeAlso,
};

/// A [CalculatrixCommandEntry], as the full multi-line text `cx commands
/// show` prints (issue #41, AC1): every field spec section 7 documents.
String commandEntryToText(CalculatrixCommandEntry entry) {
  final StringBuffer buffer = StringBuffer();
  buffer.writeln(
    entry.aliases.isEmpty
        ? entry.name
        : '${entry.name} (${entry.aliases.join(', ')})',
  );
  buffer.writeln('Category: ${categoryToCliName(entry.category)}');
  buffer.writeln(
    'Definition: ${entry.isPrimitive ? 'primitive' : entry.definition}',
  );
  if (entry.searchTerms.isNotEmpty) {
    buffer.writeln('Search terms: ${entry.searchTerms.join(', ')}');
  }
  if (entry.hp50gReference != null) {
    buffer.writeln('HP 50g reference: ${entry.hp50gReference}');
  }
  buffer.writeln('Stack effect: ${entry.stackEffect}');
  if (entry.preconditions != null) {
    buffer.writeln('Preconditions: ${entry.preconditions}');
  }
  buffer.writeln('Description: ${entry.description}');
  if (entry.examples.isNotEmpty) {
    buffer.writeln('Examples:');
    for (final CalculatrixCommandExample example in entry.examples) {
      buffer.writeln('  ${commandExampleToText(example)}');
    }
  }
  if (entry.errors.isNotEmpty) {
    buffer.writeln(
      'Errors: '
      '${entry.errors.map((CalculatrixErrorId id) => id.id).join(', ')}',
    );
  }
  if (entry.seeAlso.isNotEmpty) {
    buffer.writeln('See also: ${entry.seeAlso.join(', ')}');
  }
  return buffer.toString().trimRight();
}

/// A [CalculatrixCommandEntry], as the one-line summary `cx commands
/// search` and `cx commands list` print in text mode (issue #41, AC2:
/// "lists each match with its name, aliases and one-line description").
String commandEntrySummaryText(CalculatrixCommandEntry entry) {
  final String aliases = entry.aliases.isEmpty
      ? ''
      : ' (${entry.aliases.join(', ')})';
  return '${entry.name}$aliases: ${entry.description}';
}

/// Whether `entry` matches `text` for `cx commands search` (spec section 7,
/// "Finding a command"; issue #41, AC2): a case-insensitive substring match
/// against the name, aliases, HP reference, search terms and description.
bool commandEntryMatchesSearch(CalculatrixCommandEntry entry, String text) {
  final String needle = text.toLowerCase();
  if (entry.name.toLowerCase().contains(needle)) return true;
  if (entry.aliases.any(
    (String alias) => alias.toLowerCase().contains(needle),
  )) {
    return true;
  }
  final String? hp = entry.hp50gReference;
  if (hp != null && hp.toLowerCase().contains(needle)) return true;
  if (entry.searchTerms.any(
    (String term) => term.toLowerCase().contains(needle),
  )) {
    return true;
  }
  if (entry.description.toLowerCase().contains(needle)) return true;
  return false;
}
