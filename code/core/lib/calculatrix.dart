/// Matrix-first computation engine for calculator products.
///
/// All values are immutable [Matrix] instances (scalars are 1×1).
/// Evaluation is available via infix, RPN, stack machine commands, or
/// interactive session.
library calculatrix;

export 'src/errors/errors.dart';
export 'src/evaluation/calculatrix.dart';
export 'src/machine/calculatrix_command.dart';
export 'src/machine/calculatrix_machine.dart';
export 'src/machine/calculatrix_macro.dart';
export 'src/machine/calculatrix_program.dart';
export 'src/machine/commands.dart';
export 'src/machine/macros.dart';
export 'src/matrix/matrix.dart';
export 'src/matrix/matrix_display_formatter.dart';
export 'src/numeric/numeric_policy.dart';
export 'src/rpn/rpn_engine.dart';
export 'src/session/calculatrix_session.dart';
