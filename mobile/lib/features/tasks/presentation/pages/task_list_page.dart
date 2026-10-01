import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/features/tasks/presentation/cubit/task_list_cubit.dart';
import 'package:taskinspect/features/tasks/presentation/task_tab.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/task_tile.dart';

/// All tasks on the device, in tabs by status.
class TaskListPage extends StatelessWidget {
  const TaskListPage({this.initialTab = TaskTab.all, super.key});

  final TaskTab initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: TaskTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tasks'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in TaskTab.values) Tab(text: tab.label)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final tab in TaskTab.values)
              BlocProvider(
                create: (_) => TaskListCubit(getIt(), tab),
                child: const _TaskTabView(),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskTabView extends StatelessWidget {
  const _TaskTabView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskListCubit, TaskListState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.tasks.isEmpty) {
          return const Center(child: Text('No tasks here'));
        }
        final now = DateTime.now();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.tasks.length,
          itemBuilder: (context, index) => TaskTile(task: state.tasks[index], now: now),
        );
      },
    );
  }
}
