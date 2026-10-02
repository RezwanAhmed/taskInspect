import 'package:equatable/equatable.dart';

/// A manager's team in numbers only - all a worker sees of other teams
/// (docs/architecture.md, "What a Worker Sees").
class TeamSummary extends Equatable {
  const TeamSummary({
    required this.managerId,
    required this.managerName,
    required this.memberCount,
    required this.unfinishedTaskCount,
    required this.isMyTeam,
  });

  final String managerId;
  final String managerName;

  /// Active members of the team.
  final int memberCount;

  /// Tasks of the team members (also deactivated ones) that are not
  /// approved or cancelled yet.
  final int unfinishedTaskCount;

  /// The user leads this team or is a member of it.
  final bool isMyTeam;

  @override
  List<Object?> get props => [managerId, managerName, memberCount, unfinishedTaskCount, isMyTeam];
}
