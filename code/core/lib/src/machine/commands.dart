import '../errors/errors.dart';
import '../exact/rational.dart';
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
    final Matrix exponent = engine.popAny();
    final Matrix base = engine.popAny();
    final BigInt? integerExponent = _exactIntegerScalar(exponent);
    // An exact base takes an exact integer exponent exactly: any integer
    // for a scalar, a non-negative one for a square matrix (a negative
    // power of a matrix needs its inverse, exact from step T3 of the
    // runbook). Everything else, fractional powers included, is
    // approximate (runbook D53).
    if (base.isExact &&
        integerExponent != null &&
        base.isSquare &&
        (base.isScalar || !integerExponent.isNegative)) {
      engine.push(engine.exact.power(base, integerExponent));
      return;
    }
    engine.push(base.toApproximate().power(exponent.toApproximate()));
  }
}

final class AppendRowCommand extends CalculatrixCommand {
  const AppendRowCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix row = engine.popAny();
    final Matrix target = engine.popAny();
    engine.push(target.appendRow(row));
  }
}

final class AppendColumnCommand extends CalculatrixCommand {
  const AppendColumnCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix column = engine.popAny();
    final Matrix target = engine.popAny();
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
    final int count = _requireNonNegativeIntegerCount(
      engine.popAny(),
      'vector',
    );

    // Checked once, up front, rather than letting the loop below run out
    // and have its very last pop raise the engine's own generic "needs 1
    // value" (issue #51, AC5 regression): that message names the wrong
    // need entirely, since what actually falls short is not one value but
    // however many of the n values below the count are still missing.
    // `needed`/`found` here, not the fallback message text (which
    // RpnStackUnderflowError.message only falls back to when either is
    // null; see that getter), are what the real, rendered message is
    // built from once `token` is also set.
    if (engine.depth < count) {
      throw RpnStackUnderflowError(
        'vector needs $count values below the count, found ${engine.depth}.',
        errorId: CalculatrixErrorId.stackUnderflow,
        token: 'vector',
        needed: count,
        found: engine.depth,
      );
    }

    final List<Matrix> valuesTopToBottom = <Matrix>[];
    for (int i = 0; i < count; i++) {
      final Matrix value = engine.popAny();
      _requireScalar(value, 'vector');
      valuesTopToBottom.add(value);
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

    // Exact only when every value is exact (runbook D49).
    final Iterable<Matrix> values = valuesTopToBottom.reversed;
    if (values.every((Matrix value) => value.isExact)) {
      engine.push(
        Matrix.exact(
          values
              .map((Matrix value) => <Rational>[value.exactAt(0, 0)])
              .toList(growable: false),
        ),
      );
      return;
    }
    engine.push(
      Matrix(
        values
            .map((Matrix value) => <double>[value.toApproximate().scalarValue])
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
    final Matrix value = engine.popAny();
    for (int r = 0; r < value.rowCount; r++) {
      engine.push(
        value.isExact
            ? Matrix.exact(<List<Rational>>[value.exactRows[r]])
            : Matrix(<List<double>>[List<double>.from(value.rows[r])]),
      );
    }
    engine.push(Matrix.exactScalar(Rational.fromInt(value.rowCount)));
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
    final Matrix b = engine.popAny();
    final Matrix a = engine.popAny();
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
    final Matrix b = engine.popAny();
    final Matrix a = engine.popAny();
    engine.push(a.appendRows(b));
  }
}

void _requireScalar(Matrix value, String word) {
  if (!value.isScalar) {
    throw MatrixDomainError(
      '$word requires a scalar operand, found a '
      '${value.rowCount}x${value.columnCount} matrix.',
      errorId: CalculatrixErrorId.typeMismatch,
    );
  }
}

/// The value of an exact scalar that is an integer, or null.
BigInt? _exactIntegerScalar(Matrix value) {
  if (!value.isExact || !value.isScalar) {
    return null;
  }
  final Rational entry = value.exactAt(0, 0);
  return entry.isInteger ? entry.numerator : null;
}

// Counts, sizes, stack levels and indexes are arguments, not values: they
// take an exact or approximate whole number alike and never make a result
// approximate (`~2 3 zeros` is exact zeros). Clamped to a bound no list
// can reach, so the conversion to int is safe and the range checks of each
// word still fail.
const int _largestArgument = 0x7fffffff;

int? _wholeArgument(Matrix value, String word) {
  _requireScalar(value, word);
  if (value.isExact) {
    final Rational entry = value.exactAt(0, 0);
    if (!entry.isInteger) {
      return null;
    }
    final BigInt bound = BigInt.from(_largestArgument);
    if (entry.numerator > bound) {
      return _largestArgument;
    }
    if (entry.numerator < -bound) {
      return -_largestArgument;
    }
    return entry.numerator.toInt();
  }
  final double raw = value.scalarValue;
  if (!raw.isFinite || raw != raw.truncateToDouble()) {
    return null;
  }
  return raw.clamp(-_largestArgument, _largestArgument).toInt();
}

String _argumentText(Matrix value) => value.isExact
    ? value.exactAt(0, 0).toDisplayString()
    : '~${value.scalarValue}';

int _requireNonNegativeIntegerCount(Matrix value, String word) {
  final int? whole = _wholeArgument(value, word);
  if (whole == null || whole < 0) {
    throw MatrixDomainError(
      '$word requires a non-negative integer count, found '
      '${_argumentText(value)}.',
      errorId: CalculatrixErrorId.typeMismatch,
    );
  }
  return whole;
}

/// Pops a 1-based index or stack level, rejecting a non-integer, negative
/// or zero value as type-mismatch (runbook D46, issue #39, AC3). Shared by
/// every word that takes a stack level (`pick`, `roll`) or a row/column
/// index (`delete-row`, `move-col`, ...), so the format check lives in one
/// place.
int _requirePositiveInteger(Matrix value, String word) {
  final int? whole = _wholeArgument(value, word);
  if (whole == null || whole < 1) {
    throw MatrixDomainError(
      '$word requires a positive integer index, found '
      '${_argumentText(value)}.',
      errorId: CalculatrixErrorId.typeMismatch,
    );
  }
  return whole;
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
    final Matrix value = engine.popAny();
    engine.push(value.isExact ? engine.exact.negate(value) : value.scale(-1));
  }
}

final class TransposeCommand extends CalculatrixCommand {
  const TransposeCommand();

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.popAny();
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
    final Matrix value = engine.popAny();
    engine.push(value.deleteRow(rowIndex));
  }
}

final class DeleteColumnCommand extends CalculatrixCommand {
  const DeleteColumnCommand(this.columnIndex);

  final int columnIndex;

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.popAny();
    engine.push(value.deleteColumn(columnIndex));
  }
}

final class DuplicateRowCommand extends CalculatrixCommand {
  const DuplicateRowCommand(this.rowIndex);

  final int rowIndex;

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.popAny();
    engine.push(value.duplicateRow(rowIndex));
  }
}

final class DuplicateColumnCommand extends CalculatrixCommand {
  const DuplicateColumnCommand(this.columnIndex);

  final int columnIndex;

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.popAny();
    engine.push(value.duplicateColumn(columnIndex));
  }
}

final class MoveRowCommand extends CalculatrixCommand {
  const MoveRowCommand(this.fromIndex, this.toIndex);

  final int fromIndex;
  final int toIndex;

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.popAny();
    engine.push(value.moveRow(fromIndex, toIndex));
  }
}

final class MoveColumnCommand extends CalculatrixCommand {
  const MoveColumnCommand(this.fromIndex, this.toIndex);

  final int fromIndex;
  final int toIndex;

  @override
  void executeOn(RpnEngine engine) {
    final Matrix value = engine.popAny();
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
    final int level = _requirePositiveInteger(engine.popAny(), 'pick');
    engine.pick(level);
  }
}

/// `n roll` (issue #39, S4d): the RPN word for `roll`, the stack-argument
/// counterpart of [RollCommand]. See [PickWordCommand].
final class RollWordCommand extends CalculatrixCommand {
  const RollWordCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int level = _requirePositiveInteger(engine.popAny(), 'roll');
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
      engine.popAny(),
      'zeros',
    );
    final int rowCount = _requireNonNegativeIntegerCount(
      engine.popAny(),
      'zeros',
    );
    engine.push(Matrix.exactFilled(rowCount, columnCount, Rational.zero));
  }
}

/// `r c ones` (issue #39, S4d): the stack-argument counterpart of
/// [PushOnesCommand]. See [ZerosCommand].
final class OnesCommand extends CalculatrixCommand {
  const OnesCommand();

  @override
  void executeOn(RpnEngine engine) {
    final int columnCount = _requireNonNegativeIntegerCount(
      engine.popAny(),
      'ones',
    );
    final int rowCount = _requireNonNegativeIntegerCount(
      engine.popAny(),
      'ones',
    );
    engine.push(Matrix.exactFilled(rowCount, columnCount, Rational.one));
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
    final int size = _requireNonNegativeIntegerCount(
      engine.popAny(),
      'identity',
    );
    if (size == 0) {
      throw MatrixShapeError(
        'identity requires a positive size, found 0.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
    engine.push(Matrix.exactIdentity(size));
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
    final int index1 = _requirePositiveInteger(engine.popAny(), 'delete-row');
    final Matrix value = engine.popAny();
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
    final int index1 = _requirePositiveInteger(engine.popAny(), 'delete-col');
    final Matrix value = engine.popAny();
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
    final int index1 = _requirePositiveInteger(
      engine.popAny(),
      'duplicate-row',
    );
    final Matrix value = engine.popAny();
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
    final int index1 = _requirePositiveInteger(
      engine.popAny(),
      'duplicate-col',
    );
    final Matrix value = engine.popAny();
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
    final int toIndex1 = _requirePositiveInteger(engine.popAny(), 'move-row');
    final int fromIndex1 = _requirePositiveInteger(engine.popAny(), 'move-row');
    final Matrix value = engine.popAny();
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
    final int toIndex1 = _requirePositiveInteger(engine.popAny(), 'move-col');
    final int fromIndex1 = _requirePositiveInteger(engine.popAny(), 'move-col');
    final Matrix value = engine.popAny();
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

/// `approx` (alias `num`): the value as an approximate one (runbook D52).
/// An approximate value is left unchanged.
final class ApproxCommand extends CalculatrixCommand {
  const ApproxCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.push(engine.popAny().toApproximate());
  }
}

/// `exact`: the value as an exact one, each entry the simplest rational
/// that rounds to the same `double` (runbook D52). An exact value is left
/// unchanged. The result is held to the digit limit (runbook D55).
final class ExactCommand extends CalculatrixCommand {
  const ExactCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.push(engine.exact.check(engine.popAny().toExact()));
  }
}
