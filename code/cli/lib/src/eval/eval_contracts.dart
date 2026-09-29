import 'package:modular_cli_sdk/modular_cli_sdk.dart';

/// The options and constraints shared by `cx eval rpn` and `cx eval infix`
/// (spec section 4 and section 5): exactly one program source, from an
/// inline positional, `--file`/`-f`, or `--stdin` (G1).
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

  /// `cx eval rpn [options] [<program>]`.
  static final CliContract rpn = CliContract(
    options: [file, stdin],
    positionals: [CliPositional.string('program', required: false)],
    constraints: const [
      ExactlyOne(['program', 'file', 'stdin']),
    ],
  );

  /// `cx eval infix [options] [<expression>]`.
  static final CliContract infix = CliContract(
    options: [file, stdin],
    positionals: [CliPositional.string('expression', required: false)],
    constraints: const [
      ExactlyOne(['expression', 'file', 'stdin']),
    ],
  );
}
