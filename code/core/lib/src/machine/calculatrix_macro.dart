import '../errors/errors.dart';
import '../matrix/matrix.dart';
import 'calculatrix_command.dart';
import 'calculatrix_machine.dart';

abstract interface class CalculatrixMacro {
  Iterable<CalculatrixCommand> expand(CalculatrixMachine machine);
}

Matrix requireTopMatrix(CalculatrixMachine machine, {required String operation}) {
  final Matrix? top = machine.top;
  if (top == null) {
    throw RpnStackUnderflowError('$operation requires at least one matrix.');
  }

  return top;
}