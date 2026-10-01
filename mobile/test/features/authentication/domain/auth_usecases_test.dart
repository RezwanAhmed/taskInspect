import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/entities/user_role.dart';
import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';
import 'package:taskinspect/features/authentication/domain/usecases/end_expired_session.dart';
import 'package:taskinspect/features/authentication/domain/usecases/login.dart';
import 'package:taskinspect/features/authentication/domain/usecases/logout.dart';
import 'package:taskinspect/features/authentication/domain/usecases/restore_session.dart';

const _worker = AuthUser(id: 'u1', email: 'worker@example.com', fullName: 'Wendy', roles: {UserRole.worker});

class _FakeRepository implements AuthRepository {
  String? loginEmail;
  bool loggedOut = false;
  bool sessionEnded = false;
  AuthUser? saved = _worker;

  @override
  Future<Result<AuthUser>> login({required String email, required String password}) async {
    loginEmail = email;
    return const Ok(_worker);
  }

  @override
  Future<Result<AuthUser?>> restoreSession() async => Ok(saved);

  @override
  Future<void> logout() async => loggedOut = true;

  @override
  Future<void> endExpiredSession() async => sessionEnded = true;
}

void main() {
  late _FakeRepository repository;

  setUp(() => repository = _FakeRepository());

  group('Login', () {
    test('trims the email and asks the repository', () async {
      final result = await Login(repository)(email: '  worker@example.com ', password: 'secret');

      expect(result, isA<Ok<AuthUser>>());
      expect(repository.loginEmail, 'worker@example.com');
    });

    test('refuses empty or invalid input without calling the server', () async {
      final empty = await Login(repository)(email: ' ', password: 'secret');
      final invalid = await Login(repository)(email: 'not-an-email', password: 'secret');
      final noPassword = await Login(repository)(email: 'worker@example.com', password: '');

      expect((empty as Err<AuthUser>).failure,
          isA<InvalidInputFailure>().having((f) => f.field, 'field', 'email'));
      expect((invalid as Err<AuthUser>).failure,
          isA<InvalidInputFailure>().having((f) => f.message, 'message', 'Enter a valid email address'));
      expect((noPassword as Err<AuthUser>).failure,
          isA<InvalidInputFailure>().having((f) => f.field, 'field', 'password'));
      expect(repository.loginEmail, isNull);
    });
  });

  test('RestoreSession returns the saved user or null', () async {
    expect((await RestoreSession(repository)() as Ok<AuthUser?>).value, _worker);
    repository.saved = null;
    expect((await RestoreSession(repository)() as Ok<AuthUser?>).value, isNull);
  });

  test('Logout ends the session', () async {
    await Logout(repository)();

    expect(repository.loggedOut, isTrue);
  });

  test('roles', () {
    expect(UserRole.tryParse('MANAGER'), UserRole.manager);
    expect(UserRole.tryParse('BOSS'), isNull);
    const solo = AuthUser(id: 'u2', email: 'solo@example.com', fullName: 'Solo',
        roles: {UserRole.manager, UserRole.worker});
    expect(solo.isManager && solo.isWorker, isTrue);
    expect(_worker.isManager, isFalse);
  });

  test('EndExpiredSession asks the repository', () async {
    await EndExpiredSession(repository)();

    expect(repository.sessionEnded, isTrue);
    expect(repository.loggedOut, isFalse);
  });
}
