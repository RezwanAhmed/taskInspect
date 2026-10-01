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

  test('starting a task updates it on the device and keeps its requirements', () async {
    await local.replaceAll([(TaskRemoteDataSource.taskFromJson(taskJson('t1', 'Kitchen')), [
      TaskRemoteDataSource.requirementFromJson('t1', requirements.first),
    ])]);
    serve((path, query) async => path == '/api/tasks/t1/start'
        ? (200, taskJson('t1', 'Kitchen', status: 'IN_PROGRESS'))
        : (404, null));

    final result = await repository.start('t1');

    expect((result as Ok<Task>).value.status, TaskStatus.inProgress);
    expect((await repository.watchTask('t1').first)!.status, TaskStatus.inProgress);
    expect(await repository.watchRequirements('t1').first, hasLength(1));
  });

  test('a refused start changes nothing on the device', () async {
    await local.replaceAll([(TaskRemoteDataSource.taskFromJson(taskJson('t1', 'Kitchen')), [])]);
    serve((path, query) async => (409, {'code': 'TASK_INVALID_TRANSITION', 'message': 'Cannot start'}));

    expect(await repository.start('t1'), isA<Err<Object?>>());
    expect((await repository.watchTask('t1').first)!.status, TaskStatus.assigned);
  });
}
