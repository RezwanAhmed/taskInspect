import 'package:get_it/get_it.dart';

/// The app's service locator. Every dependency is registered in
/// [configureDependencies]; widgets and BLoCs never create their own
/// repositories or clients, so tests can swap in fakes.
final GetIt getIt = GetIt.instance;

/// Registers all dependencies. Called once in `main()` before the app starts.
///
/// Registrations are added by the tasks that introduce them (environment
/// config, API client, secure storage, local database, repositories, BLoCs).
Future<void> configureDependencies() async {
  await getIt.reset();
}
