import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/synchronization/sync_status.dart';
import 'package:taskinspect/core/synchronization/sync_status_cubit.dart';

import '../../helpers/fake_tasks.dart';

/// A source that counts its listeners, to see the cubit subscribe once and cancel on close.
class _CountingSource implements SyncStatusSource {
  int listens = 0;
  int cancels = 0;

  @override
  Stream<SyncStatus> watch() {
    listens++;
    return StreamController<SyncStatus>(onCancel: () => cancels++).stream;
  }
}

/// Unit tests of the sync status cubit behind the banner and the Retry button (task 9.4d).
void main() {
  test('shows nothing to sync until started, then follows the sync status', () async {
    final source = FakeSyncStatusSource(const SyncStatus(unsent: 2));
    final cubit = SyncStatusCubit(source, () async {});
    expect(cubit.state, const SyncStatus());

    cubit.start();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.unsent, 2);

    source.emit(const SyncStatus(online: false, unsent: 3, failed: 1, failureCode: 'TASK_INVALID_TRANSITION'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.online, isFalse);
    expect(cubit.state.failed, 1);
    expect(cubit.state.failureCode, 'TASK_INVALID_TRANSITION');
    await cubit.close();
  });

  test('starting again does not subscribe twice', () async {
    final source = _CountingSource();
    final cubit = SyncStatusCubit(source, () async {});

    cubit.start();
    cubit.start();

    expect(source.listens, 1);
    await cubit.close();
  });

  test('closing stops listening to the sync status', () async {
    final source = _CountingSource();
    final cubit = SyncStatusCubit(source, () async {});
    cubit.start();
    await Future<void>.delayed(Duration.zero);

    await cubit.close();

    expect(source.cancels, 1);
  });

  test('retry sends the failed changes again', () async {
    var retries = 0;
    final cubit = SyncStatusCubit(FakeSyncStatusSource(), () async => retries++);

    await cubit.retry();

    expect(retries, 1);
    await cubit.close();
  });
}
