import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
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
    manager = SyncManager(db, SyncRemoteDataSource(api), TaskLocalDataSource(db), batchSize: 2);
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

  test('offline: the operations become FAILED for the automatic retry, nothing is lost', () async {
    await add('t1', 'e1');
    api.dio.httpClientAdapter = FakeServer((_) async => (0, null));

    final result = await manager.push();

    expect((result as Err<void>).failure, isA<NetworkFailure>());
    final row = (await queued()).single;
    expect(row.status, 'FAILED');
    expect(row.lastError, SyncManager.networkError);
    expect(row.retryCount, 1);
  });

  test('a server error is a temporary failure too', () async {
    await add('t1', 'e1');
    api.dio.httpClientAdapter = FakeServer((_) async => (503, {'code': 'INTERNAL_ERROR'}));

    await manager.push();

    expect((await queued()).single.lastError, SyncManager.serverError);
  });

  test('other failures of the whole push leave the operations PENDING', () async {
    await add('t1', 'e1');
    api.dio.httpClientAdapter = FakeServer((_) async => (401, {'code': 'INVALID_TOKEN'}));

    await manager.push();

    expect((await queued()).single.status, 'PENDING');
  });

  test('retryTemporaryFailures brings back only temporary failures; retryFailed brings back all', () async {
    await add('t1', 'offline');
    await add('t2', 'refused');
    await db.update(db.localSyncOperations).write(const LocalSyncOperationsCompanion(status: Value('FAILED')));
    await (db.update(db.localSyncOperations)..where((o) => o.entityId.equals('offline')))
        .write(const LocalSyncOperationsCompanion(lastError: Value(SyncManager.networkError)));
    await (db.update(db.localSyncOperations)..where((o) => o.entityId.equals('refused')))
        .write(const LocalSyncOperationsCompanion(lastError: Value('TASK_INVALID_TRANSITION')));

    await manager.retryTemporaryFailures();
    expect((await queued()).map((o) => (o.entityId, o.status)), [('offline', 'PENDING'), ('refused', 'FAILED')]);

    await manager.retryFailed();
    expect((await queued()).map((o) => o.status), ['PENDING', 'PENDING']);
  });

  test('isTemporary: no connection and 5xx only', () {
    expect(SyncManager.isTemporary(const NetworkFailure()), isTrue);
    expect(SyncManager.isTemporary(const ServerFailure(statusCode: 502)), isTrue);
    expect(SyncManager.isTemporary(const ServerFailure(statusCode: 409)), isFalse);
    expect(SyncManager.isTemporary(const UnauthorizedFailure()), isFalse);
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
    expect((await queued()).single.lastError, SyncManager.networkError);
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

  test('operations left SYNCING by a closed app go back to PENDING', () async {
    await add('t1', 'e1');
    await db.update(db.localSyncOperations).write(const LocalSyncOperationsCompanion(status: Value('SYNCING')));

    await manager.resetInterrupted();

    expect((await queued()).single.status, 'PENDING');
  });

  test('reports when a change is queued, not when only a status changes', () async {
    final seen = <DateTime?>[];
    final subscription = manager.watchLatestChange().listen(seen.add);
    addTearDown(subscription.cancel);
    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

    await settle();
    await add('t1', 'e1');
    await settle();
    await db.update(db.localSyncOperations).write(const LocalSyncOperationsCompanion(status: Value('SYNCING')));
    await settle();

    expect(seen, hasLength(2));
    expect(seen.first, isNull);
    expect(seen.last, isNotNull);
  });

  group('pull', () {
    Map<String, Object?> taskJson(String id, String title, {String status = 'ASSIGNED'}) => {
          'id': id,
          'title': title,
          'description': null,
          'priority': 'HIGH',
          'status': status,
          'dueDate': '2026-10-02T09:00:00Z',
          'createdBy': {'id': 'm1', 'fullName': 'Mia Manager'},
          'reviewer': {'id': 'm1', 'fullName': 'Mia Manager'},
          'assignee': {'id': 'u1', 'fullName': 'Wendy Worker'},
          'version': 4,
          'createdAt': '2026-10-01T08:00:00Z',
          'updatedAt': '2026-10-01T08:30:00Z',
        };
    Map<String, Object?> pulled(String id, String title) => {
          'task': taskJson(id, title),
          'requirements': [
            {'id': 'r-$id-new', 'title': 'Fridge temperature', 'description': null, 'type': 'NUMBER',
             'required': true, 'position': 0, 'unit': '°C', 'options': <Object?>[]},
          ],
        };

    /// Answers pulls with [body]; records the `since` of every pull.
    List<Object?> servePull(Map<String, Object?> body) {
      final sinces = <Object?>[];
      api.dio.httpClientAdapter = FakeServer((request) async {
        if (request.path == '/api/sync/pull') {
          sinces.add(request.queryParameters['since']);
          return (200, body);
        }
        final operations = ((request.data as Map)['operations'] as List).cast<_Sent>();
        pushes.add(operations);
        return (200, {
          'results': [for (final o in operations) {'id': o['id'], 'status': 'APPLIED'}],
        });
      });
      return sinces;
    }

    Future<List<String>> localTitles() async =>
        (await TaskLocalDataSource(db).watchTasks().first).map((t) => t.title).toList();

    test('stores changed tasks with their requirements and removes tasks no longer visible', () async {
      servePull({
        'cursor': '2026-10-01T10:00:00Z',
        'taskIds': ['t1', 't3'],
        'tasks': [pulled('t1', 'Kitchen (new)'), pulled('t3', 'Warehouse')],
      });

      expect(await manager.pull(), isA<Ok<void>>());

      expect(await localTitles(), ['Kitchen (new)', 'Warehouse']);
      final requirements = await TaskLocalDataSource(db).watchRequirements('t3').first;
      expect(requirements.single.unit, '°C');
    });

    test('the first pull loads everything, the next one only changes since its cursor', () async {
      final sinces = servePull({'cursor': '2026-10-01T10:00:00Z', 'taskIds': ['t1', 't2'], 'tasks': <Object?>[]});

      await manager.pull();
      await manager.pull();

      expect(sinces, [null, '2026-10-01T10:00:00Z']);
    });

    test('a task with unsent changes keeps its local version and is not removed', () async {
      await add('t2', 'e1');
      servePull({'cursor': 'c', 'taskIds': ['t1'], 'tasks': [pulled('t1', 'Kitchen (new)')]});

      await manager.pull();

      expect(await localTitles(), ['Kitchen (new)', 'Task t2']);
    });

    test('offline: nothing changes and the cursor stays', () async {
      servePull({'cursor': 'c1', 'taskIds': ['t1', 't2'], 'tasks': <Object?>[]});
      await manager.pull();
      api.dio.httpClientAdapter = FakeServer((_) async => (0, null));

      final result = await manager.pull();

      expect((result as Err<void>).failure, isA<NetworkFailure>());
      expect(await localTitles(), ['Task t1', 'Task t2']);
      final cursor = await db.select(db.localSyncState).getSingle();
      expect(cursor.value, 'c1');
    });

    test('sync pushes first, then pulls', () async {
      await add('t1', 'e1');
      final sinces = servePull({'cursor': 'c', 'taskIds': ['t1', 't2'], 'tasks': <Object?>[]});

      expect(await manager.sync(), isA<Ok<void>>());

      expect(pushes, hasLength(1));
      expect(sinces, hasLength(1));
      expect(await queued(), isEmpty);
    });

    test('no pull when the push fails', () async {
      await add('t1', 'e1');
      var pulls = 0;
      api.dio.httpClientAdapter = FakeServer((request) async {
        if (request.path == '/api/sync/pull') {
          pulls++;
        }
        return (0, null);
      });

      expect(await manager.sync(), isA<Err<void>>());
      expect(pulls, 0);
    });
  });
}
