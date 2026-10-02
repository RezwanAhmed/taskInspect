import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/teams/domain/entities/team_summary.dart';
import 'package:taskinspect/features/teams/domain/repositories/team_repository.dart';
import 'package:taskinspect/features/teams/domain/usecases/load_teams.dart';

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

  testWidgets('managers also see their drafts and open tasks', (tester) async {
    registerFakeTasks(FakeTaskRepository([
      fakeTask('1', status: TaskStatus.draft),
      fakeTask('2', status: TaskStatus.open),
      fakeTask('3', status: TaskStatus.open),
    ]));
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testManager))));
    await tester.pumpAndSettle();

    expect(countOn(tester, 'Draft'), 1);
    expect(countOn(tester, 'Open'), 2);
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

  testWidgets('a worker opens the Teams page from the dashboard', (tester) async {
    getIt.registerFactory(() => LoadTeams(_OneTeam()));
    await open(tester, FakeTaskRepository());

    await tester.tap(find.byTooltip('Teams'));
    await tester.pumpAndSettle();

    expect(find.text('Mia Manager'), findsOneWidget);
    expect(find.text('2 members · 4 open tasks'), findsOneWidget);
  });
}

class _OneTeam implements TeamRepository {
  @override
  Future<Result<List<TeamSummary>>> loadTeams() async => const Ok([
        TeamSummary(managerId: 'm1', managerName: 'Mia Manager', memberCount: 2, unfinishedTaskCount: 4, isMyTeam: true),
      ]);
}
