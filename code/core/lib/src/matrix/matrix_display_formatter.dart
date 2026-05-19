import 'matrix.dart';

class MatrixDisplayFormatter {
  const MatrixDisplayFormatter._();

  static String compact(Matrix matrix) {
    final StringBuffer buffer = StringBuffer('[');

    for (int row = 0; row < matrix.rowCount; row++) {
      if (row > 0) {
        buffer.write(', ');
      }

      buffer.write('[');
      for (int column = 0; column < matrix.columnCount; column++) {
        if (column > 0) {
          buffer.write(', ');
        }

        buffer.write(_formatNumber(matrix.at(row, column)));
      }
      buffer.write(']');
    }

    buffer.write(']');
    return buffer.toString();
  }

  static String expanded(Matrix matrix) {
    final List<List<String>> cells = List<List<String>>.generate(
      matrix.rowCount,
      (int row) => List<String>.generate(
        matrix.columnCount,
        (int column) => _formatNumber(matrix.at(row, column)),
        growable: false,
      ),
      growable: false,
    );

    final List<int> widths = List<int>.generate(matrix.columnCount, (int column) {
      int maxWidth = 0;
      for (int row = 0; row < matrix.rowCount; row++) {
        final int cellWidth = cells[row][column].length;
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }
      return maxWidth;
    }, growable: false);

    return List<String>.generate(matrix.rowCount, (int row) {
      final String content = List<String>.generate(matrix.columnCount, (int column) {
        return cells[row][column].padLeft(widths[column]);
      }, growable: false).join(' ');
      return '[$content]';
    }, growable: false).join('\n');
  }

  static String _formatNumber(double value) {
    if (value == 0) {
      return '0';
    }

    if (value == value.toInt().toDouble() && value.abs() < 1e12) {
      return value.toInt().toString();
    }

    String text = value.toStringAsPrecision(12);
    if (text.contains('.')) {
      text = text.replaceAll(RegExp(r'0+$'), '');
      text = text.replaceAll(RegExp(r'\.$'), '');
    }
    return text;
  }

  /// Formats a complex-form matrix as `a + bi` or `a - bi`.
  ///
  /// Requires [matrix] to satisfy [Matrix.isComplexForm].
  /// Returns the standard mathematical notation for complex numbers,
  /// using Gauss's "lateral unit" terminology when displayed.
  static String complex(Matrix matrix) {
    final double re = matrix.realPart;
    final double im = matrix.imagPart;

    final String reStr = _formatNumber(re);

    if (im == 0) {
      return reStr;
    }

    final String imAbs = _formatNumber(im.abs());
    final String sign = im < 0 ? ' - ' : ' + ';
    final String imStr = imAbs == '1' ? 'i' : '${imAbs}i';

    if (re == 0) {
      return im < 0 ? '-$imStr' : imStr;
    }

    return '$reStr$sign$imStr';
  }
}