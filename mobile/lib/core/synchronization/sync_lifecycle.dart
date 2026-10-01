import 'package:taskinspect/core/synchronization/background_sync_registration.dart';
import 'package:taskinspect/core/synchronization/sync_scheduler.dart';
import 'package:taskinspect/core/synchronization/sync_turns.dart';

/// Chooses who syncs (docs/architecture.md, "When Sync Runs"), only ever
/// one of them at a time:
///
/// - signed in and the app open in the foreground: the [SyncScheduler]
///   (it syncs at once when the app comes back to the foreground, after a
///   running background sync has finished);
/// - signed in and the app in the background or closed: the background
///   sync scheduled with the operating system;
/// - signed out: nobody.
///
/// Changes are handled one after another, in the order they come in.
class SyncLifecycle {
  SyncLifecycle(this._scheduler, this._registration, this._turns, {Future<void> Function()? refreshScreens})
      : _refreshScreens = refreshScreens ?? _nothing;

  static Future<void> _nothing() async {}

  final SyncScheduler _scheduler;
  final BackgroundSyncRegistration _registration;
  final SyncTurns _turns;

  /// Shows the app what a background sync changed in the local database
  /// (it uses its own connection, so the app's screens don't notice).
  final Future<void> Function() _refreshScreens;

  bool _signedIn = false;
  bool? _inForeground;
  Future<void> _last = Future.value();

  Future<void> signedIn() => _serial(() async {
        _signedIn = true;
        await _registration.schedule();
        await _update();
      });

  Future<void> signedOut() => _serial(() async {
        _signedIn = false;
        await _registration.cancel();
        await _update();
      });

  Future<void> foregroundChanged({required bool inForeground}) => _serial(() async {
        if (inForeground == _inForeground) {
          return;
        }
        _inForeground = inForeground;
        if (inForeground) {
          _turns.enterForeground();
          await _turns.waitForBackgroundSync();
          await _refreshScreens();
          await _update();
        } else {
          // The app's own sync must be over before the background sync may run.
          await _update();
          _turns.leaveForeground();
        }
      });

  Future<void> _update() {
    if (_signedIn && (_inForeground ?? false)) {
      return _scheduler.start();
    }
    return _scheduler.stop();
  }

  Future<void> _serial(Future<void> Function() step) {
    final next = _last.then((_) => step());
    _last = next.catchError((Object _) {});
    return next;
  }
}
