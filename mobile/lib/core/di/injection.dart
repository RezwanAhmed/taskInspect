import 'package:get_it/get_it.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/security/token_storage.dart';

/// The app's service locator. Every dependency is registered in
/// [configureDependencies]; widgets and BLoCs never create their own
/// repositories or clients, so tests can swap in fakes.
final GetIt getIt = GetIt.instance;

/// Registers all dependencies. Called once in `main()` before the app starts.
///
/// [config] can be given by tests; the app reads it from the build.
Future<void> configureDependencies({AppConfig? config}) async {
  await getIt.reset();
  getIt
    ..registerSingleton<AppConfig>(config ?? AppConfig.fromEnvironment())
    ..registerLazySingleton<ApiClient>(() => ApiClient.forConfig(getIt<AppConfig>()))
    ..registerLazySingleton<TokenStorage>(SecureTokenStorage.new);
}
