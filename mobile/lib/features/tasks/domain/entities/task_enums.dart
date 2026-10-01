/// Task status, as in the backend's task lifecycle.
enum TaskStatus {
  draft('DRAFT'),

  /// Published without an assignee; a worker may take it (Phase 7A).
  open('OPEN'),
  assigned('ASSIGNED'),
  inProgress('IN_PROGRESS'),
  submitted('SUBMITTED'),
  approved('APPROVED'),
  rejected('REJECTED'),
  correctionRequested('CORRECTION_REQUESTED'),
  cancelled('CANCELLED');

  const TaskStatus(this.apiName);

  /// The name the API uses, e.g. `IN_PROGRESS`.
  final String apiName;

  static TaskStatus fromApi(String name) => values.firstWhere((status) => status.apiName == name);

  /// Approved and cancelled tasks can no longer change.
  bool get isFinal => this == approved || this == cancelled;
}

enum TaskPriority {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const TaskPriority(this.apiName);

  final String apiName;

  static TaskPriority fromApi(String name) => values.firstWhere((priority) => priority.apiName == name);
}

/// How a requirement is answered.
enum RequirementType {
  checkbox('CHECKBOX'),
  yesNo('YES_NO'),
  text('TEXT'),
  number('NUMBER'),
  dropdown('DROPDOWN'),
  multipleSelection('MULTIPLE_SELECTION'),
  photo('PHOTO'),
  document('DOCUMENT'),
  comment('COMMENT');

  const RequirementType(this.apiName);

  final String apiName;

  static RequirementType fromApi(String name) => values.firstWhere((type) => type.apiName == name);

  bool get hasOptions => this == dropdown || this == multipleSelection;

  /// Photos and documents are answered with evidence files.
  bool get isEvidence => this == photo || this == document;
}
