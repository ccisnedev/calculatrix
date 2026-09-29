// Tests for runbook stage S3 (docs/runbook-cli-stage-0.md, "Publishing
// (dogfood)"), covering the version/doctor/upgrade/uninstall rows of
// docs/spec/calculatrix_cli.md section 13 that calculatrix_cli_test.dart
// (stage S2) explicitly excludes.
//
// Open point 1: docs/spec/calculatrix_cli.md section 13 documents
// "cx upgrade --apply, no network -> release-lookup-failed, 1", but
// modular_cli_sdk 0.8.1's InstallationPlugin throws every release-lookup
// failure (installation_plugin.dart lines 549, 557, 570, 601) with
// `exitCode: ExitCode.apiError` (2), never `ExitCode.genericError` (1). This
// is a spec/SDK documentation mismatch, not a config gap: the tests below
// assert the SDK's actual, unmodified behavior (exit code 2). The spec
// table's "1" should be corrected in a documentation-only follow-up; see the
// PR body.
//
// Open point 2: the spec's section 13 row "cx --json version -> version as
// JSON, 0 (GNU order, G6 amended 2026-09-29)" does not hold against the
// pinned cli_router 0.2.1: `_readOption` (cli_router-0.2.1/lib/src/trie.dart
// line 990, `_peekIsLiteralChild`) refuses to read *any* option, global or
// not, whenever the very next token could still continue the route (here,
// 'version' is a literal child of the root the option precedes); it reports
// `misplacedOption` instead of reading the option, exactly as it does for a
// route-specific option before its own route ("cx -f prog.rpn eval rpn",
// same table, "permutation never crosses a route boundary"). GNU
// permutation itself (`_normalizeForPermute`) never repairs this either: it
// only reorders tokens that follow an already-consumed run of literal route
// words, and no route word is consumed yet when the option is the very
// first token. So `cx --json version` is `misplaced-option`, exit 7,
// unconditionally, with or without `POSIXLY_CORRECT` -- not only under it,
// as the spec's row implies. This reproduces on every root-level route,
// version included, and predates this stage's own changes; it is not a
// `CliInstallationConfig` gap and is flagged here, not worked around.
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

    test('cx --json version is misplaced-option, exit 7 (open point 2: the '
        'spec table says 0, GNU order; the pinned cli_router 0.2.1 never '
        'permutes an option that precedes the very first route word, global '
        'or not)', () async {
      final code = await run(['--json', 'version']);
      expect(code, ExitCode.validationFailed);
      expect(err.output, contains('misplaced-option'));
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
          releases: [_release('cli-v0.8.0', asset: _platformAsset)],
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
          releases: [_release('cli-v0.8.0', asset: _platformAsset)],
        ),
      );

      expect(code, ExitCode.configError);
      expect(err.output, contains('error'));
    });

    test('the release lookup ignores the app\'s vX.Y.Z tags and picks the '
        'newest cli-v* one', () async {
      // A repository with both an app release (v9.9.9, deliberately a
      // "newer"-looking number) and this CLI's own cli-v0.8.1: only the
      // second is a candidate (runbook D31, "3. releases/latest is
      // ambiguous").
      final releaseSource = FakeReleaseSource(
        releases: [
          _release('v9.9.9', asset: 'Calculatrix-windows-x64.zip'),
          _release('cli-v0.8.1', asset: _platformAsset),
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
      // 0.8.1 is newer than cxVersion (0.8.0): a real newer cli-v release
      // was found and reported as a warning, not silently ignored as
      // "up to date" (which would mean v9.9.9 leaked into the comparison).
      expect(release['status'], 'warning');
      expect(release['detail'], contains('0.8.1'));
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

      // Open point above: the spec table says exit code 1; the SDK's own
      // InstallationPlugin (0.8.1) uses ExitCode.apiError (2) for every
      // release-lookup-failed, so 2 is what this asserts.
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
