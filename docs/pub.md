# Public distribution

Updated: 2026-10-28. The earlier step-by-step plan was mostly done or
obsolete and was cut down to what is true now and what is still to do. The
releases themselves are described by the workflows in `.github/workflows/`
and by [release-checklist.md](release-checklist.md); each package versions
and releases on its own ([ADR 0002](adr/0002-versioning-and-changelog-policy.md)).

## Channels

| Channel | State | How |
|---|---|---|
| Web, https://calculatrix.ccisne.dev | Live | `pages-release.yml` on every push to `main`; also serves `install.ps1` and `install.sh` for `cx`. |
| `cx` (Windows, Linux) | Released as `cli-vX.Y.Z` | `cli-release.yml` when `code/cli/pubspec.yaml` changes on `main`. |
| App for Windows | Built per `vX.Y.Z` release | `windows-release.yml`: Inno Setup installer, portable zip, `SHA256SUMS.txt`. Not Authenticode-signed. |
| App for Android | Signed `.aab` built per `vX.Y.Z` release | `android-release.yml`; see [android-release-signing.md](android-release-signing.md). Signing secrets are configured in the repository. Not yet on Google Play. |
| winget | Not published | A manifest (`release/winget/manifests/c/CcisneDev/Calculatrix/0.7.1`, installer type Inno Setup, requires `Microsoft.VCRedist.2015+.x64`) was submitted in microsoft/winget-pkgs#381654, which was closed without merging. |
| pub.dev | Published 0.0.1 only (publisher `ccisne.dev`) | The core is `calculatrix` (`code/core`, now 0.8.0); `cx` is `publish_to: none`. Releasing it follows the checklist (`dart pub publish --dry-run`). |

## Identity

- Publisher `ccisne.dev`; Android `applicationId` `dev.ccisne.calculatrix`;
  winget identifier `CcisneDev.Calculatrix`; executable `Calculatrix.exe`.
- Privacy policy: https://ccisne.dev/legal/calculatrix/privacy/.
- License: MIT, [../LICENSE](../LICENSE).

## Still to do

- Google Play: create the app in Play Console, complete the listing, Data
  safety and App content declarations, upload a signed `.aab`.
- winget: find out why the submission was closed and resubmit for a current
  app version.
- Windows: sign the installer (Authenticode) if wanted; Microsoft Store is a
  later option.
- Confirm that HTTPS is enforced for calculatrix.ccisne.dev in the repository
  Pages settings.
- One release process that builds web, Windows and Android from one revision
  (today each workflow runs on its own trigger).

## Constraints worth remembering

- The `github-pages` environment only deploys from `main`, so the Pages
  workflow must not run on tag events.
- App workflows run only for `v*` tags; `cli-v*` releases are excluded so
  they do not trigger app builds.
- Never use `releases/latest` to find a CLI release: app releases share the
  repository. `cli-release.yml` publishes with `--latest=false`.
- Platform requirements (Play target API, Data safety, winget manifest
  schema) change; read the current official pages before each submission:
  - GitHub Pages: https://docs.github.com/en/pages
  - winget: https://learn.microsoft.com/en-us/windows/package-manager/package/
  - Google Play: https://support.google.com/googleplay/android-developer
  - Windows installer choice: [research/winget-installer-format-2026.md](research/winget-installer-format-2026.md)
