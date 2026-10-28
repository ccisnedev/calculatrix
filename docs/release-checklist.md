# Release Checklist

Checklist for Calculatrix releases under ADR 0002. Each publishable package
is released on its own.

## 1. Scope

- [ ] Name the package being released (core, CLI, app) and its new version.
- [ ] Choose the bump from the change to that package's contract (SemVer; before `1.0.0` a breaking change may bump the minor version).

## 2. Versioning

- [ ] Set the version in that package's `pubspec.yaml` (`X.Y.Z`; the app adds `+N`).
- [ ] If the package depends on another package of this repository, confirm the dependency range it was built and tested with.
- [ ] Tag the published revision with the package's prefix (`vX.Y.Z` app, `cli-vX.Y.Z` CLI) and never move a published tag.

## 3. Changelogs

- [ ] Update `code/core/CHANGELOG.md` for a core release.
- [ ] Update the root `CHANGELOG.md` for a CLI or app release.
- [ ] Name the package and version in the changelog entry.

## 4. Static Validation

- [ ] Run `dart analyze` in `code/core`.
- [ ] Run `dart analyze` in `code/cli`.
- [ ] Run `dart analyze` in `code/app`.

## 5. Automated Tests

- [ ] Run `dart test` in `code/core`.
- [ ] Run `dart test` in `code/cli`.
- [ ] Run `flutter test` in `code/app`.
- [ ] Run `flutter test integration_test/calculator_test.dart -d <android-emulator>` in `code/app` when Android support is available.

## 6. Packaging Checks

- [ ] Run `dart pub publish --dry-run` in `code/core` when preparing a package release.
- [ ] Run `flutter build apk --debug` or the target packaging command in `code/app` when Android artifacts matter for the release.

## 7. Manual Gate

- [ ] Complete manual user validation before declaring the release closed.
- [ ] Record any deferred manual findings before starting the next roadmap stage.

## 8. Commit and Automation

- [ ] Commit version, changelog, docs, and validation-related changes together.
- [ ] Keep Android wrapper files versioned and local machine files untracked.
- [ ] Move repetitive checklist items into CI or release scripts when stable.
- [ ] If obsolete prerelease tags exist locally after a history cleanup, delete them before closing the release work.