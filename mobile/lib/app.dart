import 'package:flutter/material.dart';

/// The root widget of the TaskInspect app.
///
/// Theme, routing and dependency injection are added in the next tasks.
class TaskInspectApp extends StatelessWidget {
  const TaskInspectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'TaskInspect',
      home: Scaffold(
        body: Center(child: Text('TaskInspect')),
      ),
    );
  }
}
