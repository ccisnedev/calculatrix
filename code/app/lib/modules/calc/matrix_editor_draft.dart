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

  bool appendRow() {
    if (rowCount >= _maxDimension) {
      return false;
    }

    _clearRow(rowCount);
    rowCount += 1;
    return true;
  }

  bool appendColumn() {
    if (columnCount >= _maxDimension) {
      return false;
    }

    _clearColumn(columnCount);
    columnCount += 1;
    return true;
  }

  bool deleteRow(int rowIndex) {
    _validateRowIndex(rowIndex);
    if (rowCount == 1) {
      return false;
    }

    for (int row = rowIndex; row < _maxDimension - 1; row++) {
      _copyRow(from: row + 1, to: row);
    }
    _clearRow(_maxDimension - 1);
    rowCount -= 1;
    return true;
  }

  bool deleteColumn(int columnIndex) {
    _validateColumnIndex(columnIndex);
    if (columnCount == 1) {
      return false;
    }

    for (int column = columnIndex; column < _maxDimension - 1; column++) {
      _copyColumn(from: column + 1, to: column);
    }
    _clearColumn(_maxDimension - 1);
    columnCount -= 1;
    return true;
  }

  bool duplicateRow(int rowIndex) {
    _validateRowIndex(rowIndex);
    if (rowCount >= _maxDimension) {
      return false;
    }

    final List<String> rowCopy = List<String>.from(_cells[rowIndex]);
    final int insertIndex = rowIndex + 1;
    for (int row = _maxDimension - 1; row > insertIndex; row--) {
      _copyRow(from: row - 1, to: row);
    }
    for (int column = 0; column < _maxDimension; column++) {
      _cells[insertIndex][column] = rowCopy[column];
    }
    rowCount += 1;
    return true;
  }

  bool duplicateColumn(int columnIndex) {
    _validateColumnIndex(columnIndex);
    if (columnCount >= _maxDimension) {
      return false;
    }

    final List<String> columnCopy = List<String>.generate(
      _maxDimension,
      (int row) => _cells[row][columnIndex],
      growable: false,
    );
    final int insertIndex = columnIndex + 1;
    for (int column = _maxDimension - 1; column > insertIndex; column--) {
      _copyColumn(from: column - 1, to: column);
    }
    for (int row = 0; row < _maxDimension; row++) {
      _cells[row][insertIndex] = columnCopy[row];
    }
    columnCount += 1;
    return true;
  }

  bool moveRow(int fromIndex, int toIndex) {
    _validateRowIndex(fromIndex);
    _validateRowIndex(toIndex);
    if (fromIndex == toIndex) {
      return false;
    }

    final List<String> rowCopy = List<String>.from(_cells[fromIndex]);
    if (fromIndex < toIndex) {
      for (int row = fromIndex; row < toIndex; row++) {
        _copyRow(from: row + 1, to: row);
      }
    } else {
      for (int row = fromIndex; row > toIndex; row--) {
        _copyRow(from: row - 1, to: row);
      }
    }
    for (int column = 0; column < _maxDimension; column++) {
      _cells[toIndex][column] = rowCopy[column];
    }
    return true;
  }

  bool moveColumn(int fromIndex, int toIndex) {
    _validateColumnIndex(fromIndex);
    _validateColumnIndex(toIndex);
    if (fromIndex == toIndex) {
      return false;
    }

    final List<String> columnCopy = List<String>.generate(
      _maxDimension,
      (int row) => _cells[row][fromIndex],
      growable: false,
    );
    if (fromIndex < toIndex) {
      for (int column = fromIndex; column < toIndex; column++) {
        _copyColumn(from: column + 1, to: column);
      }
    } else {
      for (int column = fromIndex; column > toIndex; column--) {
        _copyColumn(from: column - 1, to: column);
      }
    }
    for (int row = 0; row < _maxDimension; row++) {
      _cells[row][toIndex] = columnCopy[row];
    }
    return true;
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

  void _validateRowIndex(int rowIndex) {
    RangeError.checkValidIndex(rowIndex, _cells, 'rowIndex', rowCount);
  }

  void _validateColumnIndex(int columnIndex) {
    RangeError.checkValidIndex(
      columnIndex,
      _cells.first,
      'columnIndex',
      columnCount,
    );
  }

  void _copyRow({required int from, required int to}) {
    for (int column = 0; column < _maxDimension; column++) {
      _cells[to][column] = _cells[from][column];
    }
  }

  void _copyColumn({required int from, required int to}) {
    for (int row = 0; row < _maxDimension; row++) {
      _cells[row][to] = _cells[row][from];
    }
  }

  void _clearRow(int rowIndex) {
    for (int column = 0; column < _maxDimension; column++) {
      _cells[rowIndex][column] = '';
    }
  }

  void _clearColumn(int columnIndex) {
    for (int row = 0; row < _maxDimension; row++) {
      _cells[row][columnIndex] = '';
    }
  }
}