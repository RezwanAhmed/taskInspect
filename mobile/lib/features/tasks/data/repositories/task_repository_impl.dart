import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  const TaskRepositoryImpl(this._local);

  final TaskLocalDataSource _local;

  @override
  Stream<List<Task>> watchTasks({TaskStatus? status}) => _local.watchTasks(status: status);

  @override
  Stream<Task?> watchTask(String id) => _local.watchTask(id);

  @override
  Stream<List<Requirement>> watchRequirements(String taskId) => _local.watchRequirements(taskId);
}
