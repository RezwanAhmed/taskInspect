import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/domain/entities/history_entry.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

/// A task's history from the server, oldest first (needs a connection).
class LoadTaskHistory {
  const LoadTaskHistory(this._repository);

  final TaskRepository _repository;

  Future<Result<List<HistoryEntry>>> call(String taskId) => _repository.loadHistory(taskId);
}
