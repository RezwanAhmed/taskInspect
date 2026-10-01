import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';

/// Finds out at start-up whether a user is still logged in.
class RestoreSession {
  const RestoreSession(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthUser?>> call() => _repository.restoreSession();
}
