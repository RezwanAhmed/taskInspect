import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

/// Loads the latest tasks from the server into the device. Screens keep
/// showing the local data; when this fails (e.g. offline) nothing changes.
class RefreshTasks {
  const RefreshTasks(this._repository);

  final TaskRepository _repository;

  Future<Result<void>> call() => _repository.refresh();
}
