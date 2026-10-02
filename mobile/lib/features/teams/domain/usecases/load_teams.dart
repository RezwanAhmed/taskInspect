import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/teams/domain/entities/team_summary.dart';
import 'package:taskinspect/features/teams/domain/repositories/team_repository.dart';

/// Loads every manager's team in numbers (task count, member count).
class LoadTeams {
  const LoadTeams(this._repository);

  final TeamRepository _repository;

  Future<Result<List<TeamSummary>>> call() => _repository.loadTeams();
}
