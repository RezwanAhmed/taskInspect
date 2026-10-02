import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/domain/entities/history_entry.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement_draft.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_draft.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_review.dart';
import 'package:taskinspect/features/tasks/domain/entities/team_task.dart';

/// Tasks as the screens see them. Everything is read from the local
/// database as live streams, so screens update by themselves and work the
/// same offline (ADR-0004). [refresh] brings the device up to date with
/// the server.
abstract interface class TaskRepository {
  /// Tasks sorted by due date, optionally only one [status].
  Stream<List<Task>> watchTasks({TaskStatus? status});

  /// The team members' tasks (tiles) sorted by due date (Phase 7A, workers only).
  Stream<List<TeamTask>> watchTeamTasks();

  /// One task, or `null` if it is not on the device.
  Stream<Task?> watchTask(String id);

  /// The requirements of a task in the order the worker completes them.
  Stream<List<Requirement>> watchRequirements(String taskId);

  /// The task's latest review (why it came back to the worker), or `null`.
  Stream<TaskReview?> watchReview(String taskId);

  /// The task's history from the server, oldest first (needs a connection).
  Future<Result<List<HistoryEntry>>> loadHistory(String taskId);

  /// Loads the tasks the user may see (with their requirements) from the
  /// server and stores them, removing tasks that are no longer there.
  /// Tasks with unsent local changes are kept as they are. On failure the
  /// local data stays as it was.
  Future<Result<void>> refresh();

  /// A manager creates a draft task (works offline: stored on the device and
  /// sent to the server at the next sync).
  Future<Result<Task>> createDraft(TaskDraft draft, {required PersonRef creator});

  /// The creator changes a task's details while it is DRAFT, OPEN or
  /// ASSIGNED (works offline, like [createDraft]).
  Future<Result<Task>> updateDraft(String taskId, TaskDraft draft);

  /// Requirement changes of a task's creator (work offline, sent at the
  /// next sync like drafts).
  Future<Result<Requirement>> addRequirement(String taskId, RequirementDraft draft);

  Future<Result<void>> updateRequirement(String taskId, String requirementId, RequirementDraft draft);

  Future<Result<void>> deleteRequirement(String taskId, String requirementId);

  Future<Result<void>> reorderRequirements(String taskId, List<String> requirementIds);

  /// The sub-tasks of a main task from the server (needs a connection;
  /// not stored on the device).
  Future<Result<List<Task>>> loadSubTasks(String mainTaskId);

  /// A worker takes an open task (needs a connection). On success the task
  /// is stored as theirs; when someone else took it first (or it is no
  /// longer open to them) it is removed from the device.
  Future<Result<Task>> take(String taskId);

  /// The assigned worker starts the task (or starts again after a reject
  /// or correction request). Works offline: the task is started on the
  /// device and the start is sent to the server by the sync queue.
  Future<Result<Task>> start(String taskId);

  /// The assigned worker submits the task for review. Works offline: the
  /// task is submitted on the device and the submit is sent to the server
  /// by the sync queue, after the task's files are uploaded.
  Future<Result<Task>> submit(String taskId);
}
