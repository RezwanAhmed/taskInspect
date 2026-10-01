import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/evidence/domain/evidence_item.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_review.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_tasks.dart';

const _requirements = [
  Requirement(id: 'r1', taskId: 't1', title: 'Is the gas connection safe?', type: RequirementType.yesNo,
      required: true, position: 0),
  Requirement(id: 'r2', taskId: 't1', title: 'Fridge temperature', type: RequirementType.number, required: true,
      position: 1, unit: '°C'),
];

void main() {
  tearDown(getIt.reset);

  late FakeAnswerRepository answers;

  Future<void> openCorrection(WidgetTester tester, {ReviewResult result = ReviewResult.correctionRequested}) async {
    answers = FakeAnswerRepository()..saved['t1'] = {'r1': const Answer(booleanValue: true)};
    final tasks = FakeTaskRepository([fakeTask('t1', status: TaskStatus.inProgress, title: 'Kitchen')])
      ..requirements = {'t1': _requirements}
      ..reviews = {
        't1': TaskReview(
          result: result,
          reviewerName: 'Mia Manager',
          createdAt: DateTime.utc(2026, 10, 1),
          markedRequirements: result == ReviewResult.correctionRequested
              ? const {'r2': 'The thermometer was not in the fridge'}
              : const {},
        ),
      };
    registerFakeTasks(tasks, answers: answers);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.execute('t1')));
    await tester.pumpAndSettle();
  }

  testWidgets('an unmarked requirement stays as submitted and cannot be changed', (tester) async {
    await openCorrection(tester);

    expect(find.byKey(const Key('locked-notice')), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(answers.saved['t1']!['r1'], const Answer(booleanValue: true), reason: 'unchanged');
  });

  testWidgets("a marked requirement shows the reviewer's comment and can be changed", (tester) async {
    await openCorrection(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('To fix: The thermometer was not in the fridge'), findsOneWidget);
    expect(find.byKey(const Key('locked-notice')), findsNothing);
    await tester.enterText(find.byType(TextField).first, '4');
    await tester.pumpAndSettle();

    expect(answers.saved['t1']!['r2']!.numberValue, 4);
  });

  testWidgets('after a reject everything can be changed', (tester) async {
    await openCorrection(tester, result: ReviewResult.rejected);

    expect(find.byKey(const Key('locked-notice')), findsNothing);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(answers.saved['t1']!['r1'], const Answer(booleanValue: false));
  });

  testWidgets('submitting a correction does not ask for answers of requirements that stay as submitted',
      (tester) async {
    answers = FakeAnswerRepository(); // e.g. another phone: the submitted answers are not stored here
    final tasks = FakeTaskRepository([fakeTask('t1', status: TaskStatus.inProgress, title: 'Kitchen')])
      ..requirements = {'t1': _requirements}
      ..reviews = {
        't1': TaskReview(
          result: ReviewResult.correctionRequested,
          reviewerName: 'Mia Manager',
          createdAt: DateTime.utc(2026, 10, 1),
          markedRequirements: const {'r2': 'Measure again'},
        ),
      };
    answers.saved['t1'] = {'r2': const Answer(numberValue: 4)};
    registerFakeTasks(tasks, answers: answers);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.execute('t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
    await tester.pumpAndSettle();

    expect(tasks.submitted, ['t1']);
  });

  testWidgets('a photo that stays as submitted can be viewed but not replaced', (tester) async {
    answers = FakeAnswerRepository();
    final evidence = FakeEvidenceRepository()
      ..items.add(EvidenceItem(
        id: 'e1',
        taskId: 't1',
        requirementId: 'p1',
        localPath: '/fridge.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048,
        createdAt: DateTime.utc(2026, 10, 1),
        uploaded: true,
      ));
    final tasks = FakeTaskRepository([fakeTask('t1', status: TaskStatus.inProgress, title: 'Kitchen')])
      ..requirements = {
        't1': const [
          Requirement(id: 'p1', taskId: 't1', title: 'Photo of the fridge', type: RequirementType.photo,
              required: true, position: 0),
          Requirement(id: 'r2', taskId: 't1', title: 'Fridge temperature', type: RequirementType.number,
              required: true, position: 1),
        ],
      }
      ..reviews = {
        't1': TaskReview(
          result: ReviewResult.correctionRequested,
          reviewerName: 'Mia Manager',
          createdAt: DateTime.utc(2026, 10, 1),
          markedRequirements: const {'r2': 'Measure again'},
        ),
      };
    registerFakeTasks(tasks, answers: answers, evidence: evidence);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.execute('t1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('take-photo')), findsNothing);
    await tester.tap(find.byKey(const Key('photo-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('remove-evidence')), findsNothing, reason: 'viewable, not removable');
  });
}
