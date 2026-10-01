import 'package:flutter/material.dart';

/// Shown while the app checks for a saved session. The router leaves this
/// screen as soon as the login state is known.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fact_check_outlined, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('TaskInspect', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
