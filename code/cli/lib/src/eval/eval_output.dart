import 'package:calculatrix/calculatrix.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'eval_support.dart';

/// The result of `eval rpn` or `eval infix`: the stack the program leaves,
/// bottom to top (spec section 6, runbook D47). `eval rpn` keeps every
/// level; `eval infix` always leaves exactly one. Each level says whether
/// its value is exact (runbook D54).
class EvalOutput extends Output {
  EvalOutput(this.stack);

  /// Bottom to top: the last element is level 1.
  final List<Matrix> stack;

  /// Every level, highest first, level 1 last: the order the text prints.
  List<({int level, Matrix value})> get _levels => [
    for (var index = 0; index < stack.length; index++)
      (level: stack.length - index, value: stack[index]),
  ];

  @override
  Map<String, dynamic> toJson() => {
    'stack': [
      for (final entry in _levels)
        {
          'level': entry.level,
          'exact': entry.value.isExact,
          'value': matrixToJsonValue(entry.value),
        },
    ],
  };

  @override
  int get exitCode => ExitCode.ok;

  /// One HP 50g style line per level, level 1 at the bottom. An empty stack
  /// is an empty text: the SDK still ends it with a newline.
  @override
  String? toText() => [
    for (final entry in _levels) '${entry.level}: ${matrixToText(entry.value)}',
  ].join('\n');
}
