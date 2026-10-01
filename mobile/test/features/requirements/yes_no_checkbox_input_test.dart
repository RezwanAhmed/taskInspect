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

void main() {
  tearDown(getIt.reset);

  Future<void> open(WidgetTester tester) async {
    registerFakeTasks(FakeTaskRepository([fakeTask('t1', status: TaskStatus.inProgress)])
      ..requirements = {
        't1': const [
          Requirement(id: 'r1', taskId: 't1', title: 'Is the gas connection safe?', type: RequirementType.yesNo,
              required: true, position: 0),
          Requirement(id: 'r2', taskId: 't1', title: 'Fire extinguisher checked', type: RequirementType.checkbox,
              required: true, position: 1),
        ],
      });
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.execute('t1')));
    await tester.pumpAndSettle();
  }

  Set<bool> yesNoSelection(WidgetTester tester) =>
      tester.widget<SegmentedButton<bool>>(find.byKey(const Key('yes-no-input'))).selected;

  testWidgets('yes/no starts unanswered and records the choice', (tester) async {
    await open(tester);

    expect(yesNoSelection(tester), isEmpty);
    expect(find.textContaining('0 answered'), findsOneWidget);

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(yesNoSelection(tester), {false});
    expect(find.textContaining('1 answered'), findsOneWidget);

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(yesNoSelection(tester), {true});
  });

  testWidgets('checkbox ticks the item off and answers survive moving between requirements', (tester) async {
    await open(tester);
    await tester.tap(find.text('Yes'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkbox-input')));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('checkbox-input'))).value, isTrue);
    expect(find.textContaining('2 answered'), findsOneWidget);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(yesNoSelection(tester), {true});

    await tester.tap(find.byTooltip('All requirements'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
  });
}
