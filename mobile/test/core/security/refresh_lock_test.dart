import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/security/refresh_lock.dart';

void main() {
  test('one refresh at a time; the second waits until the first is done', () async {
    final first = IsolateRefreshLock(pollInterval: const Duration(milliseconds: 5));
    final second = IsolateRefreshLock(pollInterval: const Duration(milliseconds: 5));
    final release = Completer<void>();
    final order = <String>[];

    final running = first.run(() async {
      order.add('first started');
      await release.future;
      order.add('first done');
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final waiting = second.run(() async => order.add('second'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(order, ['first started']);

    release.complete();
    await Future.wait([running, waiting]);
    expect(order, ['first started', 'first done', 'second']);
    expect(first.isLocked, isFalse);
  });

  test('the lock is released when the refresh throws', () async {
    final lock = IsolateRefreshLock();

    await expectLater(lock.run<void>(() async => throw StateError('offline')), throwsStateError);

    expect(lock.isLocked, isFalse);
  });

  test('a lock left behind by a stopped isolate is taken over after the longest possible refresh', () async {
    final stopped = IsolateRefreshLock();
    final left = Completer<void>();
    unawaited(stopped.run(() => left.future));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final impatient = IsolateRefreshLock(pollInterval: const Duration(milliseconds: 5), maxWait: Duration.zero);
    expect(await impatient.run(() async => 'refreshed'), 'refreshed');

    left.complete();
  });
}
