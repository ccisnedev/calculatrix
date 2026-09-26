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

  // Every command runs through this single choke point, so this is where
  // atomicity is guaranteed structurally: snapshot the stack first, and if
  // the command throws for any reason, restore it exactly, so a partially
  // applied command (e.g. one that popped its operands before failing)
  // never leaves the stack changed. Individual commands and engine helpers
  // may still compute before popping as a cheap optimization, but they no
  // longer need to be individually correct for this guarantee to hold.
  void execute(CalculatrixCommand command) {
    final List<Matrix> snapshot = _engine.stack;
    try {
      command.executeOn(_engine);
    } catch (_) {
      _engine.restore(snapshot);
      rethrow;
    }
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