import 'dart:convert';

import 'unquoted_program_error.dart' show reservedTopLevelWords;

/// The options `cx eval rpn` has and the `cx <program>` shortcut does not
/// (spec G4, runbook D63). The global output options `--json` and
/// `--quiet`/`-q` are not here: the shortcut accepts them.
const Set<String> _evalOnlyOptions = <String>{'--file', '-f', '--stdin'};

/// Options that take the next argument as their value, so that value is
/// never the program or a command word.
const Set<String> _optionsWithValue = <String>{'--max-digits'};

/// The first argument of [args] that is an option the shortcut rejects, or
/// null when [args] is not a shortcut invocation or has none (issue #68).
///
/// An invocation is the shortcut when its first argument that is neither an
/// option nor the value of one is not a command word (`eval`, `commands`,
/// ...); with no such argument at all (`cx --file p.txt`) it is the
/// shortcut too. Arguments after `--` are values, never options.
String? shortcutRejectedOption(List<String> args) {
  String? rejected;
  bool sawPositional = false;
  for (int index = 0; index < args.length; index++) {
    final String arg = args[index];
    if (arg == '--') break;
    if (_optionsWithValue.contains(arg)) {
      index++;
      continue;
    }
    if (arg.startsWith('-') && arg.length > 1) {
      if (_evalOnlyOptions.contains(arg)) {
        rejected ??= arg;
        // `--file p.txt`: the value of the rejected option is not a
        // command word either.
        if (arg != '--stdin') index++;
      }
      continue;
    }
    if (!sawPositional) {
      if (reservedTopLevelWords.contains(arg)) return null;
      sawPositional = true;
    }
  }
  return rejected;
}

const Set<String> _rejectionIds = <String>{
  'misplaced-option',
  'unknown-option',
};

final RegExp _errorLinePattern = RegExp(r'^Error: .* \[([\w-]+)\]$');

final RegExp _needsQuotes = RegExp(r'''[\s\[\]{}()*?^&|<>;$'"]''');

String _shellArgument(String arg) =>
    _needsQuotes.hasMatch(arg) ? "'$arg'" : arg;

String _message(List<String> args, String option) =>
    '$option is not accepted by the shortcut; use: '
    'cx eval rpn ${args.map(_shellArgument).join(' ')}';

/// Rewrites the rejection of an option the shortcut does not take
/// (`cx '1 2 +' --file p.txt`) into `unknown-option`, exit 7, with a
/// message that gives the full spelling on `cx eval rpn` (spec G4, runbook
/// D63). The SDK reports it as `misplaced-option` ("options go before the
/// program ... belongs to one of eval rpn, eval infix"), which sends the
/// reader to the wrong place.
///
/// Handles the text line `Error: ... [id]` (anything after it, such as a
/// usage block, is kept) and the `--json` error object. Leaves [errorText]
/// untouched when [args] has no rejected option ([shortcutRejectedOption])
/// or the recorded error is another id. The exit code is never changed.
String rewriteShortcutOptionError(String errorText, List<String> args) {
  final String? option = shortcutRejectedOption(args);
  if (option == null) return errorText;
  final String message = _message(args, option);

  final String trimmed = errorText.trimRight();
  if (trimmed.startsWith('{')) {
    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> &&
          decoded['error'] is Map<String, dynamic>) {
        final Map<String, dynamic> error =
            decoded['error'] as Map<String, dynamic>;
        if (!_rejectionIds.contains(error['id'])) return errorText;
        error['id'] = 'unknown-option';
        error['message'] = message;
        return '${jsonEncode(decoded)}${errorText.substring(trimmed.length)}';
      }
    } on FormatException {
      return errorText;
    }
    return errorText;
  }

  final int firstLineEnd = errorText.indexOf('\n');
  final String firstLine = firstLineEnd == -1
      ? errorText
      : errorText.substring(0, firstLineEnd);
  final String rest = firstLineEnd == -1
      ? ''
      : errorText.substring(firstLineEnd);
  final RegExpMatch? match = _errorLinePattern.firstMatch(firstLine);
  if (match == null || !_rejectionIds.contains(match.group(1))) {
    return errorText;
  }
  return 'Error: $message [unknown-option]$rest';
}
