import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// The tabs of the task list (spec: All, Pending, In progress, Submitted,
/// Rejected, Approved). "Rejected" also holds correction requests, since
/// both need the worker again.
enum TaskTab {
  all('All', null),
  pending('Pending', {TaskStatus.assigned}),
  inProgress('In progress', {TaskStatus.inProgress}),
  submitted('Submitted', {TaskStatus.submitted}),
  rejected('Rejected', {TaskStatus.rejected, TaskStatus.correctionRequested}),
  approved('Approved', {TaskStatus.approved});

  const TaskTab(this.label, this.statuses);

  final String label;

  /// Statuses shown on this tab; `null` means all.
  final Set<TaskStatus>? statuses;

  bool matches(TaskStatus status) => statuses?.contains(status) ?? true;

  /// The tab for a URL value like `inProgress`, or [all].
  static TaskTab parse(String? name) => values.firstWhere((tab) => tab.name == name, orElse: () => all);
}
