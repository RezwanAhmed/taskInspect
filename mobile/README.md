# TaskInspect — Mobile

Flutter app for Android and iOS (BLoC, feature-based Clean Architecture,
offline-first). See the
[mobile architecture](../docs/architecture.md#mobile-architecture) for
the design.

| | |
|---|---|
| Flutter | 3.47 (stable) |
| Dart | 3.13 |
| Platforms | Android (released first), iOS (after the Google Play release) |
| Application ID | `com.taskinspect.taskinspect` |

## Requirements

- Flutter SDK 3.47 or newer (`flutter doctor` should show no problems
  for Flutter and the Android toolchain).
- Android SDK 36 (installed with Android Studio).
- iOS builds need macOS with Xcode — they run on a cloud Mac in
  Phase 12.

## Common Commands

Run from this `mobile/` folder:

| Command | What it does |
|---------|--------------|
| `flutter pub get` | Download the packages |
| `flutter analyze` | Static analysis (lint rules) |
| `flutter test` | Run the unit and widget tests |
| `flutter run` | Run the app on a connected device or emulator |
| `flutter build apk --debug` | Build a debug APK for Android |
