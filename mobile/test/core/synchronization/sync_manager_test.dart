import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_manager.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/core/synchronization/sync_remote_data_source.dart';
import 'package:taskinspect/features/requirements/data/local/answer_local_data_source.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/fake_tasks.dart';

typedef _Sent = Map<String, Object?>;

void main() {
  late AppDatabase db;
  late ApiClient api;
  late SyncQueue queue;
  late SyncManager manager;
  late DateTime now;

  /// Operations of every push, as sent.
  late List<List<_Sent>> pushes;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    api = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    now = DateTime.utc(2026, 10, 1, 9);
    queue = SyncQueue(db, now: () => now = now.add(const Duration(seconds: 1)));
    manager = SyncManager(db, SyncRemoteDataSource(api), batchSize: 2);
    pushes = [];
    for (final id in ['t1', 't2']) {
      await TaskLocalDataSource(db).saveTask(fakeTask(id, status: TaskStatus.inProgress), [
        Requirement(id: 'r-$id', taskId: id, title: 'Ok?', type: RequirementType.yesNo, required: true, position: 0),
      ]);
    }
  });

  tearDown(() => db.close());

  /// Answers every push with [result] per operation (by entity ID).
  void serve(String Function(_Sent operation) result, {String? code}) {
    api.dio.httpClientAdapter = FakeServer((request) async {
      final operations = ((request.data as Map)['operations'] as List).cast<_Sent>();
      pushes.add(operations);
      return (200, {
        'results': [
          for (final operation in operations)
            {'id': operation['id'], 'status': result(operation), 'code': code},
        ],
      });
    });
  }

  Future<void> add(String taskId, String entityId, {SyncOperation operation = SyncOperation.create}) {
    return queue.add(entity: SyncEntity.evidence, entityId: entityId, taskId: taskId, operation: operation);
  }

  Future<List<SyncOperationRow>> queued() {
    final query = db.select(db.localSyncOperations)..orderBy([(o) => OrderingTerm(expression: o.createdAt)]);
    return query.get();
  }

  test('sends the queue in order, in batches, and removes what was applied', () async {
    for (final id in ['e1', 'e2', 'e3']) {
      await add('t1', id);
    }
    serve((_) => 'APPLIED');

    expect(await manager.push(), isA<Ok<void>>());

    expect(pushes.map((p) => p.map((o) => o['entityId'])), [
      ['e1', 'e2'],
      ['e3'],
    ]);
    expect(await queued(), isEmpty);
  });

  test('sends what the server needs: ID, entity, task, operation and the payload as JSON', () async {
    await queue.add(
      entity: SyncEntity.task,
      entityId: 't1',
      taskId: 't1',
      operation: SyncOperation.start,
      payload: {'version': 3},
    );
    final id = (await queued()).single.id;
    serve((_) => 'APPLIED');

    await manager.push();

    expect(pushes.single.single, {
      'id': id,
      'entityType': 'Task',
      'entityId': 't1',
      'taskId': 't1',
      'operation': 'START',
      'payload': {'version': 3},
    });
  });

  test('a rejected operation becomes FAILED and holds back the later ones of its task only', () async {
    await add('t1', 'bad');
    await add('t1', 'after-bad');
    await add('t2', 'other');
    serve((o) => switch (o['entityId']) {
          'bad' => 'REJECTED',
          'after-bad' => 'SKIPPED',
          _ => 'APPLIED',
        }, code: 'EVIDENCE_LOCKED');

    await manager.push();

    final rows = await queued();
    expect(rows.map((o) => (o.entityId, o.status)), [('bad', 'FAILED'), ('after-bad', 'PENDING')]);
    expect(rows.first.lastError, 'EVIDENCE_LOCKED');
    expect(rows.first.retryCount, 1);

    // The next push doesn't send the held-back operation again.
    pushes.clear();
    await manager.push();
    expect(pushes, isEmpty);
  });

  test('offline: the push fails and everything stays PENDING for the next try', () async {
    await add('t1', 'e1');
    api.dio.httpClientAdapter = FakeServer((_) async => (0, null));

    final result = await manager.push();

    expect((result as Err<void>).failure, isA<NetworkFailure>());
    final row = (await queued()).single;
    expect(row.status, 'PENDING');
    expect(row.retryCount, 0);
  });

  test('an answer is marked synced once its last change was applied', () async {
    final answers = AnswerLocalDataSource(db, queue);
    await answers.saveAnswer(taskId: 't1', requirementId: 'r-t1', answer: const Answer(booleanValue: true));
    serve((_) => 'APPLIED');

    await manager.push();

    expect(await answers.pendingRequirementIds('t1'), isEmpty);
  });

  test('an answer changed while it was being sent stays pending', () async {
    final answers = AnswerLocalDataSource(db, queue);
    await answers.saveAnswer(taskId: 't1', requirementId: 'r-t1', answer: const Answer(booleanValue: true));
    var calls = 0;
    api.dio.httpClientAdapter = FakeServer((request) async {
      if (++calls > 1) {
        return (0, null); // offline before the second change is sent
      }
      // The worker changes the answer while the first one is on its way.
      await answers.saveAnswer(taskId: 't1', requirementId: 'r-t1', answer: const Answer(booleanValue: false));
      final operations = ((request.data as Map)['operations'] as List).cast<_Sent>();
      return (200, {
        'results': [for (final o in operations) {'id': o['id'], 'status': 'APPLIED'}],
      });
    });

    await manager.push();

    expect(await answers.pendingRequirementIds('t1'), ['r-t1']);
    expect((await queued()).single.status, 'PENDING');
  });

  test('only one push runs at a time', () async {
    await add('t1', 'e1');
    final release = Completer<void>();
    var calls = 0;
    api.dio.httpClientAdapter = FakeServer((request) async {
      calls++;
      await release.future;
      final operations = ((request.data as Map)['operations'] as List).cast<_Sent>();
      return (200, {
        'results': [for (final o in operations) {'id': o['id'], 'status': 'APPLIED'}],
      });
    });

    final first = manager.push();
    final second = manager.push();
    release.complete();
    await Future.wait([first, second]);

    expect(identical(first, second), isTrue);
    expect(calls, 1);
  });

  test('stops instead of looping when the server neither applies nor rejects', () async {
    await add('t1', 'e1');
    serve((_) => 'SKIPPED');

    expect(await manager.push(), isA<Ok<void>>());

    expect(pushes, hasLength(1));
    expect((await queued()).single.status, 'PENDING');
  });
}
