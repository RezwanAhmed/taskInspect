import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/data/remote/task_remote_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/history_entry.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_draft.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_review.dart';
import 'package:taskinspect/features/tasks/domain/entities/team_task.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  const TaskRepositoryImpl(this._local, this._remote);

  final TaskLocalDataSource _local;
  final TaskRemoteDataSource _remote;

  @override
  Stream<List<Task>> watchTasks({TaskStatus? status}) => _local.watchTasks(status: status);

  @override
  Stream<List<TeamTask>> watchTeamTasks() => _local.watchTeamTasks();

  @override
  Stream<Task?> watchTask(String id) => _local.watchTask(id);

  @override
  Stream<List<Requirement>> watchRequirements(String taskId) => _local.watchRequirements(taskId);

  @override
  Stream<TaskReview?> watchReview(String taskId) => _local.watchReview(taskId);

  @override
  Future<Result<List<HistoryEntry>>> loadHistory(String taskId) => _remote.fetchHistory(taskId);

  @override
  Future<Result<void>> refresh() async {
    final tasks = await _remote.fetchTasks();
    if (tasks case Err(:final failure)) {
      return Err(failure);
    }
    final loaded = (tasks as Ok<List<Task>>).value;

    // Load everything first, so a failure half-way leaves the device unchanged.
    final requirements = <String, List<Requirement>>{};
    for (final task in loaded) {
      switch (await _remote.fetchRequirements(task.id)) {
        case Ok(:final value):
          requirements[task.id] = value;
        case Err(:final failure):
          return Err(failure);
      }
    }

    // Tasks with unsent local changes keep their local version.
    await _local.replaceAll([for (final task in loaded) (task, requirements[task.id]!)]);
    return const Ok(null);
  }

  @override
  Future<Result<Task>> createDraft(TaskDraft draft, {required PersonRef creator}) async =>
      Ok(await _local.createDraft(draft, creator: creator));

  @override
  Future<Result<Task>> updateDraft(String taskId, TaskDraft draft) async {
    final updated = await _local.updateDraft(taskId, draft);
    return updated == null
        ? const Err(InvalidInputFailure(field: 'task', message: 'This task can no longer be edited.'))
        : Ok(updated);
  }

  @override
  Future<Result<List<Task>>> loadSubTasks(String mainTaskId) => _remote.fetchSubTasks(mainTaskId);

  @override
  Future<Result<Task>> take(String taskId) async {
    final result = await _remote.take(taskId);
    switch (result) {
      case Ok(:final value):
        await _local.saveTaskDetails(value);
      case Err(failure: ServerFailure(code: 'TASK_ALREADY_TAKEN' || 'TASK_NOT_FOUND')):
        await _local.deleteTask(taskId);
      case Err():
        break;
    }
    return result;
  }

  @override
  Future<Result<Task>> start(String taskId) async {
    final started = await _local.start(taskId);
    return started == null ? Err(UnexpectedFailure(StateError('Task $taskId is not on the device'))) : Ok(started);
  }

  @override
  Future<Result<Task>> submit(String taskId) async {
    final submitted = await _local.submit(taskId);
    return submitted == null
        ? Err(UnexpectedFailure(StateError('Task $taskId is not on the device or not in progress')))
        : Ok(submitted);
  }
}
