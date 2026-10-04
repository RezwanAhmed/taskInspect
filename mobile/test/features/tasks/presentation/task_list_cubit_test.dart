import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/team_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_tasks.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_team_tasks.dart';
import 'package:taskinspect/features/tasks/presentation/cubit/task_list_cubit.dart';
import 'package:taskinspect/features/tasks/presentation/cubit/team_task_list_cubit.dart';
import 'package:taskinspect/features/tasks/presentation/task_tab.dart';

import '../../../helpers/fake_tasks.dart';

/// Unit tests of the task list cubits (task 9.4a).
void main() {
  group('TaskListCubit', () {
    test('starts loading, then shows only the tasks of its tab', () async {
      final repository = FakeTaskRepository([
        fakeTask('1'),
        fakeTask('2', status: TaskStatus.rejected),
        fakeTask('3', status: TaskStatus.correctionRequested),
        fakeTask('4', status: TaskStatus.approved),
      ]);
      final cubit = TaskListCubit(WatchTasks(repository), (task) => TaskTab.rejected.matches(task.status));
      expect(cubit.state.isLoading, isTrue);

      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.tasks.map((task) => task.id), ['2', '3']);
      await cubit.close();
    });

    test('follows changes on the device', () async {
      final repository = FakeTaskRepository([fakeTask('1')]);
      final cubit = TaskListCubit(WatchTasks(repository), (task) => TaskTab.inProgress.matches(task.status));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.tasks, isEmpty);

      repository.emit([fakeTask('1', status: TaskStatus.inProgress), fakeTask('2')]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.tasks.map((task) => task.id), ['1']);
      await cubit.close();
    });

    // A cubit that still listened after close would emit on the next change; bloc throws
    // "Cannot emit new states after calling close" in the test zone, which fails the test.
    test('stops listening when closed', () async {
      final repository = FakeTaskRepository([fakeTask('1')]);
      final cubit = TaskListCubit(WatchTasks(repository), (_) => true);
      await Future<void>.delayed(Duration.zero);
      final before = cubit.state;

      await cubit.close();
      repository.emit([fakeTask('2')]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, before);
    });
  });

  group('TeamTaskListCubit', () {
    test('shows the team members\' tasks of its tab', () async {
      final repository = FakeTaskRepository()
        ..teamTasks = [
          teamTask('a', TaskStatus.assigned),
          teamTask('b', TaskStatus.inProgress),
          teamTask('c', TaskStatus.submitted),
          teamTask('d', TaskStatus.rejected),
          teamTask('e', TaskStatus.approved),
        ];

      final pending = TeamTaskListCubit(WatchTeamTasks(repository), TeamTaskTab.pending);
      final rejected = TeamTaskListCubit(WatchTeamTasks(repository), TeamTaskTab.rejected);
      await Future<void>.delayed(Duration.zero);

      expect(pending.state.isLoading, isFalse);
      expect(pending.state.tasks.map((task) => task.id), ['a', 'b', 'c']);
      expect(rejected.state.tasks.map((task) => task.id), ['d']);
      await pending.close();
      await rejected.close();
    });

    test('an empty team shows an empty list, not a spinner', () async {
      final cubit = TeamTaskListCubit(WatchTeamTasks(FakeTaskRepository()), TeamTaskTab.pending);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, const TeamTaskListState(isLoading: false));
      await cubit.close();
    });
  });
}

TeamTask teamTask(String id, TaskStatus status) => TeamTask(
      id: id,
      title: 'Task $id',
      priority: TaskPriority.medium,
      status: status,
      dueDate: DateTime.utc(2026, 10, 10),
      updatedAt: DateTime.utc(2026, 10, 1),
      assignee: const PersonRef(id: 'w2', name: 'Walter Worker'),
    );
