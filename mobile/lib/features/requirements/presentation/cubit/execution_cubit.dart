import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';

class ExecutionState extends Equatable {
  const ExecutionState({this.task, this.requirements = const [], this.index = 0, this.isLoading = true});

  final Task? task;
  final List<Requirement> requirements;

  /// The requirement on screen.
  final int index;
  final bool isLoading;

  Requirement? get current => requirements.isEmpty ? null : requirements[index];

  bool get isFirst => index == 0;

  bool get isLast => index >= requirements.length - 1;

  ExecutionState copyWith({Task? task, List<Requirement>? requirements, int? index, bool? isLoading}) {
    return ExecutionState(
      task: task ?? this.task,
      requirements: requirements ?? this.requirements,
      index: index ?? this.index,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [task, requirements, index, isLoading];
}

/// Walks the worker through a task's requirements one at a time.
class ExecutionCubit extends Cubit<ExecutionState> {
  ExecutionCubit(WatchTaskDetails watch, String taskId) : super(const ExecutionState()) {
    _task = watch.task(taskId).listen((task) => emit(state.copyWith(task: task)));
    _requirements = watch.requirements(taskId).listen((requirements) {
      final index = requirements.isEmpty ? 0 : state.index.clamp(0, requirements.length - 1);
      emit(state.copyWith(requirements: requirements, index: index, isLoading: false));
    });
  }

  late final StreamSubscription<Task?> _task;
  late final StreamSubscription<List<Requirement>> _requirements;

  void goTo(int index) {
    if (index >= 0 && index < state.requirements.length) {
      emit(state.copyWith(index: index));
    }
  }

  void next() => goTo(state.index + 1);

  void previous() => goTo(state.index - 1);

  @override
  Future<void> close() async {
    await _task.cancel();
    await _requirements.cancel();
    return super.close();
  }
}
