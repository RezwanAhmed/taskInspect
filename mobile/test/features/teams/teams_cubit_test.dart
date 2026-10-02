import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/teams/domain/entities/team_summary.dart';
import 'package:taskinspect/features/teams/domain/repositories/team_repository.dart';
import 'package:taskinspect/features/teams/domain/usecases/load_teams.dart';
import 'package:taskinspect/features/teams/presentation/cubit/teams_cubit.dart';

class _FakeTeams implements TeamRepository {
  _FakeTeams(this.result);

  final Result<List<TeamSummary>> result;

  @override
  Future<Result<List<TeamSummary>>> loadTeams() async => result;
}

/// Unit tests of the teams cubit (task 9.4a).
void main() {
  const team = TeamSummary(
    managerId: 'm1',
    managerName: 'Mia Manager',
    memberCount: 3,
    unfinishedTaskCount: 5,
    isMyTeam: true,
  );

  TeamsCubit build(Result<List<TeamSummary>> result) => TeamsCubit(LoadTeams(_FakeTeams(result)));

  blocTest<TeamsCubit, TeamsState>(
    'loads the teams',
    build: () => build(const Ok([team])),
    act: (cubit) => cubit.load(),
    expect: () => [
      const TeamsState(),
      const TeamsState(teams: [team], isLoading: false),
    ],
  );

  blocTest<TeamsCubit, TeamsState>(
    'offline: explains that teams need a connection and offers a retry',
    build: () => build(const Err(NetworkFailure())),
    act: (cubit) => cubit.load(),
    expect: () => [
      const TeamsState(),
      const TeamsState(isLoading: false, canRetry: true, error: 'The teams need an internet connection.'),
    ],
  );

  blocTest<TeamsCubit, TeamsState>(
    'a server error is shown without a retry',
    build: () => build(const Err(ServerFailure(statusCode: 403, message: 'Not allowed'))),
    act: (cubit) => cubit.load(),
    expect: () => [
      const TeamsState(),
      const TeamsState(isLoading: false, error: 'Not allowed'),
    ],
  );

  blocTest<TeamsCubit, TeamsState>(
    'a reload starts from the loading state again',
    build: () => build(const Ok([team])),
    seed: () => const TeamsState(teams: [team], isLoading: false),
    act: (cubit) => cubit.load(),
    expect: () => [
      const TeamsState(),
      const TeamsState(teams: [team], isLoading: false),
    ],
  );

  test('a result arriving after the page is closed is dropped', () async {
    final cubit = build(const Ok([team]));

    final loading = cubit.load();
    await cubit.close();

    await expectLater(loading, completes);
  });
}
