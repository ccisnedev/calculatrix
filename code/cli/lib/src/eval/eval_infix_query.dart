import 'package:calculatrix/calculatrix.dart';
import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../stdin_reader.dart';
import 'eval_output.dart';
import 'eval_support.dart';

/// `cx eval infix [<expression>] [--file <path>] [--stdin]` (spec section 4).
class EvalInfixInput extends Input {
  EvalInfixInput({
    required this.expression,
    required this.filePath,
    required this.readStdin,
  });

  factory EvalInfixInput.fromCliRequest(CliRequest req) => EvalInfixInput(
    expression: req.param('expression'),
    filePath: req.flagString('file'),
    readStdin: req.flagBool('stdin'),
  );

  final String? expression;
  final String? filePath;
  final bool readStdin;

  @override
  Map<String, dynamic> toJson() => {
    if (expression != null) 'expression': expression,
    if (filePath != null) 'file': filePath,
    if (readStdin) 'stdin': true,
  };
}

class EvalInfixQuery implements Query<EvalInfixInput, EvalOutput> {
  EvalInfixQuery(this.input, {required this.readStdin});

  @override
  final EvalInfixInput input;

  final StdinReader readStdin;

  @override
  String? validate() => null;

  @override
  Future<EvalOutput> execute() async {
    final expression = resolveProgramSource(
      inline: input.expression,
      filePath: input.filePath,
      readStdin: input.readStdin,
      stdinReader: readStdin,
    );
    try {
      final result = Calculatrix.evaluateInfix(expression);
      return EvalOutput(result);
    } on CalculatrixError catch (error) {
      throw toCommandException(error);
    }
  }
}
