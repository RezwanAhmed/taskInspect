import 'package:flutter/material.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/presentation/task_filter.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/status_chip.dart';

/// Bottom sheet to choose priority, due date and status filters. Returns
/// the new filter, or `null` when closed without applying.
class TaskFilterSheet extends StatefulWidget {
  const TaskFilterSheet({required this.initial, super.key});

  final TaskFilter initial;

  static Future<TaskFilter?> show(BuildContext context, TaskFilter current) {
    return showModalBottomSheet<TaskFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TaskFilterSheet(initial: current),
    );
  }

  @override
  State<TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<TaskFilterSheet> {
  late TaskFilter _filter = widget.initial;

  Set<T> _toggle<T>(Set<T> values, T value) =>
      values.contains(value) ? ({...values}..remove(value)) : {...values, value};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter tasks', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Priority', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                for (final priority in TaskPriority.values.reversed)
                  FilterChip(
                    label: Text(switch (priority) {
                      TaskPriority.high => 'High',
                      TaskPriority.medium => 'Medium',
                      TaskPriority.low => 'Low',
                    }),
                    selected: _filter.priorities.contains(priority),
                    onSelected: (_) => setState(
                      () => _filter = _filter.copyWith(priorities: _toggle(_filter.priorities, priority)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Due date', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                for (final due in DueFilter.values)
                  ChoiceChip(
                    label: Text(due.label),
                    selected: _filter.due == due,
                    onSelected: (_) => setState(() => _filter = _filter.copyWith(due: due)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Status', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final status in TaskStatus.values)
                  FilterChip(
                    label: Text(StatusChip.label(status)),
                    selected: _filter.statuses.contains(status),
                    onSelected: (_) => setState(
                      () => _filter = _filter.copyWith(statuses: _toggle(_filter.statuses, status)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, const TaskFilter()),
                  child: const Text('Clear all'),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('apply-filters'),
                  style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
                  onPressed: () => Navigator.pop(context, _filter),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
