import '../errors/errors.dart';
import '../matrix/matrix.dart';
import '../rpn/rpn_engine.dart';
import 'calculatrix_command.dart';

final class PushMatrixCommand extends CalculatrixCommand {
  const PushMatrixCommand(this.value);

  final Matrix value;

  @override
  void executeOn(RpnEngine engine) {
    engine.push(value);
  }
}

final class PushScalarCommand extends CalculatrixCommand {
  const PushScalarCommand(this.value);

  final double value;

  @override
  void executeOn(RpnEngine engine) {
    engine.pushScalar(value);
  }
}

final class PushZerosCommand extends CalculatrixCommand {
  const PushZerosCommand(this.rowCount, this.columnCount);

  final int rowCount;
  final int columnCount;

  @override
  void executeOn(RpnEngine engine) {
    engine.push(Matrix.zeros(rowCount, columnCount));
  }
}

final class PushOnesCommand extends CalculatrixCommand {
  const PushOnesCommand(this.rowCount, this.columnCount);

  final int rowCount;
  final int columnCount;

  @override
  void executeOn(RpnEngine engine) {
    engine.push(Matrix.ones(rowCount, columnCount));
  }
}

final class PushIdentityCommand extends CalculatrixCommand {
  const PushIdentityCommand(this.size);

  final int size;

  @override
  void executeOn(RpnEngine engine) {
    engine.push(Matrix.identity(size));
  }
}

final class AddCommand extends CalculatrixCommand {
  const AddCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.applyBinary(RpnBinaryOperator.add);
  }
}

final class SubtractCommand extends CalculatrixCommand {
  const SubtractCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.applyBinary(RpnBinaryOperator.subtract);
  }
}

final class MultiplyCommand extends CalculatrixCommand {
  const MultiplyCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.applyBinary(RpnBinaryOperator.multiply);
  }
}

final class DivideCommand extends CalculatrixCommand {
  const DivideCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.applyBinary(RpnBinaryOperator.divide);
  }
}

final class PowerCommand extends CalculatrixCommand {
  const PowerCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix exponent = engine.pop();
    final Matrix base = engine.pop();
    engine.push(base.power(exponent));
  }
}

final class AppendRowCommand extends CalculatrixCommand {
  const AppendRowCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix row = engine.pop();
    final Matrix target = engine.pop();
    engine.push(target.appendRow(row));
  }
}

final class AppendColumnCommand extends CalculatrixCommand {
  const AppendColumnCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix column = engine.pop();
    final Matrix target = engine.pop();
    engine.push(target.appendColumn(column));
  }
}

/// `x1 ... xn n` gives the n x 1 column `[[x1] ... [xn]]` (issue #37, S4c).
///
/// `n` needs the stack depth at run time (how many operands to gather is
/// only known once `n` itself has been popped), so this cannot be a fixed
/// literal-argument command like the ones above; it inspects the engine's
/// stack directly, like [RowsCommand] below.
final class VectorCommand extends CalculatrixCommand {
  const VectorCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int count = _requireNonNegativeIntegerCount(engine.pop(), 'vector');

    final List<double> valuesTopToBottom = <double>[];
    for (int i = 0; i < count; i++) {
      valuesTopToBottom.add(_requireScalarValue(engine.pop(), 'vector'));
    }

    // A 0-item column is not representable: Matrix itself rejects an empty
    // row list with dimension-mismatch, so "0 vector" raises the same error
    // (the decision documented on the "vector" registry entry).
    if (valuesTopToBottom.isEmpty) {
      throw MatrixShapeError(
        'vector cannot build an empty column: 0 vector has no matrix form.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }

    engine.push(
      Matrix(
        valuesTopToBottom.reversed
            .map((double value) => <double>[value])
            .toList(growable: false),
      ),
    );
  }
}

/// `[[...]]` gives `[row1] ... [rown] n`, each row a 1 x m matrix, followed
/// by the row count (issue #37, S4c).
final class RowsCommand extends CalculatrixCommand {
  const RowsCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    for (final List<double> row in value.rows) {
      engine.push(Matrix(<List<double>>[List<double>.from(row)]));
    }
    engine.pushScalar(value.rowCount.toDouble());
  }
}

/// `A B` gives `[A B]` (A and B side by side); a generalization of
/// [AppendColumnCommand] to any operand B with a matching row count (issue
/// #37, S4c). Both share the single `Matrix.appendColumns` implementation
/// (D44).
final class AppendColsCommand extends CalculatrixCommand {
  const AppendColsCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix b = engine.pop();
    final Matrix a = engine.pop();
    engine.push(a.appendColumns(b));
  }
}

/// `A B` gives A over B; a generalization of [AppendRowCommand] to any
/// operand B with a matching column count (issue #37, S4c). Both share the
/// single `Matrix.appendRows` implementation (D44).
final class AppendRowsCommand extends CalculatrixCommand {
  const AppendRowsCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix b = engine.pop();
    final Matrix a = engine.pop();
    engine.push(a.appendRows(b));
  }
}

double _requireScalarValue(Matrix value, String word) {
  if (!value.isScalar) {
    throw MatrixDomainError(
      '$word requires a scalar operand, found a '
      '${value.rowCount}x${value.columnCount} matrix.',
      errorId: CalculatrixErrorId.typeMismatch,
    );
  }
  return value.scalarValue;
}

int _requireNonNegativeIntegerCount(Matrix value, String word) {
  final double raw = _requireScalarValue(value, word);
  if (raw < 0 || raw != raw.truncateToDouble()) {
    throw MatrixDomainError(
      '$word requires a non-negative integer count, found $raw.',
      errorId: CalculatrixErrorId.typeMismatch,
    );
  }
  return raw.toInt();
}

/// Pops a 1-based index or stack level, rejecting a non-integer, negative
/// or zero value as type-mismatch (runbook D46, issue #39, AC3). Shared by
/// every word that takes a stack level (`pick`, `roll`) or a row/column
/// index (`delete-row`, `move-col`, ...), so the format check lives in one
/// place.
int _requirePositiveInteger(Matrix value, String word) {
  final double raw = _requireScalarValue(value, word);
  if (raw < 1 || raw != raw.truncateToDouble()) {
    throw MatrixDomainError(
      '$word requires a positive integer index, found $raw.',
      errorId: CalculatrixErrorId.typeMismatch,
    );
  }
  return raw.toInt();
}

/// Converts a 1-based row or column index to the 0-based index `Matrix`
/// methods take, checking it against `count` first (runbook D46: "the
/// conversion to the 0-based indices of the core happens once, in the
/// words"; the `Matrix` methods keep their existing 0-based signature,
/// issue #39 AC2). An index above `count` is dimension-mismatch (AC3), not
/// `Matrix`'s own id-less `MatrixIndexError`: the word checks the bound
/// before the 0-based index ever reaches the `Matrix` method, so that
/// throw site is never hit from an RPN word.
int _requireIndexWithinCount(
  int index1Based,
  int count, {
  required String word,
  required String label,
}) {
  if (index1Based > count) {
    throw MatrixIndexError(
      '$word: $label index $index1Based is out of range for $count '
      '$label(s).',
      errorId: CalculatrixErrorId.dimensionMismatch,
    );
  }
  return index1Based - 1;
}

final class SqrtCommand extends CalculatrixCommand {
  const SqrtCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.applyUnary(RpnUnaryOperator.sqrt);
  }
}

final class PercentCommand extends CalculatrixCommand {
  const PercentCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.applyUnary(RpnUnaryOperator.percent);
  }
}

final class NegateCommand extends CalculatrixCommand {
  const NegateCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.scale(-1));
  }
}

final class TransposeCommand extends CalculatrixCommand {
  const TransposeCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.transpose());
  }
}

final class InverseCommand extends CalculatrixCommand {
  const InverseCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.inverse());
  }
}

final class DeterminantCommand extends CalculatrixCommand {
  const DeterminantCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.determinant());
  }
}

final class EigenvaluesCommand extends CalculatrixCommand {
  const EigenvaluesCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.eigenvalues());
  }
}

final class DiagonalizationCommand extends CalculatrixCommand {
  const DiagonalizationCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    final Diagonalization result = value.diagonalization();
    engine.push(result.p);
    engine.push(result.d);
  }
}

final class TraceCommand extends CalculatrixCommand {
  const TraceCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.trace());
  }
}

final class NormCommand extends CalculatrixCommand {
  const NormCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.frobeniusNorm());
  }
}

final class RankCommand extends CalculatrixCommand {
  const RankCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.rank());
  }
}

final class CofactorMatrixCommand extends CalculatrixCommand {
  const CofactorMatrixCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.cofactorMatrix());
  }
}

final class AdjugateCommand extends CalculatrixCommand {
  const AdjugateCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.adjugate());
  }
}

final class DotProductCommand extends CalculatrixCommand {
  const DotProductCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix b = engine.pop();
    final Matrix a = engine.pop();
    engine.push(a.dot(b));
  }
}

final class CrossProductCommand extends CalculatrixCommand {
  const CrossProductCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix b = engine.pop();
    final Matrix a = engine.pop();
    engine.push(a.cross(b));
  }
}

final class RrefCommand extends CalculatrixCommand {
  const RrefCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.rref());
  }
}

final class SpectralNormCommand extends CalculatrixCommand {
  const SpectralNormCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.spectralNorm());
  }
}

final class LuDecompositionCommand extends CalculatrixCommand {
  const LuDecompositionCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    final LuDecomposition decomposition = value.luDecomposition();
    engine.push(decomposition.permutation);
    engine.push(decomposition.lower);
    engine.push(decomposition.upper);
  }
}

final class QrDecompositionCommand extends CalculatrixCommand {
  const QrDecompositionCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    final QrDecomposition decomposition = value.qrDecomposition();
    engine.push(decomposition.q);
    engine.push(decomposition.r);
  }
}

final class DropCommand extends CalculatrixCommand {
  const DropCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.drop();
  }
}

final class PickCommand extends CalculatrixCommand {
  const PickCommand(this.indexFromTop);

  final int indexFromTop;

  @override
  void executeOn(RpnEngine engine) {
    engine.pick(indexFromTop);
  }
}

final class RollCommand extends CalculatrixCommand {
  const RollCommand(this.indexFromTop);

  final int indexFromTop;

  @override
  void executeOn(RpnEngine engine) {
    engine.roll(indexFromTop);
  }
}

final class DeleteRowCommand extends CalculatrixCommand {
  const DeleteRowCommand(this.rowIndex);

  final int rowIndex;

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.deleteRow(rowIndex));
  }
}

final class DeleteColumnCommand extends CalculatrixCommand {
  const DeleteColumnCommand(this.columnIndex);

  final int columnIndex;

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.deleteColumn(columnIndex));
  }
}

final class DuplicateRowCommand extends CalculatrixCommand {
  const DuplicateRowCommand(this.rowIndex);

  final int rowIndex;

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.duplicateRow(rowIndex));
  }
}

final class DuplicateColumnCommand extends CalculatrixCommand {
  const DuplicateColumnCommand(this.columnIndex);

  final int columnIndex;

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.duplicateColumn(columnIndex));
  }
}

final class MoveRowCommand extends CalculatrixCommand {
  const MoveRowCommand(this.fromIndex, this.toIndex);

  final int fromIndex;
  final int toIndex;

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.moveRow(fromIndex, toIndex));
  }
}

final class MoveColumnCommand extends CalculatrixCommand {
  const MoveColumnCommand(this.fromIndex, this.toIndex);

  final int fromIndex;
  final int toIndex;

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.moveColumn(fromIndex, toIndex));
  }
}

final class ExpCommand extends CalculatrixCommand {
  const ExpCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.exp());
  }
}

final class LnCommand extends CalculatrixCommand {
  const LnCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.pop();
    engine.push(value.log());
  }
}

/// `n pick` (issue #39, S4d): the RPN word for `pick`, taking its stack
/// level from the stack itself rather than a fixed int argument like
/// [PickCommand], which the app's typed-command session still uses. Both
/// delegate to the very same [RpnEngine.pick] (D44).
final class PickWordCommand extends CalculatrixCommand {
  const PickWordCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int level = _requirePositiveInteger(engine.pop(), 'pick');
    engine.pick(level);
  }
}

/// `n roll` (issue #39, S4d): the RPN word for `roll`, the stack-argument
/// counterpart of [RollCommand]. See [PickWordCommand].
final class RollWordCommand extends CalculatrixCommand {
  const RollWordCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int level = _requirePositiveInteger(engine.pop(), 'roll');
    engine.roll(level);
  }
}

/// `r c zeros` (issue #39, S4d): the RPN word for `zeros`, taking its shape
/// from the stack rather than a fixed int argument like [PushZerosCommand],
/// which `macros.dart`'s app-facing macros still use. Both share the very
/// same [Matrix.zeros] (D44).
final class ZerosCommand extends CalculatrixCommand {
  const ZerosCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int columnCount = _requireNonNegativeIntegerCount(
      engine.pop(),
      'zeros',
    );
    final int rowCount = _requireNonNegativeIntegerCount(engine.pop(), 'zeros');
    engine.push(Matrix.zeros(rowCount, columnCount));
  }
}

/// `r c ones` (issue #39, S4d): the stack-argument counterpart of
/// [PushOnesCommand]. See [ZerosCommand].
final class OnesCommand extends CalculatrixCommand {
  const OnesCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int columnCount = _requireNonNegativeIntegerCount(
      engine.pop(),
      'ones',
    );
    final int rowCount = _requireNonNegativeIntegerCount(engine.pop(), 'ones');
    engine.push(Matrix.ones(rowCount, columnCount));
  }
}

/// `n identity` (issue #39, S4d): the stack-argument counterpart of
/// [PushIdentityCommand]. `Matrix.identity` itself raises an id-less error
/// for size 0 (a pre-existing gap left untouched, per the instruction to
/// prefer validating in the word over changing `Matrix` semantics), so this
/// word checks for a zero size itself and raises dimension-mismatch before
/// ever calling `Matrix.identity` (AC3, issue #39: "0 identity" is
/// dimension-mismatch, like "0 vector" and "0 3 zeros").
final class IdentityCommand extends CalculatrixCommand {
  const IdentityCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int size = _requireNonNegativeIntegerCount(engine.pop(), 'identity');
    if (size == 0) {
      throw MatrixShapeError(
        'identity requires a positive size, found 0.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
    engine.push(Matrix.identity(size));
  }
}

/// `A i delete-row` (issue #39, S4d): the RPN word for `delete-row`, taking
/// its 1-based row index from the stack rather than a fixed int argument
/// like [DeleteRowCommand], which the app's typed-command session still
/// uses. Both share the very same [Matrix.deleteRow] (D44); this word does
/// the 1-based-to-0-based conversion (D46) and the bounds check that
/// produces dimension-mismatch (AC3) before calling it.
final class DeleteRowWordCommand extends CalculatrixCommand {
  const DeleteRowWordCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int index1 = _requirePositiveInteger(engine.pop(), 'delete-row');
    final Matrix value = engine.pop();
    final int index0 = _requireIndexWithinCount(
      index1,
      value.rowCount,
      word: 'delete-row',
      label: 'row',
    );
    engine.push(value.deleteRow(index0));
  }
}

/// `A j delete-col` (issue #39, S4d): the stack-argument counterpart of
/// [DeleteColumnCommand]. See [DeleteRowWordCommand].
final class DeleteColumnWordCommand extends CalculatrixCommand {
  const DeleteColumnWordCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int index1 = _requirePositiveInteger(engine.pop(), 'delete-col');
    final Matrix value = engine.pop();
    final int index0 = _requireIndexWithinCount(
      index1,
      value.columnCount,
      word: 'delete-col',
      label: 'column',
    );
    engine.push(value.deleteColumn(index0));
  }
}

/// `A i duplicate-row` (issue #39, S4d): the stack-argument counterpart of
/// [DuplicateRowCommand]. See [DeleteRowWordCommand].
final class DuplicateRowWordCommand extends CalculatrixCommand {
  const DuplicateRowWordCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int index1 = _requirePositiveInteger(engine.pop(), 'duplicate-row');
    final Matrix value = engine.pop();
    final int index0 = _requireIndexWithinCount(
      index1,
      value.rowCount,
      word: 'duplicate-row',
      label: 'row',
    );
    engine.push(value.duplicateRow(index0));
  }
}

/// `A j duplicate-col` (issue #39, S4d): the stack-argument counterpart of
/// [DuplicateColumnCommand]. See [DeleteRowWordCommand].
final class DuplicateColumnWordCommand extends CalculatrixCommand {
  const DuplicateColumnWordCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int index1 = _requirePositiveInteger(engine.pop(), 'duplicate-col');
    final Matrix value = engine.pop();
    final int index0 = _requireIndexWithinCount(
      index1,
      value.columnCount,
      word: 'duplicate-col',
      label: 'column',
    );
    engine.push(value.duplicateColumn(index0));
  }
}

/// `A i k move-row` (issue #39, S4d): the stack-argument counterpart of
/// [MoveRowCommand]. `i` is typed (and therefore pushed) before `k`, so `k`
/// is popped first. See [DeleteRowWordCommand].
final class MoveRowWordCommand extends CalculatrixCommand {
  const MoveRowWordCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int toIndex1 = _requirePositiveInteger(engine.pop(), 'move-row');
    final int fromIndex1 = _requirePositiveInteger(engine.pop(), 'move-row');
    final Matrix value = engine.pop();
    final int fromIndex0 = _requireIndexWithinCount(
      fromIndex1,
      value.rowCount,
      word: 'move-row',
      label: 'row',
    );
    final int toIndex0 = _requireIndexWithinCount(
      toIndex1,
      value.rowCount,
      word: 'move-row',
      label: 'row',
    );
    engine.push(value.moveRow(fromIndex0, toIndex0));
  }
}

/// `A j k move-col` (issue #39, S4d): the stack-argument counterpart of
/// [MoveColumnCommand]. See [MoveRowWordCommand].
final class MoveColumnWordCommand extends CalculatrixCommand {
  const MoveColumnWordCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int toIndex1 = _requirePositiveInteger(engine.pop(), 'move-col');
    final int fromIndex1 = _requirePositiveInteger(engine.pop(), 'move-col');
    final Matrix value = engine.pop();
    final int fromIndex0 = _requireIndexWithinCount(
      fromIndex1,
      value.columnCount,
      word: 'move-col',
      label: 'column',
    );
    final int toIndex0 = _requireIndexWithinCount(
      toIndex1,
      value.columnCount,
      word: 'move-col',
      label: 'column',
    );
    engine.push(value.moveColumn(fromIndex0, toIndex0));
  }
}
