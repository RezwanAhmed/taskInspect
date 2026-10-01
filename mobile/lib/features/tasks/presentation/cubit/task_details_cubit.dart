import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/failure_messages.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/start_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';

class TaskDetailsState extends Equatable {
  const TaskDetailsState({
    this.task,
    this.requirements = const [],
    this.isLoading = true,
    this.isStarting = false,
    this.message,
  });

  /// `null` once loaded means the task is not on this device.
  final Task? task;
  final List<Requirement> requirements;
  final bool isLoading;
  final bool isStarting;

  /// A one-off message, e.g. why starting failed.
  final String? message;

  TaskDetailsState copyWith({
    Task? Function()? task,
    List<Requirement>? requirements,
    bool? isLoading,
    bool? isStarting,
    String? Function()? message,
  }) {
    return TaskDetailsState(
      task: task != null ? task() : this.task,
      requirements: requirements ?? this.requirements,
      isLoading: isLoading ?? this.isLoading,
      isStarting: isStarting ?? this.isStarting,
      message: message != null ? message() : this.message,
    );
  }

  @override
  List<Object?> get props => [task, requirements, isLoading, isStarting, message];
}

/// Follows one task and its requirements on the device.
class TaskDetailsCubit extends Cubit<TaskDetailsState> {
  TaskDetailsCubit(WatchTaskDetails watch, this._startTask, this.taskId) : super(const TaskDetailsState()) {
    _task = watch.task(taskId).listen((task) => emit(state.copyWith(task: () => task, isLoading: false)));
    _requirements = watch.requirements(taskId).listen((requirements) {
      emit(state.copyWith(requirements: requirements));
    });
  }

  final StartTask _startTask;
  final String taskId;

  /// Starts the task; the screen updates from the device when it succeeds.
  Future<void> start() async {
    emit(state.copyWith(isStarting: true, message: () => null));
    final result = await _startTask(taskId);
    if (isClosed) {
      return;
    }
    emit(state.copyWith(
      isStarting: false,
      message: () => switch (result) {
        Ok() => null,
        Err(failure: NetworkFailure()) => 'No connection. Starting a task needs the internet for now.',
        Err(:final failure) => userMessage(failure),
      },
    ));
  }

  /// The message was shown.
  void clearMessage() => emit(state.copyWith(message: () => null));

  late final StreamSubscription<Task?> _task;
  late final StreamSubscription<List<Requirement>> _requirements;

  @override
  Future<void> close() async {
    await _task.cancel();
    await _requirements.cancel();
    return super.close();
  }
}
