import 'dart:async';

import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';
import 'package:taskinspect/features/tasks/domain/usecases/refresh_tasks.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_tasks.dart';

Task fakeTask(String id, {TaskStatus status = TaskStatus.assigned, DateTime? due, String? title}) => Task(
      id: id,
      title: title ?? 'Task $id',
      priority: TaskPriority.medium,
      status: status,
      dueDate: due ?? DateTime.utc(2099),
      createdBy: const PersonRef(id: 'm1', name: 'Mia Manager'),
      reviewer: const PersonRef(id: 'm1', name: 'Mia Manager'),
      assignee: const PersonRef(id: 'u1', name: 'Wendy Worker'),
      version: 1,
      updatedAt: DateTime.utc(2026, 10, 1),
    );

/// An in-memory [TaskRepository] for widget and cubit tests.
class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository([List<Task> tasks = const []]) : current = tasks;

  final List<StreamController<List<Task>>> _watchers = [];
  List<Task> current;
  Map<String, List<Requirement>> requirements = {};
  Failure? refreshFailure;
  int refreshes = 0;

  /// Changes the tasks on the "device"; every watcher sees the change.
  void emit(List<Task> tasks) {
    current = tasks;
    for (final watcher in _watchers) {
      watcher.add(tasks);
    }
  }

  /// Like the local database: the current tasks first, then every change.
  @override
  Stream<List<Task>> watchTasks({TaskStatus? status}) {
    late final StreamController<List<Task>> controller;
    controller = StreamController<List<Task>>(
      onListen: () {
        _watchers.add(controller);
        controller.add(current);
      },
      onCancel: () => _watchers.remove(controller),
    );
    return controller.stream
        .map((tasks) => status == null ? tasks : tasks.where((t) => t.status == status).toList());
  }

  @override
  Stream<Task?> watchTask(String id) =>
      watchTasks().map((tasks) => tasks.where((t) => t.id == id).firstOrNull);

  @override
  Stream<List<Requirement>> watchRequirements(String taskId) async* {
    yield requirements[taskId] ?? const [];
  }

  @override
  Future<Result<void>> refresh() async {
    refreshes++;
    return refreshFailure == null ? const Ok(null) : Err(refreshFailure!);
  }
}

/// Registers the task screens' dependencies with [repository] in the
/// service locator, as the app does.
void registerFakeTasks(FakeTaskRepository repository) {
  if (getIt.isRegistered<DashboardCubit>()) {
    getIt.unregister<DashboardCubit>();
  }
  if (getIt.isRegistered<WatchTasks>()) {
    getIt.unregister<WatchTasks>();
  }
  getIt
    ..registerFactory(() => DashboardCubit(repository, RefreshTasks(repository)))
    ..registerFactory(() => WatchTasks(repository));
}
