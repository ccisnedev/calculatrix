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

  group('MatrixEditorDraft cells (runbook D56, D59)', () {
    MatrixEditorDraft draftWith(String a, String b) => MatrixEditorDraft(
      order: null,
      rowCount: 1,
      columnCount: 2,
    )..setCell(0, 0, a)..setCell(0, 1, b);

    test('a fraction or a marked value is a number, kept as typed', () {
      final MatrixEditorDraft draft = draftWith('1/3', '~0.1');

      expect(draft.validationError(), isNull);
      expect(draft.buildLiteral(), '[[1/3,~0.1]]');
    });

    test('a negative fraction and an exponent are numbers', () {
      final MatrixEditorDraft draft = draftWith('-5/3', '1e3');

      expect(draft.validationError(), isNull);
      expect(draft.buildLiteral(), '[[-5/3,1e3]]');
    });

    test('text that is no literal gets the example message', () {
      for (final String cell in <String>['oops', '1/2/3', '[[1]]', '1.5/2']) {
        expect(
          draftWith('1', cell).validationError(),
          'r1 c2 must be a number, like -2, 3.5 or 1/3',
          reason: cell,
        );
      }
    });

    test('a zero denominator gets the core message', () {
      expect(
        draftWith('1/0', '2').validationError(),
        startsWith('r1 c1 is not a valid number: '),
      );
    });
  });
}
