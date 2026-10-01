import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/entities/user_role.dart';
import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';
import 'package:taskinspect/features/authentication/domain/usecases/login.dart';
import 'package:taskinspect/features/authentication/domain/usecases/logout.dart';
import 'package:taskinspect/features/authentication/domain/usecases/restore_session.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';

const testWorker = AuthUser(id: 'u1', email: 'worker@example.com', fullName: 'Wendy Worker', roles: {UserRole.worker});

/// An [AuthRepository] for widget tests: one known user and password.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.savedUser});

  AuthUser? savedUser;
  int logouts = 0;

  @override
  Future<Result<AuthUser>> login({required String email, required String password}) async {
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
}

AuthBloc authBlocWith(FakeAuthRepository repository) => AuthBloc(
      login: Login(repository),
      restoreSession: RestoreSession(repository),
      logout: Logout(repository),
    );
