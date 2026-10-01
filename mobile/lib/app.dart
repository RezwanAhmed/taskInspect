import 'package:flutter/material.dart';
import 'package:taskinspect/core/theme/app_theme.dart';

/// The root widget of the TaskInspect app. Follows the device's light or
/// dark mode setting.
///
/// Routing is added in the next task.
class TaskInspectApp extends StatelessWidget {
  const TaskInspectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskInspect',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const Scaffold(
        body: Center(child: Text('TaskInspect')),
      ),
    );
  }
}
