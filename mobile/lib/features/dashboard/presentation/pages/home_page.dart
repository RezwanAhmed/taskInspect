import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/core/synchronization/sync_status_cubit.dart';
import 'package:taskinspect/core/theme/status_colors.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:taskinspect/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:taskinspect/features/dashboard/presentation/widgets/count_tile.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/presentation/task_tab.dart';
import 'package:taskinspect/shared/widgets/sync_status_banner.dart';

/// The dashboard: how many tasks are in each status, and which are overdue.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DashboardCubit>()..start(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  /// Signing out deletes the user's data from the device, so changes that
  /// are not on the server yet would be lost: then the dialog says so.
  Future<void> _confirmSignOut(BuildContext context) async {
    final unsent = context.read<SyncStatusCubit>().state.unsent;
    final error = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(unsent == 0
            ? 'You will need your email and password to sign in again.'
            : '${unsent == 1 ? '1 change is' : '$unsent changes are'} not synced yet. If you sign out now, '
                'they are deleted from this device and lost.\n\n'
                'To keep them, connect to the internet and wait until they are synced.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('confirm-sign-out'),
            style: unsent == 0 ? null : FilledButton.styleFrom(backgroundColor: error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(unsent == 0 ? 'Sign out' : 'Sign out anyway'),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && context.mounted) {
      context.read<AuthBloc>().add(const LogoutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is Authenticated ? auth.user : null;
    final colors = Theme.of(context).extension<StatusColors>()!;
    final errorColor = Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Teams',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => context.push(AppRoutes.teams),
          ),
          IconButton(
            tooltip: 'All tasks',
            icon: const Icon(Icons.list_alt),
            onPressed: () => context.push(AppRoutes.tasks),
          ),
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => _confirmSignOut(context)),
        ],
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          void open(TaskTab tab) => context.push(AppRoutes.tasksOn(tab));
          final tiles = <Widget>[
            if (user?.isManager ?? false) ...[
              CountTile(label: 'Draft', count: state.count(TaskStatus.draft), color: colors.draft),
              CountTile(label: 'Open', count: state.count(TaskStatus.open), color: colors.open),
            ],
            CountTile(
              label: 'Pending',
              count: state.count(TaskStatus.assigned),
              color: colors.assigned,
              onTap: () => open(TaskTab.pending),
            ),
            CountTile(
              label: 'In progress',
              count: state.count(TaskStatus.inProgress),
              color: colors.inProgress,
              onTap: () => open(TaskTab.inProgress),
            ),
            CountTile(
              label: 'Submitted',
              count: state.count(TaskStatus.submitted),
              color: colors.submitted,
              onTap: () => open(TaskTab.submitted),
            ),
            CountTile(
              label: 'Rejected',
              count: state.count(TaskStatus.rejected),
              color: colors.rejected,
              onTap: () => open(TaskTab.rejected),
            ),
            CountTile(
              label: 'Correction requested',
              count: state.count(TaskStatus.correctionRequested),
              color: colors.correctionRequested,
              onTap: () => open(TaskTab.rejected),
            ),
            CountTile(
              label: 'Approved',
              count: state.count(TaskStatus.approved),
              color: colors.approved,
              onTap: () => open(TaskTab.approved),
            ),
            CountTile(label: 'Overdue', count: state.overdue, color: errorColor, icon: Icons.schedule),
          ];
          return RefreshIndicator(
            onRefresh: () => context.read<DashboardCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (user != null) Text('Hello, ${user.fullName}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('${state.total} tasks on this device', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                const SyncStatusBanner(),
                if (state.message != null) ...[
                  const SizedBox(height: 12),
                  MaterialBanner(
                    key: const Key('dashboard-message'),
                    content: Text(state.message!),
                    leading: const Icon(Icons.cloud_off),
                    actions: [
                      TextButton(
                        onPressed: () => context.read<DashboardCubit>().refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: tiles,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
