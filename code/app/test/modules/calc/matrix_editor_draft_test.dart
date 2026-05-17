import 'package:flutter_test/flutter_test.dart';
import 'package:calculatrix_app/modules/calc/matrix_editor_draft.dart';

void main() {
  group('MatrixEditorDraft', () {
    test('changing order preserves and restores hidden top-left values', () {
      final MatrixEditorDraft draft = MatrixEditorDraft();

      draft.setCell(0, 0, '1');
      draft.setCell(0, 1, '2');
      draft.setCell(1, 0, '3');
      draft.setCell(1, 1, '4');

      draft.setOrder(4);
      draft.setCell(2, 2, '9');
      draft.setCell(3, 3, '16');

      draft.setOrder(2);
      expect(draft.rowCount, 2);
      expect(draft.columnCount, 2);
      expect(draft.buildLiteral(), '[[1,2],[3,4]]');

      draft.setOrder(4);
      expect(draft.rowCount, 4);
      expect(draft.columnCount, 4);
      expect(draft.cellValue(2, 2), '9');
      expect(draft.cellValue(3, 3), '16');
    });

    test('identity fills the active visible order only', () {
      final MatrixEditorDraft draft = MatrixEditorDraft(order: 3);

      draft.fillIdentity();

      expect(draft.buildLiteral(), '[[1,0,0],[0,1,0],[0,0,1]]');

      draft.setOrder(4);
      expect(draft.cellValue(3, 3), '');
    });

    test('zeros and clear affect only visible active cells', () {
      final MatrixEditorDraft draft = MatrixEditorDraft(order: 4);

      draft.setCell(3, 3, '8');
      draft.setOrder(2);
      draft.fillZeros();

      expect(draft.buildLiteral(), '[[0,0],[0,0]]');

      draft.clearVisible();
      expect(() => draft.buildLiteral(), throwsFormatException);

      draft.setOrder(4);
      expect(draft.cellValue(3, 3), '8');
    });
  });
}