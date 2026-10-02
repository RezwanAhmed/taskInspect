import 'dart:async';
import 'dart:math';

import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/connectivity_monitor.dart';
import 'package:taskinspect/core/synchronization/sync_manager.dart';

/// Decides when the [SyncManager] syncs (push, then pull): whenever the
/// device is online (docs/architecture.md, "When Sync Runs"). That is at
/// sign in and app start, as soon as the connection comes back, and shortly
/// after a local change, so quick edits are sent together. Runs while
/// someone is signed in and the app is in the foreground; otherwise the
/// background sync takes over (see SyncLifecycle).
///
/// When a sync fails for a temporary reason (no connection, server error),
/// it is retried while the device is online with a growing delay (30 s,
/// 1 min, 2 min, ... up to 5 min), and at once when the connection comes
/// back. It never gives up on unsent data.
class SyncScheduler {
  SyncScheduler(
    this._manager,
    this._connectivity, {
    this.delay = const Duration(seconds: 2),
    this.firstRetryDelay = const Duration(seconds: 30),
    this.maxRetryDelay = const Duration(minutes: 5),
  });

  final SyncManager _manager;
  final ConnectivityMonitor _connectivity;

  /// How long to wait after a local change before syncing.
  final Duration delay;

  /// Delay before the first automatic retry; it doubles up to [maxRetryDelay].
  final Duration firstRetryDelay;
  final Duration maxRetryDelay;

  StreamSubscription<bool>? _online;
  StreamSubscription<DateTime?>? _changes;
  Timer? _timer;
  Timer? _retryTimer;

  /// The sync that is running, if any.
  Future<void>? _inFlight;

  /// Temporary failures in a row; decides the next retry delay.
  int _failures = 0;

  bool get isRunning => _changes != null;

  Future<void> start() async {
    if (isRunning) {
      return;
    }
    await _manager.resetInterrupted();
    _online = _connectivity.onlineChanges.listen((online) {
      if (online) {
        _retryNow();
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

  /// Stops syncing; completes once a sync that is running has finished.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _failures = 0;
    await _online?.cancel();
    await _changes?.cancel();
    _online = null;
    _changes = null;
    await _inFlight;
  }

  /// Syncs at once while running, e.g. after the user tapped Retry.
  void syncNow() {
    if (isRunning) {
      _syncNow();
    }
  }

  void _syncSoon() {
    _timer?.cancel();
    _timer = Timer(delay, _syncNow);
  }

  void _syncNow() {
    _timer?.cancel();
    final run = _sync(after: _inFlight);
    _inFlight = run;
    unawaited(run.whenComplete(() {
      if (identical(_inFlight, run)) {
        _inFlight = null;
      }
    }));
  }

  Future<void> _sync({Future<void>? after}) async {
    // SyncManager runs one sync at a time anyway; waiting here keeps
    // [_inFlight] set until the last sync has finished.
    await after;
    if (!isRunning || !await _connectivity.isOnline()) {
      return;
    }
    final result = await _manager.sync();
    if (!isRunning) {
      return;
    }
    if (result case Err(:final failure) when SyncManager.isTemporary(failure)) {
      _failures++;
      _retryTimer?.cancel();
      _retryTimer = Timer(retryDelay(_failures), _retryNow);
    } else {
      _failures = 0;
    }
  }

  /// Puts temporarily failed operations back in line and syncs.
  void _retryNow() {
    _retryTimer?.cancel();
    unawaited(() async {
      await _manager.retryTemporaryFailures();
      _syncNow();
    }());
  }

  /// 30 s, 1 min, 2 min, 4 min, then 5 min (with the default settings).
  Duration retryDelay(int failures) {
    final delay = firstRetryDelay * pow(2, min(failures - 1, 10)).toInt();
    return delay > maxRetryDelay ? maxRetryDelay : delay;
  }
}
