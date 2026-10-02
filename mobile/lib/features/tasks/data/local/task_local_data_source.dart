import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement_draft.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_draft.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_review.dart';
import 'package:taskinspect/features/tasks/domain/entities/team_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/save_draft_task.dart';
import 'package:uuid/uuid.dart';

/// Reads and writes tasks and requirements in the local database.
class TaskLocalDataSource {
  TaskLocalDataSource(this._db, {SyncQueue? queue, Uuid? ids})
      : _queue = queue ?? SyncQueue(_db),
        _ids = ids ?? const Uuid();

  final AppDatabase _db;
  final SyncQueue _queue;
  final Uuid _ids;

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

  /// Team members' tasks (tiles), sorted by due date.
  Stream<List<TeamTask>> watchTeamTasks() {
    final query = _db.select(_db.localTeamTasks)
      ..orderBy([(t) => OrderingTerm(expression: t.dueDate), (t) => OrderingTerm(expression: t.title)]);
    return query.watch().map((rows) => rows.map(_toTeamTask).toList());
  }

  /// Stores the [changed] tiles and removes the tiles that are not in
  /// [visibleIds] any more (call it inside the pull's transaction).
  Future<void> applyTeamChanges(List<TeamTask> changed, Set<String> visibleIds) async {
    for (final tile in changed) {
      await _db.into(_db.localTeamTasks).insertOnConflictUpdate(LocalTeamTasksCompanion.insert(
            id: tile.id,
            title: tile.title,
            priority: tile.priority.apiName,
            status: tile.status.apiName,
            dueDate: tile.dueDate,
            assigneeId: Value(tile.assignee?.id),
            assigneeName: Value(tile.assignee?.name),
            updatedAt: tile.updatedAt,
          ));
    }
    await (_db.delete(_db.localTeamTasks)..where((t) => t.id.isNotIn(visibleIds))).go();
  }

  static TeamTask _toTeamTask(TeamTaskRow row) => TeamTask(
        id: row.id,
        title: row.title,
        priority: TaskPriority.fromApi(row.priority),
        status: TaskStatus.fromApi(row.status),
        dueDate: row.dueDate,
        assignee: row.assigneeId == null ? null : PersonRef(id: row.assigneeId!, name: row.assigneeName ?? ''),
        updatedAt: row.updatedAt,
      );

  /// Whether changes of the task are still waiting in the sync queue
  /// (e.g. a draft the server doesn't have yet).
  Future<bool> hasQueuedChanges(String taskId) async =>
      (await _taskIdsInQueue()).contains(taskId);

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
  /// Creates a draft task on the device and queues it for the server, in
  /// one transaction, so it works offline: the task gets its ID here and is
  /// sent as a `Task CREATE` at the next sync.
  Future<Task> createDraft(TaskDraft draft, {required PersonRef creator}) {
    return _db.transaction(() async {
      final task = Task(
        id: _ids.v4(),
        title: draft.title,
        description: draft.description,
        priority: draft.priority,
        status: TaskStatus.draft,
        dueDate: draft.dueDate.toUtc(),
        createdBy: creator,
        reviewer: draft.reviewer ?? creator,
        version: 0,
        updatedAt: DateTime.now().toUtc(),
      );
      await _db.into(_db.localTasks).insert(_toTaskRow(task));
      await _queue.add(
        entity: SyncEntity.task,
        entityId: task.id,
        taskId: task.id,
        operation: SyncOperation.create,
        payload: _draftPayload(draft),
      );
      return task;
    });
  }

  /// Changes a task's details on the device and queues the change, in one
  /// transaction. While the task's CREATE is still waiting to be sent, that
  /// CREATE carries the new details instead; otherwise a `Task UPDATE` with
  /// the version from the last pull is queued (the server refuses it if
  /// someone changed the task meanwhile). Returns `null` when the task is
  /// not on the device or can no longer be edited.
  Future<Task?> updateDraft(String taskId, TaskDraft draft) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.localTasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
      if (row == null || !SaveDraftTask.editable.contains(TaskStatus.fromApi(row.status))) {
        return null;
      }
      final updated = row.copyWith(
        title: draft.title,
        description: Value(draft.description),
        priority: draft.priority.apiName,
        dueDate: draft.dueDate.toUtc(),
        reviewerId: draft.reviewer?.id ?? row.createdById,
        reviewerName: draft.reviewer?.name ?? row.createdByName,
        updatedAt: DateTime.now().toUtc(),
      );
      await _db.update(_db.localTasks).replace(updated);
      final waitingCreate = await (_db.update(_db.localSyncOperations)
            ..where((o) =>
                o.taskId.equals(taskId) &
                o.entityType.equals(SyncEntity.task.apiName) &
                o.operation.equals(SyncOperation.create.apiName) &
                o.status.equals('PENDING')))
          .write(LocalSyncOperationsCompanion(payload: Value(jsonEncode(_draftPayload(draft)))));
      if (waitingCreate == 0) {
        await _queue.add(
          entity: SyncEntity.task,
          entityId: taskId,
          taskId: taskId,
          operation: SyncOperation.update,
          payload: {..._draftPayload(draft), 'version': row.version},
        );
      }
      return _toTask(updated);
    });
  }

  /// Adds a requirement at the end of the task's list on the device and
  /// queues its `Requirement CREATE` (with the ID made here), in one
  /// transaction - works offline like [createDraft].
  Future<Requirement> addRequirement(String taskId, RequirementDraft draft) {
    return _db.transaction(() async {
      final count = await (_db.select(_db.localRequirements)..where((r) => r.taskId.equals(taskId))).get();
      final requirement = _requirementFrom(_ids.v4(), taskId, count.length, draft);
      await _writeRequirement(requirement);
      await _queue.add(
        entity: SyncEntity.requirement,
        entityId: requirement.id,
        taskId: taskId,
        operation: SyncOperation.create,
        payload: _requirementPayload(draft),
      );
      return requirement;
    });
  }

  /// Changes a requirement on the device and queues the change: a still
  /// PENDING CREATE carries the new content, otherwise a `Requirement
  /// UPDATE` is queued (updates of the same requirement coalesce).
  Future<void> updateRequirement(String taskId, String requirementId, RequirementDraft draft) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.localRequirements)..where((r) => r.id.equals(requirementId)))
          .getSingleOrNull();
      if (row == null || row.taskId != taskId) {
        return;
      }
      await _writeRequirement(_requirementFrom(requirementId, taskId, row.position, draft));
      if (await _rewritePendingCreate(SyncEntity.requirement, requirementId, _requirementPayload(draft)) == 0) {
        await _queue.add(
          entity: SyncEntity.requirement,
          entityId: requirementId,
          taskId: taskId,
          operation: SyncOperation.update,
          payload: _requirementPayload(draft),
        );
      }
    });
  }

  /// Deletes a requirement on the device and closes the gap in the
  /// positions. One the server never got just leaves the queue (its CREATE
  /// and updates); otherwise a `Requirement DELETE` is queued. A waiting
  /// new order no longer names it.
  Future<void> deleteRequirement(String taskId, String requirementId) {
    return _db.transaction(() async {
      await (_db.delete(_db.localRequirements)
            ..where((r) => r.id.equals(requirementId) & r.taskId.equals(taskId)))
          .go();
      final remaining = await (_db.select(_db.localRequirements)
            ..where((r) => r.taskId.equals(taskId))
            ..orderBy([(r) => OrderingTerm(expression: r.position)]))
          .get();
      for (final (index, row) in remaining.indexed) {
        await (_db.update(_db.localRequirements)..where((r) => r.id.equals(row.id)))
            .write(LocalRequirementsCompanion(position: Value(index)));
      }
      final queue = _db.localSyncOperations;
      final neverSent = await (_db.delete(queue)
            ..where((o) =>
                o.entityType.equals(SyncEntity.requirement.apiName) &
                o.entityId.equals(requirementId) &
                o.operation.equals(SyncOperation.create.apiName) &
                o.status.equals('PENDING')))
          .go();
      await (_db.delete(queue)
            ..where((o) =>
                o.entityType.equals(SyncEntity.requirement.apiName) &
                o.entityId.equals(requirementId) &
                o.status.equals('PENDING')))
          .go();
      if (neverSent == 0) {
        await _queue.add(
          entity: SyncEntity.requirement,
          entityId: requirementId,
          taskId: taskId,
          operation: SyncOperation.delete,
        );
      }
      final waitingOrder = await (_db.select(queue)
            ..where((o) =>
                o.entityType.equals(SyncEntity.requirementOrder.apiName) &
                o.entityId.equals(taskId) &
                o.status.equals('PENDING')))
          .getSingleOrNull();
      if (waitingOrder != null) {
        await (_db.update(queue)..where((o) => o.id.equals(waitingOrder.id))).write(LocalSyncOperationsCompanion(
          payload: Value(jsonEncode({'requirementIds': [for (final row in remaining) row.id]})),
        ));
      }
    });
  }

  /// Puts the task's requirements in the given order on the device and
  /// queues a `RequirementOrder UPDATE` (later reorders replace it).
  /// [requirementIds] must name each requirement of the task exactly once
  /// (the server's rule); otherwise nothing changes and `false` is returned.
  Future<bool> reorderRequirements(String taskId, List<String> requirementIds) {
    return _db.transaction(() async {
      final current = await (_db.select(_db.localRequirements)..where((r) => r.taskId.equals(taskId))).get();
      final ids = {for (final row in current) row.id};
      if (requirementIds.length != ids.length || requirementIds.toSet().length != ids.length ||
          !ids.containsAll(requirementIds)) {
        return false;
      }
      for (final (index, id) in requirementIds.indexed) {
        await (_db.update(_db.localRequirements)..where((r) => r.id.equals(id) & r.taskId.equals(taskId)))
            .write(LocalRequirementsCompanion(position: Value(index)));
      }
      await _queue.add(
        entity: SyncEntity.requirementOrder,
        entityId: taskId,
        taskId: taskId,
        operation: SyncOperation.update,
        payload: {'requirementIds': requirementIds},
      );
      return true;
    });
  }

  Requirement _requirementFrom(String id, String taskId, int position, RequirementDraft draft) => Requirement(
        id: id,
        taskId: taskId,
        title: draft.title,
        description: draft.description,
        type: draft.type,
        required: draft.required,
        position: position,
        unit: draft.type == RequirementType.number ? draft.unit : null,
        options: draft.type.hasOptions
            ? [
                for (final (index, label) in draft.options.indexed)
                  RequirementOption(id: _ids.v4(), label: label, position: index),
              ]
            : const [],
      );

  Future<void> _writeRequirement(Requirement requirement) async {
    await _db.into(_db.localRequirements).insertOnConflictUpdate(LocalRequirementsCompanion.insert(
          id: requirement.id,
          taskId: requirement.taskId,
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

  /// Gives a still PENDING CREATE of the entity the new payload; returns
  /// how many were changed (0: the CREATE was sent already, or none).
  Future<int> _rewritePendingCreate(SyncEntity entity, String entityId, Map<String, Object?> payload) {
    return (_db.update(_db.localSyncOperations)
          ..where((o) =>
              o.entityType.equals(entity.apiName) &
              o.entityId.equals(entityId) &
              o.operation.equals(SyncOperation.create.apiName) &
              o.status.equals('PENDING')))
        .write(LocalSyncOperationsCompanion(payload: Value(jsonEncode(payload))));
  }

  static Map<String, Object?> _requirementPayload(RequirementDraft draft) => {
        'title': draft.title,
        'description': draft.description,
        'type': draft.type.apiName,
        'required': draft.required,
        'unit': draft.type == RequirementType.number ? draft.unit : null,
        'options': draft.type.hasOptions ? draft.options : null,
      };

  /// The request body for a new or changed task (CreateTaskRequest).
  static Map<String, Object?> draftPayload(TaskDraft draft) => _draftPayload(draft);

  static Map<String, Object?> _draftPayload(TaskDraft draft) => {
        'title': draft.title,
        'description': draft.description,
        'priority': draft.priority.apiName,
        'dueDate': draft.dueDate.toUtc().toIso8601String(),
        'reviewerId': draft.reviewer?.id,
      };

  /// Replaces a task's details (e.g. after taking it), keeping its
  /// requirements, answers and evidence on the device.
  Future<void> saveTaskDetails(Task task) => _db.into(_db.localTasks).insertOnConflictUpdate(_toTaskRow(task));

  /// Removes one task with its requirements (e.g. an open task someone else took).
  Future<void> deleteTask(String id) => (_db.delete(_db.localTasks)..where((t) => t.id.equals(id))).go();

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
