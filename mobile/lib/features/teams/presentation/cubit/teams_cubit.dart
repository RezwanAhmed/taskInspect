import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/failure_messages.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/teams/domain/entities/team_summary.dart';
import 'package:taskinspect/features/teams/domain/usecases/load_teams.dart';

class TeamsState extends Equatable {
  const TeamsState({this.teams = const [], this.isLoading = true, this.error, this.canRetry = false});

  final List<TeamSummary> teams;
  final bool isLoading;
  final String? error;

  /// Whether trying again can help (a connection problem).
  final bool canRetry;

  @override
  List<Object?> get props => [teams, isLoading, error, canRetry];
}

/// Loads the teams in numbers from the server.
class TeamsCubit extends Cubit<TeamsState> {
  TeamsCubit(this._loadTeams) : super(const TeamsState());

  final LoadTeams _loadTeams;

  Future<void> load() async {
    emit(const TeamsState());
    final result = await _loadTeams();
    if (isClosed) {
      return;
    }
    emit(switch (result) {
      Ok(:final value) => TeamsState(teams: value, isLoading: false),
      Err(failure: NetworkFailure()) =>
        const TeamsState(isLoading: false, canRetry: true, error: 'The teams need an internet connection.'),
      Err(:final failure) => TeamsState(isLoading: false, error: userMessage(failure)),
    });
  }
}
