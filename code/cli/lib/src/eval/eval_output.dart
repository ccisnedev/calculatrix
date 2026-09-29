import 'package:calculatrix/calculatrix.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'eval_support.dart';

/// The result of `eval rpn` or `eval infix`: a single [Matrix] on top of an
/// otherwise-empty stack (spec section 6). S2 only ever produces this one
/// result; a persistent multi-value stack is deferred to a later stage.
class EvalOutput extends Output {
  EvalOutput(this.result);

  final Matrix result;

  @override
  Map<String, dynamic> toJson() => {
    'stack': [matrixToJsonValue(result)],
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => '1: ${matrixToText(result)}';
}
