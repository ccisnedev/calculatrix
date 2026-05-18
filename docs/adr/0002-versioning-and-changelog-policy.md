# ADR 0002: Versioning and Changelog Policy

**Status:** Accepted

## Context

Calculatrix is a multi-target repository with one semantic core and multiple
consumer shells:

- `code/core`: published Dart package (`calculatrix`)
- `code/cli`: internal CLI consumer (`calculatrix_cli`)
- `code/app`: internal Flutter consumer (`calculatrix_app`)

The core package is the reusable computation engine and the semantic source of
truth for matrix operations, infix evaluation, RPN behavior, numeric policy,
and public error taxonomy.

The repository currently has divergent component versions. That is not
necessarily wrong, but without an explicit policy it creates ambiguity about:

- which version is authoritative for release communication,
- when all targets must move together,
- how app and CLI versions relate to the core package,
- where changes should be recorded for users versus package consumers.

We need a versioning policy that matches good monorepo practice while keeping
the published core package usable on its own.

## Decision

### 1. The core version is the authoritative product version

`calculatrix` in `code/core` is the canonical semantic version for the project.

- Public compatibility decisions are anchored to the core package.
- Until the first public `1.0.0` product release, coordinated stage milestones
  use the pre-`1.0.0` line: each stage closes on a stable `0.N.0` release.
- Before `1.0.0`, incompatible architectural resets may advance to the next
  stable `0.N.0` stage release instead of introducing artificial `1.x`, `2.x`,
  or `3.x` lines.
- After the first public `1.0.0`, breaking API or semantic changes in the core
  require a SemVer-major bump.
- Backward-compatible feature additions in the core require a SemVer-minor bump.
- Backward-compatible fixes in the core require a SemVer-patch bump.
- Until `1.0.0`, the repository may rewrite internal prerelease history,
  documentation, and local tags to keep the `0.x` line coherent.

When the repository communicates a coordinated release, the release number is
the core version.

### 2. App and CLI follow the core on coordinated releases

For repository releases that ship the whole product experience together, the
CLI and app should align their visible version with the core version.

- `code/cli/pubspec.yaml` should use the same `X.Y.Z` as the core for a
  coordinated release.
- `code/app/pubspec.yaml` should use the same visible `X.Y.Z`, while keeping an
  independent Flutter build suffix `+N`.

Example for the current pre-`1.0.0` line:

- Core: `0.4.0`
- CLI: `0.4.0`
- App: `0.4.0+8`

This preserves a single external release number while still allowing platform
build iteration for the app.

### 3. Shell-only changes do not force a core version bump

Changes limited to the app or CLI do not require bumping the published core
package if the core package API and semantics are unchanged.

Examples:

- App-only layout polish
- Accessibility fixes in the Flutter shell
- CLI help text or argument UX improvements
- Packaging/build metadata changes

In those cases:

- the affected shell may bump independently if needed,
- the root changelog must record the release scope clearly,
- the core version must not change just to keep numbers cosmetically aligned.

### 4. Coordinated stage completions should use synchronized visible versions

When a roadmap stage is treated as a repository-wide release milestone, all
three components should be brought to the same visible version before release
completion.

Before the first public `1.0.0`, this means each completed stage lands on a
stable `0.N.0` release with synchronized visible versions across core, CLI,
and app.

### 5. Changelog ownership is split by audience

Calculatrix will maintain two changelog layers:

- Repository changelog at the repo root for the whole product release history
- Package changelog in `code/core/CHANGELOG.md` for the published Dart package

The repository changelog is for users of the complete system.

- It records coordinated releases and important shell-only releases.
- Entries should be grouped by component when helpful: Core, App, CLI, Docs, QA.

The core package changelog is for package consumers.

- It records only changes relevant to `package:calculatrix` users.
- App-only and CLI-only changes should not be added there unless they affect the
  public package contract.

### 6. Dependency intent must remain explicit

The CLI and app must declare their dependency on the core in a way that makes
the supported relationship visible.

- During local monorepo development, `path: ../core` remains acceptable.
- At release time, the coordinated version in each shell must match the core
  version it is intended to ship with.
- If the repository later publishes the CLI or app independently, they should
  also declare an explicit compatible core range.

### 7. Release notes should describe scope precisely

Each release entry should make clear whether it is:

- a core release,
- a coordinated product release,
- an app-only release,
- or a CLI-only release.

Release communication must avoid implying a new core semantic contract when the
change only affects a consumer shell.

### 8. Git tags start at the first public 1.0.0 release

Pre-`1.0.0` coordinated milestones should not create or preserve git release
tags.

- The repository may keep the `0.x` line tag-free while scope, numbering, and
  historical grouping are still being refined.
- If prerelease tags become misleading after history cleanup, delete them
  instead of treating them as immutable release markers.
- Begin git release tags with the first public `v1.0.0` release and continue
  from there under normal SemVer expectations.

## Consequences

- The project gets one authoritative release number without forcing fake core
  bumps for shell-only changes.
- Coordinated milestones remain easy to communicate because app, CLI, and core
  can share the same visible version when released together.
- The pre-`1.0.0` line stays clean: stage closures advance through `0.N.0`
  instead of implying already-public major lines.
- The Flutter app keeps a proper independent build suffix for store/distribution
  needs.
- The root changelog and core changelog serve different audiences cleanly.
- Future automation can validate that stage-closing releases keep app/CLI/core
  versions synchronized when required.
- Release discipline becomes stricter: every release must declare its scope,
  update the appropriate changelog(s), and avoid premature git tags.

## Follow-up Guidance

- Keep `code/core/CHANGELOG.md` in sync with package-facing releases.
- Keep the root `CHANGELOG.md` in sync with coordinated repository releases.
- Use `docs/release-checklist.md` for release execution and automation targets.
- Do not create repository release tags before the first public `v1.0.0`.
- If the repository adopts CI release automation, encode this ADR's rules in the
  workflow rather than relying on convention alone.