import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_review.dart';

/// Reads and writes tasks and requirements in the local database.
class TaskLocalDataSource {
  TaskLocalDataSource(this._db, {SyncQueue? queue}) : _queue = queue ?? SyncQueue(_db);

  final AppDatabase _db;
  final SyncQueue _queue;

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
  ///
  /// Requirements are updated in place, not deleted and inserted again:
  /// the worker's answers and evidence belong to them (deleting a
  /// requirement deletes them too). Only requirements the manager removed
  /// are deleted.
  Future<void> saveTask(Task task, List<Requirement> requirements) {
    return _db.transaction(() async {
      await _db.into(_db.localTasks).insertOnConflictUpdate(_toTaskRow(task));
      final ids = [for (final requirement in requirements) requirement.id];
      await (_db.delete(_db.localRequirements)..where((r) => r.taskId.equals(task.id) & r.id.isNotIn(ids))).go();
      for (final requirement in requirements) {
        await _db.into(_db.localRequirements).insertOnConflictUpdate(LocalRequirementsCompanion.insert(
              id: requirement.id,
              taskId: task.id,
              title: requirement.title,
              description: Value(requirement.description),
              type: requirement.type.apiName,
              isRequired: requirement.required,
              position: requirement.position,
              unit: Value(requirement.unit),
            ));
        await (_db.delete(_db.localRequirementOptions)..where((o) => o.requirementId.equals(requirement.id))).go();
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
  /// Tasks with changes in the sync queue that are still on their way keep
  /// their local version, so the server's older copy can't undo them.
  Future<void> replaceAll(List<(Task, List<Requirement>)> tasks) =>
      applyServerChanges(tasks, {for (final (task, _) in tasks) task.id});

  /// Stores the [changed] tasks and removes the tasks that are not in
  /// [visibleIds] any more, in one transaction. Tasks with unsent changes
  /// keep their local version, as in [replaceAll].
  ///
  /// [reviews] (from the sync pull) are the changed tasks' latest reviews;
  /// they are stored for every task on the device, also one with unsent
  /// changes (the review doesn't touch the worker's own changes).
  Future<void> applyServerChanges(
    List<(Task, List<Requirement>)> changed,
    Set<String> visibleIds, {
    Map<String, TaskReview?>? reviews,
  }) {
    return _db.transaction(() async {
      final unsent = await _taskIdsWithUnsentChanges();
      for (final (task, requirements) in changed) {
        if (!unsent.contains(task.id)) {
          await saveTask(task, requirements);
        }
      }
      for (final MapEntry(key: taskId, value: review) in (reviews ?? const <String, TaskReview?>{}).entries) {
        await _saveReview(taskId, review);
      }
      // A task with anything left in the queue stays on the device, even
      // when the server no longer shows it (e.g. reassigned after a refused
      // change): its answers, evidence and the failure stay visible.
      await deleteTasksExcept({...visibleIds, ...await _taskIdsInQueue()});
    });
  }

  Future<Set<String>> _taskIdsInQueue() {
    final queue = _db.localSyncOperations;
    final query = _db.selectOnly(queue, distinct: true)..addColumns([queue.taskId]);
    return query.map((row) => row.read(queue.taskId)!).get().then((ids) => ids.toSet());
  }

  /// Starts a task on the device and queues the START for the server, in
  /// one transaction, so it works offline. Returns the started task, or
  /// `null` if it is not on the device.
  Future<Task?> start(String taskId) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.localTasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
      if (row == null) {
        return null;
      }
      final started = row.copyWith(status: TaskStatus.inProgress.apiName);
      await _db.update(_db.localTasks).replace(started);
      // The server refuses the start if the task changed in the meantime.
      await _queue.add(
        entity: SyncEntity.task,
        entityId: taskId,
        taskId: taskId,
        operation: SyncOperation.start,
        payload: {'version': row.version},
      );
      return _toTask(started);
    });
  }

  /// The task's latest review, or `null` (none, or not on the device).
  Stream<TaskReview?> watchReview(String taskId) {
    return (_db.select(_db.localTaskReviews)..where((r) => r.taskId.equals(taskId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _toReview(row));
  }

  Future<void> _saveReview(String taskId, TaskReview? review) async {
    if (review == null) {
      await (_db.delete(_db.localTaskReviews)..where((r) => r.taskId.equals(taskId))).go();
      return;
    }
    final onDevice = await (_db.select(_db.localTasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (onDevice == null) {
      return;
    }
    await _db.into(_db.localTaskReviews).insertOnConflictUpdate(LocalTaskReviewsCompanion.insert(
          taskId: taskId,
          result: review.result.apiName,
          reason: Value(review.reason),
          reviewerName: review.reviewerName,
          createdAt: review.createdAt,
          markedRequirements: Value(jsonEncode(review.markedRequirements)),
        ));
  }

  static TaskReview _toReview(TaskReviewRow row) => TaskReview(
        result: ReviewResult.fromApi(row.result),
        reason: row.reason,
        reviewerName: row.reviewerName,
        createdAt: row.createdAt.toUtc(),
        markedRequirements: (jsonDecode(row.markedRequirements) as Map<String, Object?>).cast<String, String>(),
      );

  /// Submits a task on the device and queues the SUBMIT for the server, in
  /// one transaction, so it works offline ("Submitted locally - waiting for
  /// synchronization"). The sync sends it once the task's files are
  /// uploaded; it replaces an earlier submit the server refused. Returns
  /// the submitted task, or `null` if it is not on the device or not
  /// IN_PROGRESS (e.g. submitted already).
  Future<Task?> submit(String taskId) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.localTasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
      if (row == null || row.status != TaskStatus.inProgress.apiName) {
        return null;
      }
      await (_db.delete(_db.localSyncOperations)
            ..where((o) =>
                o.taskId.equals(taskId) &
                o.operation.equals(SyncOperation.submit.apiName) &
                o.status.equals('FAILED') &
                o.lastError.isNotIn(SyncErrors.temporary)))
          .go();
      final submitted = row.copyWith(status: TaskStatus.submitted.apiName);
      await _db.update(_db.localTasks).replace(submitted);
      await _queue.add(
        entity: SyncEntity.task,
        entityId: taskId,
        taskId: taskId,
        operation: SyncOperation.submit,
        payload: {'version': row.version},
      );
      return _toTask(submitted);
    });
  }

  /// Tasks with changes that are still on their way: waiting, being sent,
  /// or failed for a temporary reason. A task with a change the server
  /// refused doesn't count, even if later changes wait behind it: then the
  /// server's version of the task wins (e.g. the manager cancelled it
  /// meanwhile), as in docs/architecture.md "Conflicts".
  Future<Set<String>> _taskIdsWithUnsentChanges() async {
    final queue = _db.localSyncOperations;
    final refused = queue.status.equals('FAILED') & queue.lastError.isNotIn(SyncErrors.temporary);
    Future<Set<String>> taskIds(Expression<bool> where) {
      final query = _db.selectOnly(queue, distinct: true)
        ..addColumns([queue.taskId])
        ..where(where);
      return query.map((row) => row.read(queue.taskId)!).get().then((ids) => ids.toSet());
    }

    final onTheirWay = await taskIds(queue.status.isIn(['PENDING', 'SYNCING']) |
        (queue.status.equals('FAILED') & queue.lastError.isIn(SyncErrors.temporary)));
    return onTheirWay.difference(await taskIds(refused));
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
