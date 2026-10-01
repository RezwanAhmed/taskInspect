import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';

/// Logs a user in. Checks the input first, so obvious mistakes don't need
/// a network round trip.
class Login {
  const Login(this._repository);

  final AuthRepository _repository;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<Result<AuthUser>> call({required String email, required String password}) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      return const Err(InvalidInputFailure(field: 'email', message: 'Enter your email address'));
    }
    if (!_email.hasMatch(trimmedEmail)) {
      return const Err(InvalidInputFailure(field: 'email', message: 'Enter a valid email address'));
    }
    if (password.isEmpty) {
      return const Err(InvalidInputFailure(field: 'password', message: 'Enter your password'));
    }
    return _repository.login(email: trimmedEmail, password: password);
  }
}
