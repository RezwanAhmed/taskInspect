import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/synchronization/sync_turns.dart';

void main() {
  late IsolateSyncTurns app;
  late IsolateSyncTurns background;

  setUp(() {
    app = IsolateSyncTurns(pollInterval: const Duration(milliseconds: 5));
    background = IsolateSyncTurns();
  });

  tearDown(() {
    app.leaveForeground();
    background.endBackgroundSync();
  });

  test('the foreground mark is visible to other isolates until the app leaves the foreground', () {
    expect(app.isInForeground, isFalse);

    app.enterForeground();
    expect(IsolateSyncTurns().isInForeground, isTrue);

    app.leaveForeground();
    expect(IsolateSyncTurns().isInForeground, isFalse);
  });

  test('no background sync while the app is in the foreground', () {
    app.enterForeground();

    expect(background.tryStartBackgroundSync(), isFalse);
    expect(app.isBackgroundSyncRunning, isFalse, reason: 'no mark is left behind');
  });

  test('only one background sync at a time', () {
    expect(background.tryStartBackgroundSync(), isTrue);

    expect(IsolateSyncTurns().tryStartBackgroundSync(), isFalse);
    expect(app.isBackgroundSyncRunning, isTrue, reason: "the first run's mark stays");

    background.endBackgroundSync();
    expect(app.isBackgroundSyncRunning, isFalse);
  });

  test('the app waits until a running background sync has finished', () async {
    expect(background.tryStartBackgroundSync(), isTrue);
    app.enterForeground();
    var waited = false;

    final waiting = app.waitForBackgroundSync().then((_) => waited = true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(waited, isFalse);

    background.endBackgroundSync();
    await waiting;
    expect(waited, isTrue);
  });

  test('a mark left behind by a stopped run is removed after the longest possible run', () async {
    expect(background.tryStartBackgroundSync(), isTrue);
    final impatient = IsolateSyncTurns(pollInterval: const Duration(milliseconds: 5), maxWait: Duration.zero);

    await impatient.waitForBackgroundSync();

    expect(impatient.isBackgroundSyncRunning, isFalse);
  });

  test('a new instance can remove the mark, e.g. after Android stopped the run', () {
    expect(background.tryStartBackgroundSync(), isTrue);

    IsolateSyncTurns().endBackgroundSync();

    expect(app.isBackgroundSyncRunning, isFalse);
  });
}
