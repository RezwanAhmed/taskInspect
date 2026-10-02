import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/synchronization/sync_status_cubit.dart';

/// Shows the sync status (docs/architecture.md, "Sync Status in the App"):
/// offline, failed (with Retry), syncing, or changes waiting. Nothing when
/// everything is on the server.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  /// Why a change was refused, in words the worker understands; `null` for
  /// temporary problems (the message already says the data is safe).
  static String? reason(String? code) => switch (code) {
        null || 'NETWORK_ERROR' || 'SERVER_ERROR' || 'UPLOAD_URL_EXPIRED' => null,
        'TASK_INVALID_TRANSITION' || 'EVIDENCE_LOCKED' || 'RESPONSES_LOCKED' || 'TASK_ALREADY_CANCELLED' =>
          'The task was changed on the server, for example cancelled by the manager.',
        'VERSION_CONFLICT' => 'The task was changed on the server meanwhile.',
        'FILE_MISSING' => 'A photo or document is missing on this device.',
        'REQUIREMENTS_MISSING' =>
          'The task was not submitted: a required requirement is missing. Complete it and submit again.',
        'EVIDENCE_NOT_UPLOADED' => 'The task was not submitted: a photo or document is not uploaded yet.',
        _ => 'The server refused a change ($code).',
      };

  @override
  Widget build(BuildContext context) {
    final status = context.watch<SyncStatusCubit>().state;
    final theme = Theme.of(context);
    String changes(int count) => count == 1 ? '1 change' : '$count changes';
    if (!status.online) {
      return _Banner(
        key: const Key('sync-offline'),
        icon: Icons.cloud_off,
        text: "Changes saved locally. They will sync when you're online.",
        detail: status.unsent > 0 ? '${changes(status.unsent)} waiting.' : null,
      );
    }
    if (status.failed > 0) {
      return _Banner(
        key: const Key('sync-failed'),
        icon: Icons.sync_problem,
        color: theme.colorScheme.errorContainer,
        text: 'Unable to synchronize. Your changes are saved on this device.',
        detail: reason(status.failureCode),
        action: TextButton(onPressed: () => context.read<SyncStatusCubit>().retry(), child: const Text('Retry')),
      );
    }
    if (status.syncing) {
      return const _Banner(key: Key('sync-progress'), icon: Icons.sync, text: 'Syncing…', progress: true);
    }
    if (status.unsent > 0) {
      return _Banner(
        key: const Key('sync-pending'),
        icon: Icons.cloud_upload_outlined,
        text: '${changes(status.unsent)} waiting to sync.',
      );
    }
    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    this.detail,
    this.action,
    this.color,
    this.progress = false,
    super.key,
  });

  final IconData icon;
  final String text;
  final String? detail;
  final Widget? action;
  final Color? color;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color ?? theme.colorScheme.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(icon),
            title: Text(text),
            subtitle: detail == null ? null : Text(detail!),
            trailing: action,
          ),
          if (progress) const LinearProgressIndicator(semanticsLabel: 'Syncing'),
        ],
      ),
    );
  }
}
