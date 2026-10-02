import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/presentation/cubit/main_task_cubit.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/status_chip.dart';

/// A main task's sub-tasks for its manager: "N of M approved", each
/// sub-task with status and worker, and the submit once all are approved
/// (cancelled ones don't count). Loaded from the server.
class MainTaskPanel extends StatelessWidget {
  const MainTaskPanel({required this.task, super.key});

  /// While the server accepts new sub-tasks (TaskService.createSubTask).
  static const _takesSubTasks = {
    TaskStatus.assigned,
    TaskStatus.inProgress,
    TaskStatus.rejected,
    TaskStatus.correctionRequested,
  };

  final Task task;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MainTaskCubit(getIt(), getIt(), task.id)..load(),
      child: BlocConsumer<MainTaskCubit, MainTaskState>(
        listenWhen: (previous, current) => current.message != null && previous.message != current.message,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message!)));
          context.read<MainTaskCubit>().clearMessage();
        },
        builder: (context, state) {
          final theme = Theme.of(context);
          return Card(
            key: const Key('main-task-panel'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Sub-tasks', style: theme.textTheme.titleMedium)),
                      IconButton(
                        tooltip: 'Reload sub-tasks',
                        icon: const Icon(Icons.refresh),
                        onPressed: state.isLoading ? null : () => context.read<MainTaskCubit>().load(),
                      ),
                    ],
                  ),
                  if (state.isLoading)
                    const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
                  else if (state.error != null)
                    Text(state.error!, key: const Key('sub-tasks-error'))
                  else if (state.subTasks.isEmpty)
                    const Text('No sub-tasks yet.')
                  else ...[
                    Text('${state.approved} of ${state.total} approved'),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: state.total == 0 ? 0 : state.approved / state.total),
                    const SizedBox(height: 6),
                    for (final subTask in state.subTasks)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(subTask.title),
                        subtitle: Text(subTask.assignee?.name ?? 'Not assigned'),
                        trailing: StatusChip(subTask.status),
                        onTap: () => context.push(AppRoutes.task(subTask.id)),
                      ),
                  ],
                  if (_takesSubTasks.contains(task.status))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('add-sub-task'),
                        onPressed: () async {
                          final cubit = context.read<MainTaskCubit>();
                          await context.push(AppRoutes.newSubTask(task.id));
                          await cubit.load();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add sub-task'),
                      ),
                    ),
                  if (task.status == TaskStatus.inProgress) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const Key('submit-main-task'),
                      onPressed: state.canSubmit && !state.isSubmitting
                          ? () => context.read<MainTaskCubit>().submit()
                          : null,
                      icon: const Icon(Icons.send),
                      label: const Text('Submit main task'),
                    ),
                    if (!state.isLoading && state.error == null && !state.canSubmit)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Every sub-task must be approved first.', style: theme.textTheme.bodySmall),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
