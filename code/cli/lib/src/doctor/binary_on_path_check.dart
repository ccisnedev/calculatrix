import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

/// Looks up [executable] on `PATH` and returns the full path to the first
/// match, or null when none is found.
///
/// A plain, direct-filesystem lookup: no shelling out to `where`/`which`, so
/// it behaves the same on every platform this CLI ships for and needs no
/// child process. [environment] defaults to the real process environment
/// ([Platform.environment]); a test overrides it, the same seam
/// `bin/cx.dart` leaves for `cli_router`'s own `POSIXLY_CORRECT` read (see
/// that file's doc comment). [fileExists] defaults to a real filesystem
/// check; a test overrides it too, so no test needs a real file on disk.
typedef PathLookup = String? Function(String executable);

String? resolveOnPath(
  String executable, {
  Map<String, String>? environment,
  bool Function(String path)? fileExists,
}) {
  final env = environment ?? Platform.environment;
  final exists = fileExists ?? (path) => File(path).existsSync();
  final pathValue = env['PATH'] ?? '';
  if (pathValue.isEmpty) return null;

  final separator = Platform.isWindows ? ';' : ':';
  final names = Platform.isWindows
      ? _windowsExecutableNames(executable, env)
      : [executable];

  for (final dir in pathValue.split(separator)) {
    if (dir.isEmpty) continue;
    for (final name in names) {
      final candidate = p.join(dir, name);
      if (exists(candidate)) return candidate;
    }
  }
  return null;
}

/// Windows resolves a bare command name against `PATHEXT`
/// (`.COM;.EXE;.BAT;.CMD;...` by default), not `.exe` alone: this matches
/// what a real command prompt does when a user types `cx`, rather than
/// hard-coding the one extension this CLI happens to ship with today.
List<String> _windowsExecutableNames(
  String executable,
  Map<String, String> env,
) {
  if (p.extension(executable).isNotEmpty) return [executable];
  final pathExt = env['PATHEXT'] ?? '.EXE;.CMD;.BAT;.COM';
  return [
    for (final ext in pathExt.split(';'))
      if (ext.isNotEmpty) '$executable$ext',
  ];
}

/// Contributes the "binary on `PATH`" check that
/// `docs/spec/calculatrix_cli.md` section 5 and runbook D31 require for `cx
/// doctor`, and that `InstallationPlugin` no longer provides: its own doc
/// comment (`installation_plugin.dart`) records that the `binary` and
/// `alias` checks it used to contribute were removed before
/// `modular_cli_sdk` 0.8.0 shipped, since neither macss nor inquiry checked
/// its own binary is reachable (both assume `doctor` running at all proves
/// it). `cx` still wants the check (D31, amended 2026-09-29 to drop only the
/// alias half, since `cx` has no alias, D40), so it contributes its own,
/// exactly as spec section 8.7 anticipates: "A CLI can contribute its own
/// checks to `doctor.checks` from a plugin of its own."
///
/// Requires `modular_cli.doctor`, exactly as `InstallationPlugin` does, so
/// `DoctorPlugin` has already declared the extension point this plugin
/// contributes to by the time this one runs.
class BinaryOnPathDoctorPlugin implements CliPlugin {
  BinaryOnPathDoctorPlugin({required this.executable, PathLookup? pathLookup})
    : _pathLookup = pathLookup ?? resolveOnPath;

  final String executable;
  final PathLookup _pathLookup;

  @override
  CliPluginManifest get manifest => CliPluginManifest(
    id: 'calculatrix.doctor.path',
    displayName: 'Binary on PATH',
    version: '1.0.0',
    hostApiVersion: '^$cliPluginHostApiVersion',
    requires: const ['modular_cli.doctor'],
  );

  @override
  void setup(CliPluginHost host) {
    host.contribute<CliDoctorCheck>(
      DoctorPlugin.extensionPoint,
      CliDoctorCheck(name: 'path', run: _check),
    );
  }

  Future<CliCheckResult> _check() async {
    final found = _pathLookup(executable) != null;
    return found
        ? CliCheckResult(
            status: CliCheckStatus.ok,
            message: '$executable found on PATH',
          )
        : CliCheckResult(
            status: CliCheckStatus.error,
            message: '$executable not found on PATH',
          );
  }
}
