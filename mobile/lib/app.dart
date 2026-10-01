import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/core/theme/app_theme.dart';

/// The root widget of the TaskInspect app. Follows the device's light or
/// dark mode setting.
class TaskInspectApp extends StatefulWidget {
  const TaskInspectApp({super.key, this.initialLocation = AppRoutes.splash});

  /// Where the app starts; tests can start on another screen.
  final String initialLocation;

  @override
  State<TaskInspectApp> createState() => _TaskInspectAppState();
}

class _TaskInspectAppState extends State<TaskInspectApp> {
  late final GoRouter _router = createRouter(initialLocation: widget.initialLocation);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TaskInspect',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
