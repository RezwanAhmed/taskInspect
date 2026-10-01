import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';

/// Authentication as the rest of the app sees it. The data layer
/// implements it with the API and secure token storage.
abstract interface class AuthRepository {
  /// Logs in and keeps the session on the device.
  Future<Result<AuthUser>> login({required String email, required String password});

  /// The user of a session saved on the device, or `null` when there is
  /// none (or it can no longer be refreshed).
  Future<Result<AuthUser?>> restoreSession();

  /// Ends the session on the server (best effort) and on the device.
  Future<void> logout();
}
