import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:taskinspect/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:taskinspect/features/authentication/data/token_refresher.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/entities/user_role.dart';

Map<String, Object?> _session(String access, String refresh) => {
      'accessToken': access,
      'tokenType': 'Bearer',
      'expiresAt': '2026-10-01T09:15:00Z',
      'refreshToken': refresh,
      'refreshTokenExpiresAt': '2026-10-31T09:00:00Z',
      'user': {
        'id': 'u1',
        'email': 'solo@example.com',
        'fullName': 'Solo User',
        'roles': ['MANAGER', 'WORKER'],
      },
    };

void main() {
  late DioAdapter server;
  late InMemoryTokenStorage storage;
  late DateTime now;
  late AuthRepositoryImpl repository;
  late int clearedLocalData;
  late List<String> claimedBy;

  setUp(() {
    final api = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    server = DioAdapter(dio: api.dio, matcher: const UrlRequestMatcher());
    storage = InMemoryTokenStorage();
    now = DateTime.utc(2026, 10, 1, 9);
    final remote = AuthRemoteDataSource(api);
    clearedLocalData = 0;
    claimedBy = [];
    repository = AuthRepositoryImpl(remote, storage, TokenRefresher(remote, storage),
        now: () => now,
        clearLocalData: () async => clearedLocalData++,
        claimLocalData: (userId) async => claimedBy.add(userId));
  });

  Future<void> loggedIn() async {
    server.onPost('/api/auth/login', (s) => s.reply(200, _session('access-1', 'refresh-1')));
    await repository.login(email: 'solo@example.com', password: 'secret');
  }

  test('login saves tokens and profile and returns the user', () async {
    await loggedIn();

    expect(storage.tokens!.accessToken, 'access-1');
    expect(storage.tokens!.refreshToken, 'refresh-1');
    final restored = (await repository.restoreSession() as Ok<AuthUser?>).value!;
    expect(restored.fullName, 'Solo User');
    expect(restored.roles, {UserRole.manager, UserRole.worker});
  });

  test('wrong password returns the failure and saves nothing', () async {
    server.onPost('/api/auth/login', (s) => s.reply(401, {'code': 'INVALID_CREDENTIALS'}));

    final result = await repository.login(email: 'solo@example.com', password: 'wrong');

    expect((result as Err<AuthUser>).failure, isA<UnauthorizedFailure>());
    expect(storage.tokens, isNull);
  });

  test('no saved session means logged out', () async {
    expect((await repository.restoreSession() as Ok<AuthUser?>).value, isNull);
  });

  test('expired access token is refreshed and the new tokens are saved', () async {
    await loggedIn();
    now = DateTime.utc(2026, 10, 1, 10);
    server.onPost('/api/auth/refresh', (s) => s.reply(200, _session('access-2', 'refresh-2')),
        data: {'refreshToken': 'refresh-1'});

    final user = (await repository.restoreSession() as Ok<AuthUser?>).value;

    expect(user, isNotNull);
    expect(storage.tokens!.accessToken, 'access-2');
    expect(storage.tokens!.refreshToken, 'refresh-2');
  });

  test('offline with an expired access token keeps the saved session', () async {
    await loggedIn();
    now = DateTime.utc(2026, 10, 1, 10);
    server.onPost('/api/auth/refresh', (s) => s.throws(0,
        DioException.connectionError(requestOptions: RequestOptions(path: '/api/auth/refresh'), reason: 'offline')));

    final user = (await repository.restoreSession() as Ok<AuthUser?>).value;

    expect(user!.email, 'solo@example.com');
    expect(storage.tokens!.accessToken, 'access-1');
  });

  test('refused refresh token logs out', () async {
    await loggedIn();
    now = DateTime.utc(2026, 10, 1, 10);
    server.onPost('/api/auth/refresh', (s) => s.reply(401, {'code': 'INVALID_REFRESH_TOKEN'}));

    expect((await repository.restoreSession() as Ok<AuthUser?>).value, isNull);
    expect(storage.tokens, isNull);
  });

  test('expired refresh token logs out without calling the server', () async {
    await loggedIn();
    now = DateTime.utc(2026, 11, 1);

    expect((await repository.restoreSession() as Ok<AuthUser?>).value, isNull);
    expect(storage.userProfile, isNull);
  });

  test('logout clears the device and tells the server', () async {
    await loggedIn();
    var serverCalled = false;
    server.onPost('/api/auth/logout', (s) {
      serverCalled = true;
      s.reply(204, null);
    }, data: {'refreshToken': 'refresh-1'});

    await repository.logout();

    expect(storage.tokens, isNull);
    expect(serverCalled, isTrue);
    expect(clearedLocalData, 1, reason: 'the user\'s tasks and answers are removed from the device');
  });

  test('signing in or restoring the session claims the local data for the user', () async {
    await loggedIn();
    await repository.restoreSession();

    expect(claimedBy, ['u1', 'u1']);
  });

  test('a session that can no longer be restored claims nothing', () async {
    await loggedIn();
    claimedBy.clear();
    now = DateTime.utc(2026, 10, 1, 10);
    server.onPost('/api/auth/refresh', (s) => s.reply(401, {'code': 'INVALID_REFRESH_TOKEN'}));

    await repository.restoreSession();

    expect(claimedBy, isEmpty);
  });

  test('an expired session removes the tokens but keeps the local data', () async {
    await loggedIn();

    await repository.endExpiredSession();

    expect(storage.tokens, isNull);
    expect(clearedLocalData, 0);
  });
}
