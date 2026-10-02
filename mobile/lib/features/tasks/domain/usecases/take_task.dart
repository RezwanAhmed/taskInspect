import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

/// A worker takes an open task; from then on it is their task
/// (docs/architecture.md, "Open Tasks"). Needs a connection.
class TakeTask {
  const TakeTask(this._repository);

  final TaskRepository _repository;

  /// Whether [user] may try to take [task]: it is open, they are a worker
  /// and not its reviewer (the server refuses that). The server only sends
  /// open tasks the worker may take.
  static bool canTake(Task task, AuthUser user) =>
      task.status == TaskStatus.open && user.isWorker && task.reviewer.id != user.id;

  Future<Result<Task>> call(String taskId) => _repository.take(taskId);
}
