# Android Release Signing Setup

This document covers the repository-side setup required to produce Play-ready signed AAB artifacts in CI (`.github/workflows/android-release.yml`). The four secrets below are already configured in the repository.

## Required GitHub Actions secrets

Configure these repository secrets:

- `ANDROID_UPLOAD_KEYSTORE_BASE64`: Base64 payload of the upload keystore (`.jks`)
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password
- `ANDROID_KEY_ALIAS`: Key alias inside the keystore
- `ANDROID_KEY_PASSWORD`: Key password for the alias

The Android release workflow reads these secrets and creates `code/app/android/key.properties` (and `keystore/upload-keystore.jks`) at runtime. For a local signed build, copy `code/app/android/key.properties.example` to `key.properties` and fill it in; never commit it.

## Generate upload keystore (example)

Run locally and store the resulting keystore securely:

```bash
keytool -genkeypair \
  -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

Then encode for GitHub secret input:

```bash
base64 -w 0 upload-keystore.jks
```

On PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))
```

## Workflow behavior

- `workflow_dispatch`: builds Android AAB even without signing secrets (debug fallback)
- `release.published`: runs only for app releases (tags `vX.Y.Z`, not `cli-v*`); the tag must match the public version in `code/app/pubspec.yaml`; requires all signing secrets and fails fast if any are missing

## Output artifacts

The workflow publishes:

- `Calculatrix-android-<version>.aab` (`<version>` is the public version without `+N`)
- `SHA256SUMS-android.txt`

They are kept as the `android-release-assets` workflow artifact and, on release events, uploaded to the GitHub Release.
