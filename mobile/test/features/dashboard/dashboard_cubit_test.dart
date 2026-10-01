import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/usecases/refresh_tasks.dart';

import '../../helpers/fake_tasks.dart';

void main() {
  final now = DateTime.utc(2026, 10, 3);

  DashboardCubit build(FakeTaskRepository repository) =>
      DashboardCubit(repository, RefreshTasks(repository), now: () => now);

  test('counts tasks by status and finds overdue ones', () async {
    final repository = FakeTaskRepository([
      fakeTask('1'),
      fakeTask('2', due: DateTime.utc(2026, 10, 1)),
      fakeTask('3', status: TaskStatus.inProgress),
      fakeTask('4', status: TaskStatus.approved, due: DateTime.utc(2026, 10, 1)),
    ]);
    final cubit = build(repository);

    await cubit.start();

    expect(cubit.state.count(TaskStatus.assigned), 2);
    expect(cubit.state.count(TaskStatus.inProgress), 1);
    expect(cubit.state.count(TaskStatus.approved), 1);
    expect(cubit.state.count(TaskStatus.submitted), 0);
    expect(cubit.state.total, 4);
    expect(cubit.state.overdue, 1);
    expect(cubit.state.isLoading, isFalse);
    expect(repository.refreshes, 1);
    await cubit.close();
  });

  test('counts follow changes on the device', () async {
    final repository = FakeTaskRepository([fakeTask('1')]);
    final cubit = build(repository);
    await cubit.start();

    repository.emit([fakeTask('1', status: TaskStatus.inProgress), fakeTask('2')]);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.count(TaskStatus.inProgress), 1);
    expect(cubit.state.count(TaskStatus.assigned), 1);
    await cubit.close();
  });

  blocTest<DashboardCubit, DashboardState>(
    'offline refresh keeps the device counts and explains why',
    build: () => build(FakeTaskRepository()..refreshFailure = const NetworkFailure()),
    act: (cubit) => cubit.refresh(),
    expect: () => [
      const DashboardState(isRefreshing: true),
      const DashboardState(message: 'Offline — showing the tasks saved on this device.'),
    ],
  );
}
