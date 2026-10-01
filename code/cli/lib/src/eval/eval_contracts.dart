import 'package:calculatrix/calculatrix.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

/// The options and constraints shared by `cx eval rpn` and `cx eval infix`
/// (spec section 4 and section 5): exactly one program source, from an
/// inline positional, `--file`/`-f`, or `--stdin` (G1), and the digit
/// limit of exact results, `--max-digits` (runbook D55).
abstract final class EvalContracts {
  static final CliParam file = CliParam.path(
    'file',
    abbr: 'f',
    required: false,
    repeatable: false,
    mustExist: true,
    defaultValue: null,
    description: 'Read the program from this file.',
  );

  static final CliParam stdin = CliParam.flag(
    'stdin',
    abbr: null,
    repeatable: false,
    description: 'Read the program from standard input.',
  );

  /// The digit limit of runbook D55: the most digits an exact numerator or
  /// denominator may have. Shared with the `cx <program>` shortcut.
  static final CliParam maxDigits = CliParam.integer(
    'max-digits',
    abbr: null,
    required: false,
    repeatable: false,
    defaultValue: null,
    description:
        'Most digits an exact number may have '
        '(default ${ExactArithmetic.defaultMaxDigits}).',
  );

  /// `cx eval rpn [options] [<program>]`.
  static final CliContract rpn = CliContract(
    options: [file, stdin, maxDigits],
    positionals: [CliPositional.string('program', required: false)],
    constraints: const [
      ExactlyOne(['program', 'file', 'stdin']),
    ],
  );

  /// `cx eval infix [options] [<expression>]`.
  static final CliContract infix = CliContract(
    options: [file, stdin, maxDigits],
    positionals: [CliPositional.string('expression', required: false)],
    constraints: const [
      ExactlyOne(['expression', 'file', 'stdin']),
    ],
  );
}

/// Why the `--max-digits` value is not a limit, for [Query.validate], or
/// null when it is one: the limit counts digits, so it starts at 1.
String? validateMaxDigits(int? maxDigits) => maxDigits != null && maxDigits < 1
    ? '--max-digits must be at least 1, found $maxDigits'
    : null;
