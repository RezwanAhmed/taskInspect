import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/core/synchronization/sync_status.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
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

  Future<void> openApp(WidgetTester tester) async {
    registerFakeTasks(tasks);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
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
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    await go(tester, AppRoutes.tasks);

    expect(find.byKey(const Key('task-unsent')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('task-unsent')), matching: find.text('Not synced yet')), findsOneWidget);
    expect(find.text('1 change waiting to sync.'), findsOneWidget);
  });
}
