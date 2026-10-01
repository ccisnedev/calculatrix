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
CommandException toCommandException(CalculatrixError error) {
  final details = <String, dynamic>{
    if (error.token != null) 'token': error.token,
    if (error.position != null) 'position': error.position,
    if (error.suggestions.isNotEmpty) 'suggestions': error.suggestions,
    if (error.name != null) 'name': error.name,
  };
  return CommandException(
    id: error.errorId?.id ?? 'calculatrix-error',
    message: error.message,
    exitCode: ExitCode.dataError,
    details: details.isEmpty ? null : details,
  );
}

/// One stack value as the JSON `"value"` of a level wants it (spec section
/// 6): a 1x1 matrix is a bare number, any other matrix is an array of rows,
/// never flattened. Numbers keep the full double (runbook D45).
Object matrixToJsonValue(Matrix matrix) {
  if (matrix.isScalar) return _jsonNumber(matrix.scalarValue);
  return [
    for (var row = 0; row < matrix.rowCount; row++)
      [
        for (var column = 0; column < matrix.columnCount; column++)
          _jsonNumber(matrix.at(row, column)),
      ],
  ];
}

/// One stack value as an HP 50g-style stack line wants it (spec section 6):
/// `1: 3`, `1: [[0 -1] [1 0]]`. Each number goes through the display
/// formatter of core, the one the app uses (runbook D45).
String matrixToText(Matrix matrix) {
  if (matrix.isScalar) return _numberText(matrix.scalarValue);
  final rows = [
    for (var row = 0; row < matrix.rowCount; row++)
      '[${[for (var column = 0; column < matrix.columnCount; column++) _numberText(matrix.at(row, column))].join(' ')}]',
  ];
  return '[${rows.join(' ')}]';
}

Object _jsonNumber(double value) {
  if (value.isFinite && value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toInt();
  }
  return value;
}

String _numberText(double value) => MatrixDisplayFormatter.number(value);
