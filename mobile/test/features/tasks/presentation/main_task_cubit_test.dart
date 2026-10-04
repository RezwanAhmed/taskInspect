import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/usecases/load_sub_tasks.dart';
import 'package:taskinspect/features/tasks/domain/usecases/submit_task.dart';
import 'package:taskinspect/features/tasks/presentation/cubit/main_task_cubit.dart';

import '../../../helpers/fake_tasks.dart';

/// Unit tests of the main task cubit (task 9.4b).
void main() {
  MainTaskCubit build(FakeTaskRepository repository) =>
      MainTaskCubit(LoadSubTasks(repository), SubmitTask(repository), 'main');

  test('counts the sub-tasks without cancelled ones and can submit once all are approved', () async {
    final repository = FakeTaskRepository()
      ..subTasks = {
        'main': [
          fakeTask('a', status: TaskStatus.approved),
          fakeTask('b', status: TaskStatus.approved),
          fakeTask('c', status: TaskStatus.cancelled),
        ],
      };
    final cubit = build(repository);

    await cubit.load();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.subTasks, hasLength(3));
    expect(cubit.state.approved, 2);
    expect(cubit.state.total, 2);
    expect(cubit.state.canSubmit, isTrue);
    await cubit.close();
  });

  test('cannot submit while a sub-task is open or when there are none', () async {
    final open = build(FakeTaskRepository()
      ..subTasks = {
        'main': [fakeTask('a', status: TaskStatus.approved), fakeTask('b', status: TaskStatus.submitted)],
      });
    final none = build(FakeTaskRepository());

    await open.load();
    await none.load();

    expect(open.state.approved, 1);
    expect(open.state.canSubmit, isFalse);
    expect(none.state.total, 0);
    expect(none.state.canSubmit, isFalse);
    await open.close();
    await none.close();
  });

  blocTest<MainTaskCubit, MainTaskState>(
    'offline: explains that sub-tasks need a connection, and nothing can be submitted',
    build: () => build(FakeTaskRepository()..subTasksFailure = const NetworkFailure()),
    act: (cubit) => cubit.load(),
    expect: () => [
      const MainTaskState(),
      const MainTaskState(isLoading: false, error: 'The sub-tasks need an internet connection.'),
    ],
    verify: (cubit) => expect(cubit.state.canSubmit, isFalse),
  );

  blocTest<MainTaskCubit, MainTaskState>(
    'a server error while loading is shown',
    build: () =>
        build(FakeTaskRepository()..subTasksFailure = const ServerFailure(statusCode: 404, message: 'Not found')),
    act: (cubit) => cubit.load(),
    expect: () => [
      const MainTaskState(),
      const MainTaskState(isLoading: false, error: 'Not found'),
    ],
  );

  test('submitting sends the main task and says so', () async {
    final repository = FakeTaskRepository([fakeTask('main', status: TaskStatus.inProgress)])
      ..subTasks = {
        'main': [fakeTask('a', status: TaskStatus.approved)],
      };
    final cubit = build(repository);
    await cubit.load();

    final submitting = cubit.submit();
    expect(cubit.state.isSubmitting, isTrue);
    await submitting;

    expect(repository.submitted, ['main']);
    expect(cubit.state.isSubmitting, isFalse);
    expect(cubit.state.message, 'Main task submitted for review.');

    cubit.clearMessage();
    expect(cubit.state.message, isNull);
    await cubit.close();
  });

  test('a refused submit shows the reason', () async {
    final repository = FakeTaskRepository([fakeTask('main', status: TaskStatus.inProgress)])
      ..submitFailure = const ServerFailure(
          statusCode: 409, code: 'SUB_TASKS_NOT_APPROVED', message: '1 of 2 sub-tasks are not approved yet');
    final cubit = build(repository);

    await cubit.submit();

    expect(cubit.state.isSubmitting, isFalse);
    expect(cubit.state.message, '1 of 2 sub-tasks are not approved yet');
    await cubit.close();
  });
}
