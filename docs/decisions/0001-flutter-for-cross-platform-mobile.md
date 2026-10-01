# ADR-0001: Flutter for Cross-platform Mobile

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

Workers and managers use TaskInspect on their phones. The app is
released on Google Play first and on the Apple App Store afterwards, so
it has to run on both Android and iOS. It is built and maintained by
one developer.

The app needs:

- an offline-first local database and background synchronization,
- camera access and image compression for photo evidence,
- push notifications,
- a predictable way to manage screen state (loading, offline, syncing,
  failed, ...),
- automated unit, widget and integration tests.

Writing and maintaining two separate native apps would double the work
for every feature and every fix.

## Decision

Build the mobile app with **Flutter** (Dart) from one codebase for
Android and iOS, using **BLoC** for state management and feature-based
**Clean Architecture** (see [architecture.md](../architecture.md#mobile-architecture)).

- Android is built and released first; iOS follows the Google Play
  release. Until then, only packages that support both platforms are
  used, and platform-specific setup (permissions, notifications,
  background work) is planned for both.
- Business logic stays in plain Dart (domain layer), so it is shared
  completely and tested without a device.

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Flutter** (chosen) | One codebase for Android and iOS; own rendering engine gives the same UI on both; fast development with hot reload; strong testing support (unit, widget, integration); mature packages for camera, local database, notifications and background work. | Larger app size than native; platform features not covered by a package need native code (Kotlin / Swift) through platform channels. |
| Native Android (Kotlin) + native iOS (Swift) | Best access to every platform feature; smallest apps; platform look and feel. | Two codebases, two languages and two sets of tests for one developer; every feature built twice. |
| React Native | One codebase; large JavaScript ecosystem. | UI built from native components can behave differently per platform; the bridge to native code adds complexity for camera and background work; less built-in testing support than Flutter. |
| Kotlin Multiplatform | Shared business logic in Kotlin; fully native UI. | UI still written twice (Jetpack Compose + SwiftUI, or Compose Multiplatform on iOS, which is newer); smaller ecosystem for this kind of app. |

## Consequences

- One team member can build and test the whole app; features reach both
  platforms at the same time.
- iOS builds need macOS. The laptop runs Windows, so iOS builds will run
  on a cloud Mac (GitHub Actions macOS runner or Codemagic) in Phase 12.
- Some platform behaviour still differs and must be handled per
  platform — for example background sync is scheduled by WorkManager on
  Android but limited by the system on iOS.
- Dart and Flutter need to be kept up to date (task 4.1), and packages
  are chosen with both platforms in mind.
