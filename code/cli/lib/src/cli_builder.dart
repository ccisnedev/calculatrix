import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'banner/banner_query.dart';
import 'eval/eval_contracts.dart';
import 'eval/eval_infix_query.dart';
import 'eval/eval_output.dart';
import 'eval/eval_rpn_query.dart';
import 'stdin_reader.dart';

/// Builds the `calculatrix`/`cx` CLI (spec section 4, runbook stage S2):
/// the bare banner, `eval rpn`, `eval infix`, and the `cx <program>` RPN
/// shortcut (G3). [readStdin] is the only injection seam a test needs: the
/// real process's standard input has no clean fake, so production code
/// reaches it only through this one indirection (see [StdinReader]).
ModularCli buildCalculatrixCli({StdinReader readStdin = readAllStdin}) {
  final cli = ModularCli(
    name: 'calculatrix',
    version: '0.8.0',
    suggestionDistance: 2,
  );

  cli.query<BannerInput, BannerOutput>(
    '',
    (req) => BannerQuery(BannerInput.fromCliRequest(req)),
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
