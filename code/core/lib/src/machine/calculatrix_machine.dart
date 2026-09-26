import '../matrix/matrix.dart';
import '../rpn/rpn_engine.dart';
import 'calculatrix_command.dart';
import 'calculatrix_macro.dart';
import 'calculatrix_program.dart';

final class CalculatrixMachine {
  CalculatrixMachine({RpnEngine? engine}) : _engine = engine ?? RpnEngine();

  final RpnEngine _engine;

  int _mutationCount = 0;

  int get depth => _engine.depth;

  // Counts every command that has run through execute() without throwing.
  // A command either fully applies or fully rolls itself back (see the
  // comment on execute() below), so this is an exact proxy for "did the
  // stack's content change", unlike depth: a macro can mutate a matrix in
  // place without changing the number of elements on the stack (e.g.
  // negating the top), so a before/after depth comparison alone can miss a
  // real mutation that happened before a later command in the same macro
  // failed.
  int get mutationCount => _mutationCount;

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
    _mutationCount++;
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