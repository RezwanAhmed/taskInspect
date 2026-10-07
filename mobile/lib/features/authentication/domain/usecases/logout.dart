import 'package:taskinspect/core/notifications/push_notification_service.dart';
import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';

/// Ends the session. Stops push notifications on this device first, while
/// the session is still valid to make that call (DeviceController: "called
/// before logout").
class Logout {
  const Logout(this._repository, this._pushNotificationService);

  final AuthRepository _repository;
  final PushNotificationService _pushNotificationService;

  Future<void> call() async {
    await _pushNotificationService.unregister();
    await _repository.logout();
  }
}
