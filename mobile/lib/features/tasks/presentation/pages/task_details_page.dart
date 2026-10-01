import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/usecases/start_task.dart';
import 'package:taskinspect/features/tasks/presentation/cubit/task_details_cubit.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/requirement_type_icon.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/status_chip.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/task_tile.dart';

/// Everything about one task (spec: title, description, assigned user,
/// creator, priority, deadline, requirements, current status).
class TaskDetailsPage extends StatelessWidget {
  const TaskDetailsPage({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TaskDetailsCubit(getIt(), getIt(), taskId),
      child: BlocConsumer<TaskDetailsCubit, TaskDetailsState>(
        listenWhen: (previous, current) =>
            (current.message != null && previous.message != current.message) ||
            (previous.task?.status != current.task?.status &&
                current.task?.status == TaskStatus.inProgress &&
                previous.isStarting),
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message!)));
            context.read<TaskDetailsCubit>().clearMessage();
          } else {
            // Just started: go straight to the requirements.
            context.push(AppRoutes.execute(taskId));
          }
        },
        builder: (context, state) {
          final task = state.task;
          final auth = context.watch<AuthBloc>().state;
          final userId = auth is Authenticated ? auth.user.id : '';
          return Scaffold(
            appBar: AppBar(title: const Text('Task')),
            bottomNavigationBar: task != null && _canContinue(task, userId)
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        key: const Key('continue-task'),
                        onPressed: () =>
                            context.push(AppRoutes.execute(taskId)),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Continue'),
                      ),
                    ),
                  )
                : task != null && StartTask.canStart(task, userId)
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        key: const Key('start-task'),
                        onPressed: state.isStarting
                            ? null
                            : () => context.read<TaskDetailsCubit>().start(),
                        icon: state.isStarting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(switch (task.status) {
                          TaskStatus.rejected => 'Start again',
                          TaskStatus.correctionRequested => 'Start correction',
                          _ => 'Start task',
                        }),
                      ),
                    ),
                  )
                : null,
            body: switch ((state.isLoading, task)) {
              (true, _) => const Center(child: CircularProgressIndicator()),
              (false, null) => const Center(
                child: Text('This task is not on this device.'),
              ),
              (false, final Task task) => _Details(
                task: task,
                requirements: state.requirements,
              ),
            },
          );
        },
      ),
    );
  }
}

bool _canContinue(Task task, String userId) =>
    task.status == TaskStatus.inProgress && task.assignee?.id == userId;

class _Details extends StatelessWidget {
  const _Details({required this.task, required this.requirements});

  final Task task;
  final List<Requirement> requirements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = task.isOverdue(DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(task.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: StatusChip(task.status)),
        if (task.description != null) ...[
          const SizedBox(height: 16),
          Text(task.description!, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 16),
        _Fact(
          icon: Icons.flag_outlined,
          label: 'Priority',
          value: switch (task.priority) {
            TaskPriority.high => 'High',
            TaskPriority.medium => 'Medium',
            TaskPriority.low => 'Low',
          },
        ),
        _Fact(
          icon: Icons.event_outlined,
          label: 'Deadline',
          value:
              '${TaskTile.formatDue(task.dueDate)}${overdue ? ' (overdue)' : ''}',
          valueColor: overdue ? theme.colorScheme.error : null,
        ),
        _Fact(
          icon: Icons.engineering_outlined,
          label: 'Assigned to',
          value: task.assignee?.name ?? 'Not assigned',
        ),
        _Fact(
          icon: Icons.person_outline,
          label: 'Created by',
          value: task.createdBy.name,
        ),
        _Fact(
          icon: Icons.verified_outlined,
          label: 'Reviewer',
          value: task.reviewer.name,
        ),
        const Divider(height: 32),
        Text(
          'Requirements (${requirements.length})',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (requirements.isEmpty) const Text('No requirements yet.'),
        for (final requirement in requirements) _RequirementRow(requirement),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow(this.requirement);

  final Requirement requirement;

  @override
  Widget build(BuildContext context) {
    final details = [
      RequirementTypeLook.label(requirement.type),
      if (requirement.unit != null) requirement.unit!,
      if (requirement.options.isNotEmpty)
        requirement.options.map((option) => option.label).join(' / '),
      if (requirement.required) 'Required' else 'Optional',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(RequirementTypeLook.icon(requirement.type)),
        title: Text(requirement.title),
        subtitle: Text(
          requirement.description == null
              ? details
              : '${requirement.description}\n$details',
        ),
      ),
    );
  }
}
