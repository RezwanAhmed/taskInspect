import 'package:equatable/equatable.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// When a task is due, for filtering.
enum DueFilter {
  any('Any time'),
  overdue('Overdue'),
  today('Due today'),
  next7Days('Next 7 days');

  const DueFilter(this.label);

  final String label;
}

/// Filters for the task list (spec: priority, due date, status). Status is
/// chosen with the tabs; [statuses] narrows the "All" tab further.
class TaskFilter extends Equatable {
  const TaskFilter({this.priorities = const {}, this.due = DueFilter.any, this.statuses = const {}});

  /// Empty means every priority.
  final Set<TaskPriority> priorities;
  final DueFilter due;

  /// Empty means every status.
  final Set<TaskStatus> statuses;

  bool get isActive => priorities.isNotEmpty || due != DueFilter.any || statuses.isNotEmpty;

  int get activeCount => (priorities.isNotEmpty ? 1 : 0) + (due != DueFilter.any ? 1 : 0) + (statuses.isNotEmpty ? 1 : 0);

  bool matches(Task task, DateTime now) {
    if (priorities.isNotEmpty && !priorities.contains(task.priority)) {
      return false;
    }
    if (statuses.isNotEmpty && !statuses.contains(task.status)) {
      return false;
    }
    final localNow = now.toLocal();
    final startOfToday = DateTime(localNow.year, localNow.month, localNow.day);
    final due = task.dueDate.toLocal();
    return switch (this.due) {
      DueFilter.any => true,
      DueFilter.overdue => task.isOverdue(now),
      DueFilter.today => !due.isBefore(startOfToday) && due.isBefore(startOfToday.add(const Duration(days: 1))),
      DueFilter.next7Days => !due.isBefore(localNow) && due.isBefore(startOfToday.add(const Duration(days: 8))),
    };
  }

  TaskFilter copyWith({Set<TaskPriority>? priorities, DueFilter? due, Set<TaskStatus>? statuses}) => TaskFilter(
        priorities: priorities ?? this.priorities,
        due: due ?? this.due,
        statuses: statuses ?? this.statuses,
      );

  @override
  List<Object?> get props => [priorities, due, statuses];
}
