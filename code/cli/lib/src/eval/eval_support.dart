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
CommandException toCommandException(CalculatrixError error) {
  final details = <String, dynamic>{
    if (error.token != null) 'token': error.token,
    if (error.position != null) 'position': error.position,
  };
  return CommandException(
    id: error.errorId?.id ?? 'calculatrix-error',
    message: error.message,
    exitCode: ExitCode.dataError,
    details: details.isEmpty ? null : details,
  );
}

/// The result matrix as the JSON `"stack"` array wants it (spec section 6):
/// a 1x1 matrix is a bare number, any other matrix is an array of rows,
/// never flattened.
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

/// The result matrix as one HP 50g-style stack line wants it (spec section
/// 6): `1: 3`, `1: [[0 -1] [1 0]]`.
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

String _numberText(double value) => _jsonNumber(value).toString();
