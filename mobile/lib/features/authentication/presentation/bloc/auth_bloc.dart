import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/failure_messages.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/usecases/end_expired_session.dart';
import 'package:taskinspect/features/authentication/domain/usecases/login.dart';
import 'package:taskinspect/features/authentication/domain/usecases/logout.dart';
import 'package:taskinspect/features/authentication/domain/usecases/restore_session.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// App-wide login state. The router listens to it: [Authenticated] opens
/// the app, [Unauthenticated] shows the login screen.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this._login,
    required this._restoreSession,
    required this._logout,
    required this._endExpiredSession,
  }) : super(const AuthUnknown()) {
    on<AuthStarted>(_onStarted);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<SessionExpired>(_onSessionExpired);
  }

  final Login _login;
  final RestoreSession _restoreSession;
  final Logout _logout;
  final EndExpiredSession _endExpiredSession;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final result = await _restoreSession();
    emit(switch (result) {
      Ok(value: final user?) => Authenticated(user),
      _ => const Unauthenticated(),
    });
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(const Unauthenticated(isSubmitting: true));
    final result = await _login(email: event.email, password: event.password);
    emit(switch (result) {
      Ok(:final value) => Authenticated(value),
      // Logging in needs the server, so "saved locally" makes no sense here.
      Err(failure: NetworkFailure()) =>
        const Unauthenticated(errorMessage: 'No internet connection. Connect to sign in.'),
      Err(failure: final InvalidInputFailure failure) =>
        Unauthenticated(errorMessage: failure.message, errorField: failure.field),
      Err(:final failure) => Unauthenticated(errorMessage: userMessage(failure)),
    });
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    await _logout();
    emit(const Unauthenticated());
  }

  /// Unlike a logout, the user's data and unsent changes stay on the
  /// device; synchronization goes on once the same user signs in again.
  Future<void> _onSessionExpired(SessionExpired event, Emitter<AuthState> emit) async {
    await _endExpiredSession();
    emit(Unauthenticated(errorMessage: userMessage(const UnauthorizedFailure())));
  }
}
