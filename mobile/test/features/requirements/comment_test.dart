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
          Requirement(id: 'r1', taskId: 't1', title: 'Is the refrigerator door closing?',
              type: RequirementType.yesNo, required: true, position: 0),
          Requirement(id: 'r2', taskId: 't1', title: 'General remarks', type: RequirementType.comment,
              required: false, position: 1),
        ],
      });
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.execute('t1')));
    await tester.pumpAndSettle();
  }

  testWidgets('a comment can be added and is kept, but does not answer the requirement', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('add-comment')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('comment-input')), 'Door seal is worn');
    await tester.pump();
    expect(find.textContaining('0 answered'), findsOneWidget);

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 answered'), findsOneWidget);
    expect(find.text('Door seal is worn'), findsOneWidget, reason: 'answering keeps the comment');

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('Door seal is worn'), findsOneWidget);
  });

  testWidgets('COMMENT requirements have no extra comment field', (tester) async {
    await open(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-comment')), findsNothing);
    expect(find.byKey(const Key('text-input')), findsOneWidget);
  });
}
