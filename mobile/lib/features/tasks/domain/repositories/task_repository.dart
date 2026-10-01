import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// Tasks as the screens see them. Everything is read from the local
/// database as live streams, so screens update by themselves and work the
/// same offline (ADR-0004). [refresh] brings the device up to date with
/// the server.
abstract interface class TaskRepository {
  /// Tasks sorted by due date, optionally only one [status].
  Stream<List<Task>> watchTasks({TaskStatus? status});

  /// One task, or `null` if it is not on the device.
  Stream<Task?> watchTask(String id);

  /// The requirements of a task in the order the worker completes them.
  Stream<List<Requirement>> watchRequirements(String taskId);

  /// Loads the tasks the user may see (with their requirements) from the
  /// server and stores them, removing tasks that are no longer there. On
  /// failure the local data stays as it was.
  Future<Result<void>> refresh();
}
