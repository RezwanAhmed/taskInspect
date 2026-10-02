import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/core/synchronization/sync_status.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/entities/user_role.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/team_task.dart';
import 'package:taskinspect/features/tasks/presentation/task_tab.dart';

import '../../../helpers/fake_auth.dart';
import '../../../helpers/fake_tasks.dart';

void main() {
  tearDown(getIt.reset);

  final tasks = FakeTaskRepository([
    fakeTask('1', title: 'Kitchen check'),
    fakeTask('2', title: 'Fire exits', status: TaskStatus.inProgress),
    fakeTask('3', title: 'Warehouse', status: TaskStatus.correctionRequested, due: DateTime.utc(2020)),
    fakeTask('4', title: 'Storage', status: TaskStatus.approved),
  ]);

  /// Managers see every task by status; workers get "My tasks" (tests at the end).
  Future<void> openApp(WidgetTester tester, {AuthUser user = testManager}) async {
    registerFakeTasks(tasks);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: user))));
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String location) async {
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location));
    await tester.pumpAndSettle();
  }

  testWidgets('All shows every task with its status', (tester) async {
    await openApp(tester);
    await go(tester, AppRoutes.tasks);

    expect(find.text('Kitchen check'), findsOneWidget);
    expect(find.text('Fire exits'), findsOneWidget);
    expect(find.text('Warehouse'), findsOneWidget);
    expect(find.text('Correction requested'), findsWidgets);
    expect(find.textContaining('Overdue'), findsOneWidget);
  });

  testWidgets('tabs show only their statuses; Rejected includes correction requests', (tester) async {
    await openApp(tester);
    await go(tester, AppRoutes.tasks);

    await tester.tap(find.widgetWithText(Tab, 'In progress'));
    await tester.pumpAndSettle();
    expect(find.text('Fire exits'), findsOneWidget);
    expect(find.text('Kitchen check'), findsNothing);

    await tester.tap(find.widgetWithText(Tab, 'Rejected'));
    await tester.pumpAndSettle();
    expect(find.text('Warehouse'), findsOneWidget);
    expect(find.text('Fire exits'), findsNothing);
  });

  testWidgets('a dashboard tile opens the list on its tab', (tester) async {
    await openApp(tester);

    await tester.ensureVisible(find.text('Approved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approved'));
    await tester.pumpAndSettle();

    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Kitchen check'), findsNothing);
  });

  testWidgets('empty tab says so', (tester) async {
    await openApp(tester);
    await go(tester, AppRoutes.tasksOn(TaskTab.submitted));

    expect(find.text('No tasks here'), findsOneWidget);
  });

  testWidgets('filters narrow every tab and can be cleared', (tester) async {
    await openApp(tester);
    await go(tester, AppRoutes.tasks);

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Overdue'));
    await tester.tap(find.byKey(const Key('apply-filters')));
    await tester.pumpAndSettle();

    expect(find.text('Warehouse'), findsOneWidget);
    expect(find.text('Kitchen check'), findsNothing);

    await tester.tap(find.widgetWithText(Tab, 'Pending'));
    await tester.pumpAndSettle();
    expect(find.text('No tasks match the filters'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Kitchen check'), findsOneWidget);
  });

  testWidgets('tasks with changes not on the server yet are marked, with the sync status on top', (tester) async {
    registerFakeTasks(tasks, syncStatus: FakeSyncStatusSource(const SyncStatus(unsent: 1, unsentTaskIds: {'2'})));
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testManager))));
    await tester.pumpAndSettle();
    await go(tester, AppRoutes.tasks);

    expect(find.byKey(const Key('task-unsent')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('task-unsent')), matching: find.text('Not synced yet')), findsOneWidget);
    expect(find.text('1 change waiting to sync.'), findsOneWidget);
  });

  group('worker: My tasks', () {
    final workerTasks = FakeTaskRepository([
      fakeTask('1', title: 'Kitchen check'),
      fakeTask('2', title: 'Fire exits', status: TaskStatus.inProgress),
      fakeTask('3', title: 'Warehouse', status: TaskStatus.correctionRequested),
      fakeTask('4', title: 'Storage', status: TaskStatus.approved),
      fakeTask('5', title: 'Roof', status: TaskStatus.submitted),
      Task(
        id: '6',
        title: 'Open boiler room',
        priority: TaskPriority.low,
        status: TaskStatus.open,
        dueDate: DateTime.utc(2099),
        createdBy: const PersonRef(id: 'm1', name: 'Mia Manager'),
        reviewer: const PersonRef(id: 'm1', name: 'Mia Manager'),
        version: 1,
        updatedAt: DateTime.utc(2026, 10, 1),
      ),
      Task(
        id: '7',
        title: 'Someone else',
        priority: TaskPriority.low,
        status: TaskStatus.assigned,
        dueDate: DateTime.utc(2099),
        createdBy: const PersonRef(id: 'm1', name: 'Mia Manager'),
        reviewer: const PersonRef(id: 'm1', name: 'Mia Manager'),
        assignee: const PersonRef(id: 'u2', name: 'Tom Teammate'),
        version: 1,
        updatedAt: DateTime.utc(2026, 10, 1),
      ),
    ]);

    workerTasks.teamTasks = [
      TeamTask(
        id: 'x1',
        title: 'Roof check',
        priority: TaskPriority.high,
        status: TaskStatus.inProgress,
        dueDate: DateTime.utc(2099),
        assignee: const PersonRef(id: 'u2', name: 'Tom Teammate'),
        updatedAt: DateTime.utc(2026, 10, 1),
      ),
      TeamTask(
        id: 'x2',
        title: 'Cellar check',
        priority: TaskPriority.low,
        status: TaskStatus.rejected,
        dueDate: DateTime.utc(2099),
        assignee: const PersonRef(id: 'u2', name: 'Tom Teammate'),
        updatedAt: DateTime.utc(2026, 10, 1),
      ),
    ];

    Future<void> openAsWorker(WidgetTester tester) async {
      registerFakeTasks(workerTasks);
      await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
      await tester.pumpAndSettle();
    }

    testWidgets('tabs show only my tasks: Pending, Rejected, Partially done, Done', (tester) async {
      await openAsWorker(tester);
      await go(tester, AppRoutes.tasks);

      expect(find.text('My tasks'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'All'), findsNothing);
      expect(find.text('Kitchen check'), findsOneWidget);
      expect(find.text('Someone else'), findsNothing);
      expect(find.text('Open boiler room'), findsNothing);

      await tester.tap(find.widgetWithText(Tab, 'Rejected'));
      await tester.pumpAndSettle();
      expect(find.text('Warehouse'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Partially done'));
      await tester.pumpAndSettle();
      expect(find.text('Fire exits'), findsOneWidget);
      expect(find.text('Kitchen check'), findsNothing);

      await tester.tap(find.widgetWithText(Tab, 'Done'));
      await tester.pumpAndSettle();
      expect(find.text('Storage'), findsOneWidget);
      expect(find.text('Roof'), findsOneWidget);
    });

    testWidgets('All tasks: open tasks to take, and the team tasks as tiles', (tester) async {
      await openAsWorker(tester);
      await go(tester, AppRoutes.tasks);

      await tester.tap(find.widgetWithText(Tab, 'Open tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Open boiler room'), findsOneWidget);
      expect(find.text('Kitchen check'), findsNothing);

      await tester.ensureVisible(find.widgetWithText(Tab, 'Team: pending'));
      await tester.tap(find.widgetWithText(Tab, 'Team: pending'));
      await tester.pumpAndSettle();
      expect(find.text('Roof check'), findsOneWidget);
      expect(find.text('Tom Teammate'), findsOneWidget);
      expect(find.text('Cellar check'), findsNothing);

      await tester.ensureVisible(find.widgetWithText(Tab, 'Team: rejected'));
      await tester.tap(find.widgetWithText(Tab, 'Team: rejected'));
      await tester.pumpAndSettle();
      expect(find.text('Cellar check'), findsOneWidget);
    });

    testWidgets('filters also narrow the team tabs', (tester) async {
      await openAsWorker(tester);
      await go(tester, AppRoutes.tasks);
      await tester.ensureVisible(find.widgetWithText(Tab, 'Team: pending'));
      await tester.tap(find.widgetWithText(Tab, 'Team: pending'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Low'));
      await tester.tap(find.byKey(const Key('apply-filters')));
      await tester.pumpAndSettle();

      expect(find.text('Roof check'), findsNothing);
      expect(find.text('No tasks match the filters'), findsOneWidget);
    });

    testWidgets('a user who is also a manager keeps the manager tabs', (tester) async {
      registerFakeTasks(workerTasks);
      const both = AuthUser(id: 'u1', email: 'both@example.com', fullName: 'Bo Both', roles: {UserRole.worker, UserRole.manager});
      await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: both))));
      await tester.pumpAndSettle();
      await go(tester, AppRoutes.tasks);

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'All'), findsOneWidget);
      expect(find.text('Someone else'), findsOneWidget);
    });

    testWidgets('a dashboard tile opens the matching My tasks tab', (tester) async {
      await openAsWorker(tester);

      await tester.ensureVisible(find.text('In progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In progress'));
      await tester.pumpAndSettle();

      expect(find.text('Fire exits'), findsOneWidget);
      expect(find.text('Kitchen check'), findsNothing);
    });
  });
}
