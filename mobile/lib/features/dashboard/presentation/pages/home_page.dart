import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';

/// Placeholder for the dashboard (built in task 5.3).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    final name = state is Authenticated ? state.user.fullName : '';
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: Center(child: Text('Signed in as $name')),
    );
  }
}
