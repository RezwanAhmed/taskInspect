import 'package:firebase_messaging/firebase_messaging.dart';

/// Where the device's push notification token comes from. Wraps
/// [FirebaseMessaging] so [PushNotificationService] can be tested with a
/// fake instead of the real plugin.
abstract interface class PushTokenSource {
  /// The device's current token, or `null` if none is available yet.
  Future<String?> currentToken();

  /// Fires whenever Firebase replaces the token (it can at any time).
  Stream<String> get onTokenRefresh;

  /// Asks the user to allow notifications (iOS; Android 13+).
  Future<void> requestPermission();
}

class FirebaseMessagingTokenSource implements PushTokenSource {
  const FirebaseMessagingTokenSource(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<String?> currentToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<void> requestPermission() async {
    await _messaging.requestPermission();
  }
}
