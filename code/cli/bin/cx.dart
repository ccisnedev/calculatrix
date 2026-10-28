import 'dart:io';

import 'package:calculatrix_cli/calculatrix_cli.dart';

/// The `cx` executable entry point.
///
/// The executable is named `cx`, with no `calculatrix` executable and no
/// alias of any kind: a `.cmd`/`.bat` shim runs through cmd.exe, which
/// consumes `^` while parsing the command line before the shim body ever
/// runs.
///
/// Options may follow operands (GNU `getopt` order): `cli_router` moves them
/// in front before the strict grammar runs. This entry point passes no
/// `environment` to [ModularCli.run], so `cli_router` reads `POSIXLY_CORRECT`
/// from the real process environment: unset, GNU order applies; set to any
/// value, strict POSIX order applies instead (options must precede operands).
Future<void> main(List<String> args) async {
  exitCode = await runCalculatrixCli(args);
}
