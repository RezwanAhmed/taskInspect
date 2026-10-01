import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:taskinspect/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:taskinspect/features/evidence/domain/document_opener.dart';
import 'package:taskinspect/features/evidence/domain/evidence_picker.dart';
import 'package:taskinspect/features/evidence/domain/evidence_repository.dart';
import 'package:taskinspect/features/requirements/domain/repositories/answer_repository.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';
import 'package:taskinspect/features/tasks/domain/usecases/start_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_tasks.dart';

class _FakeService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(getIt.reset);

  test('configureDependencies starts from a clean container', () async {
    getIt.registerSingleton<_FakeService>(_FakeService());

    await configureDependencies();

    expect(getIt.isRegistered<_FakeService>(), isFalse);
  });

  test('can be called more than once', () async {
    await configureDependencies();
    await configureDependencies();
  });

  test('every dependency of the app can be built', () async {
    // The device database needs the phone's file system; use one in memory.
    await configureDependencies(database: AppDatabase(NativeDatabase.memory()));

    expect(getIt<ApiClient>(), isNotNull);
    expect(getIt<TokenStorage>(), isNotNull);
    expect(getIt<SyncQueue>(), isNotNull);
    expect(getIt<AuthRepository>(), isNotNull);
    expect(getIt<AuthBloc>(), isNotNull);
    expect(getIt<TaskRepository>(), isNotNull);
    expect(getIt<WatchTasks>(), isNotNull);
    expect(getIt<WatchTaskDetails>(), isNotNull);
    expect(getIt<StartTask>(), isNotNull);
    expect(getIt<AnswerRepository>(), isNotNull);
    expect(getIt<EvidencePicker>(), isNotNull);
    expect(getIt<DocumentOpener>(), isNotNull);
    expect(getIt<EvidenceRepository>(), isNotNull);
    expect(getIt<DashboardCubit>(), isNotNull);
  });
}
