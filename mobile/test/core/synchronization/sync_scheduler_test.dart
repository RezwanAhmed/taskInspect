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
    when(manager.push).thenAnswer((_) async => const Ok(null));
    scheduler = SyncScheduler(manager, connectivity, delay: const Duration(milliseconds: 20));
  });

  tearDown(() async {
    await scheduler.stop();
    await latestChange.close();
    await onlineChanges.close();
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));

  test('start resets interrupted operations first', () async {
    await scheduler.start();

    verify(manager.resetInterrupted).called(1);
    expect(scheduler.isRunning, isTrue);
  });

  test('pushes shortly after local changes, grouping quick ones', () async {
    await scheduler.start();

    latestChange
      ..add(DateTime.utc(2026, 10, 1, 9))
      ..add(DateTime.utc(2026, 10, 1, 9, 0, 1))
      ..add(DateTime.utc(2026, 10, 1, 9, 0, 2));
    await settle();

    verify(manager.push).called(1);
  });

  test('an empty queue is not pushed', () async {
    await scheduler.start();

    latestChange.add(null);
    await settle();

    verifyNever(manager.push);
  });

  test('pushes as soon as the connection comes back', () async {
    await scheduler.start();

    connectivity.changes.add(false);
    await settle();
    verifyNever(manager.push);

    connectivity.changes.add(true);
    await settle();
    verify(manager.push).called(1);
  });

  test('does not push while offline', () async {
    connectivity.online = false;
    await scheduler.start();

    latestChange.add(DateTime.utc(2026, 10, 1, 9));
    await settle();

    verifyNever(manager.push);
  });

  test('after stop nothing is pushed any more; starting twice is harmless', () async {
    await scheduler.start();
    await scheduler.start();
    verify(manager.resetInterrupted).called(1);

    await scheduler.stop();
    latestChange.add(DateTime.utc(2026, 10, 1, 9));
    connectivity.changes.add(true);
    await settle();

    verifyNever(manager.push);
    expect(scheduler.isRunning, isFalse);
  });
}
