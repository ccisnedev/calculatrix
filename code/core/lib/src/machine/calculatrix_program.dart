import 'calculatrix_command.dart';

final class CalculatrixProgram {
  CalculatrixProgram(Iterable<CalculatrixCommand> commands)
    : commands = List<CalculatrixCommand>.unmodifiable(commands);

  final List<CalculatrixCommand> commands;
}