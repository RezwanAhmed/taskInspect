import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/notifications/push_token_source.dart';

/// Registers and removes this device's push notification token with the
/// backend (`PUT`/`DELETE /api/devices`, task 8.4/8.7). Sending the request
/// never throws - a failure here must not block signing in or out. Callers
/// decide *when* to register (the signed-in state lives in [AuthBloc], and
/// depending on it here would be circular: AuthBloc needs Logout, which
/// needs this service).
class PushNotificationService {
  PushNotificationService(this._tokenSource, this._apiClient);

  final PushTokenSource _tokenSource;
  final ApiClient _apiClient;

  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Asks for permission and keeps the registered token current. Call once
  /// when the app starts.
  Future<void> start() async {
    await _tokenSource.requestPermission();
    _tokenRefreshSubscription = _tokenSource.onTokenRefresh.listen((_) => registerCurrentToken());
  }

  /// Registers this device's current token for the signed-in user. A call
  /// while signed out is simply refused by the backend (no valid session).
  Future<void> registerCurrentToken() async {
    final token = await _tokenSource.currentToken();
    if (token == null) {
      return;
    }
    await _apiClient.send(
      (dio) => dio.put<Object?>('/api/devices', data: {'token': token, 'platform': _platform}),
      (_) => null,
    );
  }

  /// Stops notifications on this device. Called before logout, while the
  /// session is still valid - a token the backend no longer recognizes for
  /// this user would just be re-claimed by whoever signs in here next.
  Future<void> unregister() async {
    final token = await _tokenSource.currentToken();
    if (token == null) {
      return;
    }
    await _apiClient.send(
      (dio) => dio.delete<Object?>('/api/devices', data: {'token': token}),
      (_) => null,
    );
  }

  static String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

  void dispose() {
    unawaited(_tokenRefreshSubscription?.cancel());
  }
}
