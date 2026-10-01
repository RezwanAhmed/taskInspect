import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

/// The assigned worker submits a task for review (works offline).
class SubmitTask {
  const SubmitTask(this._repository);

  final TaskRepository _repository;

  /// Whether [userId] may submit [task] now.
  static bool canSubmit(Task task, String userId) =>
      task.status == TaskStatus.inProgress && task.assignee?.id == userId;

  /// The required requirements that are not complete yet (the server
  /// refuses the submit otherwise).
  static List<Requirement> missing(List<Requirement> requirements, bool Function(Requirement) isComplete) =>
      [for (final requirement in requirements) if (requirement.required && !isComplete(requirement)) requirement];

  Future<Result<Task>> call(String taskId) => _repository.submit(taskId);
}
