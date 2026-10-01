import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/entities/unsynced_changes.dart';
import 'package:taskinspect/features/authentication/domain/entities/user_role.dart';
import 'package:taskinspect/features/authentication/domain/usecases/check_unsynced_changes.dart';
import 'package:taskinspect/features/authentication/domain/usecases/end_expired_session.dart';
import 'package:taskinspect/features/authentication/domain/usecases/login.dart';
import 'package:taskinspect/features/authentication/domain/usecases/logout.dart';
import 'package:taskinspect/features/authentication/domain/usecases/restore_session.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';

class _MockLogin extends Mock implements Login {}

class _MockRestoreSession extends Mock implements RestoreSession {}

class _MockLogout extends Mock implements Logout {}

class _MockEndExpiredSession extends Mock implements EndExpiredSession {}

class _MockCheckUnsyncedChanges extends Mock implements CheckUnsyncedChanges {}

const _user = AuthUser(id: 'u1', email: 'worker@example.com', fullName: 'Wendy', roles: {UserRole.worker});

void main() {
  late _MockLogin login;
  late _MockRestoreSession restoreSession;
  late _MockLogout logout;
  late _MockEndExpiredSession endExpiredSession;
  late _MockCheckUnsyncedChanges checkUnsyncedChanges;

  setUp(() {
    login = _MockLogin();
    restoreSession = _MockRestoreSession();
    logout = _MockLogout();
    when(() => logout()).thenAnswer((_) async {});
    endExpiredSession = _MockEndExpiredSession();
    when(() => endExpiredSession()).thenAnswer((_) async {});
    checkUnsyncedChanges = _MockCheckUnsyncedChanges();
    when(() => checkUnsyncedChanges()).thenAnswer((_) async => null);
  });

  AuthBloc build() => AuthBloc(
        login: login,
        restoreSession: restoreSession,
        logout: logout,
        endExpiredSession: endExpiredSession,
        checkUnsyncedChanges: checkUnsyncedChanges,
      );

  const unsynced = UnsyncedChanges(ownerEmail: 'worker@example.com', count: 2);

  blocTest<AuthBloc, AuthState>(
    'without a session but with unsynced changes on the device, the login screen is told',
    setUp: () {
      when(() => restoreSession()).thenAnswer((_) async => const Ok(null));
      when(() => checkUnsyncedChanges()).thenAnswer((_) async => unsynced);
    },
    build: build,
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [const Unauthenticated(unsynced: unsynced)],
  );

  blocTest<AuthBloc, AuthState>(
    'an expired session tells the login screen about the changes it left',
    setUp: () => when(() => checkUnsyncedChanges()).thenAnswer((_) async => unsynced),
    build: build,
    seed: () => const Authenticated(_user),
    act: (bloc) => bloc.add(const SessionExpired()),
    expect: () => [isA<Unauthenticated>().having((s) => s.unsynced, 'unsynced', unsynced)],
  );

  blocTest<AuthBloc, AuthState>(
    'a failing check does not keep the user from signing in',
    setUp: () {
      when(() => restoreSession()).thenAnswer((_) async => const Ok(null));
      when(() => checkUnsyncedChanges()).thenThrow(StateError('database closed'));
    },
    build: build,
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [const Unauthenticated()],
  );

  blocTest<AuthBloc, AuthState>(
    'a failed sign in keeps the unsynced changes warning',
    setUp: () => when(() => login(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => const Err(UnauthorizedFailure(message: 'Email or password is incorrect'))),
    build: build,
    seed: () => const Unauthenticated(unsynced: unsynced),
    act: (bloc) => bloc.add(const LoginRequested(email: 'worker@example.com', password: 'x')),
    expect: () => [
      const Unauthenticated(isSubmitting: true, unsynced: unsynced),
      isA<Unauthenticated>().having((s) => s.unsynced, 'unsynced', unsynced),
    ],
  );

  void loginReturns(Result<AuthUser> result) {
    when(() => login(email: any(named: 'email'), password: any(named: 'password'))).thenAnswer((_) async => result);
  }

  test('starts as unknown', () {
    expect(build().state, const AuthUnknown());
  });

  blocTest<AuthBloc, AuthState>(
    'restores a saved session',
    setUp: () => when(() => restoreSession()).thenAnswer((_) async => const Ok(_user)),
    build: build,
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [const Authenticated(_user)],
  );

  blocTest<AuthBloc, AuthState>(
    'without a saved session the user must log in',
    setUp: () => when(() => restoreSession()).thenAnswer((_) async => const Ok(null)),
    build: build,
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [const Unauthenticated()],
  );

  blocTest<AuthBloc, AuthState>(
    'successful login',
    setUp: () => loginReturns(const Ok(_user)),
    build: build,
    act: (bloc) => bloc.add(const LoginRequested(email: 'worker@example.com', password: 'secret')),
    expect: () => [const Unauthenticated(isSubmitting: true), const Authenticated(_user)],
  );

  blocTest<AuthBloc, AuthState>(
    'wrong password shows the server message',
    setUp: () => loginReturns(const Err(UnauthorizedFailure(
        code: 'INVALID_CREDENTIALS', message: 'Email or password is incorrect'))),
    build: build,
    act: (bloc) => bloc.add(const LoginRequested(email: 'worker@example.com', password: 'wrong')),
    expect: () => [
      const Unauthenticated(isSubmitting: true),
      const Unauthenticated(errorMessage: 'Email or password is incorrect'),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'input errors point at the field',
    setUp: () => loginReturns(const Err(InvalidInputFailure(field: 'email', message: 'Enter your email address'))),
    build: build,
    act: (bloc) => bloc.add(const LoginRequested(email: '', password: 'secret')),
    expect: () => [
      const Unauthenticated(isSubmitting: true),
      const Unauthenticated(errorMessage: 'Enter your email address', errorField: 'email'),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'offline login explains that a connection is needed',
    setUp: () => loginReturns(const Err(NetworkFailure())),
    build: build,
    act: (bloc) => bloc.add(const LoginRequested(email: 'worker@example.com', password: 'secret')),
    expect: () => [
      const Unauthenticated(isSubmitting: true),
      const Unauthenticated(errorMessage: 'No internet connection. Connect to sign in.'),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'logout',
    build: build,
    seed: () => const Authenticated(_user),
    act: (bloc) => bloc.add(const LogoutRequested()),
    expect: () => [const Unauthenticated()],
    verify: (_) => verify(() => logout()).called(1),
  );

  blocTest<AuthBloc, AuthState>(
    'expired session asks to sign in again but keeps the data on the device',
    build: build,
    seed: () => const Authenticated(_user),
    act: (bloc) => bloc.add(const SessionExpired()),
    expect: () => [const Unauthenticated(errorMessage: 'Your session has expired. Please sign in again.')],
    verify: (_) {
      verify(() => endExpiredSession()).called(1);
      verifyNever(() => logout());
    },
  );
}
