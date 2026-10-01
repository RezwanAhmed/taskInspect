import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

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
    expect(find.text('Number · °C · Required'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Choose one · Clean / Dirty · Optional'), 200);
    expect(find.text('Choose one · Clean / Dirty · Optional'), findsOneWidget);
  });

  testWidgets('a task that is not on the device says so', (tester) async {
    await openApp(tester);
    await go(tester, AppRoutes.task('missing'));

    expect(find.text('This task is not on this device.'), findsOneWidget);
  });
}
