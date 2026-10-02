import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/network/connectivity_monitor.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_manager.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/core/synchronization/sync_remote_data_source.dart';
import 'package:taskinspect/core/synchronization/sync_status.dart';
import 'package:taskinspect/features/evidence/data/evidence_uploader.dart';
import 'package:taskinspect/features/evidence/data/remote/evidence_remote_data_source.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/fake_tasks.dart';

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
  late AppDatabase db;
  late ApiClient api;
  late StreamController<bool> onlineChanges;
  late _FakeConnectivity connectivity;
  late SyncManager manager;
  late SyncQueue queue;
  late List<SyncStatus> seen;
  late StreamSubscription<SyncStatus> subscription;
  var minute = 0;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    api = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    onlineChanges = StreamController<bool>.broadcast();
    connectivity = _FakeConnectivity(onlineChanges);
    manager = SyncManager(db, SyncRemoteDataSource(api), TaskLocalDataSource(db), EvidenceUploader(db, EvidenceRemoteDataSource(api)));
    queue = SyncQueue(db, now: () => DateTime.utc(2026, 10, 1, 9, minute++));
    for (final id in ['t1', 't2']) {
      await TaskLocalDataSource(db).saveTask(fakeTask(id, status: TaskStatus.inProgress), [
        Requirement(id: 'r-$id', taskId: id, title: 'Photo', type: RequirementType.photo, required: true, position: 0),
      ]);
    }
    seen = [];
    subscription = DatabaseSyncStatusSource(db, connectivity, manager).watch().listen(seen.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await onlineChanges.close();
    await db.close();
  });

  Future<SyncStatus> latest() async {
    await pumpEventQueue();
    return seen.last;
  }

  Future<void> photo(String id, String taskId, {String status = 'PENDING', String? error}) {
    return db.into(db.localEvidence).insert(LocalEvidenceCompanion.insert(
          id: id,
          taskId: taskId,
          requirementId: 'r-$taskId',
          localPath: '/$id.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 5,
          createdAt: DateTime.utc(2026, 10, 1, 9, minute++),
          uploadStatus: Value(status),
          uploadError: Value(error),
        ));
  }

  test('nothing unsent: online, nothing waiting', () async {
    expect(await latest(), const SyncStatus());
  });

  test('nothing is shown before the connection is known (no "waiting" flash when offline)', () async {
    connectivity.online = false;
    final statuses = <SyncStatus>[];
    final watching = DatabaseSyncStatusSource(db, connectivity, manager).watch().listen(statuses.add);
    addTearDown(watching.cancel);

    await pumpEventQueue();

    expect(statuses, isNotEmpty);
    expect(statuses.every((status) => !status.online), isTrue);
  });

  test('counts queued changes and files not uploaded yet, and which tasks have them', () async {
    await queue.add(entity: SyncEntity.taskResponse, entityId: 'r-t1', taskId: 't1', operation: SyncOperation.update);
    await photo('e1', 't2');
    await queue.add(entity: SyncEntity.evidence, entityId: 'e1', taskId: 't2', operation: SyncOperation.create);
    await photo('e2', 't2', status: 'UPLOADED');

    final status = await latest();

    expect(status.unsent, 2, reason: 'a file whose registration is queued counts once');
    expect(status.unsentTaskIds, {'t1', 't2'});
    expect(status.failed, 0);
  });

  test('failures: count and the reason of the oldest one (changes and uploads)', () async {
    await photo('e1', 't1', status: 'FAILED', error: 'FILE_MISSING');
    await queue.add(entity: SyncEntity.task, entityId: 't2', taskId: 't2', operation: SyncOperation.start);
    await db.update(db.localSyncOperations).write(
      const LocalSyncOperationsCompanion(status: Value('FAILED'), lastError: Value('TASK_INVALID_TRANSITION')),
    );

    final status = await latest();

    expect(status.failed, 2);
    expect(status.failureCode, 'FILE_MISSING');
  });

  test('follows the connection and the running sync', () async {
    connectivity.changes.add(false);
    expect((await latest()).online, isFalse);

    api.dio.httpClientAdapter = FakeServer((_) async => (200, {'cursor': 'c1', 'taskIds': <String>[], 'tasks': <Object?>[]}));
    seen.clear();
    await manager.sync();
    await pumpEventQueue();
    expect(seen.map((status) => status.syncing), containsAllInOrder([true, false]));
    expect(seen.last.syncing, isFalse);
  });
}
