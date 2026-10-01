import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/features/authentication/presentation/pages/login_page.dart';
import 'package:taskinspect/features/authentication/presentation/pages/splash_page.dart';
import 'package:taskinspect/features/dashboard/presentation/pages/home_page.dart';

/// Route paths, so screens never hard-code URLs.
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
}

/// Creates the app's router. Redirects based on the login state are added
/// with authentication (tasks 4.15 / 4.16).
GoRouter createRouter({String initialLocation = AppRoutes.splash}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginPage()),
      GoRoute(path: AppRoutes.home, builder: (context, state) => const HomePage()),
    ],
    errorBuilder: (context, state) => const _NotFoundPage(),
  );
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Page not found'),
            const SizedBox(height: 16),
            TextButton(onPressed: () => context.go(AppRoutes.splash), child: const Text('Go to start')),
          ],
        ),
      ),
    );
  }
}
