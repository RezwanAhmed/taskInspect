import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/theme/status_colors.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:taskinspect/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:taskinspect/features/dashboard/presentation/widgets/count_tile.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

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

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your email and password to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sign out')),
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
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => _confirmSignOut(context)),
        ],
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final tiles = <Widget>[
            if (user?.isManager ?? false)
              CountTile(label: 'Draft', count: state.count(TaskStatus.draft), color: colors.draft),
            CountTile(label: 'Pending', count: state.count(TaskStatus.assigned), color: colors.assigned),
            CountTile(label: 'In progress', count: state.count(TaskStatus.inProgress), color: colors.inProgress),
            CountTile(label: 'Submitted', count: state.count(TaskStatus.submitted), color: colors.submitted),
            CountTile(label: 'Rejected', count: state.count(TaskStatus.rejected), color: colors.rejected),
            CountTile(
              label: 'Correction requested',
              count: state.count(TaskStatus.correctionRequested),
              color: colors.correctionRequested,
            ),
            CountTile(label: 'Approved', count: state.count(TaskStatus.approved), color: colors.approved),
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
