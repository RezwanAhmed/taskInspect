import 'package:drift/drift.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// Reads and writes tasks and requirements in the local database.
class TaskLocalDataSource {
  const TaskLocalDataSource(this._db);

  final AppDatabase _db;

  Stream<List<Task>> watchTasks({TaskStatus? status}) {
    final query = _db.select(_db.localTasks)
      ..orderBy([(t) => OrderingTerm(expression: t.dueDate), (t) => OrderingTerm(expression: t.title)]);
    if (status != null) {
      query.where((t) => t.status.equals(status.apiName));
    }
    return query.watch().map((rows) => rows.map(_toTask).toList());
  }

  Stream<Task?> watchTask(String id) {
    final query = _db.select(_db.localTasks)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull().map((row) => row == null ? null : _toTask(row));
  }

  Stream<List<Requirement>> watchRequirements(String taskId) {
    final query = _db.select(_db.localRequirements).join([
      leftOuterJoin(_db.localRequirementOptions,
          _db.localRequirementOptions.requirementId.equalsExp(_db.localRequirements.id)),
    ])
      ..where(_db.localRequirements.taskId.equals(taskId))
      ..orderBy([
        OrderingTerm(expression: _db.localRequirements.position),
        OrderingTerm(expression: _db.localRequirementOptions.position),
      ]);
    return query.watch().map((rows) {
      final requirements = <String, RequirementRow>{};
      final options = <String, List<RequirementOption>>{};
      for (final row in rows) {
        final requirement = row.readTable(_db.localRequirements);
        requirements[requirement.id] = requirement;
        final option = row.readTableOrNull(_db.localRequirementOptions);
        if (option != null) {
          (options[requirement.id] ??= []).add(
            RequirementOption(id: option.id, label: option.label, position: option.position),
          );
        }
      }
      return [
        for (final requirement in requirements.values) _toRequirement(requirement, options[requirement.id] ?? []),
      ];
    });
  }

  /// Stores a task and replaces its requirements, in one transaction.
  Future<void> saveTask(Task task, List<Requirement> requirements) {
    return _db.transaction(() async {
      await _db.into(_db.localTasks).insertOnConflictUpdate(_toTaskRow(task));
      await (_db.delete(_db.localRequirements)..where((r) => r.taskId.equals(task.id))).go();
      for (final requirement in requirements) {
        await _db.into(_db.localRequirements).insert(LocalRequirementsCompanion.insert(
              id: requirement.id,
              taskId: task.id,
              title: requirement.title,
              description: Value(requirement.description),
              type: requirement.type.apiName,
              isRequired: requirement.required,
              position: requirement.position,
              unit: Value(requirement.unit),
            ));
        for (final option in requirement.options) {
          await _db.into(_db.localRequirementOptions).insert(LocalRequirementOptionsCompanion.insert(
                id: option.id,
                requirementId: requirement.id,
                label: option.label,
                position: option.position,
              ));
        }
      }
    });
  }

  /// Updates a stored task without touching its requirements.
  Future<void> updateTask(Task task) => _db.into(_db.localTasks).insertOnConflictUpdate(_toTaskRow(task));

  /// Stores the server's tasks and removes all others, in one transaction.
  Future<void> replaceAll(List<(Task, List<Requirement>)> tasks) {
    return _db.transaction(() async {
      for (final (task, requirements) in tasks) {
        await saveTask(task, requirements);
      }
      await deleteTasksExcept({for (final (task, _) in tasks) task.id});
    });
  }

  /// Removes tasks that are no longer on the server (with their requirements).
  Future<void> deleteTasksExcept(Set<String> keepIds) {
    return (_db.delete(_db.localTasks)..where((t) => t.id.isNotIn(keepIds))).go();
  }

  static Task _toTask(TaskRow row) => Task(
        id: row.id,
        title: row.title,
        description: row.description,
        priority: TaskPriority.fromApi(row.priority),
        status: TaskStatus.fromApi(row.status),
        // SQLite gives back local time; the app works with UTC.
        dueDate: row.dueDate.toUtc(),
        createdBy: PersonRef(id: row.createdById, name: row.createdByName),
        reviewer: PersonRef(id: row.reviewerId, name: row.reviewerName),
        assignee: row.assigneeId == null ? null : PersonRef(id: row.assigneeId!, name: row.assigneeName ?? ''),
        version: row.version,
        updatedAt: row.updatedAt.toUtc(),
      );

  static LocalTasksCompanion _toTaskRow(Task task) => LocalTasksCompanion.insert(
        id: task.id,
        title: task.title,
        description: Value(task.description),
        priority: task.priority.apiName,
        status: task.status.apiName,
        dueDate: task.dueDate,
        createdById: task.createdBy.id,
        createdByName: task.createdBy.name,
        reviewerId: task.reviewer.id,
        reviewerName: task.reviewer.name,
        assigneeId: Value(task.assignee?.id),
        assigneeName: Value(task.assignee?.name),
        version: task.version,
        updatedAt: task.updatedAt,
      );

  static Requirement _toRequirement(RequirementRow row, List<RequirementOption> options) => Requirement(
        id: row.id,
        taskId: row.taskId,
        title: row.title,
        description: row.description,
        type: RequirementType.fromApi(row.type),
        required: row.isRequired,
        position: row.position,
        unit: row.unit,
        options: options,
      );
}
