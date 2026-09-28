import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Matrix throw sites carry the dimension-mismatch id (issue #5)', () {
    test('operator * dimension mismatch', () {
      try {
        Matrix(<List<double>>[
              <double>[1, 2],
            ]) *
            Matrix(<List<double>>[
              <double>[1, 2],
            ]);
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });

    test('minor requires at least a 2x2 matrix', () {
      try {
        Matrix.scalar(1).minor(0, 0);
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });

    test('dot product requires column vectors', () {
      try {
        Matrix(<List<double>>[
          <double>[1, 2],
        ]).dot(
          Matrix(<List<double>>[
            <double>[1, 2],
          ]),
        );
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });

    test('cross product requires 3x1 column vectors', () {
      try {
        Matrix(<List<double>>[
          <double>[1],
          <double>[2],
        ]).cross(
          Matrix(<List<double>>[
            <double>[1],
            <double>[2],
            <double>[3],
          ]),
        );
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });

    test('QR decomposition requires row count >= column count', () {
      try {
        Matrix(<List<double>>[
          <double>[1, 2, 3],
        ]).qrDecomposition();
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });

    test('appendRow rejects a mismatched row', () {
      try {
        Matrix(<List<double>>[
          <double>[1, 2],
        ]).appendRow(
          Matrix(<List<double>>[
            <double>[1, 2, 3],
          ]),
        );
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });

    test('appendColumn rejects a mismatched column', () {
      try {
        Matrix(<List<double>>[
          <double>[1, 2],
        ]).appendColumn(
          Matrix(<List<double>>[
            <double>[1],
            <double>[2],
          ]),
        );
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });

    test('deleteRow refuses to delete the only row', () {
      try {
        Matrix(<List<double>>[
          <double>[1, 2],
        ]).deleteRow(0);
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });

    test('deleteColumn refuses to delete the only column', () {
      try {
        Matrix(<List<double>>[
          <double>[1],
          <double>[2],
        ]).deleteColumn(0);
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });

    test('the constructor rejects an empty matrix', () {
      try {
        Matrix(<List<double>>[]);
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });

    test('the constructor rejects ragged rows', () {
      try {
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[1],
        ]);
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });

    test('_requireSameDimensions (operator +) mismatch', () {
      try {
        Matrix(<List<double>>[
              <double>[1, 2],
            ]) +
            Matrix(<List<double>>[
              <double>[1, 2, 3],
            ]);
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });

    test('_requireSquare (inverse on a non-square matrix)', () {
      try {
        Matrix(<List<double>>[
          <double>[1, 2, 3],
        ]).inverse();
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
      }
    });
  });

  group(
    'Matrix throw sites carry the non-finite / type-mismatch ids (issue #5)',
    () {
      test('division by a zero scalar is non-finite', () {
        try {
          Matrix.scalar(1) / Matrix.scalar(0);
          fail('expected MatrixDomainError');
        } on MatrixDomainError catch (error) {
          expect(error.errorId, CalculatrixErrorId.nonFinite);
        }
      });

      test('division by a non-scalar denominator is a type mismatch', () {
        try {
          Matrix.scalar(1) /
              Matrix(<List<double>>[
                <double>[1, 2],
              ]);
          fail('expected UnsupportedCalculatrixOperationError');
        } on UnsupportedCalculatrixOperationError catch (error) {
          expect(error.errorId, CalculatrixErrorId.typeMismatch);
        }
      });
    },
  );

  group('Matrix throw sites carry the singular-matrix id (issue #5)', () {
    test('inverse of a singular matrix', () {
      try {
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[2, 4],
        ]).inverse();
        fail('expected MatrixDomainError');
      } on MatrixDomainError catch (error) {
        expect(error.errorId, CalculatrixErrorId.singularMatrix);
      }
    });
  });

  group('RpnEngine throw sites carry the stack-underflow id (issue #5)', () {
    test('dup on an empty stack', () {
      try {
        RpnEngine().dup();
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
      }
    });

    test('drop on an empty stack', () {
      try {
        RpnEngine().drop();
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
      }
    });

    test('swap with fewer than two values', () {
      try {
        (RpnEngine()..push(Matrix.scalar(1))).swap();
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
      }
    });

    test('over with fewer than two values', () {
      try {
        (RpnEngine()..push(Matrix.scalar(1))).over();
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
      }
    });

    test('rot with fewer than three values', () {
      try {
        (RpnEngine()
              ..push(Matrix.scalar(1))
              ..push(Matrix.scalar(2)))
            .rot();
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
      }
    });

    test('peek on an empty stack', () {
      try {
        RpnEngine().peek();
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
      }
    });

    test('pop on an empty stack', () {
      try {
        RpnEngine().pop();
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
      }
    });

    test('applyBinary with fewer than two values', () {
      try {
        RpnEngine().applyBinary(RpnBinaryOperator.add);
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
      }
    });

    test('applyUnary on an empty stack', () {
      try {
        RpnEngine().applyUnary(RpnUnaryOperator.sqrt);
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
      }
    });

    test('pick on an empty stack', () {
      try {
        RpnEngine().pick(1);
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
      }
    });
  });

  group('requireTopMatrix carries the stack-underflow id (issue #5)', () {
    test('empty machine stack', () {
      try {
        requireTopMatrix(CalculatrixMachine(), operation: 'transpose');
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
      }
    });
  });
}
