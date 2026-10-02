import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/core/synchronization/sync_status_cubit.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/presentation/cubit/task_list_cubit.dart';
import 'package:taskinspect/features/tasks/presentation/task_filter.dart';
import 'package:taskinspect/features/tasks/presentation/task_tab.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/task_filter_sheet.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/task_tile.dart';
import 'package:taskinspect/shared/widgets/sync_status_banner.dart';

/// The tasks on the device in tabs, with filters for priority, due date and
/// status that apply to every tab. Managers get every task by status
/// ([TaskTab]); workers get "My tasks", only those assigned to them
/// ([MyTaskTab], docs/architecture.md "The Worker's Tabs").
class TaskListPage extends StatelessWidget {
  const TaskListPage({this.initialTab = TaskTab.all, super.key});

  final TaskTab initialTab;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is Authenticated ? auth.user : null;
    final myTasks = user != null && user.isWorker && !user.isManager;
    final tabs = myTasks
        ? [
            for (final tab in MyTaskTab.values)
              _TabSpec(tab.label, (task) => tab.matches(task.status) && task.assignee?.id == user.id),
          ]
        : [for (final tab in TaskTab.values) _TabSpec(tab.label, (task) => tab.matches(task.status))];
    return BlocProvider(
      create: (_) => TaskFilterCubit(),
      child: DefaultTabController(
        // A new controller when the tab set changes (e.g. another user signs in).
        key: ValueKey(myTasks),
        length: tabs.length,
        initialIndex: myTasks ? MyTaskTab.of(initialTab).index : initialTab.index,
        child: Scaffold(
          appBar: AppBar(
            title: Text(myTasks ? 'My tasks' : 'Tasks'),
            actions: const [_FilterButton()],
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final tab in tabs) Tab(text: tab.label)],
            ),
          ),
          body: Column(
            children: [
              const Padding(padding: EdgeInsets.fromLTRB(8, 8, 8, 0), child: SyncStatusBanner()),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final tab in tabs)
                      BlocProvider(
                        create: (_) => TaskListCubit(getIt(), tab.matches),
                        child: const _TaskTabView(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tab of the page: its label and which tasks it shows.
class _TabSpec {
  const _TabSpec(this.label, this.matches);

  final String label;
  final bool Function(Task task) matches;
}

/// The filter chosen on the task list page, shared by all tabs.
class TaskFilterCubit extends Cubit<TaskFilter> {
  TaskFilterCubit() : super(const TaskFilter());

  void apply(TaskFilter filter) => emit(filter);
}

class _FilterButton extends StatelessWidget {
  const _FilterButton();

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<TaskFilterCubit>().state;
    return IconButton(
      tooltip: 'Filter',
      icon: Badge(
        isLabelVisible: filter.isActive,
        label: Text('${filter.activeCount}'),
        child: const Icon(Icons.filter_list),
      ),
      onPressed: () async {
        final chosen = await TaskFilterSheet.show(context, filter);
        if (chosen != null && context.mounted) {
          context.read<TaskFilterCubit>().apply(chosen);
        }
      },
    );
  }
}

/// Compared by content, so the list rebuilds only when the tasks with
/// unsent changes change (not on every sync status update).
class _UnsentTasks {
  const _UnsentTasks(this.ids);

  final Set<String> ids;

  @override
  bool operator ==(Object other) => other is _UnsentTasks && setEquals(other.ids, ids);

  @override
  int get hashCode => Object.hashAllUnordered(ids);
}

class _TaskTabView extends StatelessWidget {
  const _TaskTabView();

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<TaskFilterCubit>().state;
    final unsent = context.select((SyncStatusCubit cubit) => _UnsentTasks(cubit.state.unsentTaskIds)).ids;
    return BlocBuilder<TaskListCubit, TaskListState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final now = DateTime.now();
        final tasks = state.tasks.where((task) => filter.matches(task, now)).toList();
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(filter.isActive ? 'No tasks match the filters' : 'No tasks here'),
                if (filter.isActive)
                  TextButton(
                    onPressed: () => context.read<TaskFilterCubit>().apply(const TaskFilter()),
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: tasks.length,
          itemBuilder: (context, index) => TaskTile(
            task: tasks[index],
            now: now,
            hasUnsentChanges: unsent.contains(tasks[index].id),
            onTap: () => context.push(AppRoutes.task(tasks[index].id)),
          ),
        );
      },
    );
  }
}
