import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/features/teams/data/team_repository_impl.dart';
import 'package:taskinspect/features/teams/domain/entities/team_summary.dart';
import 'package:taskinspect/features/teams/domain/repositories/team_repository.dart';
import 'package:taskinspect/features/teams/domain/usecases/load_teams.dart';
import 'package:taskinspect/features/teams/presentation/pages/teams_page.dart';

import '../../helpers/fake_server.dart';

class _FakeTeams implements TeamRepository {
  _FakeTeams(this.result);

  Result<List<TeamSummary>> result;
  int loads = 0;

  @override
  Future<Result<List<TeamSummary>>> loadTeams() async {
    loads++;
    return result;
  }
}

void main() {
  test('reads GET /api/teams', () async {
    final api = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    api.dio.httpClientAdapter = FakeServer((request) async {
      expect(request.path, '/api/teams');
      return (200, [
        {'managerId': 'm1', 'managerName': 'Mia Manager', 'memberCount': 3, 'unfinishedTaskCount': 5, 'myTeam': true},
      ]);
    });

    final result = await TeamRepositoryImpl(api).loadTeams();

    expect((result as Ok<List<TeamSummary>>).value, [
      const TeamSummary(managerId: 'm1', managerName: 'Mia Manager', memberCount: 3, unfinishedTaskCount: 5, isMyTeam: true),
    ]);
  });

  group('TeamsPage', () {
    tearDown(getIt.reset);

    Future<_FakeTeams> open(WidgetTester tester, Result<List<TeamSummary>> result) async {
      final teams = _FakeTeams(result);
      getIt.registerFactory(() => LoadTeams(teams));
      await tester.pumpWidget(const MaterialApp(home: TeamsPage()));
      await tester.pumpAndSettle();
      return teams;
    }

    testWidgets('shows every team in numbers and marks my team', (tester) async {
      await open(tester, const Ok([
        TeamSummary(managerId: 'm1', managerName: 'Mia Manager', memberCount: 3, unfinishedTaskCount: 5, isMyTeam: true),
        TeamSummary(managerId: 'm2', managerName: 'Max Manager', memberCount: 1, unfinishedTaskCount: 1, isMyTeam: false),
      ]));

      expect(find.text('Mia Manager'), findsOneWidget);
      expect(find.text('3 members · 5 open tasks'), findsOneWidget);
      expect(find.text('1 member · 1 open task'), findsOneWidget);
      expect(find.text('My team'), findsOneWidget);
    });

    testWidgets('offline: says so and can retry', (tester) async {
      final teams = await open(tester, const Err(NetworkFailure()));

      expect(find.text('The teams need an internet connection.'), findsOneWidget);
      teams.result = const Ok([]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(teams.loads, 2);
      expect(find.text('No teams yet.'), findsOneWidget);
    });
  });
}
