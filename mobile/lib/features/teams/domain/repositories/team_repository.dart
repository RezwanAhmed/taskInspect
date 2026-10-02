import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/teams/domain/entities/team_summary.dart';

/// The organization's teams in numbers, from the server (needs a connection).
abstract interface class TeamRepository {
  /// Every manager's team, sorted by the manager's name.
  Future<Result<List<TeamSummary>>> loadTeams();
}
