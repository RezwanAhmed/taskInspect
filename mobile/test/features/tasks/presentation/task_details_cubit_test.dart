import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_review.dart';
import 'package:taskinspect/features/tasks/domain/usecases/start_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/take_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';
import 'package:taskinspect/features/tasks/presentation/cubit/task_details_cubit.dart';

import '../../../helpers/fake_tasks.dart';

/// Unit tests of the task details cubit (task 9.4b).
void main() {
  TaskDetailsCubit build(FakeTaskRepository repository, String taskId) => TaskDetailsCubit(
      WatchTaskDetails(repository), StartTask(repository), TakeTask(repository), taskId);

  test('shows the task, its requirements and its latest review from the device', () async {
    const requirement =
        Requirement(id: 'r1', taskId: '1', title: 'Ok?', type: RequirementType.yesNo, required: true, position: 0);
    final review = TaskReview(
        result: ReviewResult.rejected,
        reviewerName: 'Mia Manager',
        createdAt: DateTime.utc(2026, 10, 2),
        reason: 'Redo');
    final repository = FakeTaskRepository([fakeTask('1', status: TaskStatus.rejected), fakeTask('2')])
      ..requirements = {'1': [requirement]}
      ..reviews = {'1': review};
    final cubit = build(repository, '1');
    expect(cubit.state.isLoading, isTrue);

    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.task?.id, '1');
    expect(cubit.state.requirements, [requirement]);
    expect(cubit.state.review, review);
    await cubit.close();
  });

  test('a task that is not on the device is loaded as null', () async {
    final cubit = build(FakeTaskRepository([fakeTask('1')]), 'gone');
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.task, isNull);
    await cubit.close();
  });

  test('starting updates the task from the device and shows no message', () async {
    final cubit = build(FakeTaskRepository([fakeTask('1')]), '1');
    await Future<void>.delayed(Duration.zero);

    final starting = cubit.start();
    expect(cubit.state.isStarting, isTrue);
    await starting;
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.isStarting, isFalse);
    expect(cubit.state.message, isNull);
    expect(cubit.state.starts, 1);
    expect(cubit.state.task?.status, TaskStatus.inProgress);
    await cubit.close();
  });

  test('starting offline explains that it needs the internet', () async {
    final cubit = build(FakeTaskRepository([fakeTask('1')])..startFailure = const NetworkFailure(), '1');
    await Future<void>.delayed(Duration.zero);

    await cubit.start();

    expect(cubit.state.isStarting, isFalse);
    expect(cubit.state.message, 'No connection. Starting a task needs the internet for now.');
    expect(cubit.state.starts, 0);
    expect(cubit.state.task?.status, TaskStatus.assigned);
    await cubit.close();
  });

  test('starting refused by the server shows its reason', () async {
    final repository = FakeTaskRepository([fakeTask('1')])
      ..startFailure = const ServerFailure(statusCode: 409, message: 'The task was cancelled');
    final cubit = build(repository, '1');
    await Future<void>.delayed(Duration.zero);

    await cubit.start();

    expect(cubit.state.message, 'The task was cancelled');
    await cubit.close();
  });

  test('taking an open task makes it the worker\'s', () async {
    final cubit = build(FakeTaskRepository([fakeTask('1', status: TaskStatus.open)]), '1');
    await Future<void>.delayed(Duration.zero);

    await cubit.take();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.isTaking, isFalse);
    expect(cubit.state.message, 'The task is yours now.');
    expect(cubit.state.task?.status, TaskStatus.assigned);
    await cubit.close();
  });

  for (final (failure, message) in [
    (const NetworkFailure(), 'No connection. Taking a task needs the internet.'),
    (const ServerFailure(statusCode: 409, code: 'TASK_ALREADY_TAKEN'), 'Another worker has already taken this task.'),
    (const ServerFailure(statusCode: 404, code: 'TASK_NOT_FOUND'), 'This task is no longer open to you.'),
    (const ServerFailure(statusCode: 400, message: 'You are this task\'s reviewer'), 'You are this task\'s reviewer'),
  ]) {
    test('taking fails: "$message"', () async {
      final repository = FakeTaskRepository([fakeTask('1', status: TaskStatus.open)])..takeFailure = failure;
      final cubit = build(repository, '1');
      await Future<void>.delayed(Duration.zero);

      await cubit.take();

      expect(cubit.state.isTaking, isFalse);
      expect(cubit.state.message, message);
      await cubit.close();
    });
  }

  test('a shown message is cleared', () async {
    final cubit = build(FakeTaskRepository([fakeTask('1')])..startFailure = const NetworkFailure(), '1');
    await Future<void>.delayed(Duration.zero);
    await cubit.start();

    cubit.clearMessage();

    expect(cubit.state.message, isNull);
    await cubit.close();
  });

  // Without the isClosed check the late answer would emit on a closed cubit and throw.
  test('an answer arriving after the page is closed is dropped', () async {
    final gate = Completer<void>();
    final cubit = build(FakeTaskRepository([fakeTask('1')])..startGate = gate, '1');
    await Future<void>.delayed(Duration.zero);

    final starting = cubit.start();
    await cubit.close();
    gate.complete();

    await expectLater(starting, completes);
  });
}
