import 'dart:async';

import 'package:taskinspect/core/notifications/push_token_source.dart';

/// A [PushTokenSource] for tests: no real Firebase plugin.
class FakePushTokenSource implements PushTokenSource {
  FakePushTokenSource({this.token});

  /// The token [currentToken] returns; `null` means none is available yet.
  String? token;

  int permissionRequests = 0;

  final _refreshController = StreamController<String>.broadcast();

  @override
  Future<String?> currentToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _refreshController.stream;

  @override
  Future<void> requestPermission() async {
    permissionRequests++;
  }

  /// Simulates Firebase replacing the token.
  void refreshToken(String newToken) {
    token = newToken;
    _refreshController.add(newToken);
  }

  void dispose() {
    unawaited(_refreshController.close());
  }
}
