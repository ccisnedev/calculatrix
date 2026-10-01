import 'package:calculatrix/calculatrix.dart';
import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../stdin_reader.dart';
import 'eval_contracts.dart';
import 'eval_output.dart';
import 'eval_support.dart';

/// `cx eval infix [<expression>] [--file <path>] [--stdin]` (spec section 4).
class EvalInfixInput extends Input {
  EvalInfixInput({
    required this.expression,
    required this.filePath,
    required this.readStdin,
    this.maxDigits,
  });

  factory EvalInfixInput.fromCliRequest(CliRequest req) => EvalInfixInput(
    expression: req.param('expression'),
    filePath: req.flagString('file'),
    readStdin: req.flagBool('stdin'),
    maxDigits: req.flagInt('max-digits'),
  );

  final String? expression;
  final String? filePath;
  final bool readStdin;

  /// `--max-digits`, or null for the default of runbook D55.
  final int? maxDigits;

  @override
  Map<String, dynamic> toJson() => {
    if (expression != null) 'expression': expression,
    if (filePath != null) 'file': filePath,
    if (readStdin) 'stdin': true,
    if (maxDigits != null) 'max-digits': maxDigits,
  };
}

class EvalInfixQuery implements Query<EvalInfixInput, EvalOutput> {
  EvalInfixQuery(this.input, {required this.readStdin});

  @override
  final EvalInfixInput input;

  final StdinReader readStdin;

  @override
  String? validate() => validateMaxDigits(input.maxDigits);

  @override
  Future<EvalOutput> execute() async {
    final expression = resolveProgramSource(
      inline: input.expression,
      filePath: input.filePath,
      readStdin: input.readStdin,
      stdinReader: readStdin,
    );
    try {
      return EvalOutput([
        Calculatrix.evaluateInfix(
          expression,
          maxDigits: input.maxDigits ?? ExactArithmetic.defaultMaxDigits,
        ),
      ]);
    } on CalculatrixError catch (error) {
      throw toCommandException(
        error,
        approximateHint: (error) => infixApproximateHint(expression, error),
      );
    }
  }
}
