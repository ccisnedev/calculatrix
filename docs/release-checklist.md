# Release Checklist

Checklist for coordinated Calculatrix releases under ADR 0002.

## 1. Scope

- [ ] Confirm release scope: coordinated product release, core-only, app-only, or CLI-only.
- [ ] Confirm whether version synchronization is mandatory for this release.
- [ ] Confirm the target version fits the active pre-`1.0.0` scheme (`0.N.P` slices, `0.N.0` stage closures).

## 2. Versioning

- [ ] Set `code/core/pubspec.yaml` to the canonical release version `X.Y.Z`.
- [ ] For coordinated releases, set `code/cli/pubspec.yaml` to the same `X.Y.Z`.
- [ ] For coordinated releases, set `code/app/pubspec.yaml` to `X.Y.Z+N`.
- [ ] Verify app, CLI, and core visible versions match when the release is coordinated.
- [ ] If this closes a roadmap stage before `1.0.0`, use the next stable `0.N.0` version.
- [ ] Do not create or retain git release tags for internal `0.x` releases.

## 3. Changelogs

- [ ] Update the root `CHANGELOG.md` with repository-facing release notes.
- [ ] Update `code/core/CHANGELOG.md` with package-facing release notes when core semantics change.
- [ ] Make release scope explicit in the changelog entry: core-only, coordinated, app-only, or CLI-only.

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