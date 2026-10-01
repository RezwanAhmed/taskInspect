import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/features/authentication/data/auth_interceptor.dart';
import 'package:taskinspect/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:taskinspect/features/authentication/data/token_refresher.dart';

/// A fake server: [handle] answers every request and sees exactly what was sent.
class _FakeServer implements HttpClientAdapter {
  _FakeServer(this.handle);

  final Future<(int, Object?)> Function(RequestOptions request) handle;

  /// Path and Authorization header of every request, as they were sent.
  final List<(String, Object?)> requests = [];

  int count(String path) => requests.where((r) => r.$1 == path).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add((options.path, options.headers['Authorization']));
    final (status, body) = await handle(options);
    if (status == 0) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _session(String access, String refresh) => {
      'accessToken': access,
      'expiresAt': '2026-10-01T09:30:00Z',
      'refreshToken': refresh,
      'refreshTokenExpiresAt': '2026-10-31T09:00:00Z',
      'user': {'id': 'u1', 'email': 'w@example.com', 'fullName': 'W', 'roles': ['WORKER']},
    };

void main() {
  late ApiClient api;
  late InMemoryTokenStorage storage;
  late DateTime now;
  late int expiredCalls;

  setUp(() {
    api = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    storage = InMemoryTokenStorage()
      ..tokens = StoredTokens(
        accessToken: 'access-1',
        accessTokenExpiresAt: DateTime.utc(2026, 10, 1, 9, 15),
        refreshToken: 'refresh-1',
        refreshTokenExpiresAt: DateTime.utc(2026, 10, 31, 9),
      );
    now = DateTime.utc(2026, 10, 1, 9);
    expiredCalls = 0;
    final refresher = TokenRefresher(AuthRemoteDataSource(api), storage);
    api.dio.interceptors.add(AuthInterceptor(
      dio: api.dio,
      storage: storage,
      refresher: () => refresher,
      onSessionExpired: () => expiredCalls++,
      now: () => now,
    ));
  });

  _FakeServer serve(Future<(int, Object?)> Function(RequestOptions request) handle) {
    final server = _FakeServer(handle);
    api.dio.httpClientAdapter = server;
    return server;
  }

  List<Object?> tokensSentTo(_FakeServer server, String path) =>
      server.requests.where((r) => r.$1 == path).map((r) => r.$2).toList();

  Future<Result<Object?>> getTasks() => api.send((dio) => dio.get<Object?>('/api/tasks'), (body) => body);

  test('sends the access token with API calls', () async {
    final server = serve((r) async => (200, <Object?>[]));

    expect(await getTasks(), isA<Ok<Object?>>());
    expect(tokensSentTo(server, '/api/tasks'), ['Bearer access-1']);
  });

  test('login is sent without a token', () async {
    final server = serve((r) async => (200, _session('a', 'r')));

    await AuthRemoteDataSource(api).login(email: 'w@example.com', password: 'secret');

    expect(tokensSentTo(server, '/api/auth/login'), [null]);
  });

  test('refreshes an expiring token before the call', () async {
    now = DateTime.utc(2026, 10, 1, 9, 14, 45);
    final server = serve((r) async => r.path == '/api/auth/refresh'
        ? (200, _session('access-2', 'refresh-2'))
        : (200, <Object?>[]));

    await getTasks();

    expect(tokensSentTo(server, '/api/tasks'), ['Bearer access-2']);
    expect(storage.tokens!.refreshToken, 'refresh-2');
  });

  test('a 401 is answered by refreshing once and sending the call again', () async {
    final server = serve((r) async {
      if (r.path == '/api/auth/refresh') {
        return (200, _session('access-2', 'refresh-2'));
      }
      return r.headers['Authorization'] == 'Bearer access-2'
          ? (200, <Object?>[])
          : (401, <String, Object?>{'code': 'INVALID_TOKEN'});
    });

    final result = await getTasks();

    expect(result, isA<Ok<Object?>>());
    expect(tokensSentTo(server, '/api/tasks'), ['Bearer access-1', 'Bearer access-2']);
    expect(server.count('/api/auth/refresh'), 1);
  });

  test('a refused refresh token ends the session', () async {
    serve((r) async => r.path == '/api/auth/refresh'
        ? (401, <String, Object?>{'code': 'INVALID_REFRESH_TOKEN'})
        : (401, <String, Object?>{'code': 'INVALID_TOKEN'}));

    final result = await getTasks();

    expect(result, isA<Err<Object?>>());
    expect(expiredCalls, 1);
    expect(storage.tokens, isNull);
  });

  test('a call that still gets 401 after a refresh is not retried again', () async {
    final server = serve((r) async => r.path == '/api/auth/refresh'
        ? (200, _session('access-2', 'refresh-2'))
        : (401, <String, Object?>{'code': 'INVALID_TOKEN'}));

    expect(await getTasks(), isA<Err<Object?>>());
    expect(server.count('/api/tasks'), 2);
    expect(server.count('/api/auth/refresh'), 1);
  });

  test('offline refresh keeps the session', () async {
    now = DateTime.utc(2026, 10, 1, 10);
    serve((r) async => (0, null));

    await getTasks();

    expect(expiredCalls, 0);
    expect(storage.tokens!.refreshToken, 'refresh-1');
  });

  test('calls that need a refresh at the same time share one refresh', () async {
    now = DateTime.utc(2026, 10, 1, 10);
    final server = serve((r) async {
      if (r.path == '/api/auth/refresh') {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return (200, _session('access-2', 'refresh-2'));
      }
      return (200, <Object?>[]);
    });

    await Future.wait([getTasks(), getTasks(), getTasks()]);

    expect(server.count('/api/auth/refresh'), 1);
    expect(tokensSentTo(server, '/api/tasks'), everyElement('Bearer access-2'));
  });
}
