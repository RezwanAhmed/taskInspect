import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_tasks.dart';
import 'package:taskinspect/features/tasks/presentation/task_tab.dart';

class TaskListState extends Equatable {
  const TaskListState({this.tasks = const [], this.isLoading = true});

  final List<Task> tasks;
  final bool isLoading;

  @override
  List<Object?> get props => [tasks, isLoading];
}

/// The tasks of one tab, kept up to date with the device.
class TaskListCubit extends Cubit<TaskListState> {
  TaskListCubit(this._watchTasks, this.tab) : super(const TaskListState()) {
    _subscription = _watchTasks().listen((tasks) {
      emit(TaskListState(tasks: tasks.where((task) => tab.matches(task.status)).toList(), isLoading: false));
    });
  }

  final WatchTasks _watchTasks;
  final TaskTab tab;
  late final StreamSubscription<List<Task>> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
