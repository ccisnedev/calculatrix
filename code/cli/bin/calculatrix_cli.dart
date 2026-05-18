import 'dart:io';

import 'package:calculatrix/calculatrix.dart';

void main(List<String> args) {
  if (args.isEmpty || args.first == '--help' || args.first == '-h') {
    _printUsage();
    return;
  }

  final String mode = args.first.toLowerCase();

  try {
    switch (mode) {
      case 'infix':
        if (args.length < 2) {
          throw const FormatException('Missing infix expression.');
        }
        final String expression = args.sublist(1).join(' ');
        final Matrix infixResult = Calculatrix.evaluateInfix(expression);
        print(MatrixDisplayFormatter.compact(infixResult));
      case 'rpn':
        if (args.length < 2) {
          throw const FormatException('Missing RPN tokens.');
        }
        final List<String> rpnTokens = args.sublist(1);
        final Matrix rpnResult = Calculatrix.evaluateRpn(rpnTokens);
        print(MatrixDisplayFormatter.compact(rpnResult));
      case 'command':
        if (args.length < 2) {
          throw const FormatException('Missing command sequence.');
        }
        final CalculatrixMachine machine = CalculatrixMachine();
        _executeCommandSequence(machine, args.sublist(1));
        print(_formatCommandResults(machine));
      case 'macro':
        if (args.length < 2) {
          throw const FormatException('Missing macro workflow.');
        }
        final CalculatrixMachine machine = CalculatrixMachine();
        _executeMacroWorkflow(machine, args.sublist(1));
        print(MatrixDisplayFormatter.compact(_singleResult(machine)));
      default:
        throw FormatException('Unknown command: $mode');
    }
  } on CalculatrixError catch (error) {
    print(error);
    exitCode = 1;
  } on FormatException catch (error) {
    print('CLI error: ${error.message}');
    _printUsage();
    exitCode = 64;
  }
}

void _printUsage() {
  print('calculatrix_cli usage:');
  print('  dart run bin/calculatrix_cli.dart infix "3 + 4 * 5"');
  print('  dart run bin/calculatrix_cli.dart rpn 3 4 + 5 *');
  print('  dart run bin/calculatrix_cli.dart command 3 4 add');
  print('  dart run bin/calculatrix_cli.dart macro append-zero-row [[1,2],[3,4]]');
}

void _executeCommandSequence(
  CalculatrixMachine machine,
  List<String> tokens,
) {
  for (final String rawToken in tokens) {
    final String token = rawToken.trim();
    if (token.isEmpty) {
      continue;
    }

    final String normalized = token.toLowerCase();
    switch (normalized) {
      case 'add':
        machine.execute(const AddCommand());
      case 'subtract':
      case 'sub':
        machine.execute(const SubtractCommand());
      case 'multiply':
      case 'mul':
        machine.execute(const MultiplyCommand());
      case 'divide':
      case 'div':
        machine.execute(const DivideCommand());
      case 'sqrt':
        machine.execute(const SqrtCommand());
      case 'percent':
        machine.execute(const PercentCommand());
      case 'negate':
      case 'neg':
        machine.execute(const NegateCommand());
      case 'transpose':
        machine.execute(const TransposeCommand());
      case 'inverse':
        machine.execute(const InverseCommand());
      case 'determinant':
      case 'det':
        machine.execute(const DeterminantCommand());
      case 'eigenvalues':
      case 'eig':
        machine.execute(const EigenvaluesCommand());
      case 'diagonalization':
      case 'diag':
        machine.execute(const DiagonalizationCommand());
      case 'trace':
      case 'tr':
        machine.execute(const TraceCommand());
      case 'norm':
        machine.execute(const NormCommand());
      case 'rank':
        machine.execute(const RankCommand());
      case 'lu':
        machine.execute(const LuDecompositionCommand());
      case 'qr':
        machine.execute(const QrDecompositionCommand());
      case 'append-row':
        machine.execute(const AppendRowCommand());
      case 'append-column':
        machine.execute(const AppendColumnCommand());
      case 'dup':
        machine.execute(const DupCommand());
      case 'drop':
        machine.execute(const DropCommand());
      case 'swap':
        machine.execute(const SwapCommand());
      case 'over':
        machine.execute(const OverCommand());
      case 'rot':
        machine.execute(const RotCommand());
      default:
        if (_tryExecuteParameterizedCommand(machine, normalized)) {
          continue;
        }

        machine.execute(PushMatrixCommand(_parseOperandLiteral(token)));
    }
  }
}

bool _tryExecuteParameterizedCommand(
  CalculatrixMachine machine,
  String token,
) {
  if (token.startsWith('pick:')) {
    machine.execute(PickCommand(_parseSingleIntArgument(token, prefix: 'pick:')));
    return true;
  }

  if (token.startsWith('roll:')) {
    machine.execute(RollCommand(_parseSingleIntArgument(token, prefix: 'roll:')));
    return true;
  }

  if (token.startsWith('identity:')) {
    machine.execute(
      PushIdentityCommand(_parseSingleIntArgument(token, prefix: 'identity:')),
    );
    return true;
  }

  if (token.startsWith('zeros:')) {
    final (int rows, int columns) = _parseShapeArgument(
      token,
      prefix: 'zeros:',
    );
    machine.execute(PushZerosCommand(rows, columns));
    return true;
  }

  if (token.startsWith('ones:')) {
    final (int rows, int columns) = _parseShapeArgument(
      token,
      prefix: 'ones:',
    );
    machine.execute(PushOnesCommand(rows, columns));
    return true;
  }

  if (token.startsWith('delete-row:')) {
    machine.execute(
      DeleteRowCommand(_parseSingleIntArgument(token, prefix: 'delete-row:')),
    );
    return true;
  }

  if (token.startsWith('delete-column:')) {
    machine.execute(
      DeleteColumnCommand(
        _parseSingleIntArgument(token, prefix: 'delete-column:'),
      ),
    );
    return true;
  }

  if (token.startsWith('duplicate-row:')) {
    machine.execute(
      DuplicateRowCommand(
        _parseSingleIntArgument(token, prefix: 'duplicate-row:'),
      ),
    );
    return true;
  }

  if (token.startsWith('duplicate-column:')) {
    machine.execute(
      DuplicateColumnCommand(
        _parseSingleIntArgument(token, prefix: 'duplicate-column:'),
      ),
    );
    return true;
  }

  if (token.startsWith('move-row:')) {
    final (int fromIndex, int toIndex) = _parsePairArgument(
      token,
      prefix: 'move-row:',
    );
    machine.execute(MoveRowCommand(fromIndex, toIndex));
    return true;
  }

  if (token.startsWith('move-column:')) {
    final (int fromIndex, int toIndex) = _parsePairArgument(
      token,
      prefix: 'move-column:',
    );
    machine.execute(MoveColumnCommand(fromIndex, toIndex));
    return true;
  }

  return false;
}

void _executeMacroWorkflow(
  CalculatrixMachine machine,
  List<String> args,
) {
  final String macro = args.first.toLowerCase();

  switch (macro) {
    case 'identity':
      if (args.length != 2) {
        throw const FormatException('macro identity requires a size argument.');
      }
      machine.executeMacro(CreateIdentityMacro(int.parse(args[1])));
    case 'zeros-like':
      if (args.length != 2) {
        throw const FormatException('macro zeros-like requires one matrix operand.');
      }
      machine.execute(PushMatrixCommand(_parseOperandLiteral(args[1])));
      machine.executeMacro(const FillZerosLikeTopMacro());
    case 'ones-like':
      if (args.length != 2) {
        throw const FormatException('macro ones-like requires one matrix operand.');
      }
      machine.execute(PushMatrixCommand(_parseOperandLiteral(args[1])));
      machine.executeMacro(const FillOnesLikeTopMacro());
    case 'append-zero-row':
      if (args.length != 2) {
        throw const FormatException('macro append-zero-row requires one matrix operand.');
      }
      machine.execute(PushMatrixCommand(_parseOperandLiteral(args[1])));
      machine.executeMacro(const AppendZeroRowMacro());
    case 'append-zero-column':
      if (args.length != 2) {
        throw const FormatException('macro append-zero-column requires one matrix operand.');
      }
      machine.execute(PushMatrixCommand(_parseOperandLiteral(args[1])));
      machine.executeMacro(const AppendZeroColumnMacro());
    default:
      throw FormatException('Unknown macro workflow: ${args.first}');
  }
}

Matrix _singleResult(CalculatrixMachine machine) {
  final Matrix? top = machine.top;
  if (machine.depth != 1 || top == null) {
    throw FormatException(
      'Command workflow must leave a single matrix result, found ${machine.depth}.',
    );
  }

  return top;
}

String _formatCommandResults(CalculatrixMachine machine) {
  final Matrix? top = machine.top;
  if (machine.depth == 1 && top != null) {
    return MatrixDisplayFormatter.compact(top);
  }

  if (machine.depth == 0) {
    throw const FormatException('Command workflow did not leave any results.');
  }

  final List<Matrix> stack = machine.stackSnapshot.reversed.toList(growable: false);
  return List<String>.generate(
    stack.length,
    (int index) => 'X$index: ${MatrixDisplayFormatter.compact(stack[index])}',
    growable: false,
  ).join('\n');
}

Matrix _parseOperandLiteral(String token) {
  return Calculatrix.evaluateInfix(token);
}

int _parseSingleIntArgument(String token, {required String prefix}) {
  final String value = token.substring(prefix.length);
  return int.parse(value);
}

(int, int) _parseShapeArgument(String token, {required String prefix}) {
  final String value = token.substring(prefix.length);
  final List<String> parts = value.split('x');
  if (parts.length != 2) {
    throw FormatException('Invalid shape argument: $token');
  }

  return (int.parse(parts[0]), int.parse(parts[1]));
}

(int, int) _parsePairArgument(String token, {required String prefix}) {
  final String value = token.substring(prefix.length);
  final List<String> parts = value.split(':');
  if (parts.length != 2) {
    throw FormatException('Invalid pair argument: $token');
  }

  return (int.parse(parts[0]), int.parse(parts[1]));
}
