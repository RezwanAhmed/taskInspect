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
| Application ID | `com.taskinspect` |

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
| `dart run build_runner build --delete-conflicting-outputs` | Regenerate code (e.g. the drift database, `*.g.dart`) after changing tables |

Generated `*.g.dart` files are committed, so the app builds right after
cloning; regenerate them whenever their source changes.

## Environments

The backend URL and environment are set when the app is built, from the
files in [`config/`](config/):

| Command | Backend |
|---------|---------|
| `flutter run` (no file) or `--dart-define-from-file=config/dev.json` | `http://10.0.2.2:8080` — the backend on your computer, seen from the Android emulator |
| `--dart-define-from-file=config/staging.json` | Staging (https) |
| `--dart-define-from-file=config/prod.json` | Production (https) |

On a real phone in development, use your computer's network address,
e.g. `--dart-define=API_BASE_URL=http://192.168.1.20:8080`. Plain http is
allowed only in debug builds (Android) and for local addresses (iOS);
staging and production must use https. The staging and production
domains are placeholders until deployment (Phase 8).
