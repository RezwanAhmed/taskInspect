import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/presentation/task_filter.dart';

import '../../../helpers/fake_tasks.dart';

Task prioritized(TaskPriority priority) => Task(
      id: priority.name,
      title: priority.name,
      priority: priority,
      status: TaskStatus.assigned,
      dueDate: DateTime.utc(2099),
      createdBy: const PersonRef(id: 'm', name: 'M'),
      reviewer: const PersonRef(id: 'm', name: 'M'),
      version: 1,
      updatedAt: DateTime.utc(2026),
    );

void main() {
  final now = DateTime(2026, 10, 1, 10);

  test('no filter matches everything', () {
    expect(const TaskFilter().isActive, isFalse);
    expect(const TaskFilter().matches(fakeTask('1'), now), isTrue);
  });

  test('priority', () {
    const filter = TaskFilter(priorities: {TaskPriority.high});
    expect(filter.matches(prioritized(TaskPriority.high), now), isTrue);
    expect(filter.matches(prioritized(TaskPriority.low), now), isFalse);
    expect(filter.activeCount, 1);
  });

  test('due date', () {
    final overdue = fakeTask('1', due: DateTime(2026, 9, 30).toUtc());
    final today = fakeTask('2', due: DateTime(2026, 10, 1, 18).toUtc());
    final inThreeDays = fakeTask('3', due: DateTime(2026, 10, 4).toUtc());
    final nextMonth = fakeTask('4', due: DateTime(2026, 11, 1).toUtc());

    bool shows(DueFilter due, Task task) => TaskFilter(due: due).matches(task, now);

    expect([overdue, today, inThreeDays, nextMonth].where((t) => shows(DueFilter.overdue, t)), [overdue]);
    expect([overdue, today, inThreeDays, nextMonth].where((t) => shows(DueFilter.today, t)), [today]);
    expect([overdue, today, inThreeDays, nextMonth].where((t) => shows(DueFilter.next7Days, t)),
        [today, inThreeDays]);
  });

  test('status', () {
    const filter = TaskFilter(statuses: {TaskStatus.inProgress});
    expect(filter.matches(fakeTask('1', status: TaskStatus.inProgress), now), isTrue);
    expect(filter.matches(fakeTask('2'), now), isFalse);
  });

  test('filters combine', () {
    final filter = const TaskFilter(priorities: {TaskPriority.medium}).copyWith(due: DueFilter.overdue);
    expect(filter.activeCount, 2);
    expect(filter.matches(fakeTask('1', due: DateTime(2026, 9, 1).toUtc()), now), isTrue);
    expect(filter.matches(fakeTask('2'), now), isFalse);
  });
}
