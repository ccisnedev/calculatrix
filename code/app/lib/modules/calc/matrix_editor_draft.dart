import 'package:calculatrix/calculatrix.dart';

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

        final String? cellError = _cellError(cell);
        if (cellError != null) {
          return 'r${row + 1} c${column + 1} $cellError';
        }
      }
    }

    return null;
  }

  // A cell takes the numeric literals of core (runbook D50, D56, D59): a
  // decimal, a fraction p/q, either with the mark `~`. A cell that reads as
  // a literal but has no value (`1/0`, a literal over the digit limit) gets
  // the core message.
  static String? _cellError(String cell) {
    if (!Calculatrix.isLiteralToken(cell) || cell.contains('[')) {
      return 'must be a number, like -2, 3.5 or 1/3';
    }

    try {
      Calculatrix.evaluateRpn(<String>[cell]);
    } on CalculatrixError catch (error) {
      return 'is not a valid number: ${error.message}';
    }

    return null;
  }

  String buildLiteral() {
    final String? error = validationError();
    if (error != null) {
      throw FormatException(error);
    }

    // The cells go in as typed, so an exact entry stays exact and a marked
    // one marks the matrix (runbook D56).
    final StringBuffer buffer = StringBuffer('[');
    for (int r = 0; r < rowCount; r++) {
      if (r > 0) {
        buffer.write(',');
      }
      buffer.write('[');
      for (int c = 0; c < columnCount; c++) {
        if (c > 0) {
          buffer.write(',');
        }
        buffer.write(_cells[r][c]);
      }
      buffer.write(']');
    }
    buffer.write(']');

    return buffer.toString();
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