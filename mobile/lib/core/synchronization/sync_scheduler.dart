import 'dart:async';

import 'package:taskinspect/core/network/connectivity_monitor.dart';
import 'package:taskinspect/core/synchronization/sync_manager.dart';

/// Decides when the [SyncManager] syncs (push, then pull): whenever the
/// device is online (docs/architecture.md, "When Sync Runs"). That is at
/// sign in and app start, as soon as the connection comes back, and shortly
/// after a local change, so quick edits are sent together. Runs while
/// someone is signed in. Background sync follows in task 6.11, retries with
/// backoff in 6.8.
class SyncScheduler {
  SyncScheduler(this._manager, this._connectivity, {this.delay = const Duration(seconds: 2)});

  final SyncManager _manager;
  final ConnectivityMonitor _connectivity;

  /// How long to wait after a local change before syncing.
  final Duration delay;

  StreamSubscription<bool>? _online;
  StreamSubscription<DateTime?>? _changes;
  Timer? _timer;

  bool get isRunning => _changes != null;

  Future<void> start() async {
    if (isRunning) {
      return;
    }
    await _manager.resetInterrupted();
    _online = _connectivity.onlineChanges.listen((online) {
      if (online) {
        _syncNow();
      }
    });
    _changes = _manager.watchLatestChange().listen((latest) {
      if (latest != null) {
        _syncSoon();
      }
    });
    // Sends anything left from the last session and loads what changed.
    _syncNow();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _online?.cancel();
    await _changes?.cancel();
    _online = null;
    _changes = null;
  }

  void _syncSoon() {
    _timer?.cancel();
    _timer = Timer(delay, _syncNow);
  }

  void _syncNow() {
    _timer?.cancel();
    unawaited(() async {
      if (await _connectivity.isOnline()) {
        await _manager.sync();
      }
    }());
  }
}
