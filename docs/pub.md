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
- [ ] Windows runner metadata still uses placeholder publisher and product values in [../code/app/windows/runner/Runner.rc](../code/app/windows/runner/Runner.rc).
- [ ] Only one license file was found locally: [../code/core/LICENSE](../code/core/LICENSE).
- [x] The canonical legal pages are served from `https://ccisne.dev/legal/`, including the live Calculatrix privacy policy at `https://ccisne.dev/legal/calculatrix/privacy/`.
- [ ] No Windows installer packaging files were found locally for .msix, .appx, .appinstaller, .msi, .iss, or .wxs.

## Phase 1 - GitHub Pages / calculatrix.ccisne.dev

Status: first active publication block

Outcome:

- Publish the current web build from the `v0.7.1` line at `calculatrix.ccisne.dev`
- If Pages-specific fixes are needed, keep them on `v0.7.x` until the web site is live

### Official platform requirements

- [ ] Enable GitHub Pages publication from a custom GitHub Actions workflow in the repository settings. [G1]
- [ ] Add calculatrix.ccisne.dev as the custom domain in Settings > Pages. [G2]
- [ ] Configure DNS for the chosen domain. [G2]
  - Apex domain: use ALIAS, ANAME, or A records; AAAA is optional. [G2]
  - Subdomain: use a CNAME pointing to USERNAME.github.io or ORGANIZATION.github.io. [G2]
- [ ] Verify the domain in GitHub Pages using the TXT challenge and keep the TXT record in DNS. [G3]
- [ ] Enable Enforce HTTPS once GitHub makes it available for the domain. [G2]
- [ ] Do not use wildcard DNS records for the Pages domain. GitHub documents takeover risk. [G2][G3]

### Repo-owned execution tasks

- [ ] Keep the current custom Pages workflow in [../.github/workflows/pages-release.yml](../.github/workflows/pages-release.yml) as the publication path unless deployment exposes a concrete gap. [G1]
- [x] Publish the canonical Calculatrix privacy policy URL at `https://ccisne.dev/legal/calculatrix/privacy/` on the shared publisher legal site. This satisfies the stable public privacy-policy URL requirement independently of the app domain. [P6]
- [ ] Only if deployment exposes a repo-side gap, cut the minimal `v0.7.x` patch needed for GitHub Pages publication and redeploy the same release line

### Operational completion checks

- [ ] A GitHub Pages deployment from Actions completes successfully
- [ ] `calculatrix.ccisne.dev` resolves over HTTPS to the published site
- [ ] The domain remains verified in GitHub
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

- [ ] No installer packaging files were found locally for a supported Windows installer format.
- [ ] Windows app metadata still uses placeholder values in [../code/app/windows/runner/Runner.rc](../code/app/windows/runner/Runner.rc).
- [ ] No root-level public license file was found; only [../code/core/LICENSE](../code/core/LICENSE) exists.

### Repo-owned execution tasks

- [ ] Choose the Windows installer format to generate for the Flutter Windows app
- [ ] Replace placeholder Windows publisher/product metadata in [../code/app/windows/runner/Runner.rc](../code/app/windows/runner/Runner.rc)
- [ ] Expose the public license consistently at the repo/distribution level
- [ ] Publish installer artifacts from the official release location over HTTPS

### Operational completion checks

- [ ] Local manifest validation passes
- [ ] Local silent install and uninstall tests pass
- [ ] The submission PR to `microsoft/winget-pkgs` is accepted

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