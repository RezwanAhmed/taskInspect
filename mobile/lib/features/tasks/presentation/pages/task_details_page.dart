import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
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
      create: (_) => TaskDetailsCubit(getIt(), taskId),
      child: BlocBuilder<TaskDetailsCubit, TaskDetailsState>(
        builder: (context, state) {
          final task = state.task;
          return Scaffold(
            appBar: AppBar(title: const Text('Task')),
            body: switch ((state.isLoading, task)) {
              (true, _) => const Center(child: CircularProgressIndicator()),
              (false, null) => const Center(child: Text('This task is not on this device.')),
              (false, final Task task) => _Details(task: task, requirements: state.requirements),
            },
          );
        },
      ),
    );
  }
}

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
        _Fact(icon: Icons.flag_outlined, label: 'Priority', value: switch (task.priority) {
          TaskPriority.high => 'High',
          TaskPriority.medium => 'Medium',
          TaskPriority.low => 'Low',
        }),
        _Fact(
          icon: Icons.event_outlined,
          label: 'Deadline',
          value: '${TaskTile.formatDue(task.dueDate)}${overdue ? ' (overdue)' : ''}',
          valueColor: overdue ? theme.colorScheme.error : null,
        ),
        _Fact(icon: Icons.engineering_outlined, label: 'Assigned to', value: task.assignee?.name ?? 'Not assigned'),
        _Fact(icon: Icons.person_outline, label: 'Created by', value: task.createdBy.name),
        _Fact(icon: Icons.verified_outlined, label: 'Reviewer', value: task.reviewer.name),
        const Divider(height: 32),
        Text('Requirements (${requirements.length})', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (requirements.isEmpty) const Text('No requirements yet.'),
        for (final requirement in requirements) _RequirementRow(requirement),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value, this.valueColor});

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
          SizedBox(width: 100, child: Text(label, style: theme.textTheme.bodyMedium)),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(color: valueColor))),
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
      if (requirement.options.isNotEmpty) requirement.options.map((option) => option.label).join(' / '),
      if (requirement.required) 'Required' else 'Optional',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(RequirementTypeLook.icon(requirement.type)),
        title: Text(requirement.title),
        subtitle: Text(requirement.description == null ? details : '${requirement.description}\n$details'),
      ),
    );
  }
}
