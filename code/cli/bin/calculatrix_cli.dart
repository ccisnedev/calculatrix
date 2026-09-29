import 'dart:io';

import 'package:calculatrix_cli/calculatrix_cli.dart';

/// The `calculatrix`/`cx` executable entry point.
///
/// User decision (2026-09-29): `cx` follows GNU `getopt`-style option
/// ordering by default (an option may follow an operand; `cli_router`
/// permutes it in front before the strict grammar runs), like macss,
/// inquiry and skillwire. This entry point passes no `environment` to
/// [ModularCli.run], so `cli_router` reads `POSIXLY_CORRECT` straight from
/// the real process environment (`Platform.environment`, the SDK's own
/// default when the parameter is omitted): unset, GNU order applies; set to
/// any value, strict POSIX order applies instead. Amends the previous S2
/// reading, which forced `POSIXLY_CORRECT` unconditionally; see G6 in
/// docs/spec/calculatrix_cli.md and D27 in docs/runbook-cli-stage-0.md.
Future<void> main(List<String> args) async {
  final cli = buildCalculatrixCli();
  exitCode = await cli.run(args);
}
