import 'dart:isolate';
import 'dart:ui';

/// Lets only one isolate at a time refresh the login. The app and the
/// background sync (task 6.11) run in different isolates but share the
/// saved tokens, and a refresh token can be used only once: using it twice
/// signs the user out everywhere (ADR-0003).
abstract interface class RefreshLock {
  Future<T> run<T>(Future<T> Function() action);
}

/// For a single isolate, e.g. in tests: no lock needed.
class NoRefreshLock implements RefreshLock {
  const NoRefreshLock();

  @override
  Future<T> run<T>(Future<T> Function() action) => action();
}

/// [RefreshLock] on a port name in the [IsolateNameServer], which every
/// isolate of the app's process can see.
class IsolateRefreshLock implements RefreshLock {
  IsolateRefreshLock({this.pollInterval = const Duration(milliseconds: 100), this.maxWait = const Duration(minutes: 2)});

  static const portName = 'taskinspect.auth.refresh';

  final Duration pollInterval;

  /// A refresh takes at most about 70 s (connect, send and receive
  /// timeouts). A lock held longer was left behind by an isolate that was
  /// stopped, so it is taken over.
  final Duration maxWait;

  bool get isLocked => IsolateNameServer.lookupPortByName(portName) != null;

  @override
  Future<T> run<T>(Future<T> Function() action) async {
    final port = ReceivePort();
    final waiting = Stopwatch()..start();
    while (!IsolateNameServer.registerPortWithName(port.sendPort, portName)) {
      if (waiting.elapsed >= maxWait) {
        IsolateNameServer.removePortNameMapping(portName);
        continue;
      }
      await Future<void>.delayed(pollInterval);
    }
    try {
      return await action();
    } finally {
      // Not if it was taken over meanwhile.
      if (IsolateNameServer.lookupPortByName(portName) == port.sendPort) {
        IsolateNameServer.removePortNameMapping(portName);
      }
      port.close();
    }
  }
}
