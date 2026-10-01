import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

/// The assigned worker starts working on a task.
class StartTask {
  const StartTask(this._repository);

  final TaskRepository _repository;

  /// Statuses from which the worker can start (again).
  static const startable = {TaskStatus.assigned, TaskStatus.rejected, TaskStatus.correctionRequested};

  /// Whether [userId] may start [task] now.
  static bool canStart(Task task, String userId) =>
      startable.contains(task.status) && task.assignee?.id == userId;

  Future<Result<Task>> call(String taskId) => _repository.start(taskId);
}
