import 'package:calculatrix_app/modules/calc/matrix_editor_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatrixEditorDraft structural edits', () {
    test('appendRow preserves visible rows and exposes an empty new row', () {
      final MatrixEditorDraft draft = _seededDraft(rowCount: 2, columnCount: 2);

      expect(draft.appendRow(), isTrue);

      expect(draft.rowCount, 3);
      expect(draft.columnCount, 2);
      expect(draft.cellValue(0, 0), '1');
      expect(draft.cellValue(1, 1), '4');
      expect(draft.cellValue(2, 0), '');
      expect(draft.cellValue(2, 1), '');

      draft.setCell(2, 0, '5');
      draft.setCell(2, 1, '6');
      expect(draft.buildLiteral(), '[[1,2],[3,4],[5,6]]');
    });

    test('appendColumn preserves visible columns and exposes an empty new column', () {
      final MatrixEditorDraft draft = _seededDraft(rowCount: 2, columnCount: 2);

      expect(draft.appendColumn(), isTrue);

      expect(draft.rowCount, 2);
      expect(draft.columnCount, 3);
      expect(draft.cellValue(0, 0), '1');
      expect(draft.cellValue(1, 1), '4');
      expect(draft.cellValue(0, 2), '');
      expect(draft.cellValue(1, 2), '');

      draft.setCell(0, 2, '5');
      draft.setCell(1, 2, '6');
      expect(draft.buildLiteral(), '[[1,2,5],[3,4,6]]');
    });

    test('deleteRow removes the row and shifts lower rows upward', () {
      final MatrixEditorDraft draft = _seededDraft(rowCount: 3, columnCount: 2);

      expect(draft.deleteRow(1), isTrue);

      expect(draft.rowCount, 2);
      expect(draft.columnCount, 2);
      expect(draft.buildLiteral(), '[[1,2],[5,6]]');
    });

    test('deleteColumn removes the column and shifts right columns leftward', () {
      final MatrixEditorDraft draft = _seededDraft(rowCount: 2, columnCount: 3);

      expect(draft.deleteColumn(1), isTrue);

      expect(draft.rowCount, 2);
      expect(draft.columnCount, 2);
      expect(draft.buildLiteral(), '[[1,3],[4,6]]');
    });

    test('deleteRow and deleteColumn stop at the minimum visible shape', () {
      final MatrixEditorDraft draft = MatrixEditorDraft(rowCount: 1, columnCount: 1)
        ..setCell(0, 0, '9');

      expect(draft.deleteRow(0), isFalse);
      expect(draft.deleteColumn(0), isFalse);

      expect(draft.rowCount, 1);
      expect(draft.columnCount, 1);
      expect(draft.buildLiteral(), '[[9]]');
    });

    test('duplicateRow copies the stored row values immediately after the source', () {
      final MatrixEditorDraft draft = MatrixEditorDraft(rowCount: 2, columnCount: 2)
        ..setCell(0, 0, '1')
        ..setCell(0, 1, 'oops')
        ..setCell(1, 0, '3')
        ..setCell(1, 1, '4');

      expect(draft.duplicateRow(0), isTrue);

      expect(draft.rowCount, 3);
      expect(draft.cellValue(1, 0), '1');
      expect(draft.cellValue(1, 1), 'oops');
      expect(
        draft.validationError(),
        'r1 c2 must be a number, like -2 or 3.5',
      );
    });

    test('duplicateColumn copies the stored column values immediately after the source', () {
      final MatrixEditorDraft draft = _seededDraft(rowCount: 2, columnCount: 2);

      expect(draft.duplicateColumn(0), isTrue);

      expect(draft.columnCount, 3);
      expect(draft.buildLiteral(), '[[1,1,2],[3,3,4]]');
    });

    test('duplicate operations are blocked when the target axis is full', () {
      final MatrixEditorDraft rowLimited = _seededDraft(rowCount: 4, columnCount: 2);
      final MatrixEditorDraft columnLimited = _seededDraft(rowCount: 2, columnCount: 4);

      expect(rowLimited.duplicateRow(1), isFalse);
      expect(columnLimited.duplicateColumn(1), isFalse);

      expect(rowLimited.rowCount, 4);
      expect(columnLimited.columnCount, 4);
    });

    test('moveRow reorders the visible rows and literal output', () {
      final MatrixEditorDraft draft = _seededDraft(rowCount: 3, columnCount: 2);

      expect(draft.moveRow(0, 2), isTrue);

      expect(draft.buildLiteral(), '[[3,4],[5,6],[1,2]]');
    });

    test('moveColumn reorders the visible columns and literal output', () {
      final MatrixEditorDraft draft = _seededDraft(rowCount: 2, columnCount: 3);

      expect(draft.moveColumn(0, 2), isTrue);

      expect(draft.buildLiteral(), '[[2,3,1],[5,6,4]]');
    });

    test('moveRow and moveColumn are no-ops when source equals destination', () {
      final MatrixEditorDraft draft = _seededDraft(rowCount: 2, columnCount: 3);

      expect(draft.moveRow(1, 1), isFalse);
      expect(draft.moveColumn(2, 2), isFalse);
      expect(draft.buildLiteral(), '[[1,2,3],[4,5,6]]');
    });
  });
}

MatrixEditorDraft _seededDraft({required int rowCount, required int columnCount}) {
  final MatrixEditorDraft draft = MatrixEditorDraft(
    rowCount: rowCount,
    columnCount: columnCount,
  );

  int nextValue = 1;
  for (int row = 0; row < rowCount; row++) {
    for (int column = 0; column < columnCount; column++) {
      draft.setCell(row, column, '${nextValue++}');
    }
  }

  return draft;
}