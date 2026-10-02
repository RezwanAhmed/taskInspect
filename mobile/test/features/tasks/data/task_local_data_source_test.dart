import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/data/remote/task_remote_data_source.dart';
import 'package:taskinspect/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_draft.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

Task task(String id, String title, DateTime due, {TaskStatus status = TaskStatus.assigned}) => Task(
      id: id,
      title: title,
      priority: TaskPriority.high,
      status: status,
      dueDate: due,
      createdBy: const PersonRef(id: 'm1', name: 'Mia Manager'),
      reviewer: const PersonRef(id: 'm1', name: 'Mia Manager'),
      assignee: const PersonRef(id: 'w1', name: 'Wendy Worker'),
      version: 1,
      updatedAt: DateTime.utc(2026, 10, 1),
    );

void main() {
  late AppDatabase db;
  late TaskLocalDataSource local;
  late TaskRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    local = TaskLocalDataSource(db);
    repository = TaskRepositoryImpl(local, TaskRemoteDataSource(
        ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://unused.test'))));
  });

  tearDown(() => db.close());

  test('stores tasks and lists them by due date', () async {
    await local.saveTask(task('t2', 'Warehouse', DateTime.utc(2026, 10, 5)), []);
    await local.saveTask(task('t1', 'Kitchen', DateTime.utc(2026, 10, 2)), []);

    final tasks = await repository.watchTasks().first;

    expect(tasks.map((t) => t.title), ['Kitchen', 'Warehouse']);
    expect(tasks.first.assignee!.name, 'Wendy Worker');
    expect(tasks.first.dueDate, DateTime.utc(2026, 10, 2));
  });

  test('filters by status', () async {
    await local.saveTask(task('t1', 'Kitchen', DateTime.utc(2026, 10, 2)), []);
    await local.saveTask(task('t2', 'Warehouse', DateTime.utc(2026, 10, 5), status: TaskStatus.inProgress), []);

    final inProgress = await repository.watchTasks(status: TaskStatus.inProgress).first;

    expect(inProgress.map((t) => t.id), ['t2']);
  });

  test('stores requirements in order with their options', () async {
    await local.saveTask(task('t1', 'Kitchen', DateTime.utc(2026, 10, 2)), const [
      Requirement(id: 'r2', taskId: 't1', title: 'Floor', type: RequirementType.dropdown, required: false,
          position: 1, options: [
            RequirementOption(id: 'o2', label: 'Dirty', position: 1),
            RequirementOption(id: 'o1', label: 'Clean', position: 0),
          ]),
      Requirement(id: 'r1', taskId: 't1', title: 'Fridge temperature', type: RequirementType.number,
          required: true, position: 0, unit: '°C'),
    ]);

    final requirements = await repository.watchRequirements('t1').first;

    expect(requirements.map((r) => r.title), ['Fridge temperature', 'Floor']);
    expect(requirements.first.unit, '°C');
    expect(requirements.last.options.map((o) => o.label), ['Clean', 'Dirty']);
    expect(requirements.last.required, isFalse);
  });

  test('saving a task again replaces it and its requirements', () async {
    const first = [Requirement(id: 'r1', taskId: 't1', title: 'Old', type: RequirementType.text,
        required: true, position: 0)];
    await local.saveTask(task('t1', 'Kitchen', DateTime.utc(2026, 10, 2)), first);

    await local.saveTask(task('t1', 'Kitchen check', DateTime.utc(2026, 10, 2), status: TaskStatus.inProgress), []);

    final saved = await repository.watchTask('t1').first;
    expect(saved!.title, 'Kitchen check');
    expect(saved.status, TaskStatus.inProgress);
    expect(await repository.watchRequirements('t1').first, isEmpty);
  });

  test('watchers see changes as they happen', () async {
    final updates = repository.watchTasks().map((tasks) => tasks.length);
    final expectation = expectLater(updates, emitsInOrder([0, 1]));

    await Future<void>.delayed(const Duration(milliseconds: 10));
    await local.saveTask(task('t1', 'Kitchen', DateTime.utc(2026, 10, 2)), []);

    await expectation;
  });

  test('tasks no longer on the server are removed with their requirements', () async {
    await local.saveTask(task('t1', 'Kitchen', DateTime.utc(2026, 10, 2)), const [
      Requirement(id: 'r1', taskId: 't1', title: 'Ok?', type: RequirementType.yesNo, required: true, position: 0),
    ]);
    await local.saveTask(task('t2', 'Warehouse', DateTime.utc(2026, 10, 5)), []);

    await local.deleteTasksExcept({'t2'});

    expect((await repository.watchTasks().first).map((t) => t.id), ['t2']);
    expect(await repository.watchRequirements('t1').first, isEmpty);
  });

  test('overdue means past due and still open', () {
    final now = DateTime.utc(2026, 10, 3);
    expect(task('t', 'x', DateTime.utc(2026, 10, 2)).isOverdue(now), isTrue);
    expect(task('t', 'x', DateTime.utc(2026, 10, 2), status: TaskStatus.approved).isOverdue(now), isFalse);
    expect(task('t', 'x', DateTime.utc(2026, 10, 4)).isOverdue(now), isFalse);
  });

  test("an update from the server keeps the worker's answers and evidence; a removed requirement takes its own", () async {
    Requirement requirement(String id, int position) =>
        Requirement(id: id, taskId: 't1', title: 'Q $id', type: RequirementType.yesNo, required: true, position: position);
    await local.saveTask(task('t1', 'Kitchen', DateTime.utc(2026, 10, 2)), [requirement('r1', 0), requirement('r2', 1)]);
    for (final id in ['r1', 'r2']) {
      await db.customStatement(
          "INSERT INTO local_responses (requirement_id, task_id, boolean_value, updated_at, sync_status) VALUES ('$id', 't1', 1, 0, 'SYNCED')");
    }
    await db.customStatement('INSERT INTO local_evidence (id, task_id, requirement_id, local_path, mime_type, size_bytes, '
        "created_at, upload_status) VALUES ('e1', 't1', 'r1', '/e1.jpg', 'image/jpeg', 5, 0, 'UPLOADED')");

    // The manager renamed r1 and removed r2.
    await local.saveTask(task('t1', 'Kitchen', DateTime.utc(2026, 10, 2)), const [
      Requirement(id: 'r1', taskId: 't1', title: 'Renamed', type: RequirementType.yesNo, required: true, position: 0),
    ]);

    final answers = await db.select(db.localResponses).get();
    expect(answers.map((a) => a.requirementId), ['r1']);
    expect(await db.select(db.localEvidence).get(), hasLength(1));
    expect((await db.select(db.localRequirements).getSingle()).title, 'Renamed');
  });

  group('drafts made on the device', () {
    const mia = PersonRef(id: 'm1', name: 'Mia Manager');
    final draft = TaskDraft(title: 'Boiler room', priority: TaskPriority.high, dueDate: DateTime.utc(2026, 12, 1, 9));

    Future<List<SyncOperationRow>> queue() =>
        (db.select(db.localSyncOperations)..orderBy([(o) => OrderingTerm(expression: o.createdAt)])).get();

    test('a new draft is stored and its CREATE queued, with the ID made here', () async {
      final created = await local.createDraft(draft, creator: mia);

      final stored = await local.watchTask(created.id).first;
      expect(stored!.status, TaskStatus.draft);
      expect(stored.reviewer, mia);
      final operations = await queue();
      expect(operations.single.operation, 'CREATE');
      expect(operations.single.entityType, 'Task');
      expect(operations.single.taskId, created.id);
      expect(jsonDecode(operations.single.payload), {
        'title': 'Boiler room',
        'description': null,
        'priority': 'HIGH',
        'dueDate': '2026-12-01T09:00:00.000Z',
        'reviewerId': null,
      });
    });

    test('editing before the CREATE is sent changes the CREATE', () async {
      final created = await local.createDraft(draft, creator: mia);

      await local.updateDraft(created.id, TaskDraft(title: 'Boiler room 2', priority: TaskPriority.low,
          dueDate: DateTime.utc(2026, 12, 2, 9)));

      final operations = await queue();
      expect(operations.single.operation, 'CREATE');
      expect((jsonDecode(operations.single.payload) as Map)['title'], 'Boiler room 2');
      expect((await local.watchTask(created.id).first)!.title, 'Boiler room 2');
    });

    test('once its CREATE is being sent (or failed), an edit queues an UPDATE', () async {
      final created = await local.createDraft(draft, creator: mia);
      await db.update(db.localSyncOperations).write(const LocalSyncOperationsCompanion(status: Value('FAILED')));

      await local.updateDraft(created.id, draft);

      expect([for (final o in await queue()) o.operation], ['CREATE', 'UPDATE']);
    });

    test('editing a task already on the server queues an UPDATE with its version', () async {
      await local.saveTask(task('t1', 'Kitchen', DateTime.utc(2026, 10, 2)), const []);

      await local.updateDraft('t1', draft);
      await local.updateDraft('t1', draft);

      final operations = await queue();
      expect(operations.single.operation, 'UPDATE');
      expect((jsonDecode(operations.single.payload) as Map)['version'], 1);
    });

    test('a started task can no longer be edited', () async {
      await local.saveTask(task('t1', 'Kitchen', DateTime.utc(2026, 10, 2), status: TaskStatus.inProgress), const []);

      expect(await local.updateDraft('t1', draft), isNull);
      expect(await repository.updateDraft('t1', draft), isA<Err<Task>>());
      expect(await queue(), isEmpty);
    });
  });
}
