import 'package:flutter/foundation.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/connectivity_monitor.dart';
import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/core/synchronization/sync_manager.dart';
import 'package:taskinspect/core/synchronization/sync_turns.dart';
import 'package:workmanager/workmanager.dart';

/// One background sync run (task 6.11): while the app is not open, the
/// operating system starts it about every 15 minutes when the phone is
/// online (see BackgroundSyncRegistration), so changes made offline reach
/// the server even if the worker doesn't open the app again.
class BackgroundSync {
  BackgroundSync(this._manager, this._tokens, this._connectivity, this._turns, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final SyncManager _manager;
  final TokenStorage _tokens;
  final ConnectivityMonitor _connectivity;
  final SyncTurns _turns;
  final DateTime Function() _now;

  /// Returns `false` when the sync failed for a temporary reason, so the
  /// operating system tries again sooner; `true` otherwise.
  Future<bool> run() async {
    if (!_turns.tryStartBackgroundSync()) {
      // The open app syncs itself (or another run is busy).
      return true;
    }
    try {
      final tokens = await _tokens.read();
      if (tokens == null || tokens.isRefreshTokenExpired(_now())) {
        // Signed out or the session expired: the queue is kept and sent
        // after the next sign in.
        return true;
      }
      if (!await _connectivity.isOnline()) {
        return true;
      }
      // The app may have been closed during a push, and temporary failures
      // are worth another try now.
      await _manager.resetInterrupted();
      await _manager.retryTemporaryFailures();
      return switch (await _manager.sync()) {
        Err(:final failure) when SyncManager.isTemporary(failure) => false,
        _ => true,
      };
    } finally {
      _turns.endBackgroundSync();
    }
  }
}

/// Sets up the app's dependencies for this isolate, runs [BackgroundSync]
/// and closes them again. An unexpected error counts as a failed run.
Future<bool> runBackgroundSyncTask({Future<void> Function() configure = configureDependencies}) async {
  try {
    await configure();
    return await getIt<BackgroundSync>().run();
  } on Object catch (error, stackTrace) {
    debugPrint('Background sync failed: $error\n$stackTrace');
    return false;
  } finally {
    // Closes the database connection of this isolate.
    await getIt.reset();
  }
}

/// Entry point of the background sync. The operating system starts it in a
/// new isolate, so the app's dependencies are set up again for each run.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask(
    (task, inputData) => runBackgroundSyncTask(),
    // Android stopped the run early: let the app sync again.
    onTaskStopped: (task, reason) async => IsolateSyncTurns().endBackgroundSync(),
  );
}
