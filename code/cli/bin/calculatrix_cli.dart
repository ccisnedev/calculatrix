import 'dart:io';

import 'package:calculatrix_cli/calculatrix_cli.dart';

/// The `calculatrix`/`cx` executable entry point.
///
/// Forces `POSIXLY_CORRECT` into the environment `cli_router` sees,
/// regardless of whether the real process environment set it, so this CLI's
/// option/operand ordering (G6) is strict POSIX (options before operands)
/// every time it runs, on every shell and every OS, rather than depending on
/// whichever value a caller's own environment happened to carry in. This is
/// a deliberate S2 reading of a spec that leaves POSIXLY_CORRECT's absence
/// to the platform's own default; see the PR's "Open points".
Future<void> main(List<String> args) async {
  final environment = {...Platform.environment, 'POSIXLY_CORRECT': '1'};
  final cli = buildCalculatrixCli();
  exitCode = await cli.run(args, environment: environment);
}
