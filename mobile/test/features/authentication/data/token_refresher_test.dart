import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/security/refresh_lock.dart';
import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:taskinspect/features/authentication/data/models/session_model.dart';
import 'package:taskinspect/features/authentication/data/token_refresher.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

/// A lock another isolate holds while it refreshes: [whileWaiting] runs
/// before this isolate gets the lock.
class _BusyLock implements RefreshLock {
  _BusyLock(this.whileWaiting);

  final Future<void> Function() whileWaiting;
  int runs = 0;

  @override
  Future<T> run<T>(Future<T> Function() action) async {
    runs++;
    await whileWaiting();
    return action();
  }
}

StoredTokens _tokens(String refreshToken) => StoredTokens(
      accessToken: 'access-$refreshToken',
      accessTokenExpiresAt: DateTime.utc(2026, 10, 1, 9),
      refreshToken: refreshToken,
      refreshTokenExpiresAt: DateTime.utc(2026, 10, 31),
    );

void main() {
  late _MockRemote remote;
  late InMemoryTokenStorage storage;

  setUp(() {
    remote = _MockRemote();
    storage = InMemoryTokenStorage()..tokens = _tokens('refresh-1');
    when(() => remote.refresh(any())).thenAnswer((_) async => Ok(SessionModel.fromJson({
          'accessToken': 'access-2',
          'expiresAt': '2026-10-01T09:15:00Z',
          'refreshToken': 'refresh-2',
          'refreshTokenExpiresAt': '2026-10-31T09:00:00Z',
          'user': {'id': 'u1', 'email': 'w@example.com', 'fullName': 'W', 'roles': ['WORKER']},
        })));
  });

  test('refreshes inside the lock', () async {
    final lock = _BusyLock(() async {});

    expect(await TokenRefresher(remote, storage, lock: lock).refresh(), RefreshOutcome.refreshed);

    expect(lock.runs, 1);
    verify(() => remote.refresh('refresh-1')).called(1);
    expect(storage.tokens!.refreshToken, 'refresh-2');
  });

  test('uses the tokens the other isolate got while this one waited, without refreshing again', () async {
    // The background sync refreshed meanwhile; sending refresh-1 again
    // would sign the user out everywhere.
    final lock = _BusyLock(() async => storage.tokens = _tokens('refresh-from-background'));

    expect(await TokenRefresher(remote, storage, lock: lock).refresh(), RefreshOutcome.refreshed);

    verifyNever(() => remote.refresh(any()));
    expect(storage.tokens!.refreshToken, 'refresh-from-background');
  });

  test('signed out by the other isolate while waiting: refused', () async {
    final lock = _BusyLock(() async => storage.tokens = null);

    expect(await TokenRefresher(remote, storage, lock: lock).refresh(), RefreshOutcome.refused);

    verifyNever(() => remote.refresh(any()));
  });
}
