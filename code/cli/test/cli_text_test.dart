import 'dart:io';

import 'package:test/test.dart';

/// Patterns that mark a development meta reference (a runbook, a decision,
/// an issue or PR, an acceptance criterion, a runbook step or the spec)
/// leaking into user-facing text, mirroring the check the core package runs
/// over its command registry (issue #43). Case-insensitive throughout.
///
/// A bare `D`, `R`, `S` or `AC` with no digits attached is never flagged: it
/// is free to name a matrix or any other mathematical object.
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

/// Every `.dart` file under `dir`, recursively.
Iterable<File> _dartFilesUnder(Directory dir) {
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'));
}

void main() {
  test(
    'no CLI source line outside a full-line comment carries a development '
    'meta reference (issue #43)',
    () {
      // A cheap, line-oriented scan, not a full parse: it treats a line as
      // a code comment, and skips it, only when the line holds nothing but
      // a `//` or `///` comment (matching the grep the issue was filed
      // with). A reference inside an actual user-facing string literal, in
      // error messages or help text, has nowhere to hide from it.
      final Directory libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory not found');

      final List<String> violations = <String>[];

      for (final File file in _dartFilesUnder(libDir)) {
        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i];
          if (line.trimLeft().startsWith('//')) {
            continue;
          }
          for (final RegExp pattern in _forbiddenPatterns) {
            if (pattern.hasMatch(line)) {
              violations.add(
                '${file.path}:${i + 1}: "$line" matches /${pattern.pattern}/',
              );
            }
          }
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}
