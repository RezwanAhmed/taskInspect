import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:taskinspect/features/authentication/presentation/pages/login_page.dart';
import 'package:taskinspect/features/authentication/presentation/pages/splash_page.dart';
import 'package:taskinspect/features/dashboard/presentation/pages/home_page.dart';

/// Route paths, so screens never hard-code URLs.
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
}

/// Creates the app's router. It follows the [AuthBloc]: while the session
/// is unknown the splash screen is shown, logged-out users always land on
/// the login screen, and logged-in users never see splash or login.
GoRouter createRouter(AuthBloc authBloc, {String initialLocation = AppRoutes.splash}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: _StreamListenable(authBloc.stream),
    redirect: (context, state) {
      final location = state.matchedLocation;
      return switch (authBloc.state) {
        AuthUnknown() => location == AppRoutes.splash ? null : AppRoutes.splash,
        Unauthenticated() => location == AppRoutes.login ? null : AppRoutes.login,
        Authenticated() =>
          location == AppRoutes.splash || location == AppRoutes.login ? AppRoutes.home : null,
      };
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginPage()),
      GoRoute(path: AppRoutes.home, builder: (context, state) => const HomePage()),
    ],
    errorBuilder: (context, state) => const _NotFoundPage(),
  );
}

/// Lets the router re-check its redirect whenever the login state changes.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
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
            TextButton(onPressed: () => context.go(AppRoutes.home), child: const Text('Go to start')),
          ],
        ),
      ),
    );
  }
}
