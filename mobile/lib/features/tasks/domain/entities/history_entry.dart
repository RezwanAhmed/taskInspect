import 'package:equatable/equatable.dart';

/// What happened in one step of a task's history (spec "Task History").
enum HistoryEvent {
  created('CREATED', 'Created'),
  assigned('ASSIGNED', 'Assigned'),
  started('STARTED', 'Started'),
  restarted('RESTARTED', 'Started again'),
  submitted('SUBMITTED', 'Submitted'),
  resubmitted('RESUBMITTED', 'Resubmitted'),
  approved('APPROVED', 'Approved'),
  rejected('REJECTED', 'Rejected'),
  correctionRequested('CORRECTION_REQUESTED', 'Correction requested'),
  cancelled('CANCELLED', 'Cancelled');

  const HistoryEvent(this.apiName, this.label);

  final String apiName;
  final String label;

  /// `null` for an event this app version doesn't know.
  static HistoryEvent? tryFromApi(String name) => values.where((event) => event.apiName == name).firstOrNull;
}

/// One step of a task's history: what happened, who did it, when and why.
class HistoryEntry extends Equatable {
  const HistoryEntry({required this.event, required this.byName, required this.at, this.reason});

  /// `null` when this app version doesn't know the event.
  final HistoryEvent? event;
  final String byName;
  final DateTime at;
  final String? reason;

  @override
  List<Object?> get props => [event, byName, at, reason];
}
