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

final class DupCommand extends CalculatrixCommand {
  const DupCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.dup();
  }
}

final class DropCommand extends CalculatrixCommand {
  const DropCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.drop();
  }
}

final class SwapCommand extends CalculatrixCommand {
  const SwapCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.swap();
  }
}

final class OverCommand extends CalculatrixCommand {
  const OverCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.over();
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

final class RotCommand extends CalculatrixCommand {
  const RotCommand();

  @override
  void executeOn(RpnEngine engine) {
    engine.rot();
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