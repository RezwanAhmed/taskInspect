import 'package:flutter/material.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/status_chip.dart';

/// One task in a list: title, status, priority, due date and worker, and
/// a mark when it has changes that are not on the server yet.
class TaskTile extends StatelessWidget {
  const TaskTile({required this.task, required this.now, this.onTap, this.hasUnsentChanges = false, super.key});

  final Task task;
  final DateTime now;
  final VoidCallback? onTap;
  final bool hasUnsentChanges;

  static String formatDue(DateTime due) {
    final local = due.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = task.isOverdue(now);
    final dueStyle = theme.textTheme.bodySmall?.copyWith(color: overdue ? theme.colorScheme.error : null);
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(task.status),
              _Priority(task.priority),
              Text('${overdue ? 'Overdue · ' : 'Due '}${formatDue(task.dueDate)}', style: dueStyle),
              if (task.assignee != null) Text(task.assignee!.name, style: theme.textTheme.bodySmall),
              if (hasUnsentChanges)
                Row(
                  key: const Key('task-unsent'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 14),
                    const SizedBox(width: 4),
                    Text('Not synced yet', style: theme.textTheme.bodySmall),
                  ],
                ),
            ],
          ),
        ),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _Priority extends StatelessWidget {
  const _Priority(this.priority);

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (priority) {
      TaskPriority.high => ('High', Icons.keyboard_double_arrow_up),
      TaskPriority.medium => ('Medium', Icons.drag_handle),
      TaskPriority.low => ('Low', Icons.keyboard_double_arrow_down),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 14), Text(label, style: Theme.of(context).textTheme.bodySmall)],
    );
  }
}
