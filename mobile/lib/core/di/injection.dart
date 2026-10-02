import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/network/connectivity_monitor.dart';
import 'package:taskinspect/core/security/refresh_lock.dart';
import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/storage/local_data_owner.dart';
import 'package:taskinspect/core/synchronization/background_sync.dart';
import 'package:taskinspect/core/synchronization/background_sync_registration.dart';
import 'package:taskinspect/core/synchronization/sync_lifecycle.dart';
import 'package:taskinspect/core/synchronization/sync_manager.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/core/synchronization/sync_remote_data_source.dart';
import 'package:taskinspect/core/synchronization/sync_scheduler.dart';
import 'package:taskinspect/core/synchronization/sync_status.dart';
import 'package:taskinspect/core/synchronization/sync_status_cubit.dart';
import 'package:taskinspect/core/synchronization/sync_turns.dart';
import 'package:taskinspect/features/authentication/data/auth_interceptor.dart';
import 'package:taskinspect/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:taskinspect/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:taskinspect/features/authentication/data/token_refresher.dart';
import 'package:taskinspect/features/authentication/domain/entities/unsynced_changes.dart';
import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';
import 'package:taskinspect/features/authentication/domain/usecases/check_unsynced_changes.dart';
import 'package:taskinspect/features/authentication/domain/usecases/end_expired_session.dart';
import 'package:taskinspect/features/authentication/domain/usecases/login.dart';
import 'package:taskinspect/features/authentication/domain/usecases/logout.dart';
import 'package:taskinspect/features/authentication/domain/usecases/restore_session.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:taskinspect/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:taskinspect/features/evidence/data/device_evidence_picker.dart';
import 'package:taskinspect/features/evidence/data/evidence_uploader.dart';
import 'package:taskinspect/features/evidence/data/image_compressor.dart';
import 'package:taskinspect/features/evidence/data/local/evidence_local_data_source.dart';
import 'package:taskinspect/features/evidence/data/open_filex_document_opener.dart';
import 'package:taskinspect/features/evidence/data/remote/evidence_remote_data_source.dart';
import 'package:taskinspect/features/evidence/domain/document_opener.dart';
import 'package:taskinspect/features/evidence/domain/evidence_picker.dart';
import 'package:taskinspect/features/evidence/domain/evidence_repository.dart';
import 'package:taskinspect/features/requirements/data/local/answer_local_data_source.dart';
import 'package:taskinspect/features/requirements/domain/repositories/answer_repository.dart';
import 'package:taskinspect/features/review/data/review_remote_data_source.dart';
import 'package:taskinspect/features/review/domain/review_repository.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/data/remote/task_remote_data_source.dart';
import 'package:taskinspect/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';
import 'package:taskinspect/features/tasks/domain/usecases/load_task_history.dart';
import 'package:taskinspect/features/tasks/domain/usecases/refresh_tasks.dart';
import 'package:taskinspect/features/tasks/domain/usecases/start_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/submit_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/take_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_tasks.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_team_tasks.dart';
import 'package:taskinspect/features/teams/data/team_repository_impl.dart';
import 'package:taskinspect/features/teams/domain/repositories/team_repository.dart';
import 'package:taskinspect/features/teams/domain/usecases/load_teams.dart';

/// The app's service locator. Every dependency is registered in
/// [configureDependencies]; widgets and BLoCs never create their own
/// repositories or clients, so tests can swap in fakes.
final GetIt getIt = GetIt.instance;

/// Registers all dependencies. Called once in `main()` before the app starts.
///
/// Tests can pass [config] and an in-memory [database]; the app reads the
/// config from the build and opens its database file on the device.
Future<void> configureDependencies({AppConfig? config, AppDatabase? database}) async {
  await getIt.reset();
  getIt
    ..registerSingleton<AppConfig>(config ?? AppConfig.fromEnvironment())
    ..registerLazySingleton<ApiClient>(() {
      final client = ApiClient.forConfig(getIt<AppConfig>());
      client.dio.interceptors.add(
        AuthInterceptor(
          dio: client.dio,
          storage: getIt(),
          refresher: getIt.call<TokenRefresher>,
          onSessionExpired: () => getIt<AuthBloc>().add(const SessionExpired()),
        ),
      );
      return client;
    })
    ..registerLazySingleton<ConnectivityMonitor>(DeviceConnectivityMonitor.new)
    ..registerLazySingleton<TokenStorage>(SecureTokenStorage.new)
    ..registerLazySingleton<AppDatabase>(
      () => database ?? AppDatabase(),
      dispose: (database) => database.close(),
    )
    ..registerLazySingleton(() => SyncQueue(getIt()))
    ..registerLazySingleton(() => SyncRemoteDataSource(getIt()))
    ..registerLazySingleton(() => EvidenceRemoteDataSource(getIt()))
    ..registerLazySingleton(() => EvidenceUploader(getIt(), getIt()))
    ..registerLazySingleton(
      () => SyncManager(getIt(), getIt(), getIt(), getIt()),
      dispose: (manager) => manager.dispose(),
    )
    ..registerLazySingleton(
      () => SyncScheduler(getIt(), getIt()),
      dispose: (scheduler) => scheduler.stop(),
    )
    ..registerLazySingleton<SyncTurns>(IsolateSyncTurns.new)
    ..registerLazySingleton<BackgroundSyncRegistration>(WorkmanagerSyncRegistration.new)
    ..registerLazySingleton(
      () => SyncLifecycle(
        getIt(),
        getIt(),
        getIt(),
        // A background sync may have changed the database meanwhile.
        refreshScreens: () async => getIt<AppDatabase>().markTablesUpdated(getIt<AppDatabase>().allTables),
      ),
    )
    ..registerFactory(() => BackgroundSync(getIt(), getIt(), getIt(), getIt()))
    ..registerLazySingleton<SyncStatusSource>(() => DatabaseSyncStatusSource(getIt(), getIt(), getIt()))
    ..registerFactory(
      () => SyncStatusCubit(getIt(), () async {
        await getIt<SyncManager>().retryFailed();
        getIt<SyncScheduler>().syncNow();
      }),
    )
    // Authentication
    ..registerLazySingleton(() => AuthRemoteDataSource(getIt<ApiClient>()))
    ..registerLazySingleton(() => TokenRefresher(getIt(), getIt(), lock: IsolateRefreshLock()))
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        getIt(),
        getIt(),
        getIt(),
        clearLocalData: _clearLocalData,
        claimLocalData: (user) => LocalDataOwner(getIt()).claim(user.id, email: user.email, clear: _clearLocalData),
        unsyncedChanges: () async {
          final unsynced = await LocalDataOwner(getIt()).unsynced();
          return unsynced == null ? null : UnsyncedChanges(ownerEmail: unsynced.email, count: unsynced.count);
        },
      ),
    )
    ..registerFactory(() => Login(getIt()))
    ..registerFactory(() => RestoreSession(getIt()))
    ..registerFactory(() => Logout(getIt()))
    ..registerFactory(() => EndExpiredSession(getIt()))
    ..registerFactory(() => CheckUnsyncedChanges(getIt()))
    ..registerLazySingleton(
      () => AuthBloc(
        login: getIt(),
        restoreSession: getIt(),
        logout: getIt(),
        endExpiredSession: getIt(),
        checkUnsyncedChanges: getIt(),
      ),
      dispose: (bloc) => bloc.close(),
    )
    // Tasks
    ..registerLazySingleton(() => TaskLocalDataSource(getIt()))
    ..registerLazySingleton(() => TaskRemoteDataSource(getIt()))
    ..registerLazySingleton<TaskRepository>(
      () => TaskRepositoryImpl(getIt(), getIt()),
    )
    ..registerFactory(() => RefreshTasks(getIt()))
    ..registerFactory(() => WatchTasks(getIt()))
    ..registerFactory(() => WatchTeamTasks(getIt()))
    ..registerFactory(() => WatchTaskDetails(getIt()))
    ..registerFactory(() => StartTask(getIt()))
    ..registerFactory(() => TakeTask(getIt()))
    ..registerFactory(() => SubmitTask(getIt()))
    ..registerFactory(() => LoadTaskHistory(getIt()))
    // Teams
    ..registerLazySingleton<TeamRepository>(() => TeamRepositoryImpl(getIt()))
    ..registerFactory(() => LoadTeams(getIt()))
    // Answers and evidence
    ..registerLazySingleton<EvidencePicker>(DeviceEvidencePicker.new)
    ..registerLazySingleton<DocumentOpener>(() => const OpenFilexDocumentOpener())
    ..registerLazySingleton<EvidenceRepository>(
      () => EvidenceLocalDataSource(
        getIt(),
        const NativeImageCompressor(),
        getIt(),
        documentsDirectory: getApplicationDocumentsDirectory,
      ),
    )
    ..registerLazySingleton<AnswerRepository>(
      () => AnswerLocalDataSource(getIt(), getIt()),
    )
    // Review
    ..registerLazySingleton<ReviewRepository>(
      () => ReviewRemoteDataSource(
        getIt(),
        temporaryDirectory: getTemporaryDirectory,
        storeTask: getIt<TaskLocalDataSource>().updateTask,
      ),
    )
    // Dashboard
    ..registerFactory(() => DashboardCubit(getIt(), getIt()));
}

/// Removes the user's data from the device: the database and evidence files.
Future<void> _clearLocalData() async {
  await getIt<AppDatabase>().clearUserData();
  final evidence = getIt<EvidenceRepository>();
  if (evidence is EvidenceLocalDataSource) {
    await evidence.deleteAllFiles();
  }
}
