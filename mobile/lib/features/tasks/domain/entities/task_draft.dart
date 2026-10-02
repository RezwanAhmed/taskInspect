import 'package:equatable/equatable.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// The details a manager enters for a new or edited draft task
/// (docs/architecture.md, "What Works Offline").
class TaskDraft extends Equatable {
  const TaskDraft({
    required this.title,
    required this.priority,
    required this.dueDate,
    this.description,
    this.reviewer,
  });

  final String title;
  final String? description;
  final TaskPriority priority;
  final DateTime dueDate;

  /// Another manager who reviews the task; `null`: the creator reviews it.
  final PersonRef? reviewer;

  @override
  List<Object?> get props => [title, description, priority, dueDate, reviewer];
}
