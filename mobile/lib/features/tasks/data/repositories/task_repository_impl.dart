import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/data/remote/task_remote_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  const TaskRepositoryImpl(this._local, this._remote);

  final TaskLocalDataSource _local;
  final TaskRemoteDataSource _remote;

  @override
  Stream<List<Task>> watchTasks({TaskStatus? status}) => _local.watchTasks(status: status);

  @override
  Stream<Task?> watchTask(String id) => _local.watchTask(id);

  @override
  Stream<List<Requirement>> watchRequirements(String taskId) => _local.watchRequirements(taskId);

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

    // TODO(phase-6): keep tasks with unsynced local changes.
    await _local.replaceAll([for (final task in loaded) (task, requirements[task.id]!)]);
    return const Ok(null);
  }

  @override
  Future<Result<Task>> start(String taskId) async {
    final result = await _remote.start(taskId);
    if (result case Ok(:final value)) {
      await _local.updateTask(value);
    }
    return result;
  }
}
