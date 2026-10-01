import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../../helpers/fake_auth.dart';
import '../../../helpers/fake_tasks.dart';

void main() {
  tearDown(getIt.reset);

  Future<FakeTaskRepository> openTask(WidgetTester tester, Task task) async {
    final tasks = FakeTaskRepository([task]);
    registerFakeTasks(tasks);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.task(task.id)));
    await tester.pumpAndSettle();
    return tasks;
  }

  testWidgets('the assigned worker starts the task', (tester) async {
    await openTask(tester, fakeTask('t1'));

    await tester.tap(find.byKey(const Key('start-task')));
    await tester.pumpAndSettle();

    expect(find.text('In progress'), findsOneWidget);
    expect(find.byKey(const Key('start-task')), findsNothing);
  });

  testWidgets('after a correction request the button says Start correction', (tester) async {
    await openTask(tester, fakeTask('t1', status: TaskStatus.correctionRequested));

    expect(find.text('Start correction'), findsOneWidget);
  });

  testWidgets('no start button for someone else\'s task', (tester) async {
    final othersTask = Task(
      id: 't2',
      title: 'Not mine',
      priority: TaskPriority.low,
      status: TaskStatus.assigned,
      dueDate: DateTime.utc(2099),
      createdBy: const PersonRef(id: 'm1', name: 'Mia'),
      reviewer: const PersonRef(id: 'm1', name: 'Mia'),
      assignee: const PersonRef(id: 'someone-else', name: 'Other Worker'),
      version: 1,
      updatedAt: DateTime.utc(2026),
    );
    await openTask(tester, othersTask);

    expect(find.byKey(const Key('start-task')), findsNothing);
  });

  testWidgets('offline start explains that a connection is needed', (tester) async {
    final tasks = await openTask(tester, fakeTask('t1'));
    tasks.startFailure = const NetworkFailure();

    await tester.tap(find.byKey(const Key('start-task')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No connection. Starting a task needs the internet for now.'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });
}
