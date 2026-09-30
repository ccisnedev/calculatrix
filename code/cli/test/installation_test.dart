// Tests for runbook stage S3 (docs/runbook-cli-stage-0.md, "Publishing
// (dogfood)"), covering the version/doctor/upgrade/uninstall rows of
// docs/spec/calculatrix_cli.md section 13 that calculatrix_cli_test.dart
// (stage S2) explicitly excludes.
//
// A failed release lookup exits 2 (`ExitCode.apiError`, what
// InstallationPlugin throws), as docs/spec/calculatrix_cli.md section 6
// and section 13 record since the 2026-09-29 amendment.
//
// Open point: the spec's section 13 row "cx --json version -> version as
// JSON, 0 (GNU order, G6 amended 2026-09-29)" does not hold against the
// pinned cli_router 0.2.1, which rejects any option before the first route
// word as misplaced-option, exit 7, with or without POSIXLY_CORRECT. The
// test for that row asserts the spec and is skipped until
// ccisnedev/cli_router#10 is fixed; nothing here works around it.
//
// No test here calls `cx upgrade --apply`/`cx uninstall --apply` down a path
// that would let `ReplaceInstallation` actually run: doing so through the
// real `InstallationPlugin` wiring (as opposed to constructing
// `UpgradeCommand` directly, which the SDK's own test suite does) has no
// seam for `ReplaceInstallation.runningExecutable`, which defaults to
// `Platform.resolvedExecutable` -- the real `dart` process running this
// test suite. `cx upgrade --apply` is exercised only on paths that fail (or
// are refused) before any step performs, which is exactly what the
// "no network" and the "needs --plan or --apply" rows call for.
// `cx uninstall --apply` never touches `Platform.resolvedExecutable` at all
// (`UninstallCommand.steps` only calls `PlatformOps`), so it is exercised in
// full through `FakePlatformOps`.
import 'dart:convert';
import 'dart:io';

import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:calculatrix_cli/src/cli_builder.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import 'support/installation_doubles.dart';
import 'support/memory_sink.dart';

/// The asset name `cx`'s own [cxAssets] map configures for whichever
/// platform this suite actually runs on, kept in sync with
/// `modular_cli_sdk`'s own test suite's `_platformAsset`
/// (`test/plugins/installation_plugin_test.dart`).
final String _platformAsset = cxAssets[Platform.operatingSystem]!;

void main() {
  late MemorySink out;
  late MemorySink err;

  setUp(() {
    out = MemorySink();
    err = MemorySink();
  });

  Future<int> run(
    List<String> args, {
    CliReleaseSource? releaseSource,
    PlatformOps? platformOps,
    PathLookup? pathLookup,
  }) {
    final cli = buildCalculatrixCli(
      releaseSource: releaseSource,
      platformOps: platformOps,
      pathLookup: pathLookup,
    );
    return cli.run(args, stdout: out, stderr: err);
  }

  group('version (VersionPlugin, spec 8.7)', () {
    test('cx version prints the name and version, exit 0', () async {
      final code = await run(['version']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('cx'));
      expect(out.output, contains(cxVersion));
    });

    test('cx version --json prints version as JSON, exit 0', () async {
      final code = await run(['version', '--json']);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      expect(decoded['name'], 'cx');
      expect(decoded['version'], cxVersion);
    });

    test(
      'cx --json version prints version as JSON, exit 0 (spec section 13, '
      'GNU order)',
      () async {
        final code = await run(['--json', 'version']);
        expect(code, ExitCode.ok);
        final decoded = jsonDecode(out.output) as Map<String, dynamic>;
        expect(decoded['name'], 'cx');
        expect(decoded['version'], cxVersion);
      },
      skip:
          'Blocked on ccisnedev/cli_router#10: 0.2.1 rejects a global option '
          'before the first route word as misplaced-option, exit 7.',
    );

    test('cx version junk is extra-argument, exit 64', () async {
      final code = await run(['version', 'junk']);
      expect(code, ExitCode.invalidUsage);
      expect(err.output, contains('extra-argument'));
    });

    test('cx --json=garbage version is rejected, exit 7', () async {
      final code = await run(['--json=garbage', 'version']);
      expect(code, ExitCode.validationFailed);
    });

    test('the CLI and VersionPlugin agree on cxVersion at build time', () {
      // buildCalculatrixCli() itself must not throw PLUGIN_VERSION_MISMATCH:
      // ModularCli(version: cxVersion) and VersionPlugin(version: cxVersion)
      // are given the same constant.
      expect(buildCalculatrixCli, returnsNormally);
    });
  });

  group('doctor (DoctorPlugin, InstallationPlugin, D31)', () {
    test('all checks ok: exit 0, both "path" and "release" reported', () async {
      final code = await run(
        ['doctor', '--json'],
        pathLookup: (executable) => '/usr/local/bin/$executable',
        releaseSource: FakeReleaseSource(
          releases: [_release('cli-v$cxVersion', asset: _platformAsset)],
        ),
      );

      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final checks = (decoded['checks'] as List).cast<Map<String, dynamic>>();
      expect(checks.map((c) => c['name']), containsAll(['path', 'release']));
      expect(checks.every((c) => c['status'] == 'ok'), isTrue);
    });

    test('a newer cli-v* release is a warning, not an error: exit 0', () async {
      final code = await run(
        ['doctor'],
        pathLookup: (executable) => '/usr/local/bin/$executable',
        releaseSource: FakeReleaseSource(
          releases: [_release('cli-v9.9.9', asset: _platformAsset)],
        ),
      );

      expect(code, ExitCode.ok);
      expect(out.output, contains('warning'));
    });

    test('no network on the release lookup is a warning: exit 0', () async {
      final code = await run(
        ['doctor'],
        pathLookup: (executable) => '/usr/local/bin/$executable',
        releaseSource: FakeReleaseSource(
          error: const CliReleaseLookupFailure('no network'),
        ),
      );

      expect(code, ExitCode.ok);
      expect(out.output, contains('warning'));
    });

    test('cx not found on PATH is an error: exit 78 (D31, D40)', () async {
      final code = await run(
        ['doctor'],
        pathLookup: (executable) => null,
        releaseSource: FakeReleaseSource(
          releases: [_release('cli-v$cxVersion', asset: _platformAsset)],
        ),
      );

      expect(code, ExitCode.configError);
      expect(err.output, contains('error'));
    });

    test('the release lookup ignores the app\'s vX.Y.Z tags and picks the '
        'newest cli-v* one', () async {
      // A repository with both an app release (v9.9.9, deliberately a
      // "newer"-looking number) and this CLI's own cli-v1.0.0: only the
      // second is a candidate (runbook D31, "3. releases/latest is
      // ambiguous").
      final releaseSource = FakeReleaseSource(
        releases: [
          _release('v9.9.9', asset: 'Calculatrix-windows-x64.zip'),
          _release('cli-v1.0.0', asset: _platformAsset),
        ],
      );

      final code = await run(
        ['doctor', '--json'],
        pathLookup: (executable) => '/usr/local/bin/$executable',
        releaseSource: releaseSource,
      );

      expect(code, ExitCode.ok);
      expect(releaseSource.listReleasesCalls, greaterThan(0));
      expect(releaseSource.latestReleaseCalls, 0);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final checks = (decoded['checks'] as List).cast<Map<String, dynamic>>();
      final release = checks.singleWhere((c) => c['name'] == 'release');
      // 1.0.0 is newer than cxVersion: a real newer cli-v release
      // was found and reported as a warning, not silently ignored as
      // "up to date" (which would mean v9.9.9 leaked into the comparison).
      expect(release['status'], 'warning');
      expect(release['detail'], contains('1.0.0'));
      expect(release['detail'], isNot(contains('9.9.9')));
    });
  });

  group('upgrade (InstallationPlugin, D26)', () {
    test('cx upgrade alone needs --plan or --apply: exit 7', () async {
      final code = await run(
        ['upgrade'],
        releaseSource: FakeReleaseSource(),
        platformOps: FakePlatformOps(assetName: _platformAsset),
      );
      expect(code, ExitCode.validationFailed);
    });

    test(
      'cx upgrade --plan shows the steps and changes nothing: exit 0',
      () async {
        final platformOps = FakePlatformOps(assetName: _platformAsset);
        final code = await run(
          ['upgrade', '--plan'],
          releaseSource: FakeReleaseSource(
            releases: [_release('cli-v9.9.9', asset: _platformAsset)],
          ),
          platformOps: platformOps,
        );

        expect(code, ExitCode.ok);
        // Nothing performed: a plan only previews steps() but never calls
        // perform() on any of them.
        expect(platformOps.calls, isEmpty);
      },
    );

    test('cx upgrade --apply with no network fails release-lookup-failed, '
        'nothing changed', () async {
      final platformOps = FakePlatformOps(assetName: _platformAsset);
      final code = await run(
        ['upgrade', '--apply', '--autoapprove'],
        releaseSource: FakeReleaseSource(
          error: const CliReleaseLookupFailure('no network'),
        ),
        platformOps: platformOps,
      );

      // Spec section 13: release-lookup-failed, 2.
      expect(code, ExitCode.apiError);
      expect(err.output, contains('release-lookup-failed'));
      expect(platformOps.calls, isEmpty);
    });
  });

  group('uninstall (InstallationPlugin, D26)', () {
    test('cx uninstall --apply removes the CLI: exit 0', () async {
      final platformOps = FakePlatformOps(assetName: _platformAsset);
      final code = await run([
        'uninstall',
        '--apply',
        '--autoapprove',
      ], platformOps: platformOps);

      expect(code, ExitCode.ok);
      expect(platformOps.calls, contains(startsWith('scheduleDeletion(')));
    });
  });
}

CliRelease _release(String tag, {required String asset}) => CliRelease(
  tagName: tag,
  assets: [CliReleaseAsset(name: asset, downloadUrl: 'https://dl/$asset')],
);
