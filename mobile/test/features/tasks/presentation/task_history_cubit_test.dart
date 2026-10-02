import 'package:bloc_test/bloc_test.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/features/tasks/domain/entities/history_entry.dart';
import 'package:taskinspect/features/tasks/domain/usecases/load_task_history.dart';
import 'package:taskinspect/features/tasks/presentation/cubit/task_history_cubit.dart';

import '../../../helpers/fake_tasks.dart';

/// Unit tests of the task history cubit (task 9.4b).
void main() {
  final entry = HistoryEntry(event: HistoryEvent.assigned, byName: 'Mia Manager', at: DateTime.utc(2026, 10, 1));

  TaskHistoryCubit build(FakeTaskRepository repository) => TaskHistoryCubit(LoadTaskHistory(repository), '1');

  blocTest<TaskHistoryCubit, TaskHistoryState>(
    'loads the history',
    build: () => build(FakeTaskRepository()..history = [entry]),
    act: (cubit) => cubit.load(),
    expect: () => [
      const TaskHistoryState(),
      TaskHistoryState(entries: [entry], isLoading: false),
    ],
  );

  blocTest<TaskHistoryCubit, TaskHistoryState>(
    'offline: explains that the history needs a connection and offers a retry',
    build: () => build(FakeTaskRepository()..historyFailure = const NetworkFailure()),
    act: (cubit) => cubit.load(),
    expect: () => [
      const TaskHistoryState(),
      const TaskHistoryState(isLoading: false, canRetry: true, error: 'The history needs an internet connection.'),
    ],
  );

  blocTest<TaskHistoryCubit, TaskHistoryState>(
    'a server error is shown without a retry',
    build: () => build(FakeTaskRepository()..historyFailure = const ServerFailure(statusCode: 500)),
    act: (cubit) => cubit.load(),
    expect: () => [
      const TaskHistoryState(),
      const TaskHistoryState(isLoading: false, error: 'Unable to synchronize. Please try again.'),
    ],
  );

  blocTest<TaskHistoryCubit, TaskHistoryState>(
    'a retry starts from the loading state again',
    build: () => build(FakeTaskRepository()..history = [entry]),
    seed: () => const TaskHistoryState(isLoading: false, canRetry: true, error: 'offline'),
    act: (cubit) => cubit.load(),
    expect: () => [
      const TaskHistoryState(),
      TaskHistoryState(entries: [entry], isLoading: false),
    ],
  );
}
