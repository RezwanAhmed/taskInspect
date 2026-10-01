import 'dart:io';

import 'package:workmanager/workmanager.dart';

/// Schedules the periodic background sync with the phone's operating
/// system (docs/architecture.md, "When Sync Runs").
abstract interface class BackgroundSyncRegistration {
  /// Tells the operating system which function runs the background work.
  /// Called once at app start.
  Future<void> initialize(void Function() callbackDispatcher);

  /// Runs the background sync about every [WorkmanagerSyncRegistration.frequency]
  /// while the phone is online. Scheduling again keeps one schedule.
  Future<void> schedule();

  Future<void> cancel();
}

/// [BackgroundSyncRegistration] on the workmanager package: Android's
/// WorkManager runs the sync even when the app is closed or the phone was
/// restarted.
///
/// iOS (task 12.7): BGTaskScheduler decides itself when (and whether) an app
/// may run in the background. It needs the task identifier [uniqueName] in
/// `BGTaskSchedulerPermittedIdentifiers` and `fetch` in `UIBackgroundModes`
/// (Info.plist); until then [isSupported] is false on iOS and the app syncs
/// every time it is opened.
class WorkmanagerSyncRegistration implements BackgroundSyncRegistration {
  WorkmanagerSyncRegistration({Workmanager? workmanager, bool? isSupported})
      : _workmanager = workmanager ?? Workmanager(),
        isSupported = isSupported ?? Platform.isAndroid;

  static const uniqueName = 'taskinspect.sync';

  /// Android's shortest interval for periodic work.
  static const frequency = Duration(minutes: 15);

  final Workmanager _workmanager;
  final bool isSupported;

  @override
  Future<void> initialize(void Function() callbackDispatcher) async {
    if (isSupported) {
      await _workmanager.initialize(callbackDispatcher);
    }
  }

  @override
  Future<void> schedule() async {
    if (!isSupported) {
      return;
    }
    await _workmanager.registerPeriodicTask(
      uniqueName,
      uniqueName,
      frequency: frequency,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }

  @override
  Future<void> cancel() async {
    if (isSupported) {
      await _workmanager.cancelByUniqueName(uniqueName);
    }
  }
}
