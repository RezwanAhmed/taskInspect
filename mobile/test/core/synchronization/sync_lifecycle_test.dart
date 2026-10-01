import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taskinspect/core/synchronization/background_sync_registration.dart';
import 'package:taskinspect/core/synchronization/sync_lifecycle.dart';
import 'package:taskinspect/core/synchronization/sync_scheduler.dart';
import 'package:taskinspect/core/synchronization/sync_turns.dart';

class _MockScheduler extends Mock implements SyncScheduler {}

class _MockRegistration extends Mock implements BackgroundSyncRegistration {}

class _MockTurns extends Mock implements SyncTurns {}

void main() {
  late _MockScheduler scheduler;
  late _MockRegistration registration;
  late _MockTurns turns;
  late SyncLifecycle lifecycle;

  setUp(() {
    scheduler = _MockScheduler();
    registration = _MockRegistration();
    turns = _MockTurns();
    when(scheduler.start).thenAnswer((_) async {});
    when(scheduler.stop).thenAnswer((_) async {});
    when(registration.schedule).thenAnswer((_) async {});
    when(registration.cancel).thenAnswer((_) async {});
    when(turns.waitForBackgroundSync).thenAnswer((_) async {});
    lifecycle = SyncLifecycle(scheduler, registration, turns);
  });

  test('signed in with the app open: the app syncs and the background sync is scheduled', () async {
    await lifecycle.foregroundChanged(inForeground: true);
    await lifecycle.signedIn();

    verify(turns.enterForeground).called(1);
    verify(registration.schedule).called(1);
    verify(scheduler.start).called(1);
  });

  test('coming to the foreground: the mark goes up first, then the app waits for a background sync, then syncs',
      () async {
    await lifecycle.signedIn();
    await lifecycle.foregroundChanged(inForeground: true);

    verifyInOrder([turns.enterForeground, turns.waitForBackgroundSync, scheduler.start]);
  });

  test("the app's screens are refreshed from the database after a background sync, before syncing", () async {
    final calls = <String>[];
    when(turns.waitForBackgroundSync).thenAnswer((_) async => calls.add('wait'));
    when(scheduler.start).thenAnswer((_) async => calls.add('start'));
    lifecycle = SyncLifecycle(scheduler, registration, turns, refreshScreens: () async => calls.add('refresh'));
    await lifecycle.signedIn();

    await lifecycle.foregroundChanged(inForeground: true);

    expect(calls, ['wait', 'refresh', 'start']);
  });

  test('the app does not sync while a background sync is still running', () async {
    final backgroundSync = Completer<void>();
    when(turns.waitForBackgroundSync).thenAnswer((_) => backgroundSync.future);
    await lifecycle.signedIn();

    final entering = lifecycle.foregroundChanged(inForeground: true);
    await pumpEventQueue();
    verifyNever(scheduler.start);

    backgroundSync.complete();
    await entering;
    verify(scheduler.start).called(1);
  });

  test('going to the background: the app finishes its own sync before the background sync may run', () async {
    await lifecycle.foregroundChanged(inForeground: true);
    await lifecycle.signedIn();
    clearInteractions(scheduler);
    final ownSync = Completer<void>();
    when(scheduler.stop).thenAnswer((_) => ownSync.future);

    final leaving = lifecycle.foregroundChanged(inForeground: false);
    await pumpEventQueue();
    verifyNever(turns.leaveForeground);

    ownSync.complete();
    await leaving;
    verify(turns.leaveForeground).called(1);
    verifyNever(scheduler.start);

    when(scheduler.stop).thenAnswer((_) async {});
    await lifecycle.foregroundChanged(inForeground: true);
    verify(scheduler.start).called(1);
  });

  test('changes that come in quickly are handled one after another', () async {
    await lifecycle.foregroundChanged(inForeground: true);
    final starting = Completer<void>();
    when(scheduler.start).thenAnswer((_) => starting.future);

    final signingIn = lifecycle.signedIn();
    final leaving = lifecycle.foregroundChanged(inForeground: false);
    await pumpEventQueue();
    verifyNever(turns.leaveForeground);

    starting.complete();
    await Future.wait([signingIn, leaving]);
    verifyInOrder([scheduler.start, scheduler.stop, turns.leaveForeground]);
  });

  test('a failed change does not block the next ones', () async {
    when(registration.schedule).thenThrow(StateError('no WorkManager'));

    await expectLater(lifecycle.signedIn(), throwsStateError);
    await lifecycle.signedOut();

    verify(registration.cancel).called(1);
  });

  test('the same foreground state twice changes nothing', () async {
    await lifecycle.foregroundChanged(inForeground: true);
    await lifecycle.foregroundChanged(inForeground: true);

    verify(turns.enterForeground).called(1);
    verify(scheduler.stop).called(1);
  });

  test('signed out: no sync at all, background sync cancelled', () async {
    await lifecycle.foregroundChanged(inForeground: true);
    await lifecycle.signedIn();
    clearInteractions(scheduler);

    await lifecycle.signedOut();

    verify(registration.cancel).called(1);
    verify(scheduler.stop).called(1);
    verifyNever(scheduler.start);
  });

  test('signing in while the app is in the background only schedules the background sync', () async {
    await lifecycle.foregroundChanged(inForeground: false);
    await lifecycle.signedIn();

    verify(registration.schedule).called(1);
    verifyNever(scheduler.start);
  });
}
