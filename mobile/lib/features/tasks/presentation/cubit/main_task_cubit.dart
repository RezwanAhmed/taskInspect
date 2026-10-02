import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/failure_messages.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/usecases/load_sub_tasks.dart';
import 'package:taskinspect/features/tasks/domain/usecases/submit_task.dart';

class MainTaskState extends Equatable {
  const MainTaskState({
    this.subTasks = const [],
    this.isLoading = true,
    this.error,
    this.isSubmitting = false,
    this.message,
  });

  final List<Task> subTasks;
  final bool isLoading;

  /// Why the sub-tasks could not be loaded.
  final String? error;
  final bool isSubmitting;

  /// A one-off message, e.g. that the main task was submitted.
  final String? message;

  int get approved => LoadSubTasks.counted(subTasks).where((t) => t.status == TaskStatus.approved).length;

  int get total => LoadSubTasks.counted(subTasks).length;

  bool get canSubmit => !isLoading && error == null && LoadSubTasks.allApproved(subTasks);

  MainTaskState copyWith({bool? isSubmitting, String? Function()? message}) => MainTaskState(
        subTasks: subTasks,
        isLoading: isLoading,
        error: error,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        message: message != null ? message() : this.message,
      );

  @override
  List<Object?> get props => [subTasks, isLoading, error, isSubmitting, message];
}

/// The manager's view of a main task: its sub-tasks with their progress,
/// and the submit once every one is approved.
class MainTaskCubit extends Cubit<MainTaskState> {
  MainTaskCubit(this._loadSubTasks, this._submitTask, this.taskId) : super(const MainTaskState());

  final LoadSubTasks _loadSubTasks;
  final SubmitTask _submitTask;
  final String taskId;

  Future<void> load() async {
    emit(const MainTaskState());
    final result = await _loadSubTasks(taskId);
    if (isClosed) {
      return;
    }
    emit(switch (result) {
      Ok(:final value) => MainTaskState(subTasks: value, isLoading: false),
      Err(failure: NetworkFailure()) =>
        const MainTaskState(isLoading: false, error: 'The sub-tasks need an internet connection.'),
      Err(:final failure) => MainTaskState(isLoading: false, error: userMessage(failure)),
    });
  }

  /// Submits the main task (sent by the sync queue, like any submit).
  Future<void> submit() async {
    emit(state.copyWith(isSubmitting: true, message: () => null));
    final result = await _submitTask(taskId);
    if (isClosed) {
      return;
    }
    emit(state.copyWith(
      isSubmitting: false,
      message: () => switch (result) {
        Ok() => 'Main task submitted for review.',
        Err(:final failure) => userMessage(failure),
      },
    ));
  }

  void clearMessage() => emit(state.copyWith(message: () => null));
}
