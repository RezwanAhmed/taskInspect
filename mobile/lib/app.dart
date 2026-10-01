import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/core/theme/app_theme.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';

/// The root widget of the TaskInspect app. Follows the device's light or
/// dark mode setting and checks for a saved session when it starts.
class TaskInspectApp extends StatefulWidget {
  const TaskInspectApp({super.key, this.authBloc, this.initialLocation = AppRoutes.splash});

  /// Tests pass their own bloc; the app takes it from the service locator.
  final AuthBloc? authBloc;

  final String initialLocation;

  @override
  State<TaskInspectApp> createState() => _TaskInspectAppState();
}

class _TaskInspectAppState extends State<TaskInspectApp> {
  late final AuthBloc _authBloc = widget.authBloc ?? getIt<AuthBloc>();
  late final GoRouter _router = createRouter(_authBloc, initialLocation: widget.initialLocation);

  @override
  void initState() {
    super.initState();
    if (_authBloc.state is AuthUnknown) {
      _authBloc.add(const AuthStarted());
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'TaskInspect',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: _router,
      ),
    );
  }
}
