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

/// Contributes the `cx doctor` check that the `cx` binary is on `PATH`.
/// `modular_cli_sdk`'s `InstallationPlugin` does not provide it, so `cx`
/// contributes its own through `doctor.checks`.
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
