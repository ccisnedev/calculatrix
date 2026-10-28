# ADR 0002: Versioning and Changelog Policy

**Status:** Accepted

## Context

Calculatrix is a monorepo with several publishable packages:

- `code/core`: the engine, published Dart package (`calculatrix`)
- `code/cli`: the command line `cx` (`calculatrix_cli`)
- `code/app`: the Flutter calculator (`calculatrix_app`)

More will follow (editor tooling, agent integrations, engine bindings in
other languages). Each one is released on its own schedule, through its own
channels, to its own users. We need a policy that says how each package is
versioned, how releases are tagged, and where changes are recorded.

## Decision

### 1. Each publishable package has its own version

Every package versions itself under SemVer, independently of the others.

- A change bumps only the packages it changes. No package bumps to keep
  numbers cosmetically aligned with another.
- Before a package reaches `1.0.0`, a breaking change may advance its minor
  version (`0.N.0`) instead of its major one.
- After a package reaches `1.0.0`, a breaking change of its contract requires
  a major bump, a backward-compatible feature a minor bump, and a
  backward-compatible fix a patch bump.
- The Flutter app keeps an independent build suffix `+N` for store
  distribution; its visible version is `X.Y.Z`.
- Roadmap stages are not tied to version numbers.

### 2. One shared version only for the same package in several languages

When the same package is implemented in several languages (for example the
engine bindings for different host languages), all implementations of that
package carry the same version, so a version number names one contract.

### 3. Dependencies declare the versions they support

A package that depends on another declares the compatible range.

- During local monorepo development, `path: ../core` remains acceptable.
- At release time, the released package must state which versions of its
  dependencies it was built and tested with.

### 4. Changelog ownership is split by audience

- `code/core/CHANGELOG.md` records changes relevant to `package:calculatrix`
  users.
- The root `CHANGELOG.md` records releases of the CLI and the app, grouped by
  package.
- Each release entry names the package and version it belongs to.

### 5. Git tags mark every public release

*Amended 2026-09-23.* The original rule kept the `0.x` line tag-free until
`v1.0.0`. Public distribution made that rule obsolete: the Android and Windows
release workflows run on `release: published` and name their artifacts from
the release tag, and `v0.7.1` was already tagged and published on GitHub.

- Every release published to a public channel (GitHub Releases, Google Play,
  Microsoft Store, `winget`, the web deployment) gets a git tag on the exact
  revision that was built.
- The tag uses the visible version `X.Y.Z`. The Flutter build suffix `+N`
  stays in `pubspec.yaml` and in the store metadata, not in the tag.
- Tags of published releases are immutable: never move or delete them. A fix
  ships as the next patch version.
- Internal milestones that are not published may stay untagged.

*Amended 2026-09-29.* Several packages are released from this one repository
and share its tag namespace, so each package has its own tag prefix:

- `vX.Y.Z` is reserved for app releases (Android, Windows, the web
  deployment).
- `cli-vX.Y.Z` marks a CLI release, using the version from
  `code/cli/pubspec.yaml`, on the exact revision
  `.github/workflows/cli-release.yml` built it from.
- Without a prefix, `GET /repos/{owner}/{repo}/releases/latest` would resolve
  to whichever kind happens to be newest, which is exactly the ambiguity
  `cx upgrade` and the `install.ps1`/`install.sh` installers avoid by listing
  releases and filtering by tag prefix instead of ever calling that endpoint.
- A `cli-v*` release is never marked "latest" on GitHub (`gh release edit
  --latest=false`), since GitHub tracks only one latest release per
  repository and that designation is meant for the app.
- A new package released from this repository gets its own prefix before its
  first release.

## Consequences

- Each package moves at its own pace; a CLI fix does not force a core or app
  release.
- A version number always identifies one package's contract, and only the
  implementations of the same package in several languages share one.
- Users find a package's history in the changelog that serves them.
- Every published revision is tagged under its package's prefix, and tags
  never move.

## Follow-up Guidance

- Keep `code/core/CHANGELOG.md` in sync with package-facing releases.
- Keep the root `CHANGELOG.md` in sync with CLI and app releases.
- Use `docs/release-checklist.md` for release execution.
- If the repository adopts more CI release automation, encode this ADR's rules
  in the workflow rather than relying on convention alone.
