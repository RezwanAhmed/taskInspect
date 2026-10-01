import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_tasks.dart';

void main() {
  tearDown(getIt.reset);

  Future<void> open(WidgetTester tester, FakeTaskRepository tasks) async {
    registerFakeTasks(tasks);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
  }

  int countOn(WidgetTester tester, String label) {
    final tile = find.ancestor(of: find.text(label), matching: find.byType(Card));
    final number = find.descendant(of: tile, matching: find.textContaining(RegExp(r'^\d+$')));
    return int.parse(tester.widget<Text>(number).data!);
  }

  testWidgets('shows how many tasks are in each status', (tester) async {
    await open(tester, FakeTaskRepository([
      fakeTask('1'),
      fakeTask('2'),
      fakeTask('3', status: TaskStatus.inProgress),
      fakeTask('4', status: TaskStatus.correctionRequested, due: DateTime.utc(2020)),
    ]));

    expect(find.text('Hello, Wendy Worker'), findsOneWidget);
    expect(find.text('4 tasks on this device'), findsOneWidget);
    expect(countOn(tester, 'Pending'), 2);
    expect(countOn(tester, 'In progress'), 1);
    expect(countOn(tester, 'Correction requested'), 1);
    expect(countOn(tester, 'Overdue'), 1);
    expect(find.text('Draft'), findsNothing, reason: 'workers have no drafts');
  });

  testWidgets('offline shows a message with retry', (tester) async {
    final tasks = FakeTaskRepository([fakeTask('1')])..refreshFailure = const NetworkFailure();
    await open(tester, tasks);

    expect(find.byKey(const Key('dashboard-message')), findsOneWidget);
    expect(countOn(tester, 'Pending'), 1);

    tasks.refreshFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-message')), findsNothing);
    expect(tasks.refreshes, 2);
  });
}
