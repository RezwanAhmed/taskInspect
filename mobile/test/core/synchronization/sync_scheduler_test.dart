import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/connectivity_monitor.dart';
import 'package:taskinspect/core/synchronization/sync_manager.dart';
import 'package:taskinspect/core/synchronization/sync_scheduler.dart';

class _MockSyncManager extends Mock implements SyncManager {}

class _FakeConnectivity implements ConnectivityMonitor {
  _FakeConnectivity(this.changes);

  final StreamController<bool> changes;
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => changes.stream;
}

void main() {
  late _MockSyncManager manager;
  late _FakeConnectivity connectivity;
  late StreamController<DateTime?> latestChange;
  late StreamController<bool> onlineChanges;
  late SyncScheduler scheduler;

  setUp(() {
    manager = _MockSyncManager();
    onlineChanges = StreamController<bool>.broadcast();
    connectivity = _FakeConnectivity(onlineChanges);
    latestChange = StreamController<DateTime?>.broadcast();
    when(manager.resetInterrupted).thenAnswer((_) async {});
    when(manager.watchLatestChange).thenAnswer((_) => latestChange.stream);
    when(manager.sync).thenAnswer((_) async => const Ok(null));
    scheduler = SyncScheduler(manager, connectivity, delay: const Duration(milliseconds: 20));
  });

  tearDown(() async {
    await scheduler.stop();
    await latestChange.close();
    await onlineChanges.close();
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));

  test('start resets interrupted operations, then syncs at once', () async {
    await scheduler.start();
    await settle();

    verifyInOrder([manager.resetInterrupted, manager.sync]);
    expect(scheduler.isRunning, isTrue);
  });

  /// Starts and forgets the sync that start itself runs.
  Future<void> started() async {
    await scheduler.start();
    await settle();
    clearInteractions(manager);
  }

  test('syncs shortly after local changes, grouping quick ones', () async {
    await started();

    latestChange
      ..add(DateTime.utc(2026, 10, 1, 9))
      ..add(DateTime.utc(2026, 10, 1, 9, 0, 1))
      ..add(DateTime.utc(2026, 10, 1, 9, 0, 2));
    await settle();

    verify(manager.sync).called(1);
  });

  test('an empty queue does not trigger a sync', () async {
    await started();

    latestChange.add(null);
    await settle();

    verifyNever(manager.sync);
  });

  test('syncs as soon as the connection comes back', () async {
    await started();

    connectivity.changes.add(false);
    await settle();
    verifyNever(manager.sync);

    connectivity.changes.add(true);
    await settle();
    verify(manager.sync).called(1);
  });

  test('does not sync while offline', () async {
    connectivity.online = false;
    await scheduler.start();

    latestChange.add(DateTime.utc(2026, 10, 1, 9));
    await settle();

    verifyNever(manager.sync);
  });

  test('after stop nothing is synced any more; starting twice is harmless', () async {
    await scheduler.start();
    await scheduler.start();
    await settle();
    verify(manager.resetInterrupted).called(1);
    verify(manager.sync).called(1);

    await scheduler.stop();
    latestChange.add(DateTime.utc(2026, 10, 1, 9));
    connectivity.changes.add(true);
    await settle();

    verifyNever(manager.sync);
    expect(scheduler.isRunning, isFalse);
  });
}
