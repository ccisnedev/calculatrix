import 'dart:convert';

import 'package:calculatrix/calculatrix.dart';

/// The characters that make an argument starting with `-` look like an
/// expression rather than a cluster of short options: digits, operators,
/// brackets, the approximate mark and spaces. `-qh` and `-fprog.rpn` have
/// none of them; `-sqrt(-1)`, `-e^2` and `-x 2 +` do.
final RegExp _expressionCharacter = RegExp(r'[0-9()\[\]+\-*/^%√~ ]');

final RegExp _letter = RegExp(r'^[A-Za-z]$');

/// The short options `cx` declares: `-q` and `-h`. Any other lone `-x`
/// is an `unknown-option` for the SDK.
const Set<String> _declaredShortOptions = <String>{'-q', '-h'};

/// Whether [arg], an argument starting with `-` and a letter, looks like a
/// value rather than options: its text after the dash has an expression
/// character (issue #66) or is a registry word, alias or constant, in any
/// case (issue #82).
bool _looksLikeValue(String arg) {
  final String name = arg.substring(1);
  return _expressionCharacter.hasMatch(name) ||
      CalculatrixCommandRegistry.standard.lookup(name) != null;
}

/// The index in [args] of the argument `modular_cli_sdk` rejects as
/// `invalid-short-option`, when that argument looks like a value (issues
/// #66 and #82). -1 when there is none.
///
/// The SDK reads only `-` followed by a letter as an option (`-(2+3)` and
/// `-2 3 +` are values already), accepts a lone short option such as `-q`,
/// and rejects the first longer one, before any `--`. That first one is
/// the argument the error is about: `-qh` in `cx eval infix -qh -2`, so no
/// hint there.
int _invalidShortOptionIndex(List<String> args) {
  for (int index = 0; index < args.length; index++) {
    final String arg = args[index];
    if (arg == '--') return -1;
    if (arg.length < 3 || arg[0] != '-' || !_letter.hasMatch(arg[1])) {
      continue;
    }
    return _looksLikeValue(arg) ? index : -1;
  }
  return -1;
}

/// The index in [args] of the first one-letter option that is not declared
/// by `cx` (`-e`, `-i`), when it looks like a value (issue #82). -1 when
/// there is none.
int _unknownOptionIndex(List<String> args) {
  for (int index = 0; index < args.length; index++) {
    final String arg = args[index];
    if (arg == '--') return -1;
    if (arg.length != 2 ||
        arg[0] != '-' ||
        !_letter.hasMatch(arg[1]) ||
        _declaredShortOptions.contains(arg)) {
      continue;
    }
    return _looksLikeValue(arg) ? index : -1;
  }
  return -1;
}

/// The index in [args] of the first argument that the SDK rejects and that
/// looks like a value (issues #66 and #82), or -1.
int optionLikeValueIndex(List<String> args) {
  final int invalid = _invalidShortOptionIndex(args);
  final int unknown = _unknownOptionIndex(args);
  if (invalid < 0) return unknown;
  if (unknown < 0) return invalid;
  return invalid < unknown ? invalid : unknown;
}

const String _invalidShortOption = 'invalid-short-option';
const String _unknownOption = 'unknown-option';

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
  final int invalidIndex = _invalidShortOptionIndex(args);
  final int unknownIndex = _unknownOptionIndex(args);
  if (invalidIndex < 0 && unknownIndex < 0) return errorText;

  // The message to put in place of the SDK's, or null to leave it: an
  // invalid-short-option always, an unknown-option only when it is exactly
  // `unknown option '<the argument>'`.
  String? replacement(String id, String? sdkMessage) {
    if (id == _invalidShortOption && invalidIndex >= 0) {
      return _message(args, invalidIndex);
    }
    if (id == _unknownOption &&
        unknownIndex >= 0 &&
        sdkMessage == "unknown option '${args[unknownIndex]}'") {
      return _message(args, unknownIndex);
    }
    return null;
  }

  final String trimmed = errorText.trimRight();
  if (trimmed.startsWith('{')) {
    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> &&
          decoded['error'] is Map<String, dynamic>) {
        final Map<String, dynamic> error =
            decoded['error'] as Map<String, dynamic>;
        final String? message = replacement(
          '${error['id']}',
          error['message'] as String?,
        );
        if (message == null) return errorText;
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
  if (match == null) return errorText;
  final String id = match.group(1)!;
  const String prefix = 'Error: ';
  final String sdkMessage = firstLine.substring(
    prefix.length,
    firstLine.length - ' [$id]'.length,
  );
  final String? message = replacement(id, sdkMessage);
  if (message == null) return errorText;
  return 'Error: $message [$id]$rest';
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
