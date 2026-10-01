import 'package:flutter/material.dart';
import 'package:taskinspect/core/theme/status_colors.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// A small colored label for a task status.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final TaskStatus status;

  static String label(TaskStatus status) => switch (status) {
        TaskStatus.draft => 'Draft',
        TaskStatus.assigned => 'Pending',
        TaskStatus.inProgress => 'In progress',
        TaskStatus.submitted => 'Submitted',
        TaskStatus.approved => 'Approved',
        TaskStatus.rejected => 'Rejected',
        TaskStatus.correctionRequested => 'Correction requested',
        TaskStatus.cancelled => 'Cancelled',
      };

  static Color color(BuildContext context, TaskStatus status) {
    final colors = Theme.of(context).extension<StatusColors>()!;
    return switch (status) {
      TaskStatus.draft => colors.draft,
      TaskStatus.assigned => colors.assigned,
      TaskStatus.inProgress => colors.inProgress,
      TaskStatus.submitted => colors.submitted,
      TaskStatus.approved => colors.approved,
      TaskStatus.rejected => colors.rejected,
      TaskStatus.correctionRequested => colors.correctionRequested,
      TaskStatus.cancelled => colors.cancelled,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = StatusChip.color(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label(status), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
    );
  }
}
