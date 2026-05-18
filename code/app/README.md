# calculatrix_app

Flutter consumer shell for Calculatrix.

This app depends on the shared core package in `../core` and is responsible for
UI, interaction flows, matrix entry, display policy, and platform packaging.

## Shell modes

- `Infix`: algebra-style entry that compiles to the canonical stack kernel
- `RPN`: direct-command surface with stack summaries and matrix command pages
- `Matrix`: bounded workstation for matrix editing and structural workflows

## Common Commands

Run widget and unit tests:

```text
flutter test
```

Run integration tests on the verified Windows target:

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
