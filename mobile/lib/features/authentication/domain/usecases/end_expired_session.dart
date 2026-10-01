import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';

/// The session expired (the server refused the refresh token). The user
/// must sign in again, but their unsent changes stay on the device.
class EndExpiredSession {
  const EndExpiredSession(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.endExpiredSession();
}
