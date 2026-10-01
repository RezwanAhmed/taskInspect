import 'package:get_it/get_it.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:taskinspect/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';
import 'package:taskinspect/features/authentication/domain/usecases/login.dart';
import 'package:taskinspect/features/authentication/domain/usecases/logout.dart';
import 'package:taskinspect/features/authentication/domain/usecases/restore_session.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';

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
    ..registerLazySingleton<TokenStorage>(SecureTokenStorage.new)
    ..registerLazySingleton<AppDatabase>(AppDatabase.new, dispose: (database) => database.close())
    // Authentication
    ..registerLazySingleton(() => AuthRemoteDataSource(getIt<ApiClient>()))
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(getIt(), getIt()))
    ..registerFactory(() => Login(getIt()))
    ..registerFactory(() => RestoreSession(getIt()))
    ..registerFactory(() => Logout(getIt()))
    ..registerLazySingleton(
      () => AuthBloc(login: getIt(), restoreSession: getIt(), logout: getIt()),
      dispose: (bloc) => bloc.close(),
    );
}
