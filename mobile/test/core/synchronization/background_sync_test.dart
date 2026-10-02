import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/connectivity_monitor.dart';
import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/core/synchronization/background_sync.dart';
import 'package:taskinspect/core/synchronization/sync_manager.dart';
import 'package:taskinspect/core/synchronization/sync_turns.dart';

class _MockSyncManager extends Mock implements SyncManager {}

class _FakeConnectivity implements ConnectivityMonitor {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => const Stream.empty();
}

class _FakeTurns implements SyncTurns {
  bool inForeground = false;
  bool backgroundRunning = false;
  int ended = 0;

  @override
  void enterForeground() => inForeground = true;

  @override
  void leaveForeground() => inForeground = false;

  @override
  Future<void> waitForBackgroundSync() async {}

  @override
  bool tryStartBackgroundSync() {
    if (inForeground || backgroundRunning) {
      return false;
    }
    return backgroundRunning = true;
  }

  @override
  void endBackgroundSync() {
    backgroundRunning = false;
    ended++;
  }
}

class _MockBackgroundSync extends Mock implements BackgroundSync {}

void main() {
  final now = DateTime.utc(2026, 10, 1, 9);
  late _MockSyncManager manager;
  late InMemoryTokenStorage tokens;
  late _FakeConnectivity connectivity;
  late _FakeTurns turns;
  late BackgroundSync backgroundSync;

  StoredTokens tokensUntil(DateTime refreshTokenExpiresAt) => StoredTokens(
        accessToken: 'access',
        accessTokenExpiresAt: now.subtract(const Duration(minutes: 1)),
        refreshToken: 'refresh',
        refreshTokenExpiresAt: refreshTokenExpiresAt,
      );

  setUp(() {
    manager = _MockSyncManager();
    tokens = InMemoryTokenStorage()..tokens = tokensUntil(now.add(const Duration(days: 30)));
    connectivity = _FakeConnectivity();
    turns = _FakeTurns();
    when(manager.resetInterrupted).thenAnswer((_) async {});
    when(manager.retryTemporaryFailures).thenAnswer((_) async {});
    when(manager.sync).thenAnswer((_) async => const Ok(null));
    backgroundSync = BackgroundSync(manager, tokens, connectivity, turns, now: () => now);
  });

  test('syncs when signed in and online, after resetting interrupted and temporary failures', () async {
    expect(await backgroundSync.run(), isTrue);

    verifyInOrder([manager.resetInterrupted, manager.retryTemporaryFailures, manager.sync]);
    expect(turns.backgroundRunning, isFalse, reason: 'the mark is removed again');
    expect(turns.ended, 1);
  });

  test('the mark is removed also when the sync throws', () async {
    when(manager.sync).thenThrow(StateError('database closed'));

    await expectLater(backgroundSync.run(), throwsStateError);

    expect(turns.backgroundRunning, isFalse);
  });

  test('does nothing while another background sync runs', () async {
    turns.backgroundRunning = true;

    expect(await backgroundSync.run(), isTrue);

    verifyZeroInteractions(manager);
    expect(turns.backgroundRunning, isTrue, reason: "the other run's mark stays");
  });

  test('does nothing while the app is in the foreground (it syncs itself)', () async {
    turns.enterForeground();

    expect(await backgroundSync.run(), isTrue);

    verifyZeroInteractions(manager);
  });

  test('does nothing when signed out', () async {
    tokens.tokens = null;

    expect(await backgroundSync.run(), isTrue);

    verifyZeroInteractions(manager);
  });

  test('does nothing when the session expired (the queue waits for the next sign in)', () async {
    tokens.tokens = tokensUntil(now);

    expect(await backgroundSync.run(), isTrue);

    verifyZeroInteractions(manager);
  });

  test('does nothing when offline', () async {
    connectivity.online = false;

    expect(await backgroundSync.run(), isTrue);

    verifyZeroInteractions(manager);
  });

  test('asks for an earlier retry after a temporary failure', () async {
    for (final failure in [const NetworkFailure(), const ServerFailure(statusCode: 503)]) {
      when(manager.sync).thenAnswer((_) async => Err(failure));

      expect(await backgroundSync.run(), isFalse, reason: '$failure');
    }
  });

  test('a business error is not retried sooner (it would fail again)', () async {
    when(manager.sync).thenAnswer((_) async => const Err(ServerFailure(statusCode: 409)));

    expect(await backgroundSync.run(), isTrue);
  });

  group('runBackgroundSyncTask', () {
    tearDown(getIt.reset);

    test('sets up the dependencies, runs the sync and closes them again', () async {
      final sync = _MockBackgroundSync();
      when(sync.run).thenAnswer((_) async => true);

      final result = await runBackgroundSyncTask(configure: () async {
        getIt.registerSingleton<BackgroundSync>(sync);
      });

      expect(result, isTrue);
      expect(getIt.isRegistered<BackgroundSync>(), isFalse);
    });

    test('an unexpected error counts as a failed run, and the dependencies are closed', () async {
      final result = await runBackgroundSyncTask(configure: () async {
        getIt.registerSingleton<String>('half set up');
        throw StateError('no database');
      });

      expect(result, isFalse);
      expect(getIt.isRegistered<String>(), isFalse);
    });
  });
}
