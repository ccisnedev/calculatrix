# calculatrix_app

Flutter calculator app for Calculatrix (Android, Windows, web). Its version is
in `pubspec.yaml`; each package versions independently.

This app depends on the shared core package in `../core` and is responsible for
UI, interaction flows, matrix entry, display policy, and platform packaging.

## Shell model

- Persistent `RPN` shell with truthful committed stack summaries
- Explicit `INFIX` editor over a pre-stack draft routed through the canonical stack kernel
- Explicit `MATRIX` editor for bounded matrix editing over the same draft surface
- Fixed module bar plus fixed keypad with contextual `DELETE` / `DROP` and pocket-calculator-style `MRC`

## Common Commands

Run widget and unit tests:

```text
flutter test
```

Run integration tests on Windows:

```text
flutter test integration_test/calculator_test.dart -d windows
```

Build a debug APK:

```text
flutter build apk --debug
```

Static analysis:

```text
flutter analyze
```

Run the web shell locally:

```text
flutter run -d chrome
```

## Releases

Publishing a GitHub Release tagged `vX.Y.Z` (matching the public version in
`pubspec.yaml`) builds and attaches the Windows installer and the Android
`.aab` (`.github/workflows/windows-release.yml`, `android-release.yml`). A
push to `main` publishes the web build (`pages-release.yml`). See
`docs/release-checklist.md` and `docs/android-release-signing.md`.
