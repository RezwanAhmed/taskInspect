import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/notifications/push_notification_navigation.dart';
import 'package:taskinspect/core/notifications/push_notification_service.dart';
import 'package:taskinspect/core/synchronization/background_sync.dart';
import 'package:taskinspect/core/synchronization/background_sync_registration.dart';
import 'package:taskinspect/core/synchronization/sync_lifecycle.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:taskinspect/firebase_options.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await _setUpCrashReporting();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _run();
  }, (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack, fatal: true));
}

/// Crash reporting (task 11.8): off in debug builds (kDebugMode), so a
/// developer's own crashes while coding never reach the dashboard. A
/// Flutter framework error (caught by FlutterError.onError) and an
/// uncaught async error (caught by runZonedGuarded, above) both end up
/// here; PlatformDispatcher.onError catches what either would miss.
Future<void> _setUpCrashReporting() async {
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

Future<void> _run() async {
  await configureDependencies();
  await getIt<BackgroundSyncRegistration>().initialize(backgroundSyncDispatcher);
  // Changes are synchronized while someone is signed in: by the app while
  // it is open, in the background otherwise.
  final sync = getIt<SyncLifecycle>();
  // Not awaited: a running background sync must not keep the splash screen.
  unawaited(sync.foregroundChanged(inForeground: true));
  AppLifecycleListener(
    onStateChange: (state) => sync.foregroundChanged(
      // Inactive: still visible, e.g. behind a system dialog.
      inForeground: state == AppLifecycleState.resumed || state == AppLifecycleState.inactive,
    ),
  );
  final pushNotifications = getIt<PushNotificationService>();
  unawaited(pushNotifications.start());
  setUpPushNotificationNavigation();
  getIt<AuthBloc>().stream.map((state) => state is Authenticated).distinct().listen((signedIn) {
    if (signedIn) {
      sync.signedIn();
      unawaited(pushNotifications.registerCurrentToken());
    } else {
      sync.signedOut();
    }
  });
  runApp(const TaskInspectApp());
}
