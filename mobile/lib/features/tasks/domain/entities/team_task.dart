import 'package:equatable/equatable.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// A team member's task as the worker sees it (a "tile"): title, status,
/// priority, due date and who works on it - no description, requirements,
/// answers or evidence (docs/architecture.md, "What a Worker Sees").
class TeamTask extends Equatable {
  const TeamTask({
    required this.id,
    required this.title,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.updatedAt,
    this.assignee,
  });

  final String id;
  final String title;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime dueDate;
  final PersonRef? assignee;
  final DateTime updatedAt;

  /// Same rule as [Task.isOverdue].
  bool isOverdue(DateTime now) => !status.isFinal && status != TaskStatus.submitted && dueDate.isBefore(now);

  @override
  List<Object?> get props => [id, title, priority, status, dueDate, assignee, updatedAt];
}
