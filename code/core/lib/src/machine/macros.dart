import 'calculatrix_command.dart';
import 'calculatrix_machine.dart';
import 'calculatrix_macro.dart';
import 'commands.dart';

final class FillZerosLikeTopMacro implements CalculatrixMacro {
  const FillZerosLikeTopMacro();

  @override
  Iterable<CalculatrixCommand> expand(CalculatrixMachine machine) {
    final top = requireTopMatrix(machine, operation: 'FillZerosLikeTopMacro');
    return <CalculatrixCommand>[
      const DropCommand(),
      PushZerosCommand(top.rowCount, top.columnCount),
    ];
  }
}

final class FillOnesLikeTopMacro implements CalculatrixMacro {
  const FillOnesLikeTopMacro();

  @override
  Iterable<CalculatrixCommand> expand(CalculatrixMachine machine) {
    final top = requireTopMatrix(machine, operation: 'FillOnesLikeTopMacro');
    return <CalculatrixCommand>[
      const DropCommand(),
      PushOnesCommand(top.rowCount, top.columnCount),
    ];
  }
}

final class AppendZeroRowMacro implements CalculatrixMacro {
  const AppendZeroRowMacro();

  @override
  Iterable<CalculatrixCommand> expand(CalculatrixMachine machine) {
    final top = requireTopMatrix(machine, operation: 'AppendZeroRowMacro');
    return <CalculatrixCommand>[
      PushZerosCommand(1, top.columnCount),
      const AppendRowCommand(),
    ];
  }
}

final class AppendZeroColumnMacro implements CalculatrixMacro {
  const AppendZeroColumnMacro();

  @override
  Iterable<CalculatrixCommand> expand(CalculatrixMachine machine) {
    final top = requireTopMatrix(machine, operation: 'AppendZeroColumnMacro');
    return <CalculatrixCommand>[
      PushZerosCommand(top.rowCount, 1),
      const AppendColumnCommand(),
    ];
  }
}

final class CreateIdentityMacro implements CalculatrixMacro {
  const CreateIdentityMacro(this.size);

  final int size;

  @override
  Iterable<CalculatrixCommand> expand(CalculatrixMachine machine) {
    return <CalculatrixCommand>[PushIdentityCommand(size)];
  }
}