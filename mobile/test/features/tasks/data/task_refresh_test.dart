import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/data/remote/task_remote_data_source.dart';
import 'package:taskinspect/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../../helpers/fake_server.dart';

Map<String, Object?> taskJson(String id, String title, {String status = 'ASSIGNED'}) => {
      'id': id,
      'title': title,
      'description': null,
      'priority': 'HIGH',
      'status': status,
      'dueDate': '2026-10-02T09:00:00Z',
      'createdBy': {'id': 'm1', 'fullName': 'Mia Manager'},
      'reviewer': {'id': 'm1', 'fullName': 'Mia Manager'},
      'assignee': {'id': 'w1', 'fullName': 'Wendy Worker'},
      'version': 3,
      'createdAt': '2026-10-01T08:00:00Z',
      'updatedAt': '2026-10-01T08:30:00Z',
    };

Map<String, Object?> page(List<Object?> content, int page, int totalPages) =>
    {'content': content, 'page': page, 'size': 1, 'totalElements': content.length, 'totalPages': totalPages};

final requirements = [
  {'id': 'r1', 'title': 'Fridge temperature', 'description': null, 'type': 'NUMBER', 'required': true,
   'position': 0, 'unit': '°C', 'options': <Object?>[]},
  {'id': 'r2', 'title': 'Floor', 'description': 'Pick one', 'type': 'DROPDOWN', 'required': false,
   'position': 1, 'unit': null, 'options': [
     {'id': 'o1', 'label': 'Clean', 'position': 0},
     {'id': 'o2', 'label': 'Dirty', 'position': 1},
   ]},
];

void main() {
  late AppDatabase db;
  late ApiClient api;
  late TaskLocalDataSource local;
  late TaskRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    local = TaskLocalDataSource(db);
    repository = TaskRepositoryImpl(local, TaskRemoteDataSource(api, pageSize: 1));
  });

  tearDown(() => db.close());

  FakeServer serve(Future<(int, Object?)> Function(String path, Map<String, Object?> query) handle) {
    final server = FakeServer((r) => handle(r.path, r.queryParameters));
    api.dio.httpClientAdapter = server;
    return server;
  }

  test('loads all pages of tasks with their requirements into the device', () async {
    final server = serve((path, query) async => switch (path) {
          '/api/tasks' when query['page'] == 0 => (200, page([taskJson('t1', 'Kitchen')], 0, 2)),
          '/api/tasks' => (200, page([taskJson('t2', 'Warehouse', status: 'IN_PROGRESS')], 1, 2)),
          '/api/tasks/t1/requirements' => (200, requirements),
          _ => (200, <Object?>[]),
        });

    expect(await repository.refresh(), isA<Ok<void>>());

    final tasks = await repository.watchTasks().first;
    expect(tasks.map((t) => t.title), ['Kitchen', 'Warehouse']);
    expect(tasks.last.status, TaskStatus.inProgress);
    expect(tasks.first.assignee!.name, 'Wendy Worker');
    expect(tasks.first.version, 3);
    expect(server.count('/api/tasks'), 2);
    final loaded = await repository.watchRequirements('t1').first;
    expect(loaded.map((r) => r.type), [RequirementType.number, RequirementType.dropdown]);
    expect(loaded.first.unit, '°C');
    expect(loaded.last.options.map((o) => o.label), ['Clean', 'Dirty']);
  });

  test('tasks that are no longer on the server are removed', () async {
    await local.replaceAll([(TaskRemoteDataSource.taskFromJson(taskJson('old', 'Old task')), [])]);
    serve((path, query) async => path == '/api/tasks'
        ? (200, page([taskJson('t1', 'Kitchen')], 0, 1))
        : (200, <Object?>[]));

    await repository.refresh();

    expect((await repository.watchTasks().first).map((t) => t.id), ['t1']);
  });

  test('offline: the failure is returned and the device keeps its tasks', () async {
    await local.replaceAll([(TaskRemoteDataSource.taskFromJson(taskJson('t1', 'Kitchen')), [])]);
    serve((path, query) async => (0, null));

    final result = await repository.refresh();

    expect((result as Err<void>).failure, isA<NetworkFailure>());
    expect((await repository.watchTasks().first).map((t) => t.id), ['t1']);
  });

  test('a failure half-way changes nothing', () async {
    await local.replaceAll([(TaskRemoteDataSource.taskFromJson(taskJson('t1', 'Kitchen')), [])]);
    serve((path, query) async => path == '/api/tasks'
        ? (200, page([taskJson('t2', 'Warehouse')], 0, 1))
        : (500, {'code': 'INTERNAL_ERROR'}));

    expect(await repository.refresh(), isA<Err<void>>());
    expect((await repository.watchTasks().first).map((t) => t.id), ['t1']);
  });

  test('starting a task works offline: started on the device and queued for the server', () async {
    await local.replaceAll([(TaskRemoteDataSource.taskFromJson(taskJson('t1', 'Kitchen')), [
      TaskRemoteDataSource.requirementFromJson('t1', requirements.first),
    ])]);
    final server = serve((path, query) async => (0, null));

    final result = await repository.start('t1');

    expect((result as Ok<Task>).value.status, TaskStatus.inProgress);
    expect((await repository.watchTask('t1').first)!.status, TaskStatus.inProgress);
    expect(await repository.watchRequirements('t1').first, hasLength(1));
    expect(server.count('/api/tasks/t1/start'), 0);
    final queued = await db.select(db.localSyncOperations).getSingle();
    expect(queued.entityType, 'Task');
    expect(queued.entityId, 't1');
    expect(queued.operation, 'START');
    expect(jsonDecode(queued.payload), {'version': 3});
  });

  test('starting a task that is not on the device fails and queues nothing', () async {
    expect(await repository.start('missing'), isA<Err<Task>>());
    expect(await db.select(db.localSyncOperations).get(), isEmpty);
  });

  test('a refresh keeps a task with unsent changes as it is on the device', () async {
    await local.replaceAll([
      (TaskRemoteDataSource.taskFromJson(taskJson('t1', 'Kitchen')), []),
      (TaskRemoteDataSource.taskFromJson(taskJson('t2', 'Warehouse')), []),
    ]);
    await repository.start('t1');
    // The server doesn't know about the start yet and no longer lists t2.
    serve((path, query) async => path == '/api/tasks'
        ? (200, page([taskJson('t1', 'Kitchen (renamed)')], 0, 1))
        : (200, <Object?>[]));

    expect(await repository.refresh(), isA<Ok<void>>());

    final tasks = await repository.watchTasks().first;
    expect(tasks.map((t) => (t.title, t.status)), [('Kitchen', TaskStatus.inProgress)]);
  });

  test('once its changes are sent, a task is updated from the server again', () async {
    await local.replaceAll([(TaskRemoteDataSource.taskFromJson(taskJson('t1', 'Kitchen')), [])]);
    await repository.start('t1');
    await db.update(db.localSyncOperations).write(const LocalSyncOperationsCompanion(status: Value('SYNCED')));
    serve((path, query) async => path == '/api/tasks'
        ? (200, page([taskJson('t1', 'Kitchen (renamed)', status: 'IN_PROGRESS')], 0, 1))
        : (200, <Object?>[]));

    await repository.refresh();

    expect((await repository.watchTask('t1').first)!.title, 'Kitchen (renamed)');
  });

  group('take', () {
    Future<void> storeOpenTask() async {
      await local.saveTask(
        Task(
          id: 't1',
          title: 'Boiler room',
          priority: TaskPriority.high,
          status: TaskStatus.open,
          dueDate: DateTime.utc(2026, 10, 2, 9),
          createdBy: const PersonRef(id: 'm1', name: 'Mia Manager'),
          reviewer: const PersonRef(id: 'm1', name: 'Mia Manager'),
          version: 1,
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
        const [],
      );
    }

    test('stores the taken task as the worker\'s', () async {
      await storeOpenTask();
      api.dio.httpClientAdapter = FakeServer((request) async {
        expect(request.path, '/api/tasks/t1/take');
        return (200, taskJson('t1', 'Boiler room'));
      });

      final result = await repository.take('t1');

      expect(result, isA<Ok<Task>>());
      final stored = await local.watchTask('t1').first;
      expect(stored!.status, TaskStatus.assigned);
      expect(stored.assignee!.id, 'w1');
    });

    test('someone else was faster: the open task leaves the device', () async {
      await storeOpenTask();
      api.dio.httpClientAdapter = FakeServer(
        (_) async => (409, {'status': 409, 'code': 'TASK_ALREADY_TAKEN', 'message': 'Taken'}),
      );

      final result = await repository.take('t1');

      expect(result, isA<Err<Task>>());
      expect(await local.watchTask('t1').first, isNull);
    });

    test('no longer open to the worker (404): the open task leaves the device', () async {
      await storeOpenTask();
      api.dio.httpClientAdapter = FakeServer(
        (_) async => (404, {'status': 404, 'code': 'TASK_NOT_FOUND', 'message': 'Task not found'}),
      );

      expect(await repository.take('t1'), isA<Err<Task>>());
      expect(await local.watchTask('t1').first, isNull);
    });

    test('without a connection nothing changes', () async {
      await storeOpenTask();
      api.dio.httpClientAdapter = FakeServer((_) async => (0, null));

      expect(await repository.take('t1'), isA<Err<Task>>());
      expect((await local.watchTask('t1').first)!.status, TaskStatus.open);
    });
  });
}
