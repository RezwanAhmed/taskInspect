import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/entities/user_role.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/worker_option.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/assign_sheet.dart';

import '../../../helpers/fake_auth.dart';
import '../../../helpers/fake_tasks.dart';

void main() {
  tearDown(getIt.reset);

  Future<FakeTaskRepository> openApp(WidgetTester tester, AuthUser user) async {
    final tasks = FakeTaskRepository([fakeTask('t1', title: 'Kitchen check')]);
    registerFakeTasks(tasks);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: user))));
    await tester.pumpAndSettle();
    return tasks;
  }

  Future<void> go(WidgetTester tester, String location) async {
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location));
    await tester.pumpAndSettle();
  }

  testWidgets('a manager creates a draft from the task list', (tester) async {
    final tasks = await openApp(tester, testManager);
    await go(tester, AppRoutes.tasks);

    await tester.tap(find.byKey(const Key('new-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-task')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a title'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('task-title')), '  Boiler room  ');
    await tester.tap(find.text('High'));
    await tester.tap(find.byKey(const Key('save-task')));
    await tester.pumpAndSettle();

    final draft = tasks.current.last;
    expect(draft.title, 'Boiler room');
    expect(draft.priority, TaskPriority.high);
    expect(draft.status, TaskStatus.draft);
    expect(draft.createdBy.id, testManager.id);
    expect(find.text('Draft saved. It is sent at the next sync.'), findsOneWidget);
    expect(find.text('Boiler room'), findsWidgets);
  });

  testWidgets('workers get no "New task" button', (tester) async {
    await openApp(tester, testWorker);
    await go(tester, AppRoutes.tasks);

    expect(find.byKey(const Key('new-task')), findsNothing);
  });

  testWidgets('the creator edits a task before work starts', (tester) async {
    final tasks = await openApp(tester, testManager);
    await go(tester, AppRoutes.task('t1'));

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Kitchen check'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('task-title')), 'Kitchen check 2');
    await tester.tap(find.byKey(const Key('save-task')));
    await tester.pumpAndSettle();

    expect(tasks.current.single.title, 'Kitchen check 2');
    expect(find.text('Kitchen check 2'), findsWidgets);
  });

  testWidgets('another manager cannot edit the task', (tester) async {
    const otherManager =
        AuthUser(id: 'm2', email: 'max@example.com', fullName: 'Max Manager', roles: {UserRole.manager});
    await openApp(tester, otherManager);
    await go(tester, AppRoutes.task('t1'));

    expect(find.byTooltip('Edit'), findsNothing);
    await go(tester, AppRoutes.editTask('t1'));
    expect(find.text('This task can no longer be edited.'), findsOneWidget);
    expect(find.byKey(const Key('save-task')), findsNothing);
  });

  testWidgets('the edit page of a started task says it can no longer be edited', (tester) async {
    final tasks = await openApp(tester, testManager);
    tasks.emit([fakeTask('t1', title: 'Kitchen check', status: TaskStatus.inProgress)]);
    await go(tester, AppRoutes.editTask('t1'));

    expect(find.text('This task can no longer be edited.'), findsOneWidget);
  });

  testWidgets('a started task has no Edit button', (tester) async {
    final tasks = await openApp(tester, testManager);
    tasks.emit([fakeTask('t1', title: 'Kitchen check', status: TaskStatus.inProgress)]);
    await go(tester, AppRoutes.task('t1'));

    expect(find.byTooltip('Edit'), findsNothing);
  });

  group('assign or publish a draft', () {
    Future<FakeTaskRepository> openDraft(WidgetTester tester, AuthUser user) async {
      final tasks = FakeTaskRepository([fakeTask('d1', title: 'Boiler room', status: TaskStatus.draft)])
        ..workers = const [
          WorkerOption(id: 'u1', name: 'Wendy Worker', inMyTeam: true),
          WorkerOption(id: 'u3', name: 'Olga Other', inMyTeam: false),
        ];
      registerFakeTasks(tasks);
      await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: user))));
      await tester.pumpAndSettle();
      await go(tester, AppRoutes.task('d1'));
      return tasks;
    }

    testWidgets('the creator assigns it to a worker of the team', (tester) async {
      final tasks = await openDraft(tester, testManager);

      await tester.tap(find.byKey(const Key('assign-task')));
      await tester.pumpAndSettle();
      expect(find.text('My team'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AssignSheet), matching: find.text('Wendy Worker')));
      await tester.pumpAndSettle();

      expect(find.text('Assigned to Wendy Worker.'), findsOneWidget);
      expect(tasks.current.single.status, TaskStatus.assigned);
      expect(find.byKey(const Key('assign-task')), findsNothing);
    });

    testWidgets('publishing to everyone; a refusal is shown in the sheet', (tester) async {
      final tasks = await openDraft(tester, testManager);
      tasks.assignFailure = const ServerFailure(statusCode: 409, code: 'TASK_HAS_NO_REQUIREMENTS');

      await tester.tap(find.byKey(const Key('assign-task')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('To everyone'));
      await tester.pumpAndSettle();
      expect(find.text('Add at least one requirement first.'), findsOneWidget);

      tasks.assignFailure = const ServerFailure(statusCode: 400, code: 'REVIEWER_IS_ASSIGNEE');
      await tester.tap(find.descendant(of: find.byType(AssignSheet), matching: find.text('Olga Other')));
      await tester.pumpAndSettle();
      expect(find.textContaining('The reviewer cannot also be the worker.'), findsOneWidget);

      tasks.assignFailure = null;
      await tester.tap(find.text('To everyone'));
      await tester.pumpAndSettle();
      expect(find.text('Published to every worker.'), findsOneWidget);
      expect(tasks.current.single.status, TaskStatus.open);
    });

    testWidgets('workers get no assign button', (tester) async {
      await openDraft(tester, testWorker);

      expect(find.byKey(const Key('assign-task')), findsNothing);
    });
  });
}
