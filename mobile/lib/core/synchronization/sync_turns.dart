import 'dart:isolate';
import 'dart:ui';

/// Makes sure the open app and the background sync (another isolate) never
/// sync at the same time: both could use the same refresh token, and using
/// it twice signs the user out everywhere (ADR-0003).
///
/// Each side first puts up its own mark, then looks for the other's, so at
/// least one of them always sees the other:
/// - the app, when it comes to the foreground, waits until a running
///   background sync has finished before it syncs itself;
/// - the background sync skips its run while the app is in the foreground.
abstract interface class SyncTurns {
  void enterForeground();

  void leaveForeground();

  /// Completes when no background sync is running.
  Future<void> waitForBackgroundSync();

  /// Puts up the background mark; `false` (and no mark) when the app is in
  /// the foreground or another background sync runs.
  bool tryStartBackgroundSync();

  void endBackgroundSync();
}

/// [SyncTurns] on port names in the [IsolateNameServer]: every isolate of
/// the app's process can look them up, and they disappear with the process.
class IsolateSyncTurns implements SyncTurns {
  IsolateSyncTurns({this.pollInterval = const Duration(milliseconds: 200), this.maxWait = const Duration(minutes: 10)});

  static const foregroundName = 'taskinspect.sync.foreground';
  static const backgroundName = 'taskinspect.sync.background';

  final Duration pollInterval;

  /// Android stops background work after 10 minutes. If the app has
  /// waited that long, the background mark was left behind by a run that
  /// was stopped, and it is removed.
  final Duration maxWait;

  ReceivePort? _foregroundPort;
  ReceivePort? _backgroundPort;

  bool get isInForeground => IsolateNameServer.lookupPortByName(foregroundName) != null;

  bool get isBackgroundSyncRunning => IsolateNameServer.lookupPortByName(backgroundName) != null;

  @override
  void enterForeground() {
    _foregroundPort ??= ReceivePort();
    IsolateNameServer.removePortNameMapping(foregroundName);
    IsolateNameServer.registerPortWithName(_foregroundPort!.sendPort, foregroundName);
  }

  @override
  void leaveForeground() {
    IsolateNameServer.removePortNameMapping(foregroundName);
    _foregroundPort?.close();
    _foregroundPort = null;
  }

  @override
  Future<void> waitForBackgroundSync() async {
    final stopwatch = Stopwatch()..start();
    while (isBackgroundSyncRunning) {
      if (stopwatch.elapsed >= maxWait) {
        IsolateNameServer.removePortNameMapping(backgroundName);
        return;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  @override
  bool tryStartBackgroundSync() {
    final port = ReceivePort();
    if (!IsolateNameServer.registerPortWithName(port.sendPort, backgroundName)) {
      port.close();
      return false;
    }
    if (isInForeground) {
      IsolateNameServer.removePortNameMapping(backgroundName);
      port.close();
      return false;
    }
    _backgroundPort = port;
    return true;
  }

  /// Also works on a new instance, e.g. when Android stopped the run.
  @override
  void endBackgroundSync() {
    IsolateNameServer.removePortNameMapping(backgroundName);
    _backgroundPort?.close();
    _backgroundPort = null;
  }
}
