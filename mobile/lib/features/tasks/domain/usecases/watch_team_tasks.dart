import 'package:taskinspect/features/tasks/domain/entities/team_task.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

/// The team members' tasks (tiles) on the device, sorted by due date, updated live.
class WatchTeamTasks {
  const WatchTeamTasks(this._repository);

  final TaskRepository _repository;

  Stream<List<TeamTask>> call() => _repository.watchTeamTasks();
}
