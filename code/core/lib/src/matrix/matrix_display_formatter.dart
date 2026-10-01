import '../errors/errors.dart';
import 'matrix.dart';

/// The display text of values, shared by the app and `cx` (runbook D45,
/// D54).
///
/// An exact entry prints in full, as [Rational.toDisplayString] does
/// (`3`, `0.6`, `1/3`). An approximate entry prints with at most 12
/// significant digits ([number]). An approximate value carries the mark
/// `~` once, in front of the whole value.
class MatrixDisplayFormatter {
  const MatrixDisplayFormatter._();

  /// The mark of an approximate value (runbook D54), or `''` for an exact
  /// one.
  static String mark(Matrix matrix) => matrix.isExact ? '' : '~';

  /// The text of the entry at ([row], [column]): in full when [matrix] is
  /// exact, else as [number] formats it. Never marked.
  static String entry(Matrix matrix, int row, int column) => matrix.isExact
      ? matrix.exactAt(row, column).toDisplayString()
      : _formatNumber(matrix.at(row, column));

  /// One value as a stack line of `cx` shows it (spec section 6): a scalar
  /// alone (`3`, `1/3`, `~0.333333333333`), any other matrix as rows
  /// separated by spaces (`[[1 2] [3 4]]`), with the mark of an
  /// approximate value in front.
  static String text(Matrix matrix) {
    if (matrix.isScalar) {
      return '${mark(matrix)}${entry(matrix, 0, 0)}';
    }
    final List<String> rows = <String>[
      for (int row = 0; row < matrix.rowCount; row++)
        '[${<String>[for (int column = 0; column < matrix.columnCount; column++) entry(matrix, row, column)].join(' ')}]',
    ];
    return '${mark(matrix)}[${rows.join(' ')}]';
  }

  /// One line, rows and entries separated by commas: `[[1, 2], [3, 4]]`,
  /// `~[[1, 1.41421356237]]`.
  static String compact(Matrix matrix) {
    final StringBuffer buffer = StringBuffer('${mark(matrix)}[');

    for (int row = 0; row < matrix.rowCount; row++) {
      if (row > 0) {
        buffer.write(', ');
      }

      buffer.write('[');
      for (int column = 0; column < matrix.columnCount; column++) {
        if (column > 0) {
          buffer.write(', ');
        }

        buffer.write(entry(matrix, row, column));
      }
      buffer.write(']');
    }

    buffer.write(']');
    return buffer.toString();
  }

  /// One line per row, columns aligned to the right. The mark of an
  /// approximate value goes before the first row, and the other rows are
  /// indented by one space to stay aligned with it:
  ///
  /// ```text
  /// ~[1 1.41421356237]
  ///  [2             3]
  /// ```
  static String expanded(Matrix matrix) {
    final List<List<String>> cells = List<List<String>>.generate(
      matrix.rowCount,
      (int row) => List<String>.generate(
        matrix.columnCount,
        (int column) => entry(matrix, row, column),
        growable: false,
      ),
      growable: false,
    );

    final List<int> widths = List<int>.generate(matrix.columnCount, (
      int column,
    ) {
      int maxWidth = 0;
      for (int row = 0; row < matrix.rowCount; row++) {
        final int cellWidth = cells[row][column].length;
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }
      return maxWidth;
    }, growable: false);

    final String mark = MatrixDisplayFormatter.mark(matrix);
    final String indent = ' ' * mark.length;
    return List<String>.generate(matrix.rowCount, (int row) {
      final String content = List<String>.generate(matrix.columnCount, (
        int column,
      ) {
        return cells[row][column].padLeft(widths[column]);
      }, growable: false).join(' ');
      return '${row == 0 ? mark : indent}[$content]';
    }, growable: false).join('\n');
  }

  /// Formats one approximate entry the way [compact], [expanded], [text]
  /// and [complex] do: at most 12 significant digits, trailing zeros
  /// removed.
  static String number(double value) => _formatNumber(value);

  static String _formatNumber(double value) {
    if (value == 0) {
      return '0';
    }

    if (value == value.toInt().toDouble() && value.abs() < 1e12) {
      return value.toInt().toString();
    }

    final String raw = value.toStringAsPrecision(12);

    // Split off any exponent suffix (e.g. "e+20", "E-15") before trimming
    // trailing zeros, so the trim only ever touches the mantissa and never
    // corrupts the exponent digits themselves.
    final int exponentIndex = raw.indexOf(RegExp(r'[eE]'));
    final String mantissa = exponentIndex == -1
        ? raw
        : raw.substring(0, exponentIndex);
    final String exponentSuffix = exponentIndex == -1
        ? ''
        : raw.substring(exponentIndex);

    String trimmedMantissa = mantissa;
    if (trimmedMantissa.contains('.')) {
      trimmedMantissa = trimmedMantissa.replaceAll(RegExp(r'0+$'), '');
      trimmedMantissa = trimmedMantissa.replaceAll(RegExp(r'\.$'), '');
    }

    return '$trimmedMantissa$exponentSuffix';
  }

  /// Formats a complex-form matrix as `a + bi` or `a - bi`, with the
  /// mark of an approximate value in front (`~1 + 1.41421356237i`).
  ///
  /// Requires [matrix] to satisfy [Matrix.isComplexForm].
  /// Returns the standard mathematical notation for complex numbers,
  /// using Gauss's "lateral unit" terminology when displayed.
  static String complex(Matrix matrix) {
    // In the form [[a, -b], [b, a]], the entry (0, 0) is the real part
    // and the entry (1, 0) the imaginary part. Signs and zeros come from
    // the text, so a tiny exact part is never taken for 0. An exact matrix
    // must have the form exactly, not within a tolerance.
    final bool complexForm = matrix.isExact
        ? matrix.rowCount == 2 &&
              matrix.columnCount == 2 &&
              matrix.exactAt(0, 0) == matrix.exactAt(1, 1) &&
              matrix.exactAt(0, 1) == -matrix.exactAt(1, 0)
        : matrix.isComplexForm;
    if (!complexForm) {
      throw MatrixDomainError('Matrix is not in complex form [[a,-b],[b,a]].');
    }
    final String reStr = entry(matrix, 0, 0);
    final String imText = entry(matrix, 1, 0);
    final String mark = MatrixDisplayFormatter.mark(matrix);

    if (imText == '0') {
      return '$mark$reStr';
    }

    final bool negative = imText.startsWith('-');
    final String imAbs = negative ? imText.substring(1) : imText;
    final String sign = negative ? ' - ' : ' + ';
    final String imStr = imAbs == '1' ? 'i' : '${imAbs}i';

    if (reStr == '0') {
      return '$mark${negative ? '-$imStr' : imStr}';
    }

    return '$mark$reStr$sign$imStr';
  }
}
