import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_review.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

/// One task and its requirements, updated live.
class WatchTaskDetails {
  const WatchTaskDetails(this._repository);

  final TaskRepository _repository;

  Stream<Task?> task(String id) => _repository.watchTask(id);

  Stream<List<Requirement>> requirements(String taskId) => _repository.watchRequirements(taskId);

  Stream<TaskReview?> review(String taskId) => _repository.watchReview(taskId);
}
