import '../matrix/matrix.dart';
import '../rpn/rpn_engine.dart';
import 'calculatrix_command.dart';
import 'calculatrix_macro.dart';
import 'calculatrix_program.dart';

final class CalculatrixMachine {
  CalculatrixMachine({RpnEngine? engine}) : _engine = engine ?? RpnEngine();

  final RpnEngine _engine;

  int get depth => _engine.depth;

  Matrix? get top {
    if (_engine.depth == 0) {
      return null;
    }

    return _engine.stack.last;
  }

  List<Matrix> get stackSnapshot => _engine.stack;

  void clear() {
    _engine.clear();
  }

  void execute(CalculatrixCommand command) {
    command.executeOn(_engine);
  }

  void executeAll(Iterable<CalculatrixCommand> commands) {
    for (final CalculatrixCommand command in commands) {
      execute(command);
    }
  }

  void executeProgram(CalculatrixProgram program) {
    executeAll(program.commands);
  }

  void executeMacro(CalculatrixMacro macro) {
    executeAll(macro.expand(this));
  }
}