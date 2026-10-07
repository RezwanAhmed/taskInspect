import 'package:dio/dio.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/notifications/push_notification_service.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/entities/unsynced_changes.dart';
import 'package:taskinspect/features/authentication/domain/entities/user_role.dart';
import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';
import 'package:taskinspect/features/authentication/domain/usecases/check_unsynced_changes.dart';
import 'package:taskinspect/features/authentication/domain/usecases/end_expired_session.dart';
import 'package:taskinspect/features/authentication/domain/usecases/login.dart';
import 'package:taskinspect/features/authentication/domain/usecases/logout.dart';
import 'package:taskinspect/features/authentication/domain/usecases/restore_session.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';

import 'fake_push_notifications.dart';

const testWorker = AuthUser(id: 'u1', email: 'worker@example.com', fullName: 'Wendy Worker', roles: {UserRole.worker});
const testManager = AuthUser(id: 'm1', email: 'manager@example.com', fullName: 'Mia Manager', roles: {UserRole.manager});

/// An [AuthRepository] for widget tests: one known user and password.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.savedUser, this.unsynced});

  AuthUser? savedUser;

  /// Unsynced changes left on the "device".
  UnsyncedChanges? unsynced;
  int logouts = 0;
  int expiredSessions = 0;

  /// When set, signing in fails with this (e.g. no connection).
  Failure? loginFailure;

  @override
  Future<Result<AuthUser>> login({required String email, required String password}) async {
    if (loginFailure case final failure?) {
      return Err(failure);
    }
    if (email == testWorker.email && password == 'secret') {
      savedUser = testWorker;
      return const Ok(testWorker);
    }
    return const Err(UnauthorizedFailure(code: 'INVALID_CREDENTIALS', message: 'Email or password is incorrect'));
  }

  @override
  Future<Result<AuthUser?>> restoreSession() async => Ok(savedUser);

  @override
  Future<void> logout() async {
    logouts++;
    savedUser = null;
  }

  @override
  Future<void> endExpiredSession() async {
    expiredSessions++;
    savedUser = null;
  }

  @override
  Future<UnsyncedChanges?> unsyncedChanges() async => unsynced;
}

AuthBloc authBlocWith(FakeAuthRepository repository) => AuthBloc(
      login: Login(repository),
      restoreSession: RestoreSession(repository),
      logout: Logout(repository, PushNotificationService(FakePushTokenSource(), ApiClient(Dio()))),
      endExpiredSession: EndExpiredSession(repository),
      checkUnsyncedChanges: CheckUnsyncedChanges(repository),
    );
