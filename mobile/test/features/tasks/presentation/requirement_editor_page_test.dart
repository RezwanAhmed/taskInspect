import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/entities/user_role.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../../helpers/fake_auth.dart';
import '../../../helpers/fake_tasks.dart';

void main() {
  tearDown(getIt.reset);

  Future<FakeTaskRepository> openApp(WidgetTester tester, AuthUser user, {TaskStatus status = TaskStatus.draft}) async {
    final tasks = FakeTaskRepository([fakeTask('t1', title: 'Kitchen check', status: status)])
      ..requirements = {
        't1': const [
          Requirement(id: 'r1', taskId: 't1', title: 'Gas safe?', type: RequirementType.yesNo, required: true, position: 0),
          Requirement(id: 'r2', taskId: 't1', title: 'Photo of the stove', type: RequirementType.photo, required: true, position: 1),
        ],
      };
    registerFakeTasks(tasks);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: user))));
    await tester.pumpAndSettle();
    return tasks;
  }

  Future<void> go(WidgetTester tester, String location) async {
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location));
    await tester.pumpAndSettle();
  }

  testWidgets('the creator opens the editor from the details and adds a choice requirement', (tester) async {
    final tasks = await openApp(tester, testManager);
    await go(tester, AppRoutes.task('t1'));
    await tester.ensureVisible(find.byKey(const Key('edit-requirements')));
    await tester.tap(find.byKey(const Key('edit-requirements')));
    await tester.pumpAndSettle();
    expect(find.text('Gas safe?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-requirement')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('requirement-title')), 'Floor');
    await tester.tap(find.byKey(const Key('requirement-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose one').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('requirement-options')), 'Clean');
    await tester.tap(find.byKey(const Key('save-requirement')));
    await tester.pumpAndSettle();
    expect(find.text('Add at least two options'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('requirement-options')), 'Clean\nDirty\n');
    await tester.tap(find.byKey(const Key('save-requirement')));
    await tester.pumpAndSettle();

    final added = tasks.requirements['t1']!.last;
    expect(added.title, 'Floor');
    expect(added.type, RequirementType.dropdown);
    expect(added.options.map((o) => o.label), ['Clean', 'Dirty']);
    expect(find.text('Floor'), findsOneWidget);
  });

  testWidgets('a requirement is changed and deleted', (tester) async {
    final tasks = await openApp(tester, testManager);
    await go(tester, AppRoutes.editRequirements('t1'));

    await tester.tap(find.text('Gas safe?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('requirement-title')), 'Gas connection safe?');
    await tester.tap(find.byKey(const Key('save-requirement')));
    await tester.pumpAndSettle();
    expect(find.text('Gas connection safe?'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete Photo of the stove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(tasks.requirements['t1']!.map((r) => r.id), ['r1']);
    expect(find.text('Photo of the stove'), findsNothing);
  });

  testWidgets('dragging a requirement changes the order', (tester) async {
    final tasks = await openApp(tester, testManager);
    await go(tester, AppRoutes.editRequirements('t1'));

    await tester.drag(find.byIcon(Icons.drag_handle).first, const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(tasks.lastOrder, ['r2', 'r1']);
  });

  testWidgets('changing the type asks for what the new type needs', (tester) async {
    final tasks = await openApp(tester, testManager);
    await go(tester, AppRoutes.editRequirements('t1'));

    await tester.tap(find.text('Gas safe?'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('requirement-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose any').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-requirement')));
    await tester.pumpAndSettle();
    expect(find.text('Add at least two options'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('requirement-options')), 'Gas\nWater');
    await tester.tap(find.byKey(const Key('save-requirement')));
    await tester.pumpAndSettle();

    final changed = tasks.requirements['t1']!.first;
    expect(changed.type, RequirementType.multipleSelection);
    expect(changed.options.map((o) => o.label), ['Gas', 'Water']);
  });

  testWidgets('workers get no editor', (tester) async {
    await openApp(tester, testWorker);
    await go(tester, AppRoutes.task('t1'));
    expect(find.byKey(const Key('edit-requirements')), findsNothing);
    await go(tester, AppRoutes.editRequirements('t1'));
    expect(find.text('This task can no longer be edited.'), findsOneWidget);
  });

  testWidgets('another manager gets no editor', (tester) async {
    const otherManager =
        AuthUser(id: 'm2', email: 'max@example.com', fullName: 'Max Manager', roles: {UserRole.manager});
    await openApp(tester, otherManager);
    await go(tester, AppRoutes.editRequirements('t1'));

    expect(find.text('This task can no longer be edited.'), findsOneWidget);
    expect(find.byKey(const Key('add-requirement')), findsNothing);
  });

  testWidgets('a started task gets no editor', (tester) async {
    await openApp(tester, testManager, status: TaskStatus.inProgress);
    await go(tester, AppRoutes.task('t1'));
    expect(find.byKey(const Key('edit-requirements')), findsNothing);

    await go(tester, AppRoutes.editRequirements('t1'));
    expect(find.text('This task can no longer be edited.'), findsOneWidget);
    expect(find.byKey(const Key('add-requirement')), findsNothing);
  });
}
