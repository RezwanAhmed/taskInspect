import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/worker_option.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

/// The manager who created a draft assigns it to a worker or publishes it
/// as an open task (Phase 7B). Online only; a draft whose changes are not
/// on the server yet must be synced first.
class AssignTask {
  const AssignTask(this._repository);

  final TaskRepository _repository;

  static bool canAssign(Task task, AuthUser user) =>
      user.isManager && task.createdBy.id == user.id && task.status == TaskStatus.draft;

  /// Active workers, the user's team first.
  Future<Result<List<WorkerOption>>> workers(AuthUser user) => _repository.loadWorkers(user.id);

  Future<Result<Task>> assign(String taskId, String workerId) => _repository.assign(taskId, workerId);

  Future<Result<Task>> publish(String taskId, OpenScope scope) => _repository.publish(taskId, scope);
}
