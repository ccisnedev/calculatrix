import 'package:calculatrix/calculatrix.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

/// Exactly one program source: the positional [name], `--file` or `--stdin`.
/// The SDK's `ExactlyOne` words every field as an option (`--program`), which
/// does not exist; this names the positional as `<name>`.
class ExactlyOneSource extends CliConstraint {
  const ExactlyOneSource(this.name);

  final String name;

  List<String> get _fields => [name, 'file', 'stdin'];

  @override
  String? check(Set<String> present) {
    final given = _fields.where(present.contains).toList();
    if (given.length == 1) return null;
    String label(String f) => f == name ? '<$name>' : '--$f';
    final choices = '<$name>, --file or --stdin';
    return given.isEmpty
        ? 'Give exactly one program source: $choices'
        : 'Give exactly one program source: $choices, '
              'got ${given.map(label).join(', ')}';
  }

  @override
  Map<String, dynamic> toJson() => {'kind': 'exactlyOne', 'fields': _fields};
}

/// The options and constraints shared by `cx eval rpn` and `cx eval infix`: exactly one program source, from an
/// inline positional, `--file`/`-f`, or `--stdin`, and the digit
/// limit of exact results, `--max-digits`.
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

  /// The digit limit: the most digits an exact numerator or
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
      ExactlyOneSource('program'),
    ],
  );

  /// `cx eval infix [options] [<expression>]`.
  static final CliContract infix = CliContract(
    options: [file, stdin, maxDigits],
    positionals: [CliPositional.string('expression', required: false)],
    constraints: const [
      ExactlyOneSource('expression'),
    ],
  );
}

/// Why the `--max-digits` value is not a limit, for [Query.validate], or
/// null when it is one: the limit counts digits, so it starts at 1.
String? validateMaxDigits(int? maxDigits) => maxDigits != null && maxDigits < 1
    ? '--max-digits must be at least 1, found $maxDigits'
    : null;
