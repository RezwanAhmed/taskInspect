import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/core/synchronization/sync_status.dart';
import 'package:taskinspect/features/evidence/domain/evidence_item.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_tasks.dart';

const _requirements = [
  Requirement(id: 'r1', taskId: 't1', title: 'Is the gas connection safe?', type: RequirementType.yesNo,
      required: true, position: 0),
  Requirement(id: 'r2', taskId: 't1', title: 'Notes', type: RequirementType.text, required: false, position: 1),
];

void main() {
  tearDown(getIt.reset);

  late FakeTaskRepository tasks;
  late FakeAnswerRepository answers;

  /// Opens the task's details, then its requirements, on the last one.
  Future<void> openLast(WidgetTester tester, {FakeSyncStatusSource? syncStatus}) async {
    tasks = FakeTaskRepository([fakeTask('t1', status: TaskStatus.inProgress, title: 'Kitchen')])
      ..requirements = {'t1': _requirements};
    registerFakeTasks(tasks, answers: answers, syncStatus: syncStatus);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    unawaited(router.push(AppRoutes.task('t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  Future<void> submitAndConfirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('submit-task')));
    await tester.pumpAndSettle();
    expect(find.text('Submit for review?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
    await tester.pumpAndSettle();
  }

  setUp(() => answers = FakeAnswerRepository());

  testWidgets('a missing required answer is shown instead of submitting', (tester) async {
    await openLast(tester);

    await submitAndConfirm(tester);

    expect(find.text('"Is the gas connection safe?" still needs an answer.'), findsOneWidget);
    expect(find.textContaining('Requirement 1 of 2'), findsOneWidget, reason: 'it goes to the missing one');
    expect(tasks.submitted, isEmpty);
  });

  testWidgets('a complete task is submitted and the details say it waits for synchronization', (tester) async {
    answers.saved['t1'] = {'r1': const Answer(booleanValue: true)};
    await openLast(tester, syncStatus: FakeSyncStatusSource(const SyncStatus(unsent: 1, unsentTaskIds: {'t1'})));

    await submitAndConfirm(tester);

    expect(tasks.submitted, ['t1']);
    expect(find.text('Submitted'), findsWidgets);
    expect(find.byKey(const Key('submitted-locally')), findsOneWidget);
    expect(find.byKey(const Key('continue-task')), findsNothing, reason: 'a submitted task can no longer be changed');
  });

  testWidgets('Cancel in the dialog does not submit', (tester) async {
    answers.saved['t1'] = {'r1': const Answer(booleanValue: true)};
    await openLast(tester);

    await tester.tap(find.byKey(const Key('submit-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tasks.submitted, isEmpty);
  });

  testWidgets('a photo whose file is missing on the device must be replaced before submitting', (tester) async {
    answers.saved['t1'] = {'r1': const Answer(booleanValue: true)};
    tasks = FakeTaskRepository([fakeTask('t1', status: TaskStatus.inProgress, title: 'Kitchen')])
      ..requirements = {
        't1': const [
          Requirement(id: 'r1', taskId: 't1', title: 'Is the gas connection safe?', type: RequirementType.yesNo,
              required: true, position: 0),
          Requirement(id: 'r2', taskId: 't1', title: 'Photo of the meter', type: RequirementType.photo,
              required: true, position: 1),
        ],
      };
    final evidence = FakeEvidenceRepository()
      ..items.add(EvidenceItem(
        id: 'e1',
        taskId: 't1',
        requirementId: 'r2',
        localPath: '/gone.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 5,
        createdAt: DateTime.utc(2026, 10, 1),
        fileMissing: true,
      ));
    registerFakeTasks(tasks, answers: answers, evidence: evidence);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.execute('t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await submitAndConfirm(tester);

    expect(find.text('A file of "Photo of the meter" is missing on this device. Remove it and add it again.'),
        findsOneWidget);
    expect(tasks.submitted, isEmpty);
  });
}
