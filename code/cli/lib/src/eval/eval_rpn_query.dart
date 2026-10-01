import 'package:calculatrix/calculatrix.dart';
import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../stdin_reader.dart';
import 'eval_contracts.dart';
import 'eval_output.dart';
import 'eval_support.dart';

/// `cx eval rpn [<program>] [--file <path>] [--stdin]` (spec section 4).
class EvalRpnInput extends Input {
  EvalRpnInput({
    required this.program,
    required this.filePath,
    required this.readStdin,
    this.maxDigits,
  });

  factory EvalRpnInput.fromCliRequest(CliRequest req) => EvalRpnInput(
    program: req.param('program'),
    filePath: req.flagString('file'),
    readStdin: req.flagBool('stdin'),
    maxDigits: req.flagInt('max-digits'),
  );

  final String? program;
  final String? filePath;
  final bool readStdin;

  /// `--max-digits`, or null for the default of runbook D55.
  final int? maxDigits;

  @override
  Map<String, dynamic> toJson() => {
    if (program != null) 'program': program,
    if (filePath != null) 'file': filePath,
    if (readStdin) 'stdin': true,
    if (maxDigits != null) 'max-digits': maxDigits,
  };
}

class EvalRpnQuery implements Query<EvalRpnInput, EvalOutput> {
  EvalRpnQuery(this.input, {required this.readStdin});

  @override
  final EvalRpnInput input;

  final StdinReader readStdin;

  @override
  String? validate() => validateMaxDigits(input.maxDigits);

  @override
  Future<EvalOutput> execute() async {
    final program = resolveProgramSource(
      inline: input.program,
      filePath: input.filePath,
      readStdin: input.readStdin,
      stdinReader: readStdin,
    );
    final tokens = Calculatrix.tokenizeRpnLine(program);
    try {
      return EvalOutput(
        Calculatrix.evaluateRpnStack(
          tokens,
          maxDigits: input.maxDigits ?? ExactArithmetic.defaultMaxDigits,
        ),
      );
    } on CalculatrixError catch (error) {
      throw toCommandException(
        error,
        approximateHint: (error) => rpnApproximateHint(tokens, error),
      );
    }
  }
}
