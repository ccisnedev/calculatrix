import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'banner/banner_query.dart';
import 'eval/eval_contracts.dart';
import 'eval/eval_infix_query.dart';
import 'eval/eval_output.dart';
import 'eval/eval_rpn_query.dart';
import 'stdin_reader.dart';

/// Builds the `cx` CLI (spec section 4, runbook stage S2): the bare banner,
/// `eval rpn`, `eval infix`, and the `cx <program>` RPN shortcut (G3).
/// [readStdin] is the only injection seam a test needs: the real process's
/// standard input has no clean fake, so production code reaches it only
/// through this one indirection (see [StdinReader]).
///
/// User decision (2026-09-29, issue #22): the executable is named `cx`,
/// with no alias of any kind. A `.cmd`/`.bat` alias shim runs through
/// cmd.exe, which consumes `^` while parsing the command line before the
/// shim body ever runs, so it silently mangled `cx eval infix '2^0.5'`.
/// Naming the program itself `cx` means the shell that invokes it passes
/// its argv straight through, with nothing in between.
ModularCli buildCalculatrixCli({StdinReader readStdin = readAllStdin}) {
  final cli = ModularCli(name: 'cx', version: '0.8.0', suggestionDistance: 2);

  cli.query<BannerInput, BannerOutput>(
    '',
    // The version and the registered-command names are read off [cli]
    // itself at call time, once every module below has been registered
    // (issue #26 scope 4 and 5): this is the CLI's own record of what it
    // serves, not a separate list to keep in sync by hand.
    (req) => BannerQuery(
      BannerInput.fromCliRequest(req),
      version: cli.hostMetadata?.version,
      registeredCommands: cli.catalog.commands.map((c) => c.name).toSet(),
    ),
    globals: true,
    contract: CliContract.none,
    description: 'Print a short banner.',
  );

  cli.module('eval', (m) {
    m.query<EvalRpnInput, EvalOutput>(
      'rpn [<program>]',
      (req) =>
          EvalRpnQuery(EvalRpnInput.fromCliRequest(req), readStdin: readStdin),
      globals: true,
      contract: EvalContracts.rpn,
      description: 'Evaluate an RPN program.',
    );

    m.query<EvalInfixInput, EvalOutput>(
      'infix [<expression>]',
      (req) => EvalInfixQuery(
        EvalInfixInput.fromCliRequest(req),
        readStdin: readStdin,
      ),
      globals: true,
      contract: EvalContracts.infix,
      description: 'Evaluate an infix expression.',
    );
  });

  cli.shortcut(
    '<program>',
    target: 'eval rpn',
    globals: false,
    contract: CliContract.none,
    description: 'Shortcut for "eval rpn <program>".',
  );

  return cli;
}
