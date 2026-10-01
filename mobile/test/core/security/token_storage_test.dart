import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/security/token_storage.dart';

void main() {
  late SecureTokenStorage storage;

  final tokens = StoredTokens(
    accessToken: 'access-123',
    accessTokenExpiresAt: DateTime.utc(2026, 10, 1, 9, 15),
    refreshToken: 'refresh-456',
    refreshTokenExpiresAt: DateTime.utc(2026, 10, 31, 9),
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureTokenStorage();
  });

  test('nothing is stored at first', () async {
    expect(await storage.read(), isNull);
  });

  test('saves and reads the tokens', () async {
    await storage.save(tokens);

    final read = await storage.read();

    expect(read!.accessToken, 'access-123');
    expect(read.accessTokenExpiresAt, DateTime.utc(2026, 10, 1, 9, 15));
    expect(read.refreshToken, 'refresh-456');
    expect(read.refreshTokenExpiresAt, DateTime.utc(2026, 10, 31, 9));
  });

  test('clear removes the tokens', () async {
    await storage.save(tokens);

    await storage.clear();

    expect(await storage.read(), isNull);
  });

  test('incomplete data counts as not logged in', () async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'only-this'});

    expect(await SecureTokenStorage().read(), isNull);
  });

  test('expiry checks', () {
    expect(tokens.isAccessTokenExpired(DateTime.utc(2026, 10, 1, 9)), isFalse);
    expect(tokens.isAccessTokenExpired(DateTime.utc(2026, 10, 1, 9, 15)), isTrue);
    expect(tokens.isRefreshTokenExpired(DateTime.utc(2026, 10, 30)), isFalse);
  });
}
