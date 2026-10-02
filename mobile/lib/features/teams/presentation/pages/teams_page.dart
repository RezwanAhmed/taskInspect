import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/features/teams/domain/entities/team_summary.dart';
import 'package:taskinspect/features/teams/presentation/cubit/teams_cubit.dart';

/// Every manager's team in numbers: how many members and open tasks
/// (docs/architecture.md, "What a Worker Sees" - other teams only as
/// counts). Loaded from the server.
class TeamsPage extends StatelessWidget {
  const TeamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TeamsCubit(getIt())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Teams')),
        body: BlocBuilder<TeamsCubit, TeamsState>(
          builder: (context, state) => switch (state) {
            TeamsState(isLoading: true) => const Center(child: CircularProgressIndicator()),
            TeamsState(error: final error?) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(state.canRetry ? Icons.cloud_off : Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      Text(error, key: const Key('teams-error'), textAlign: TextAlign.center),
                      if (state.canRetry) ...[
                        const SizedBox(height: 12),
                        FilledButton(onPressed: () => context.read<TeamsCubit>().load(), child: const Text('Retry')),
                      ],
                    ],
                  ),
                ),
              ),
            TeamsState(teams: []) => const Center(child: Text('No teams yet.')),
            _ => RefreshIndicator(
                onRefresh: () => context.read<TeamsCubit>().load(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: state.teams.length,
                  itemBuilder: (context, index) => _TeamCard(team: state.teams[index]),
                ),
              ),
          },
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});

  final TeamSummary team;

  @override
  Widget build(BuildContext context) {
    String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.groups_outlined),
        title: Text(team.managerName),
        subtitle: Text('${count(team.memberCount, 'member', 'members')} · '
            '${count(team.unfinishedTaskCount, 'open task', 'open tasks')}'),
        trailing: team.isMyTeam ? const Chip(label: Text('My team')) : null,
      ),
    );
  }
}
