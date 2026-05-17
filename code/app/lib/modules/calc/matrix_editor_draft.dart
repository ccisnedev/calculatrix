class MatrixEditorDraft {
  MatrixEditorDraft({
    int? order,
    int rowCount = 2,
    int columnCount = 2,
  }) : assert(order == null || (order >= 1 && order <= _maxDimension)),
       assert(rowCount > 0 && rowCount <= _maxDimension),
       assert(columnCount > 0 && columnCount <= _maxDimension),
       rowCount = order ?? rowCount,
       columnCount = order ?? columnCount,
       _cells = List<List<String>>.generate(
         _maxDimension,
         (_) => List<String>.filled(_maxDimension, '', growable: false),
         growable: false,
       );

  static const int _maxDimension = 4;

  int rowCount;
  int columnCount;
  final List<List<String>> _cells;

  String cellValue(int row, int column) {
    return _cells[row][column];
  }

  void setCell(int row, int column, String value) {
    _cells[row][column] = value.trim();
  }

  void setOrder(int order) {
    resize(rowCount: order, columnCount: order);
  }

  void resize({required int rowCount, required int columnCount}) {
    assert(rowCount > 0 && rowCount <= _maxDimension);
    assert(columnCount > 0 && columnCount <= _maxDimension);

    this.rowCount = rowCount;
    this.columnCount = columnCount;
  }

  void fillZeros() {
    for (int row = 0; row < rowCount; row++) {
      for (int column = 0; column < columnCount; column++) {
        _cells[row][column] = '0';
      }
    }
  }

  void fillIdentity() {
    for (int row = 0; row < rowCount; row++) {
      for (int column = 0; column < columnCount; column++) {
        _cells[row][column] = row == column ? '1' : '0';
      }
    }
  }

  void clearVisible() {
    for (int row = 0; row < rowCount; row++) {
      for (int column = 0; column < columnCount; column++) {
        _cells[row][column] = '';
      }
    }
  }

  String? validationError() {
    for (int row = 0; row < rowCount; row++) {
      for (int column = 0; column < columnCount; column++) {
        final String cell = _cells[row][column];
        if (cell.isEmpty) {
          return 'Enter a value for r${row + 1} c${column + 1}';
        }

        if (num.tryParse(cell) == null) {
          return 'r${row + 1} c${column + 1} must be a number, like -2 or 3.5';
        }
      }
    }

    return null;
  }

  String buildLiteral() {
    final String? error = validationError();
    if (error != null) {
      throw FormatException(error);
    }

    final List<List<num>> rows = <List<num>>[];

    for (int rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      final List<num> parsedRow = <num>[];
      for (int columnIndex = 0; columnIndex < columnCount; columnIndex++) {
        final String cell = _cells[rowIndex][columnIndex];
        final num? parsed = num.tryParse(cell);
        if (parsed == null) {
          throw FormatException(
            'r${rowIndex + 1} c${columnIndex + 1} must be a number, like -2 or 3.5',
          );
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