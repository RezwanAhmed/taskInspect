import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/notifications/push_notification_service.dart';

import '../../helpers/fake_push_notifications.dart';
import '../../helpers/fake_server.dart';

void main() {
  late FakePushTokenSource tokenSource;
  late ApiClient apiClient;
  late FakeServer server;
  late PushNotificationService service;

  setUp(() {
    tokenSource = FakePushTokenSource();
    apiClient = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    server = FakeServer((_) async => (204, null));
    apiClient.dio.httpClientAdapter = server;
    service = PushNotificationService(tokenSource, apiClient);
  });

  test('registerCurrentToken does nothing without a token yet', () async {
    await service.registerCurrentToken();

    expect(server.requests, isEmpty);
  });

  test('registerCurrentToken sends the token and platform to the backend', () async {
    tokenSource.token = 'tok-123';
    Map<String, Object?>? sentData;
    String? sentMethod;
    apiClient.dio.httpClientAdapter = FakeServer((request) async {
      sentMethod = request.method;
      sentData = request.data as Map<String, Object?>?;
      return (204, null);
    });

    await service.registerCurrentToken();

    expect(sentMethod, 'PUT');
    expect(sentData, containsPair('token', 'tok-123'));
    expect(sentData, containsPair('platform', anyOf('ANDROID', 'IOS')));
  });

  test('unregister does nothing without a token', () async {
    await service.unregister();

    expect(server.requests, isEmpty);
  });

  test('unregister sends the token to be removed', () async {
    tokenSource.token = 'tok-456';
    Map<String, Object?>? sentData;
    String? sentMethod;
    apiClient.dio.httpClientAdapter = FakeServer((request) async {
      sentMethod = request.method;
      sentData = request.data as Map<String, Object?>?;
      return (204, null);
    });

    await service.unregister();

    expect(sentMethod, 'DELETE');
    expect(sentData, {'token': 'tok-456'});
  });

  test('start requests permission and re-registers on a token refresh', () async {
    await service.start();
    expect(tokenSource.permissionRequests, 1);

    tokenSource.refreshToken('tok-new');
    await pumpEventQueue();

    expect(server.requests, hasLength(1));
  });

  test('a failed request does not throw', () async {
    tokenSource.token = 'tok-789';
    apiClient.dio.httpClientAdapter = FakeServer((_) async => (401, {'code': 'UNAUTHORIZED'}));

    await service.registerCurrentToken();
    await service.unregister();
  });
}
