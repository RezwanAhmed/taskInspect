part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// The app started: restore a saved session, if any.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class LoginRequested extends AuthEvent {
  const LoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

/// The session can no longer be refreshed (e.g. the refresh token
/// expired while the app was running).
final class SessionExpired extends AuthEvent {
  const SessionExpired();
}
