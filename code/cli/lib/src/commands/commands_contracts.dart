import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'commands_support.dart';

/// The options, positionals and constraints of `cx commands show`,
/// `cx commands search` and `cx commands list` (spec section 7, "Finding a
/// command"; issue #41).
abstract final class CommandsContracts {
  /// `--category`, `list`'s only option: a closed list taken from the
  /// registry itself ([commandCategoryCliNames]), so an unknown value is
  /// rejected by the SDK as the usage error it is (exit 7), naming the
  /// valid ones, before `ListQuery` ever runs (AC3).
  static final CliParam category = CliParam.enumeration(
    'category',
    abbr: null,
    required: false,
    repeatable: false,
    values: commandCategoryCliNames,
    defaultValue: null,
    description: 'List only this category.',
  );

  /// `cx commands show <name>`.
  static final CliContract show = CliContract(
    positionals: [CliPositional.string('name', required: true)],
  );

  /// `cx commands search <text>`.
  static final CliContract search = CliContract(
    positionals: [CliPositional.string('text', required: true)],
  );

  /// `cx commands list [--category <name>]`.
  static final CliContract list = CliContract(options: [category]);
}
