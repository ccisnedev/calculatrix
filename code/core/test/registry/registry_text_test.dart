import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// Patterns that mark a development meta reference (a runbook, a decision,
/// an issue or PR, an acceptance criterion, a runbook step or the spec)
/// leaking into user-facing text. Case-insensitive throughout, since a
/// stray "Runbook" or "Issue #" is just as much a leak as the lowercase
/// form.
///
/// A bare `D`, `R`, `S` or `AC` with no digits attached is never flagged: it
/// is free to name a matrix (the diagonal `D` of `diagonalize`, the
/// upper-triangular `R` of `qr`) or any other mathematical object.
final List<RegExp> _forbiddenPatterns = <RegExp>[
  RegExp('runbook', caseSensitive: false),
  RegExp('issue #', caseSensitive: false),
  RegExp(r'#\d+'),
  RegExp(r'\bD\d{1,3}\b'),
  RegExp(r'\bR\d{1,3}\b'),
  RegExp(r'\bAC\d+\b', caseSensitive: false),
  RegExp(r'\bS\d[a-z]\b', caseSensitive: false),
  RegExp('spec section', caseSensitive: false),
];

/// Every string a user (human or agent) can read out of a registry entry,
/// through `cx commands show|search|list`, their `--json` output, error
/// messages or the app's long-press help: every field named in issue #43's
/// acceptance criteria, plus the RPN program text of each example.
Iterable<String> _userFacingStrings(CalculatrixCommandEntry entry) {
  return <String>[
    entry.name,
    ...entry.aliases,
    ...entry.searchTerms,
    entry.description,
    entry.stackEffect,
    if (entry.preconditions != null) entry.preconditions!,
    if (entry.definition != null) entry.definition!,
    if (entry.hp50gReference != null) entry.hp50gReference!,
    ...entry.seeAlso,
    for (final CalculatrixCommandExample example in entry.examples)
      example.program,
  ];
}

/// The forbidden patterns [text] matches, if any.
Iterable<String> _matches(String text) {
  return _forbiddenPatterns
      .where((RegExp pattern) => pattern.hasMatch(text))
      .map((RegExp pattern) => pattern.pattern);
}

void main() {
  group('CalculatrixCommandRegistry.standard user-facing text', () {
    test(
      'no entry field carries a development meta reference (issue #43)',
      () {
        final List<String> violations = <String>[];

        for (final CalculatrixCommandEntry entry
            in CalculatrixCommandRegistry.standard.entries) {
          for (final String text in _userFacingStrings(entry)) {
            for (final String pattern in _matches(text)) {
              violations.add(
                'entry "${entry.name}": "$text" matches /$pattern/',
              );
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason: violations.join('\n'),
        );
      },
    );

    test(
      'a bare matrix letter such as the diagonal D or the upper-triangular '
      'R is not flagged',
      () {
        final CalculatrixCommandEntry diagonalize = CalculatrixCommandRegistry
            .standard
            .lookup('diagonalize')!;
        final CalculatrixCommandEntry qr = CalculatrixCommandRegistry.standard
            .lookup('qr')!;

        expect(diagonalize.description, contains('D'));
        expect(_matches(diagonalize.description), isEmpty);
        expect(qr.description, contains('R'));
        expect(_matches(qr.description), isEmpty);
      },
    );
  });
}
