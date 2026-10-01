import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/features/tasks/domain/entities/history_entry.dart';
import 'package:taskinspect/features/tasks/presentation/cubit/task_history_cubit.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/task_tile.dart';

/// A task's history as a timeline (spec "Task History": created, assigned,
/// started, submitted, rejected, resubmitted, approved - with time and
/// user). Loaded from the server.
class TaskHistoryPage extends StatelessWidget {
  const TaskHistoryPage({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TaskHistoryCubit(getIt(), taskId)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: BlocBuilder<TaskHistoryCubit, TaskHistoryState>(
          builder: (context, state) => switch (state) {
            TaskHistoryState(isLoading: true) => const Center(child: CircularProgressIndicator()),
            TaskHistoryState(error: final error?) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(state.canRetry ? Icons.cloud_off : Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      Text(error, key: const Key('history-error'), textAlign: TextAlign.center),
                      if (state.canRetry) ...[
                        const SizedBox(height: 12),
                        FilledButton(onPressed: () => context.read<TaskHistoryCubit>().load(), child: const Text('Retry')),
                      ],
                    ],
                  ),
                ),
              ),
            TaskHistoryState(entries: []) => const Center(child: Text('No history yet.')),
            _ => ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.entries.length,
                itemBuilder: (context, index) => _Step(
                  entry: state.entries[index],
                  isLast: index == state.entries.length - 1,
                ),
              ),
          },
        ),
      ),
    );
  }
}

/// One step of the timeline: a dot with a line to the next step, what
/// happened, who and when, and the reason if any.
class _Step extends StatelessWidget {
  const _Step({required this.entry, required this.isLast});

  final HistoryEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (entry.event) {
      HistoryEvent.approved => (Icons.check_circle, Colors.green),
      HistoryEvent.rejected || HistoryEvent.cancelled => (Icons.cancel, theme.colorScheme.error),
      HistoryEvent.correctionRequested => (Icons.build_circle, theme.colorScheme.tertiary),
      HistoryEvent.submitted || HistoryEvent.resubmitted => (Icons.send, theme.colorScheme.primary),
      _ => (Icons.radio_button_checked, theme.colorScheme.primary),
    };
    final who = entry.byName.isEmpty ? '' : '${entry.byName} · ';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Icon(icon, color: color),
                if (!isLast) Expanded(child: VerticalDivider(color: theme.colorScheme.outlineVariant, thickness: 2)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.event?.label ?? 'Changed', style: theme.textTheme.titleMedium),
                  Text('$who${TaskTile.formatDue(entry.at)}', style: theme.textTheme.bodySmall),
                  if (entry.reason != null && entry.reason!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(entry.reason!.trim()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
