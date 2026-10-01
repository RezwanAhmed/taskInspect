import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

/// The tasks on the device, sorted by due date, updated live.
class WatchTasks {
  const WatchTasks(this._repository);

  final TaskRepository _repository;

  Stream<List<Task>> call() => _repository.watchTasks();
}
