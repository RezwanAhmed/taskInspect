import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/core/synchronization/sync_status_cubit.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_review.dart';
import 'package:taskinspect/features/tasks/domain/usecases/assign_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/load_sub_tasks.dart';
import 'package:taskinspect/features/tasks/domain/usecases/save_draft_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/start_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/take_task.dart';
import 'package:taskinspect/features/tasks/presentation/cubit/task_details_cubit.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/assign_sheet.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/main_task_panel.dart';
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
      create: (_) => TaskDetailsCubit(getIt(), getIt(), getIt(), taskId),
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
          final user = auth is Authenticated ? auth.user : null;
          final userId = user?.id ?? '';
          return Scaffold(
            appBar: AppBar(
              title: const Text('Task'),
              actions: [
                if (task != null && user != null && SaveDraftTask.canEdit(task, user))
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push(AppRoutes.editTask(taskId)),
                  ),
                IconButton(
                  tooltip: 'History',
                  icon: const Icon(Icons.history),
                  onPressed: () => context.push(AppRoutes.history(taskId)),
                ),
              ],
            ),
            bottomNavigationBar: task != null && _canReview(task, userId)
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        key: const Key('review-task'),
                        onPressed: () =>
                            context.push(AppRoutes.review(taskId)),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Review'),
                      ),
                    ),
                  )
                : task != null && _canContinue(task, userId) && !(user != null && LoadSubTasks.isMainTask(task, user))
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
                : task != null && user != null && AssignTask.canAssign(task, user)
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        key: const Key('assign-task'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final done = await AssignSheet.show(context, taskId, user);
                          if (done != null) {
                            messenger.showSnackBar(SnackBar(content: Text(done)));
                          }
                        },
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Assign or publish'),
                      ),
                    ),
                  )
                : task != null && user != null && TakeTask.canTake(task, user)
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        key: const Key('take-task'),
                        onPressed: state.isTaking
                            ? null
                            : () => context.read<TaskDetailsCubit>().take(),
                        icon: state.isTaking
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.pan_tool_alt_outlined),
                        label: const Text('Take task'),
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
                review: state.review,
                mainTaskPanel: user != null && LoadSubTasks.isMainTask(task, user)
                    ? MainTaskPanel(task: task)
                    : null,
                onEditRequirements: user != null && SaveDraftTask.canEdit(task, user)
                    ? () => context.push(AppRoutes.editRequirements(taskId))
                    : null,
              ),
            },
          );
        },
      ),
    );
  }
}

/// The task's reviewer reviews a submitted task - never its own worker,
/// except a manager's own personal task (the server's rule).
bool _canReview(Task task, String userId) =>
    task.status == TaskStatus.submitted &&
    task.reviewer.id == userId &&
    (task.assignee?.id != userId || task.createdBy.id == userId);

bool _canContinue(Task task, String userId) =>
    task.status == TaskStatus.inProgress && task.assignee?.id == userId;

class _Details extends StatelessWidget {
  const _Details({
    required this.task,
    required this.requirements,
    this.review,
    this.mainTaskPanel,
    this.onEditRequirements,
  });

  final Task task;
  final List<Requirement> requirements;
  final TaskReview? review;

  /// For the manager of a main task: its sub-tasks and the submit.
  final Widget? mainTaskPanel;

  /// For the task's creator while it can still be edited.
  final VoidCallback? onEditRequirements;

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
        if (mainTaskPanel != null) ...[const SizedBox(height: 12), mainTaskPanel!],
        if (task.status == TaskStatus.submitted &&
            context.select(
              (SyncStatusCubit cubit) => cubit.state.unsentTaskIds.contains(task.id),
            )) ...[
          const SizedBox(height: 12),
          const Card(
            key: Key('submitted-locally'),
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.cloud_upload_outlined),
              title: Text('Submitted locally — waiting for synchronization.'),
            ),
          ),
        ],
        if (review != null && _showsReview(task, review!)) ...[
          const SizedBox(height: 12),
          _ReviewResult(review: review!, requirements: requirements),
        ],
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
        Row(
          children: [
            Expanded(
              child: Text(
                'Requirements (${requirements.length})',
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (onEditRequirements != null)
              TextButton.icon(
                key: const Key('edit-requirements'),
                onPressed: onEditRequirements,
                icon: const Icon(Icons.edit_note),
                label: const Text('Edit'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (requirements.isEmpty) const Text('No requirements yet.'),
        for (final requirement in requirements) _RequirementRow(requirement),
      ],
    );
  }
}

/// The review that sent the task back (or approved it); shown while it
/// matters: rejected / correction requested, while the worker fixes it,
/// and on an approved task.
bool _showsReview(Task task, TaskReview review) => switch (task.status) {
  TaskStatus.rejected ||
  TaskStatus.correctionRequested ||
  TaskStatus.approved => true,
  TaskStatus.inProgress => review.result != ReviewResult.approved,
  _ => false,
};

class _ReviewResult extends StatelessWidget {
  const _ReviewResult({required this.review, required this.requirements});

  final TaskReview review;
  final List<Requirement> requirements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final by = review.reviewerName.isEmpty ? '' : ' by ${review.reviewerName}';
    final (title, color) = switch (review.result) {
      ReviewResult.approved => (
        'Approved$by',
        theme.colorScheme.secondaryContainer,
      ),
      ReviewResult.rejected => (
        'Rejected$by',
        theme.colorScheme.errorContainer,
      ),
      ReviewResult.correctionRequested => (
        'Correction requested$by',
        theme.colorScheme.tertiaryContainer,
      ),
    };
    String titleOf(String id) =>
        requirements.where((r) => r.id == id).firstOrNull?.title ??
        'A requirement';
    return Card(
      key: const Key('review-result'),
      color: color,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (review.reason != null) ...[
              const SizedBox(height: 4),
              Text(review.reason!),
            ],
            for (final MapEntry(key: id, value: comment)
                in review.markedRequirements.entries) ...[
              const SizedBox(height: 8),
              Text(titleOf(id), style: theme.textTheme.labelLarge),
              Text(comment),
            ],
          ],
        ),
      ),
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
