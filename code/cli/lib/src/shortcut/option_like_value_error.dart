import 'dart:convert';

/// The characters that make an argument starting with `-` look like an
/// expression rather than a cluster of short options: digits, operators,
/// brackets, the approximate mark and spaces. `-qh` and `-fprog.rpn` have
/// none of them; `-sqrt(-1)`, `-e^2` and `-x 2 +` do.
final RegExp _expressionCharacter = RegExp(r'[0-9()\[\]+\-*/^%√~ ]');

final RegExp _letter = RegExp(r'^[A-Za-z]$');

/// The index in [args] of the argument `modular_cli_sdk` rejects as
/// `invalid-short-option`, when that argument looks like an expression
/// (issue #66). -1 when there is none.
///
/// The SDK reads only `-` followed by a letter as an option (`-(2+3)` and
/// `-2 3 +` are values already), accepts a lone short option such as `-q`,
/// and rejects the first longer one, before any `--`. That first one is
/// the argument the error is about: `-qh` in `cx eval infix -qh -2`, so no
/// hint there.
int optionLikeValueIndex(List<String> args) {
  for (int index = 0; index < args.length; index++) {
    final String arg = args[index];
    if (arg == '--') return -1;
    if (arg.length < 3 || arg[0] != '-' || !_letter.hasMatch(arg[1])) {
      continue;
    }
    return _expressionCharacter.hasMatch(arg.substring(1)) ? index : -1;
  }
  return -1;
}

const String _rejectionId = 'invalid-short-option';

/// `modular_cli_sdk`'s text-mode error line: `Error: <message> [<id>]`.
final RegExp _errorLinePattern = RegExp(r'^Error: .* \[([\w-]+)\]$');

/// Rewrites `modular_cli_sdk`'s `invalid-short-option` message when the
/// rejected argument looks like an expression (issue #66), so it says what
/// happened and how to pass the value: POSIX `--` ends the options, and
/// everything after it is a value even when it starts with `-`.
///
/// Handles both the text line `Error: ... [invalid-short-option]` and the
/// `--json` error object. Leaves [errorText] untouched when no argument
/// looks like an expression ([optionLikeValueIndex]) or the recorded error
/// is another id. The id and the exit code are never changed.
String rewriteOptionLikeValueError(String errorText, List<String> args) {
  final int index = optionLikeValueIndex(args);
  if (index < 0) return errorText;
  final String message = _message(args, index);

  final String trimmed = errorText.trimRight();
  if (trimmed.startsWith('{')) {
    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> &&
          decoded['error'] is Map<String, dynamic>) {
        final Map<String, dynamic> error =
            decoded['error'] as Map<String, dynamic>;
        if (error['id'] != _rejectionId) return errorText;
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
  if (match == null || match.group(1) != _rejectionId) return errorText;
  return 'Error: $message [$_rejectionId]$rest';
}

// Every cx route takes one value, so the value goes last, after --, and
// the arguments that followed it (such as --json) stay options.
String _message(List<String> args, int index) {
  final String value = args[index];
  final String command = <String>[
    'cx',
    ...args.sublist(0, index),
    ...args.sublist(index + 1),
    '--',
    "'$value'",
  ].join(' ');
  return '$value starts with "-", so it was read as options; to pass it '
      'as a value, end the options with --: $command';
}
