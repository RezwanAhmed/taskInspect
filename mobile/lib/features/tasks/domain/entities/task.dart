import 'package:equatable/equatable.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// A short reference to a person (creator, reviewer, assignee).
class PersonRef extends Equatable {
  const PersonRef({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// A task as the app shows it.
class Task extends Equatable {
  const Task({
    required this.id,
    required this.title,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.createdBy,
    required this.reviewer,
    required this.version,
    required this.updatedAt,
    this.description,
    this.assignee,
  });

  final String id;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime dueDate;
  final PersonRef createdBy;
  final PersonRef reviewer;
  final PersonRef? assignee;

  /// Server version, sent back when changing the task (stale changes are refused).
  final int version;
  final DateTime updatedAt;

  bool isOverdue(DateTime now) => !status.isFinal && status != TaskStatus.submitted && dueDate.isBefore(now);

  @override
  List<Object?> get props =>
      [id, title, description, priority, status, dueDate, createdBy, reviewer, assignee, version, updatedAt];
}
