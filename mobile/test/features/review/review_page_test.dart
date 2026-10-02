import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/entities/user_role.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/review/domain/review_repository.dart';
import 'package:taskinspect/features/review/domain/submission.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_tasks.dart';

/// The task's reviewer (fakeTask's reviewer is m1).
const _manager = AuthUser(id: 'm1', email: 'manager@example.com', fullName: 'Mia Manager', roles: {UserRole.manager});

const _requirements = [
  Requirement(id: 'r1', taskId: 't1', title: 'Is the gas connection safe?', type: RequirementType.yesNo,
      required: true, position: 0),
  Requirement(id: 'r2', taskId: 't1', title: 'Fridge temperature', type: RequirementType.number, required: true,
      position: 1, unit: '°C'),
  Requirement(id: 'r3', taskId: 't1', title: 'Photo of the fridge', type: RequirementType.photo, required: true,
      position: 2),
  Requirement(id: 'r4', taskId: 't1', title: 'Service report', type: RequirementType.document, required: false,
      position: 3),
];

class _FakeReviewRepository implements ReviewRepository {
  Failure? failure;
  final List<String> opened = [];

  @override
  Future<Result<Submission>> loadSubmission(String taskId) async {
    if (failure != null) {
      return Err(failure!);
    }
    return const Ok(Submission(
      answers: {
        'r1': Answer(booleanValue: true, comment: 'Checked twice'),
        'r2': Answer(numberValue: 4),
      },
      files: {
        'r3': [
          SubmittedFile(id: 'e1', requirementId: 'r3', fileName: 'fridge.jpg', contentType: 'image/jpeg',
              sizeBytes: 5, uploaded: true),
        ],
        'r4': [
          SubmittedFile(id: 'e2', requirementId: 'r4', fileName: 'report.pdf', contentType: 'application/pdf',
              sizeBytes: 5, uploaded: true),
        ],
      },
    ));
  }

  @override
  Future<Result<String>> fileUrl(String taskId, SubmittedFile file) async => const Err(NetworkFailure());

  @override
  Future<Result<String>> downloadFile(String taskId, SubmittedFile file) async {
    opened.add(file.id);
    return Ok('/tmp/${file.fileName}');
  }

  int cleared = 0;

  @override
  Future<void> clearDownloads(String taskId) async => cleared++;

  final List<String> decisions = [];
  Failure? decisionFailure;

  /// Like the app, which stores the decided task on the device.
  void Function(Task task)? onDecided;

  Future<Result<Task>> _decided(String what, TaskStatus status) async {
    decisions.add(what);
    if (decisionFailure != null) {
      return Err(decisionFailure!);
    }
    final task = fakeTask('t1', status: status, title: 'Kitchen');
    onDecided?.call(task);
    return Ok(task);
  }

  int refreshed = 0;

  @override
  Future<Result<Task>> refreshTask(String taskId) async {
    refreshed++;
    final task = fakeTask('t1', status: TaskStatus.approved, title: 'Kitchen');
    onDecided?.call(task);
    return Ok(task);
  }

  @override
  Future<Result<Task>> approve(String taskId, {String? comment}) => _decided('approve:${comment ?? ''}', TaskStatus.approved);

  @override
  Future<Result<Task>> reject(String taskId, {required String reason}) => _decided('reject:$reason', TaskStatus.rejected);

  @override
  Future<Result<Task>> requestCorrection(String taskId, {String? reason, required Map<String, String> requirements}) =>
      _decided('correction:$requirements', TaskStatus.correctionRequested);
}

void main() {
  tearDown(getIt.reset);

  late _FakeReviewRepository review;
  late FakeDocumentOpener opener;

  Future<void> openTask(WidgetTester tester,
      {AuthUser user = _manager, TaskStatus status = TaskStatus.submitted, bool reviewerIsWorker = false}) async {
    review = _FakeReviewRepository();
    opener = FakeDocumentOpener();
    final task = fakeTask('t1', status: status, title: 'Kitchen');
    final tasks = FakeTaskRepository();
    review.onDecided = (decided) => tasks.emit([decided]);
    registerFakeTasks(
      tasks..emit([
        if (reviewerIsWorker)
          Task(
            id: task.id,
            title: task.title,
            priority: task.priority,
            status: task.status,
            dueDate: task.dueDate,
            createdBy: task.createdBy,
            reviewer: const PersonRef(id: 'u1', name: 'Wendy Worker'),
            assignee: task.assignee,
            version: task.version,
            updatedAt: task.updatedAt,
          )
        else
          task,
      ])
        ..requirements = {'t1': _requirements},
      opener: opener,
    );
    getIt.registerSingleton<ReviewRepository>(review);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: user))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.task('t1')));
    await tester.pumpAndSettle();
  }

  testWidgets("the reviewer opens the submitted task's answers, comments and files", (tester) async {
    await openTask(tester);

    await tester.tap(find.byKey(const Key('review-task')));
    await tester.pumpAndSettle();

    expect(find.text('Submitted by Wendy Worker'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('Comment: Checked twice'), findsOneWidget);
    expect(find.text('4 °C'), findsOneWidget);
    expect(find.byKey(const Key('photo-e1')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('document-e2')), 200);
    expect(find.text('report.pdf'), findsOneWidget);

    await tester.tap(find.byKey(const Key('document-e2')));
    await tester.pumpAndSettle();
    expect(review.opened, ['e2']);
    expect(opener.opened, ['/tmp/report.pdf']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(review.cleared, 1, reason: 'downloaded files are deleted when the review closes');
  });

  testWidgets('an error that a retry cannot fix has no Retry', (tester) async {
    await openTask(tester);
    review.failure = const ServerFailure(statusCode: 404, code: 'TASK_NOT_FOUND', message: 'Task not found');

    await tester.tap(find.byKey(const Key('review-task')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review-error')), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('offline: a message and Retry', (tester) async {
    await openTask(tester);
    review.failure = const NetworkFailure();

    await tester.tap(find.byKey(const Key('review-task')));
    await tester.pumpAndSettle();

    expect(find.text('Reviewing needs an internet connection.'), findsOneWidget);
    review.failure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Yes'), findsOneWidget);
  });

  testWidgets('only the reviewer of a submitted task sees Review', (tester) async {
    await openTask(tester, user: testWorker);
    expect(find.byKey(const Key('review-task')), findsNothing);
  });

  testWidgets("a reviewer who did someone else's task themself cannot review it", (tester) async {
    await openTask(tester, user: const AuthUser(id: 'u1', email: 'both@example.com', fullName: 'Wendy Worker',
        roles: {UserRole.manager, UserRole.worker}), reviewerIsWorker: true);
    expect(find.byKey(const Key('review-task')), findsNothing);
  });

  testWidgets('a task that is not submitted has no Review', (tester) async {
    await openTask(tester, status: TaskStatus.inProgress);
    expect(find.byKey(const Key('review-task')), findsNothing);
  });

  Future<void> openReview(WidgetTester tester) async {
    await openTask(tester);
    await tester.tap(find.byKey(const Key('review-task')));
    await tester.pumpAndSettle();
  }

  testWidgets('approve, with an optional comment, then back to the task', (tester) async {
    await openReview(tester);

    await tester.tap(find.byKey(const Key('approve-task')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('approve-comment')), 'Well done');
    await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
    await tester.pumpAndSettle();

    expect(review.decisions, ['approve:Well done']);
    expect(find.text('Task approved.'), findsOneWidget);
    expect(find.byKey(const Key('review-task')), findsNothing, reason: 'back on the task');
  });

  testWidgets('reject needs a reason', (tester) async {
    await openReview(tester);

    await tester.tap(find.byKey(const Key('reject-task')));
    await tester.pumpAndSettle();
    final reject = find.widgetWithText(FilledButton, 'Reject');
    expect(tester.widget<FilledButton>(reject).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('reject-reason')), 'Wrong kitchen');
    await tester.pump();
    await tester.tap(reject);
    await tester.pumpAndSettle();

    expect(review.decisions, ['reject:Wrong kitchen']);
  });

  testWidgets('a correction marks requirements, each with a comment', (tester) async {
    await openReview(tester);

    await tester.tap(find.byKey(const Key('request-correction')));
    await tester.pumpAndSettle();
    final send = find.byKey(const Key('send-correction'));
    expect(tester.widget<TextButton>(send).onPressed, isNull, reason: 'nothing marked');

    await tester.tap(find.byKey(const Key('mark-r3')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(send).onPressed, isNull, reason: 'the marked one needs a comment');
    await tester.enterText(find.byKey(const Key('comment-r3')), 'Retake the fridge photo');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(review.decisions, ['correction:{r3: Retake the fridge photo}']);
    expect(find.text('Correction requested from the worker.'), findsOneWidget);
  });

  testWidgets('offline: the decision is not sent and the reviewer can try again', (tester) async {
    await openReview(tester);
    review.decisionFailure = const NetworkFailure();

    await tester.tap(find.byKey(const Key('approve-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
    await tester.pumpAndSettle();

    expect(find.text('No connection. Your decision was not sent; try again.'), findsOneWidget);
    expect(find.byKey(const Key('approve-task')), findsOneWidget, reason: 'still on the review');
  });

  testWidgets('reviewed meanwhile (409): the task is reloaded and the decision buttons go away', (tester) async {
    await openReview(tester);
    review.decisionFailure = const ServerFailure(statusCode: 409, code: 'TASK_ALREADY_APPROVED',
        message: 'Task has already been approved');

    await tester.tap(find.byKey(const Key('reject-task')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reject-reason')), 'Too late');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    expect(review.refreshed, 1);
    expect(find.text('Task has already been approved'), findsOneWidget);
    expect(find.byKey(const Key('approve-task')), findsNothing);
  });

  testWidgets('unmarking a requirement while typing its comment is safe', (tester) async {
    await openReview(tester);
    await tester.tap(find.byKey(const Key('request-correction')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mark-r1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('comment-r1')), 'Check');
    await tester.tap(find.byKey(const Key('mark-r1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('comment-r1')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
