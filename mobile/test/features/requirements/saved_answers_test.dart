import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_tasks.dart';

void main() {
  tearDown(getIt.reset);

  const requirements = [
    Requirement(id: 'r1', taskId: 't1', title: 'Is the gas connection safe?', type: RequirementType.yesNo,
        required: true, position: 0),
    Requirement(id: 'r2', taskId: 't1', title: 'Notes', type: RequirementType.text, required: false, position: 1),
  ];

  Future<void> open(WidgetTester tester, FakeAnswerRepository answers) async {
    registerFakeTasks(
      FakeTaskRepository([fakeTask('t1', status: TaskStatus.inProgress)])..requirements = {'t1': requirements},
      answers: answers,
    );
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.execute('t1')));
    await tester.pumpAndSettle();
  }

  testWidgets('answers are saved on the device as they change', (tester) async {
    final answers = FakeAnswerRepository();
    await open(tester, answers);

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('text-input')), 'All good');
    await tester.pumpAndSettle();

    expect(answers.saved['t1'], {
      'r1': const Answer(booleanValue: true),
      'r2': const Answer(textValue: 'All good'),
    });
  });

  testWidgets('reopening the task shows the saved answers', (tester) async {
    final answers = FakeAnswerRepository()
      ..saved['t1'] = {'r1': const Answer(booleanValue: false), 'r2': const Answer(textValue: 'Leak under sink')};
    await open(tester, answers);

    expect(find.textContaining('2 answered'), findsOneWidget);
    final yesNo = tester.widget<SegmentedButton<bool>>(find.byKey(const Key('yes-no-input')));
    expect(yesNo.selected, {false});
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Leak under sink'), findsOneWidget);
  });
}
