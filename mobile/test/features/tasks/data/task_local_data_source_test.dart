import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
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
    repository = TaskRepositoryImpl(local);
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
}
