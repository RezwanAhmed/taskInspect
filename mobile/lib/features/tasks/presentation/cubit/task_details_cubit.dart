import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';

class TaskDetailsState extends Equatable {
  const TaskDetailsState({this.task, this.requirements = const [], this.isLoading = true});

  /// `null` once loaded means the task is not on this device.
  final Task? task;
  final List<Requirement> requirements;
  final bool isLoading;

  @override
  List<Object?> get props => [task, requirements, isLoading];
}

/// Follows one task and its requirements on the device.
class TaskDetailsCubit extends Cubit<TaskDetailsState> {
  TaskDetailsCubit(WatchTaskDetails watch, String taskId) : super(const TaskDetailsState()) {
    _task = watch.task(taskId).listen((task) {
      emit(TaskDetailsState(task: task, requirements: state.requirements, isLoading: false));
    });
    _requirements = watch.requirements(taskId).listen((requirements) {
      emit(TaskDetailsState(task: state.task, requirements: requirements, isLoading: state.isLoading));
    });
  }

  late final StreamSubscription<Task?> _task;
  late final StreamSubscription<List<Requirement>> _requirements;

  @override
  Future<void> close() async {
    await _task.cancel();
    await _requirements.cancel();
    return super.close();
  }
}
