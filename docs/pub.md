# Public Distribution Operational Plan

Updated: 2026-05-30

This document turns the source-backed publication checklist into the execution plan for the current release line. Official platform requirements are kept separate from repo-owned tasks and local completion checks.

## Release line strategy

- Active public web baseline: `v0.7.1`
- If GitHub Pages publication needs repo-side changes, ship them as follow-up `v0.7.x` patches before store publication work starts
- Current channel order for the current line:

1. GitHub Pages at calculatrix.ccisne.dev
2. winget
3. Google Play

- Longer-term Windows distribution still includes Microsoft Store once signed packaging identity is ready

## Local repo snapshot

- [x] A GitHub Pages workflow already exists in [../.github/workflows/pages-release.yml](../.github/workflows/pages-release.yml).
- [ ] No file named CNAME was found in the repo.
  - Note: GitHub states that when publishing with a custom GitHub Actions workflow, a CNAME file is not required and any existing CNAME file is ignored. [G2]
- [x] A shared publisher legal site now exists at `https://ccisne.dev/legal/` in [ccisnedev/legal](https://github.com/ccisnedev/legal), with the canonical Calculatrix privacy policy published at `https://ccisne.dev/legal/calculatrix/privacy/`.
- [ ] Android still uses a placeholder package identity and debug signing in [../code/app/android/app/build.gradle.kts](../code/app/android/app/build.gradle.kts).
- [x] Windows runner metadata now uses the chosen public identity in [../code/app/windows/runner/Runner.rc](../code/app/windows/runner/Runner.rc): `CompanyName=ccisne.dev`, `ProductName=Calculatrix`, and `OriginalFilename=Calculatrix.exe`.
- [ ] Only one license file was found locally: [../code/core/LICENSE](../code/core/LICENSE).
- [x] The canonical legal pages are served from `https://ccisne.dev/legal/`, including the live Calculatrix privacy policy at `https://ccisne.dev/legal/calculatrix/privacy/`.
- [ ] No Windows installer packaging files were found locally for .msix, .appx, .appinstaller, .msi, .iss, or .wxs.

## Phase 1 - GitHub Pages / calculatrix.ccisne.dev

Status: first active publication block

Outcome:

- Publish the current web build from the `v0.7.1` line at `calculatrix.ccisne.dev`
- If Pages-specific fixes are needed, keep them on `v0.7.x` until the web site is live

### Official platform requirements

- [x] Enable GitHub Pages publication from a custom GitHub Actions workflow in the repository settings. [G1]
- [x] Add calculatrix.ccisne.dev as the custom domain in Settings > Pages. [G2]
- [x] Configure DNS for the chosen domain. [G2]
  - Apex domain: use ALIAS, ANAME, or A records; AAAA is optional. [G2]
  - Subdomain: use a CNAME pointing to USERNAME.github.io or ORGANIZATION.github.io. [G2]
- [x] Verify the domain in GitHub Pages using the TXT challenge and keep the TXT record in DNS. [G3]
- [ ] Enable Enforce HTTPS once GitHub makes it available for the domain. [G2]
  - Current blocker: the GitHub Pages API currently returns `The certificate does not exist yet` when attempting to enable HTTPS enforcement for `calculatrix.ccisne.dev`.
- [ ] Do not use wildcard DNS records for the Pages domain. GitHub documents takeover risk. [G2][G3]

### Repo-owned execution tasks

- [x] Keep the current custom Pages workflow in [../.github/workflows/pages-release.yml](../.github/workflows/pages-release.yml) as the publication path; the first manual deployment completed successfully without a repo-side workflow gap. [G1]
- [x] Restrict Pages automation to `push` on `main` and `workflow_dispatch`.
  - Root cause: the `github-pages` environment allows deployments only from `main`, while `release` workflows execute on the tag ref (for example `v0.7.1`) and therefore fail before the deploy step starts.
- [x] Publish the canonical Calculatrix privacy policy URL at `https://ccisne.dev/legal/calculatrix/privacy/` on the shared publisher legal site. This satisfies the stable public privacy-policy URL requirement independently of the app domain. [P6]
- [x] A repo-side Pages gap was exposed during the first release-triggered deployment and fixed in `v0.7.1` follow-up work by moving the workflow trigger to `push` on `main`.

### Operational completion checks

- [x] A GitHub Pages deployment from Actions completes successfully
- [ ] `calculatrix.ccisne.dev` resolves over HTTPS to the published site
- [x] The domain remains verified in GitHub
  - Current state: `http://calculatrix.ccisne.dev/` returns the published app, the DNS CNAME resolves to `ccisnedev.github.io`, and HTTPS is still pending certificate issuance on GitHub Pages.
- [x] The canonical Calculatrix privacy-policy URL `https://ccisne.dev/legal/calculatrix/privacy/` is publicly reachable

## Phase 2 - winget

Status: blocked by missing Windows installer packaging

Outcome:

- Publish the Windows release lineage through `winget`
- Keep the package metadata aligned with the shipped Windows application identity

### Official platform requirements

- [ ] Produce a supported installer type: exe, msi, msix, inno, wix, nullsoft, appx, or font. [W1]
- [ ] Ensure the installer supports silent or non-interactive installation. [W1][W2]
- [ ] Ensure the app installs and uninstalls correctly for administrators and non-administrators. [W2]
- [ ] Host the installer at a direct HTTPS URL from the publisher release location. [W2]
- [ ] Define a unique PackageIdentifier in Publisher.Package format. [W1]
- [ ] Define PackageVersion. [W1]
- [ ] Provide the minimal required manifest fields: PackageIdentifier, PackageVersion, PackageLocale, Publisher, PackageName, License, ShortDescription, Installers, ManifestType, ManifestVersion. [W1]
- [ ] Set Publisher and PackageName so they match what Windows shows in Add / Remove Programs. [W1]
- [ ] Calculate and include InstallerSha256. [W1]
- [ ] Validate the manifest locally with winget validate. [W2][W3]
- [ ] Test the manifest locally with winget install --manifest and/or the SandboxTest.ps1 workflow. [W2][W3]
- [ ] Submit exactly one package version per PR in the path manifests/<letter>/<publisher>/<package>/<version>. [W2][W3]

### Current repo gaps

- [x] A local `flutter build windows --release` succeeds and produces a runnable Windows bundle rooted at `code/app/build/windows/x64/runner/Release/`.
- [ ] The current Windows output is a portable directory containing `Calculatrix.exe`, `flutter_windows.dll`, and `data/`; it is not a supported winget installer package type by itself under [W1].
- [ ] No installer packaging files were found locally for a supported Windows installer format.
- [ ] No release workflow or release asset publication path currently exists for Windows artifacts. The only local workflows are [../.github/workflows/ci.yml](../.github/workflows/ci.yml) and [../.github/workflows/pages-release.yml](../.github/workflows/pages-release.yml), and neither produces or uploads Windows release artifacts.
- [ ] No GitHub Release currently exists for this repository, so there is no direct HTTPS publisher-hosted `InstallerURL` available for a winget manifest.
- [x] Windows app metadata no longer uses placeholder values in [../code/app/windows/runner/Runner.rc](../code/app/windows/runner/Runner.rc). A local release build now confirms `CompanyName=ccisne.dev`, `FileDescription=Calculatrix`, `ProductName=Calculatrix`, `InternalName=Calculatrix`, and `OriginalFilename=Calculatrix.exe`.
- [ ] The current Windows release executable is not Authenticode-signed.
- [ ] No root-level public license file was found; only [../code/core/LICENSE](../code/core/LICENSE) exists.

### Repo-owned execution tasks

- [ ] Choose the Windows installer format to generate from the current portable Flutter Windows bundle
- [x] Replace placeholder Windows publisher/product metadata in [../code/app/windows/runner/Runner.rc](../code/app/windows/runner/Runner.rc)
- [ ] Expose the public license consistently at the repo/distribution level
- [ ] Introduce a Windows release path that builds the release bundle, packages an installer, and uploads it to an official publisher-controlled HTTPS location
- [ ] Publish installer artifacts from the official release location over HTTPS

### Chosen Windows identity baseline

- Display publisher: `ccisne.dev`
- Package identifier target: `CcisneDev.Calculatrix`
- Product name: `Calculatrix`
- Executable name: `Calculatrix.exe`
- Rationale: keep the human-facing publisher aligned with the current public domain and normalize the winget identifier to an alphanumeric publisher stem that remains stable across GitHub, store metadata, and future upgrades.

### Actionable execution order

- [x] Step 1 - Freeze Windows identity
  - Chosen Windows identity baseline confirmed for this line
  - Final values applied in [../code/app/windows/CMakeLists.txt](../code/app/windows/CMakeLists.txt) and [../code/app/windows/runner/Runner.rc](../code/app/windows/runner/Runner.rc)
  - `flutter build windows --release` revalidated and `FileVersionInfo` now reports `Calculatrix` / `ccisne.dev`
- [x] Step 2 - Choose installer format
  - Chosen first path: Inno Setup `.exe` wrapping the existing Flutter Windows release bundle
  - Decision basis: WinGet supports `inno` as an installer type and understands its silent install behavior, while Flutter’s Windows docs explicitly present installers such as Inno Setup as a straightforward wrapper around the generated release bundle
  - Constraint: this is the best-fit first choice for the current self-hosted WinGet path, not a claim that WinGet globally recommends Inno Setup over all other installer types
  - Reference: see [../docs/research/winget-installer-format-2026.md](../docs/research/winget-installer-format-2026.md)
- [x] Step 3 - Expose distribution license
  - Added public product-level MIT license at [../LICENSE](../LICENSE)
  - Keep future winget manifest license metadata aligned with this root license surface
- [x] Step 4 - Create Windows release pipeline
  - Build the Windows release bundle from GitHub Actions
  - Package the installer from the release bundle
  - Automated first path: upload the installer and companion assets to the GitHub Release that triggered the workflow
  - Implementation anchor: [../.github/workflows/windows-release.yml](../.github/workflows/windows-release.yml), [../release/windows/build-installer.ps1](../release/windows/build-installer.ps1), and [../release/windows/Calculatrix.iss](../release/windows/Calculatrix.iss)
  - Authentication model: use the workflow-scoped built-in `GITHUB_TOKEN` to upload assets to the release that triggered the workflow; no separate PAT is required for this first automated path
  - Future signing note: code signing is intentionally deferred, so no certificate secrets are required yet; if signing is added later, introduce dedicated repository secrets for the certificate payload and password
  - Winget follow-up note: confirm during manifest authoring whether the GitHub Release asset URL is the final installer URL to publish or whether a different publisher-controlled release surface is required
  - Validated on published release `v0.7.1`: the workflow attached `Calculatrix-windows-x64-0.7.1-setup.exe`, `Calculatrix-windows-x64-0.7.1-portable.zip`, and `SHA256SUMS.txt` to the GitHub Release
- [x] Step 5 - Validate local installation behavior
  - Current-user validation passed on the published `v0.7.1` installer using `/CURRENTUSER /VERYSILENT /SUPPRESSMSGBOXES /NORESTART`
  - Observed current-user install location: `C:\Users\44358590\AppData\Local\Programs\Calculatrix\`
  - Observed current-user uninstall metadata: `DisplayVersion = 0.7.1`, `Publisher = ccisne.dev`, uninstall key `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\CcisneDev.Calculatrix_is1`
  - Current-user silent uninstall passed and removed both the install directory and the HKCU uninstall key
  - All-users validation passed on the published `v0.7.1` installer using `/ALLUSERS /VERYSILENT /SUPPRESSMSGBOXES /NORESTART`
  - Observed all-users install location: `C:\Program Files\Calculatrix\`
  - Observed all-users uninstall metadata: `DisplayVersion = 0.7.1`, `Publisher = ccisne.dev`, uninstall key `HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\CcisneDev.Calculatrix_is1`
  - All-users silent uninstall passed and removed both the Program Files install directory and the HKLM uninstall key
- [x] Step 6 - Author the winget manifest
  - Local manifest authored at [../release/winget/manifests/c/CcisneDev/Calculatrix/0.7.1/CcisneDev.Calculatrix.yaml](../release/winget/manifests/c/CcisneDev/Calculatrix/0.7.1/CcisneDev.Calculatrix.yaml), [../release/winget/manifests/c/CcisneDev/Calculatrix/0.7.1/CcisneDev.Calculatrix.locale.en-US.yaml](../release/winget/manifests/c/CcisneDev/Calculatrix/0.7.1/CcisneDev.Calculatrix.locale.en-US.yaml), and [../release/winget/manifests/c/CcisneDev/Calculatrix/0.7.1/CcisneDev.Calculatrix.installer.yaml](../release/winget/manifests/c/CcisneDev/Calculatrix/0.7.1/CcisneDev.Calculatrix.installer.yaml)
  - Chosen `PackageIdentifier`: `CcisneDev.Calculatrix`
  - Chosen installer URL: `https://github.com/ccisnedev/calculatrix/releases/download/v0.7.1/Calculatrix-windows-x64-0.7.1-setup.exe`
  - The installer manifest models both validated scopes using the same Inno Setup artifact with `/ALLUSERS` and `/CURRENTUSER`
  - The installer manifest now declares `Microsoft.VCRedist.2015+.x64` because the winget validation environment reported `STATUS_DLL_NOT_FOUND` when launching `Calculatrix.exe`
  - `PackageName` remains `Calculatrix`; `AppsAndFeaturesEntries` captures the actual Windows display name `Calculatrix version 0.7.1` observed during local install validation
- [x] Step 7 - Run submission validation
  - `winget validate --manifest .\release\winget\manifests\c\CcisneDev\Calculatrix\0.7.1` completed successfully
  - `SandboxTest.ps1` from `microsoft/winget-pkgs` completed with exit code `0` against `release/winget/manifests/c/CcisneDev/Calculatrix/0.7.1/CcisneDev.Calculatrix.yaml`
  - Direct host execution of `winget install --manifest` is blocked on this machine because the client feature `LocalManifestFiles` is only enabled by administrators; the official sandbox flow above was used instead
  - Single-version submission PR opened: https://github.com/microsoft/winget-pkgs/pull/381654
  - PR feedback then reported `STATUS_DLL_NOT_FOUND` for both machine and user scope launches; the corrective patch was to declare `Microsoft.VCRedist.2015+.x64` in the installer manifest and push the update to the PR branch
  - `Needs-CLA` is still pending; the account owner must reply personally to the PR with the required CLA acceptance text

### Operational completion checks

- [x] Local manifest validation passes
  - `winget validate --manifest .\release\winget\manifests\c\CcisneDev\Calculatrix\0.7.1` completed successfully
- [x] Local silent install and uninstall tests pass for both current-user and all-users modes
- [x] Local `SandboxTest.ps1` submission validation passes
- [ ] The submission PR to `microsoft/winget-pkgs` is accepted
  - Opened PR: https://github.com/microsoft/winget-pkgs/pull/381654

## Phase 3 - Google Play

Status: blocked by final Android identity, signing, and store declarations

Outcome:

- Publish the Android app through Google Play from a signed release AAB
- Reuse the publisher legal path at `https://ccisne.dev/legal/` for privacy-policy URLs while keeping release-facing app pages under `calculatrix.ccisne.dev`

### Official platform requirements

- [ ] Choose the final package name before creating the app in Play Console. Google documents that package names are unique and permanent and cannot be deleted or reused. [P1]
- [ ] Create the app in Play Console with default language, app name, app or game type, free or paid choice, contact email, declarations, and acceptance of Play App Signing terms. [P1]
- [ ] Publish new apps with Android App Bundle (.aab). [P2]
- [ ] Enroll in Play App Signing. Google documents that the upload key must be RSA 2048 bits or more. [P3]
- [ ] Ensure the app targets Android 15 / API 35 or higher for new apps and app updates submitted to Google Play after 2025-08-31. [P4]
- [ ] Complete the store listing fields and preview assets required by Play Console. [P1][P8]
- [ ] Complete the App content declarations that apply to the app: privacy policy, ads declaration, app access instructions if access is restricted, target audience and content, content rating, permissions declaration if high-risk permissions apply, and other applicable declarations. [P5]
- [ ] Complete the Data safety form. Google documents that every app published on Google Play must complete it, even when the app does not collect user data, and must provide a privacy policy link. [P6]
- [ ] Before rollout, ensure the store listing, App content review prep, and prices are configured. [P7]
- [ ] When preparing a release, add the app bundle, release name, and release notes. [P7]
- [ ] Conditional: if the developer account is a personal account created after 2023-11-13, satisfy Google's additional testing requirements before production. [P1][P7]

### Current repo gaps

- [ ] Android still uses a placeholder identity and debug signing in [../code/app/android/app/build.gradle.kts](../code/app/android/app/build.gradle.kts).

### Repo-owned execution tasks

- [ ] Replace the placeholder Android package identity in [../code/app/android/app/build.gradle.kts](../code/app/android/app/build.gradle.kts) before creating the Play app
- [ ] Add real release-signing inputs and the Play App Signing enrollment path
- [ ] Build the release AAB from the release pipeline
- [x] Host the canonical Calculatrix privacy policy at `https://ccisne.dev/legal/calculatrix/privacy/` and point store metadata there

### Operational completion checks

- [ ] Play Console accepts the release AAB
- [ ] Required App content and Data safety declarations are complete
- [ ] The release can be sent for review or rollout

## Notes deliberately excluded from this plan

- No unofficial store advice or community folklore is included here.
- No requirement is claimed unless it was found in an official source or directly observed in this repo.
- Platform review times, marketing recommendations, and non-required polish are intentionally excluded unless they appear as official requirements.

## Cross-cutting repo work

- [ ] Keep public distribution gated by the existing validation matrix instead of ad-hoc local releases
- [ ] Introduce a dedicated release workflow that builds the validated web, Windows, and Android artifacts from one revision
- [ ] Version privacy policy in the shared publisher legal repo and keep release notes and store metadata versioned alongside the relevant product repos

## Sources

- [G1] GitHub Pages custom workflows: https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages
- [G2] GitHub Pages custom domain management: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site
- [G3] GitHub Pages domain verification: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/verifying-your-custom-domain-for-github-pages
- [W1] Windows Package Manager manifest schema: https://learn.microsoft.com/en-us/windows/package-manager/package/manifest
- [W2] Windows Package Manager repository submission: https://learn.microsoft.com/en-us/windows/package-manager/package/repository
- [W3] winget-pkgs contributor documentation: https://github.com/microsoft/winget-pkgs/blob/master/doc/README.md
- [P1] Google Play create and set up your app: https://support.google.com/googleplay/android-developer/answer/9859152
- [P2] Google Play app bundles / latest releases and bundles: https://support.google.com/googleplay/android-developer/answer/9844279
- [P3] Google Play App Signing: https://support.google.com/googleplay/android-developer/answer/9842756
- [P4] Google Play target API requirements: https://developer.android.com/google/play/requirements/target-sdk
- [P5] Google Play App content / prepare your app for review: https://support.google.com/googleplay/android-developer/answer/9859455
- [P6] Google Play Data safety: https://support.google.com/googleplay/android-developer/answer/10787469
- [P7] Google Play release rollout: https://support.google.com/googleplay/android-developer/answer/9859348
- [P8] Google Play preview assets: https://support.google.com/googleplay/android-developer/answer/9866151