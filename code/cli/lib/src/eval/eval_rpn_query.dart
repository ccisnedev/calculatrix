import 'package:calculatrix/calculatrix.dart';
import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../stdin_reader.dart';
import 'eval_output.dart';
import 'eval_support.dart';

/// `cx eval rpn [<program>] [--file <path>] [--stdin]` (spec section 4).
class EvalRpnInput extends Input {
  EvalRpnInput({
    required this.program,
    required this.filePath,
    required this.readStdin,
  });

  factory EvalRpnInput.fromCliRequest(CliRequest req) => EvalRpnInput(
    program: req.param('program'),
    filePath: req.flagString('file'),
    readStdin: req.flagBool('stdin'),
  );

  final String? program;
  final String? filePath;
  final bool readStdin;

  @override
  Map<String, dynamic> toJson() => {
    if (program != null) 'program': program,
    if (filePath != null) 'file': filePath,
    if (readStdin) 'stdin': true,
  };
}

class EvalRpnQuery implements Query<EvalRpnInput, EvalOutput> {
  EvalRpnQuery(this.input, {required this.readStdin});

  @override
  final EvalRpnInput input;

  final StdinReader readStdin;

  @override
  String? validate() => null;

  @override
  Future<EvalOutput> execute() async {
    final program = resolveProgramSource(
      inline: input.program,
      filePath: input.filePath,
      readStdin: input.readStdin,
      stdinReader: readStdin,
    );
    try {
      final tokens = Calculatrix.tokenizeRpnLine(program);
      return EvalOutput(Calculatrix.evaluateRpnStack(tokens));
    } on CalculatrixError catch (error) {
      throw toCommandException(error);
    }
  }
}
