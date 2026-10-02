import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_tasks.dart';

const _requirements = [
  Requirement(id: 'r1', taskId: 't1', title: 'Is the gas connection safe?', type: RequirementType.yesNo,
      required: true, position: 0),
  Requirement(id: 'r2', taskId: 't1', title: 'Record refrigerator temperature', type: RequirementType.number,
      required: true, position: 1, unit: '°C', description: 'Use the thermometer on the door'),
  Requirement(id: 'r3', taskId: 't1', title: 'Notes', type: RequirementType.text, required: false, position: 2),
];

void main() {
  tearDown(getIt.reset);

  Future<void> open(WidgetTester tester, {TaskStatus status = TaskStatus.inProgress, String? location}) async {
    registerFakeTasks(FakeTaskRepository([fakeTask('t1', status: status, title: 'Kitchen')])
      ..requirements = {'t1': _requirements});
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location ?? AppRoutes.execute('t1')));
    await tester.pumpAndSettle();
  }

  testWidgets('shows one requirement at a time with progress', (tester) async {
    await open(tester);

    expect(find.textContaining('Requirement 1 of 3'), findsOneWidget);
    expect(find.text('Is the gas connection safe?'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Previous')).onPressed, isNull);
  });

  testWidgets('Next and Previous move through the requirements', (tester) async {
    await open(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Requirement 2 of 3'), findsOneWidget);
    expect(find.text('Use the thermometer on the door'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Optional'), findsOneWidget);
    expect(find.text('Next'), findsNothing, reason: 'the last requirement offers Submit instead');
    expect(find.byKey(const Key('submit-task')), findsOneWidget);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Requirement 2 of 3'), findsOneWidget);
  });

  testWidgets('the checklist jumps to any requirement', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('All requirements'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Requirement 3 of 3'), findsOneWidget);
  });

  testWidgets('swiping changes the requirement too', (tester) async {
    await open(tester);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.textContaining('Requirement 2 of 3'), findsOneWidget);
  });

  testWidgets('an in-progress task can be continued from its details', (tester) async {
    await open(tester, location: AppRoutes.task('t1'));

    await tester.tap(find.byKey(const Key('continue-task')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Requirement 1 of 3'), findsOneWidget);
  });

  testWidgets('starting a task opens the requirements', (tester) async {
    await open(tester, status: TaskStatus.assigned, location: AppRoutes.task('t1'));

    await tester.tap(find.byKey(const Key('start-task')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Requirement 1 of 3'), findsOneWidget);
  });
}
