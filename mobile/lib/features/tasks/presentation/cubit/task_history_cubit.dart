import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/failure_messages.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/domain/entities/history_entry.dart';
import 'package:taskinspect/features/tasks/domain/usecases/load_task_history.dart';

class TaskHistoryState extends Equatable {
  const TaskHistoryState({this.entries = const [], this.isLoading = true, this.error, this.canRetry = false});

  final List<HistoryEntry> entries;
  final bool isLoading;
  final String? error;

  /// Whether trying again can help (a connection problem).
  final bool canRetry;

  @override
  List<Object?> get props => [entries, isLoading, error, canRetry];
}

/// Loads a task's history from the server.
class TaskHistoryCubit extends Cubit<TaskHistoryState> {
  TaskHistoryCubit(this._loadHistory, this.taskId) : super(const TaskHistoryState());

  final LoadTaskHistory _loadHistory;
  final String taskId;

  Future<void> load() async {
    emit(const TaskHistoryState());
    final result = await _loadHistory(taskId);
    if (isClosed) {
      return;
    }
    emit(switch (result) {
      Ok(:final value) => TaskHistoryState(entries: value, isLoading: false),
      Err(failure: NetworkFailure()) => const TaskHistoryState(
          isLoading: false, canRetry: true, error: 'The history needs an internet connection.'),
      Err(:final failure) => TaskHistoryState(isLoading: false, error: userMessage(failure)),
    });
  }
}
