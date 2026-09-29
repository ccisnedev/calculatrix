/// Doubles for `cx`'s `upgrade`/`uninstall`/`doctor` tests: fakes for the
/// release lookup and the platform ops `InstallationPlugin` drives them
/// through, so no test in this project reaches the network, extracts a real
/// archive, or touches a real PATH.
///
/// Modeled on `modular_cli_sdk`'s own doubles
/// (`test/plugins/installation_doubles.dart`), reimplemented here rather
/// than imported: they live under that package's own `test/` directory,
/// which is not part of its public surface.
library;

import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

/// Serves canned releases, and counts how each lookup method was asked:
/// [latestRelease] (the no-`tagPrefix` path) and [listReleases] (the
/// `tagPrefix` path `cx` actually uses), so a test can assert which one was
/// called.
class FakeReleaseSource implements CliReleaseSource {
  FakeReleaseSource({this.releases = const [], this.error});

  final List<CliRelease> releases;
  final Object? error;

  int latestReleaseCalls = 0;
  int listReleasesCalls = 0;

  @override
  Future<CliRelease?> latestRelease(String repository) async {
    latestReleaseCalls++;
    if (error != null) throw error!;
    return releases.isEmpty ? null : releases.first;
  }

  @override
  Future<List<CliRelease>> listReleases(String repository) async {
    listReleasesCalls++;
    if (error != null) throw error!;
    return releases;
  }
}

/// A [PlatformOps] that records every call instead of touching a real
/// archive, environment, or child process.
class FakePlatformOps implements PlatformOps {
  FakePlatformOps({
    this.binaryName = 'cx',
    this.assetName = 'cx-linux-x64.tar.gz',
    this.fakeEnvValue,
    this.expandArchiveError,
    this.setEnvVariableError,
    this.scheduleDeletionError,
    this.runPostInstallError,
    this.postInstallResult,
  });

  @override
  final String binaryName;

  @override
  final String assetName;

  /// What [getEnvVariable] returns for every name, unless overridden by a
  /// specific entry in [envOverrides].
  final String? fakeEnvValue;

  /// Per-variable overrides for [getEnvVariable], checked before
  /// [fakeEnvValue].
  final Map<String, String> envOverrides = {};

  final Object? expandArchiveError;
  final Object? setEnvVariableError;
  final Object? scheduleDeletionError;
  final Object? runPostInstallError;
  final ProcessResult? postInstallResult;

  /// Every call this fake received, in order, as a human-readable line.
  final List<String> calls = [];

  @override
  Future<void> expandArchive(String archivePath, String destDir) async {
    calls.add('expandArchive($archivePath, $destDir)');
    if (expandArchiveError != null) throw expandArchiveError!;
  }

  @override
  String? getEnvVariable(String name) {
    calls.add('getEnvVariable($name)');
    return envOverrides[name] ?? fakeEnvValue;
  }

  @override
  Future<void> setEnvVariable(String name, String value) async {
    calls.add('setEnvVariable($name, $value)');
    if (setEnvVariableError != null) throw setEnvVariableError!;
  }

  @override
  Future<ProcessResult> runPostInstall(
    String installDir, {
    Duration? timeout,
  }) async {
    calls.add(
      timeout == null
          ? 'runPostInstall($installDir)'
          : 'runPostInstall($installDir, timeout: $timeout)',
    );
    if (runPostInstallError != null) throw runPostInstallError!;
    return postInstallResult ?? ProcessResult(0, 0, '', '');
  }

  @override
  Future<void> scheduleDeletion(String dir) async {
    calls.add('scheduleDeletion($dir)');
    if (scheduleDeletionError != null) throw scheduleDeletionError!;
  }
}
