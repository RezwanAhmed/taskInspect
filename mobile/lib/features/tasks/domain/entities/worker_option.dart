import 'package:equatable/equatable.dart';

/// An active worker a manager can assign a task to.
class WorkerOption extends Equatable {
  const WorkerOption({required this.id, required this.name, required this.inMyTeam});

  final String id;
  final String name;

  /// In the team of the manager who is choosing.
  final bool inMyTeam;

  @override
  List<Object?> get props => [id, name, inMyTeam];
}
