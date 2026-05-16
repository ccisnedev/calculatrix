class MatrixEditorDraft {
  MatrixEditorDraft({
    this.rowCount = 2,
    this.columnCount = 2,
  }) : assert(rowCount > 0),
       assert(columnCount > 0),
       _cells = List<List<String>>.generate(
         rowCount,
         (_) => List<String>.filled(columnCount, '', growable: false),
         growable: false,
       );

  int rowCount;
  int columnCount;
  List<List<String>> _cells;

  String cellValue(int row, int column) {
    return _cells[row][column];
  }

  void setCell(int row, int column, String value) {
    _cells[row][column] = value.trim();
  }

  void resize({required int rowCount, required int columnCount}) {
    final List<List<String>> resized = List<List<String>>.generate(
      rowCount,
      (int row) => List<String>.generate(columnCount, (int column) {
        if (row < this.rowCount && column < this.columnCount) {
          return _cells[row][column];
        }
        return '';
      }, growable: false),
      growable: false,
    );

    this.rowCount = rowCount;
    this.columnCount = columnCount;
    _cells = resized;
  }

  String buildLiteral() {
    final List<List<num>> rows = <List<num>>[];

    for (final List<String> row in _cells) {
      final List<num> parsedRow = <num>[];
      for (final String cell in row) {
        if (cell.isEmpty) {
          throw const FormatException('Matrix cells cannot be empty.');
        }

        final num? parsed = num.tryParse(cell);
        if (parsed == null) {
          throw FormatException('Invalid numeric cell: $cell');
        }

        parsedRow.add(parsed);
      }
      rows.add(parsedRow);
    }

    final StringBuffer buffer = StringBuffer('[');
    for (int r = 0; r < rows.length; r++) {
      if (r > 0) {
        buffer.write(',');
      }
      buffer.write('[');
      for (int c = 0; c < rows[r].length; c++) {
        if (c > 0) {
          buffer.write(',');
        }
        buffer.write(_formatNumber(rows[r][c]));
      }
      buffer.write(']');
    }
    buffer.write(']');

    return buffer.toString();
  }

  String _formatNumber(num value) {
    if (value is int) {
      return value.toString();
    }

    final double normalized = value.toDouble();
    if (normalized == normalized.toInt().toDouble()) {
      return normalized.toInt().toString();
    }

    return normalized.toString();
  }
}