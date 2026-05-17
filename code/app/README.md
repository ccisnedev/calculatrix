# calculatrix_app

Flutter consumer shell for Calculatrix.

This app depends on the shared core package in `../core` and is responsible for
UI, interaction flows, matrix entry, display policy, and platform packaging.

## Common Commands

Run widget and unit tests:

```text
flutter test
```

Run integration tests on the Android emulator:

```text
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/calculator_test.dart -d emulator-5554
```

Build a debug APK:

```text
flutter build apk --debug
```

Static analysis:

```text
flutter analyze
```
