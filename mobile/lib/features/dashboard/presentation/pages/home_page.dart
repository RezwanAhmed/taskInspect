import 'package:flutter/material.dart';

/// Placeholder for the dashboard (built in task 5.3).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: const Center(child: Text('Dashboard comes in task 5.3')),
    );
  }
}
