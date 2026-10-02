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
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_review.dart';

import '../../../helpers/fake_auth.dart';
import '../../../helpers/fake_tasks.dart';

void main() {
  tearDown(getIt.reset);

  Future<FakeTaskRepository> openApp(WidgetTester tester) async {
    final tasks = FakeTaskRepository([fakeTask('t1', title: 'Daily kitchen safety inspection')])
      ..requirements = {
        't1': const [
          Requirement(id: 'r1', taskId: 't1', title: 'Is the gas connection safe?', type: RequirementType.yesNo,
              required: true, position: 0),
          Requirement(id: 'r2', taskId: 't1', title: 'Record refrigerator temperature',
              type: RequirementType.number, required: true, position: 1, unit: '°C'),
          Requirement(id: 'r3', taskId: 't1', title: 'Floor condition', type: RequirementType.dropdown,
              required: false, position: 2, options: [
                RequirementOption(id: 'o1', label: 'Clean', position: 0),
                RequirementOption(id: 'o2', label: 'Dirty', position: 1),
              ]),
        ],
      };
    registerFakeTasks(tasks);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    return tasks;
  }

  Future<void> go(WidgetTester tester, String location) async {
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a task in the list opens its details', (tester) async {
    await openApp(tester);
    await go(tester, AppRoutes.tasks);

    await tester.tap(find.text('Daily kitchen safety inspection'));
    await tester.pumpAndSettle();

    expect(find.text('Assigned to'), findsOneWidget);
    expect(find.text('Wendy Worker'), findsOneWidget);
    expect(find.text('Created by'), findsOneWidget);
    expect(find.text('Requirements (3)'), findsOneWidget);
  });

  testWidgets('shows the requirements with type, unit and options', (tester) async {
    await openApp(tester);
    await go(tester, AppRoutes.task('t1'));

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Is the gas connection safe?'), findsOneWidget);
    expect(find.text('Yes / No · Required'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Number · °C · Required'), 200);
    expect(find.text('Number · °C · Required'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Choose one · Clean / Dirty · Optional'), 200);
    expect(find.text('Choose one · Clean / Dirty · Optional'), findsOneWidget);
  });

  testWidgets('a task that is not on the device says so', (tester) async {
    await openApp(tester);
    await go(tester, AppRoutes.task('missing'));

    expect(find.text('This task is not on this device.'), findsOneWidget);
  });

  testWidgets('a task sent back for correction shows the reviewer, the reason and what to fix', (tester) async {
    final tasks = await openApp(tester);
    tasks
      ..reviews = {
        't1': TaskReview(
          result: ReviewResult.correctionRequested,
          reviewerName: 'Mia Manager',
          createdAt: DateTime.utc(2026, 10, 1, 9),
          reason: 'Almost there',
          markedRequirements: const {'r2': 'Measure the fridge again'},
        ),
      }
      ..emit([fakeTask('t1', title: 'Daily kitchen safety inspection', status: TaskStatus.correctionRequested)]);
    await go(tester, AppRoutes.task('t1'));

    expect(find.byKey(const Key('review-result')), findsOneWidget);
    expect(find.text('Correction requested by Mia Manager'), findsOneWidget);
    expect(find.text('Almost there'), findsOneWidget);
    expect(find.text('Measure the fridge again'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('review-result')), matching: find.text('Record refrigerator temperature')),
        findsOneWidget);
  });

  testWidgets('a task without a review shows no review result', (tester) async {
    await openApp(tester);
    await go(tester, AppRoutes.task('t1'));

    expect(find.byKey(const Key('review-result')), findsNothing);
  });

  group('open task', () {
    final open = Task(
      id: 'o1',
      title: 'Boiler room',
      priority: TaskPriority.high,
      status: TaskStatus.open,
      dueDate: DateTime.utc(2099),
      createdBy: const PersonRef(id: 'm1', name: 'Mia Manager'),
      reviewer: const PersonRef(id: 'm1', name: 'Mia Manager'),
      version: 1,
      updatedAt: DateTime.utc(2026, 10, 1),
    );

    Future<FakeTaskRepository> openOpenTask(WidgetTester tester, AuthUser user) async {
      final tasks = FakeTaskRepository([open]);
      registerFakeTasks(tasks);
      await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: user))));
      await tester.pumpAndSettle();
      await go(tester, AppRoutes.task('o1'));
      return tasks;
    }

    testWidgets('a worker takes it, then can start it', (tester) async {
      await openOpenTask(tester, testWorker);

      await tester.tap(find.byKey(const Key('take-task')));
      await tester.pumpAndSettle();

      expect(find.text('The task is yours now.'), findsOneWidget);
      expect(find.byKey(const Key('take-task')), findsNothing);
      expect(find.byKey(const Key('start-task')), findsOneWidget);
    });

    testWidgets('when another worker was faster, it says so', (tester) async {
      final tasks = await openOpenTask(tester, testWorker);
      tasks.takeFailure = const ServerFailure(statusCode: 409, code: 'TASK_ALREADY_TAKEN');

      await tester.tap(find.byKey(const Key('take-task')));
      await tester.pumpAndSettle();

      expect(find.text('Another worker has already taken this task.'), findsOneWidget);
      expect(find.text('This task is not on this device.'), findsOneWidget);
      expect(find.byKey(const Key('take-task')), findsNothing);
    });

    testWidgets('managers do not get the take button', (tester) async {
      await openOpenTask(tester, testManager);

      expect(find.byKey(const Key('take-task')), findsNothing);
    });
  });

  group('main task (manager)', () {
    Task task(String id, String title, TaskStatus status, {PersonRef? assignee}) => Task(
          id: id,
          title: title,
          priority: TaskPriority.high,
          status: status,
          dueDate: DateTime.utc(2099),
          createdBy: const PersonRef(id: 'a1', name: 'Ada Admin'),
          reviewer: const PersonRef(id: 'a1', name: 'Ada Admin'),
          assignee: assignee,
          version: 1,
          updatedAt: DateTime.utc(2026, 10, 1),
        );
    const manager = PersonRef(id: 'm1', name: 'Mia Manager');
    const worker = PersonRef(id: 'u2', name: 'Tom Teammate');

    Future<void> openMainTask(WidgetTester tester, List<Task> subTasks) async {
      final tasks = FakeTaskRepository([task('main', 'Inspect building B', TaskStatus.inProgress, assignee: manager)])
        ..subTasks = {'main': subTasks};
      registerFakeTasks(tasks);
      await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testManager))));
      await tester.pumpAndSettle();
      await go(tester, AppRoutes.task('main'));
    }

    testWidgets('shows the sub-tasks and their progress; submit waits for all approvals', (tester) async {
      await openMainTask(tester, [
        task('s1', 'Floor 1', TaskStatus.approved, assignee: worker),
        task('s2', 'Floor 2', TaskStatus.submitted, assignee: worker),
        task('s3', 'Floor 3', TaskStatus.cancelled),
      ]);

      expect(find.text('1 of 2 approved'), findsOneWidget);
      expect(find.text('Floor 2'), findsOneWidget);
      expect(find.byKey(const Key('continue-task')), findsNothing);
      final submit = tester.widget<FilledButton>(find.byKey(const Key('submit-main-task')));
      expect(submit.onPressed, isNull);
      expect(find.text('Every sub-task must be approved first.'), findsOneWidget);
    });

    testWidgets('submits once every sub-task is approved', (tester) async {
      await openMainTask(tester, [task('s1', 'Floor 1', TaskStatus.approved, assignee: worker)]);

      await tester.ensureVisible(find.byKey(const Key('submit-main-task')));
      await tester.tap(find.byKey(const Key('submit-main-task')));
      await tester.pumpAndSettle();

      expect(find.text('Main task submitted for review.'), findsOneWidget);
    });

    testWidgets("a worker-manager's own personal task is a normal task", (tester) async {
      const both = AuthUser(id: 'm1', email: 'both@example.com', fullName: 'Mia Manager', roles: {UserRole.worker, UserRole.manager});
      final personal = Task(
        id: 'p1',
        title: 'My own check',
        priority: TaskPriority.low,
        status: TaskStatus.inProgress,
        dueDate: DateTime.utc(2099),
        createdBy: manager,
        reviewer: manager,
        assignee: manager,
        version: 1,
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      registerFakeTasks(FakeTaskRepository([personal]));
      await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: both))));
      await tester.pumpAndSettle();
      await go(tester, AppRoutes.task('p1'));

      expect(find.byKey(const Key('main-task-panel')), findsNothing);
      expect(find.byKey(const Key('continue-task')), findsOneWidget);
    });

    testWidgets('workers never see the panel', (tester) async {
      await openApp(tester);
      await go(tester, AppRoutes.task('t1'));

      expect(find.byKey(const Key('main-task-panel')), findsNothing);
    });
  });
}
