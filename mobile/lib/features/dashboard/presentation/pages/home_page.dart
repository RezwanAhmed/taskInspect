import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';

/// Placeholder for the dashboard (built in task 5.3), with sign out.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
    final state = context.watch<AuthBloc>().state;
    final name = state is Authenticated ? state.user.fullName : '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: Center(child: Text('Signed in as $name')),
    );
  }
}
