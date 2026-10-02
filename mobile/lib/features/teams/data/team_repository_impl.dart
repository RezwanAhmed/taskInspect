import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/features/teams/domain/entities/team_summary.dart';
import 'package:taskinspect/features/teams/domain/repositories/team_repository.dart';

/// `GET /api/teams`. Only numbers, so nothing is stored on the device.
class TeamRepositoryImpl implements TeamRepository {
  const TeamRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<TeamSummary>>> loadTeams() {
    return _api.send(
      (dio) => dio.get<Object?>('/api/teams'),
      (body) => [
        for (final json in (body! as List<Object?>).cast<Map<String, Object?>>())
          TeamSummary(
            managerId: json['managerId']! as String,
            managerName: json['managerName']! as String,
            memberCount: (json['memberCount']! as num).toInt(),
            unfinishedTaskCount: (json['unfinishedTaskCount']! as num).toInt(),
            isMyTeam: json['myTeam']! as bool,
          ),
      ],
    );
  }
}
