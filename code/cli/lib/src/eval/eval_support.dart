import 'dart:io';

import 'package:calculatrix/calculatrix.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../stdin_reader.dart';

/// Resolves the program text from whichever single source is present.
///
/// By the time this runs, the SDK has already enforced `ExactlyOne(program,
/// file, stdin)` (G1), so at most one of [inline]/[filePath]/[readStdin] is
/// meaningfully set. This still rejects a blank result from any of the
/// three sources (G12): "the program is empty" is a fact about the text
/// that arrived, not about which source it arrived from.
String resolveProgramSource({
  required String? inline,
  required String? filePath,
  required bool readStdin,
  required StdinReader stdinReader,
}) {
  final String raw;
  if (inline != null) {
    raw = inline;
  } else if (filePath != null) {
    raw = File(filePath).readAsStringSync();
  } else {
    raw = stdinReader();
  }

  if (raw.trim().isEmpty) {
    throw CommandException(
      id: 'validation-failed',
      message: 'the program is empty',
      exitCode: ExitCode.validationFailed,
    );
  }

  return raw;
}

/// Maps a core [CalculatrixError] onto the CLI's own JSON error envelope
/// (spec section 6, D36): kebab-case id, `exitCode` 65 (`dataError`), and
/// the offending token/position when the evaluator knew them.
///
/// A `limit-exceeded` error (runbook D55) carries `details.limit` and
/// `details.estimated`, and its message gains the next step: the same
/// program with the operand marked approximate, built by [approximateHint]
/// when the caller knows the program, and how to raise the limit.
///
/// `error.suggestions` (spec section 7, "Did you mean"; issue #41, AC5),
/// when not empty, rides along as `details.suggestions`: the core's own
/// "did you mean" candidates for an unknown RPN word, already in
/// `error.message` too. Kept apart from the route-level suggestion the
/// `<program>` shortcut adds on top of this same exception (AC6, "RPN and
/// route suggestions are listed apart").
///
/// `error.name` (issue #51, AC2: the registry word an infix name error
/// resolved to, e.g. "sqrt" for "sqrt(7)") rides along the same way, as
/// `details.name`: a caller parsing the JSON envelope has no other way to
/// recover it, since `error.message` is prose built for a human, not a
/// field meant to be re-parsed.
CommandException toCommandException(
  CalculatrixError error, {
  String? Function(CalculatrixError error)? approximateHint,
}) {
  final details = <String, dynamic>{
    if (error.token != null) 'token': error.token,
    if (error.position != null) 'position': error.position,
    if (error.suggestions.isNotEmpty) 'suggestions': error.suggestions,
    if (error.name != null) 'name': error.name,
    if (error is LimitExceededError) ...{
      'limit': error.limit,
      'estimated': error.estimated,
    },
  };
  return CommandException(
    id: error.errorId?.id ?? 'calculatrix-error',
    message: error is LimitExceededError
        ? _limitMessage(error, approximateHint?.call(error))
        : error.message,
    exitCode: ExitCode.dataError,
    details: details.isEmpty ? null : details,
  );
}

String _limitMessage(LimitExceededError error, String? hint) {
  final String base = error.message.endsWith('.')
      ? error.message.substring(0, error.message.length - 1)
      : error.message;
  final String approximate = hint == null
      ? 'for an approximate result, mark one of its numbers with ~'
      : 'for an approximate result: $hint';
  return '$base; $approximate, or raise the limit with --max-digits.';
}

/// The program of an RPN `limit-exceeded` [error] rewritten to compute
/// approximately (runbook D55), as a `cx` command line, or null when the
/// error does not say where it happened. A literal over the limit gets
/// the mark `~` (runbook D56); a word gets `approx` right before it, which
/// makes its top operand approximate and, by contagion (runbook D51), its
/// result.
String? rpnApproximateHint(List<String> tokens, CalculatrixError error) {
  final String line = tokens.join(' ');
  final String? token = error.token;
  final int? position = error.position;
  if (token == null ||
      position == null ||
      position < 1 ||
      !line.startsWith(token, position - 1)) {
    return null;
  }
  final String insert = Calculatrix.isLiteralToken(token) ? '~' : 'approx ';
  final String program =
      '${line.substring(0, position - 1)}$insert${line.substring(position - 1)}';
  return _commandLine('cx', program);
}

/// The infix expression of a `limit-exceeded` [error] with its literal
/// marked `~` (runbook D56), as a `cx eval infix` command line, or null
/// when the error is not about a literal: in infix, which operand to mark
/// depends on the expression.
String? infixApproximateHint(String expression, CalculatrixError error) {
  final String? token = error.token;
  final int? position = error.position;
  if (token == null ||
      position == null ||
      position < 1 ||
      !Calculatrix.isLiteralToken(token) ||
      !expression.startsWith(token, position - 1)) {
    return null;
  }
  final String marked =
      '${expression.substring(0, position - 1)}~${expression.substring(position - 1)}';
  return _commandLine('cx eval infix', marked.trim());
}

String? _commandLine(String command, String program) =>
    program.contains("'") || program.contains('\n')
    ? null
    : "$command '$program'";

/// One stack value as the JSON `"value"` of a level wants it (spec section
/// 6, runbook D54): a 1x1 matrix is a bare number, any other matrix is an
/// array of rows, never flattened. An exact number is a string in its text
/// form (`"1/3"`, `"12157665459056928801"`), since a JSON number cannot
/// hold it; an approximate number keeps the full double (runbook D45).
Object matrixToJsonValue(Matrix matrix) {
  Object entry(int row, int column) => matrix.isExact
      ? matrix.exactAt(row, column).toDisplayString()
      : _jsonNumber(matrix.at(row, column));
  if (matrix.isScalar) return entry(0, 0);
  return [
    for (var row = 0; row < matrix.rowCount; row++)
      [
        for (var column = 0; column < matrix.columnCount; column++)
          entry(row, column),
      ],
  ];
}

/// One stack value as an HP 50g-style stack line wants it (spec section 6,
/// runbook D54): `1: 3`, `1: [[0 -1] [1 0]]`, `1: 1/3`. The text comes from
/// the display formatter of core, the one the app uses (runbook D45): an
/// exact number prints in full, and an approximate value carries the mark
/// `~` once, in front of the whole value: `1: ~0.333333333333`,
/// `1: ~[[1 1.41421356237]]`.
String matrixToText(Matrix matrix) => MatrixDisplayFormatter.text(matrix);

Object _jsonNumber(double value) {
  if (value.isFinite && value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toInt();
  }
  return value;
}
