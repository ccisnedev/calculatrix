# calculatrix_app

Flutter consumer shell for Calculatrix.

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
