import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/failure_messages.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';
import 'package:taskinspect/features/tasks/domain/usecases/refresh_tasks.dart';

part 'dashboard_state.dart';

/// Counts the tasks on the device by status. The counts follow the local
/// database live; [refresh] loads the latest tasks from the server.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._repository, this._refreshTasks, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(const DashboardState());

  final TaskRepository _repository;
  final RefreshTasks _refreshTasks;
  final DateTime Function() _now;
  StreamSubscription<List<Task>>? _subscription;

  /// Starts following the local tasks and loads from the server once.
  Future<void> start() async {
    _subscription ??= _repository.watchTasks().listen(_onTasks);
    await refresh();
  }

  Future<void> refresh() async {
    emit(state.copyWith(isRefreshing: true, message: () => null));
    final result = await _refreshTasks();
    if (isClosed) {
      return;
    }
    emit(state.copyWith(
      isRefreshing: false,
      message: () => switch (result) {
        Ok() => null,
        Err(failure: NetworkFailure()) => 'Offline — showing the tasks saved on this device.',
        Err(:final failure) => userMessage(failure),
      },
    ));
  }

  void _onTasks(List<Task> tasks) {
    final counts = <TaskStatus, int>{};
    for (final task in tasks) {
      counts.update(task.status, (count) => count + 1, ifAbsent: () => 1);
    }
    final now = _now();
    emit(state.copyWith(
      counts: counts,
      overdue: tasks.where((task) => task.isOverdue(now)).length,
      isLoading: false,
    ));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
