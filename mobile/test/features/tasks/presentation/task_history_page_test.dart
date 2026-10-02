import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/tasks/domain/entities/history_entry.dart';

import '../../../helpers/fake_auth.dart';
import '../../../helpers/fake_tasks.dart';

void main() {
  tearDown(getIt.reset);

  late FakeTaskRepository tasks;

  Future<void> openHistory(WidgetTester tester) async {
    registerFakeTasks(tasks);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.task('t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
  }

  setUp(() => tasks = FakeTaskRepository([fakeTask('t1', title: 'Kitchen')]));

  testWidgets('every step with who, when and why', (tester) async {
    tasks.history = [
      HistoryEntry(event: HistoryEvent.created, byName: 'Mia Manager', at: DateTime.utc(2026, 10, 1, 8)),
      HistoryEntry(event: HistoryEvent.submitted, byName: 'Wendy Worker', at: DateTime.utc(2026, 10, 1, 10)),
      HistoryEntry(
          event: HistoryEvent.rejected, byName: 'Mia Manager', at: DateTime.utc(2026, 10, 1, 11), reason: 'Wrong kitchen'),
      HistoryEntry(event: HistoryEvent.restarted, byName: 'Wendy Worker', at: DateTime.utc(2026, 10, 1, 12)),
      HistoryEntry(event: HistoryEvent.resubmitted, byName: 'Wendy Worker', at: DateTime.utc(2026, 10, 1, 13)),
      HistoryEntry(event: null, byName: '', at: DateTime.utc(2026, 10, 1, 14)),
    ];

    await openHistory(tester);

    for (final label in ['Created', 'Submitted', 'Rejected', 'Started again', 'Resubmitted', 'Changed']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Wrong kitchen'), findsOneWidget);
    expect(find.textContaining('Mia Manager · '), findsNWidgets(2));
  });

  testWidgets('offline: a message and Retry', (tester) async {
    tasks.historyFailure = const NetworkFailure();

    await openHistory(tester);

    expect(find.text('The history needs an internet connection.'), findsOneWidget);
    tasks
      ..historyFailure = null
      ..history = [HistoryEntry(event: HistoryEvent.created, byName: 'Mia Manager', at: DateTime.utc(2026, 10, 1))];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Created'), findsOneWidget);
  });

  testWidgets('no history yet', (tester) async {
    await openHistory(tester);

    expect(find.text('No history yet.'), findsOneWidget);
  });
}
