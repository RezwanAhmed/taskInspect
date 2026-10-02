import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

/// Loads the sub-tasks of a main task from the server (docs/architecture.md,
/// "Tasks for Managers and Sub-tasks"). Needs a connection.
class LoadSubTasks {
  const LoadSubTasks(this._repository);

  final TaskRepository _repository;

  /// A task assigned to a manager who is not also a worker is a main task:
  /// the server assigns such users nothing else (worker tasks, re-issued and
  /// taken tasks all need the worker role). A user with both roles keeps
  /// the normal task view, also for their personal tasks.
  static bool isMainTask(Task task, AuthUser user) =>
      user.isManager && !user.isWorker && task.assignee?.id == user.id;

  /// The sub-tasks that count for the main task: all but cancelled ones.
  static List<Task> counted(List<Task> subTasks) =>
      [for (final task in subTasks) if (task.status != TaskStatus.cancelled) task];

  /// Whether the main task can be submitted: it has counted sub-tasks and all are approved.
  static bool allApproved(List<Task> subTasks) {
    final counting = counted(subTasks);
    return counting.isNotEmpty && counting.every((task) => task.status == TaskStatus.approved);
  }

  Future<Result<List<Task>>> call(String mainTaskId) => _repository.loadSubTasks(mainTaskId);
}
