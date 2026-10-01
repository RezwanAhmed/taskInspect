part of 'auth_bloc.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Start-up: not yet known whether a session is saved (splash screen).
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class Authenticated extends AuthState {
  const Authenticated(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

/// Logged out. While a login is being checked [isSubmitting] is true; a
/// failed login sets [errorMessage] (and [errorField] for input errors).
final class Unauthenticated extends AuthState {
  const Unauthenticated({this.isSubmitting = false, this.errorMessage, this.errorField});

  final bool isSubmitting;
  final String? errorMessage;

  /// `email` or `password` when that input is wrong.
  final String? errorField;

  @override
  List<Object?> get props => [isSubmitting, errorMessage, errorField];
}
