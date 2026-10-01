import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The tokens of the logged-in user (see ADR-0003).
class StoredTokens {
  const StoredTokens({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;

  bool isAccessTokenExpired(DateTime now) => !now.isBefore(accessTokenExpiresAt);

  bool isRefreshTokenExpired(DateTime now) => !now.isBefore(refreshTokenExpiresAt);
}

/// Keeps the tokens on the device. The rest of the app depends on this
/// interface, so tests can use an in-memory fake.
abstract interface class TokenStorage {
  Future<StoredTokens?> read();

  Future<void> save(StoredTokens tokens);

  Future<void> clear();
}

/// Stores tokens in the platform's secure storage: Android Keystore
/// (encrypted shared preferences) and iOS Keychain. Tokens are never put
/// in plain preferences or logs.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  static const _accessToken = 'access_token';
  static const _accessTokenExpiresAt = 'access_token_expires_at';
  static const _refreshToken = 'refresh_token';
  static const _refreshTokenExpiresAt = 'refresh_token_expires_at';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredTokens?> read() async {
    final values = await _storage.readAll();
    final accessToken = values[_accessToken];
    final accessExpiry = DateTime.tryParse(values[_accessTokenExpiresAt] ?? '');
    final refreshToken = values[_refreshToken];
    final refreshExpiry = DateTime.tryParse(values[_refreshTokenExpiresAt] ?? '');
    if (accessToken == null || accessExpiry == null || refreshToken == null || refreshExpiry == null) {
      return null;
    }
    return StoredTokens(
      accessToken: accessToken,
      accessTokenExpiresAt: accessExpiry,
      refreshToken: refreshToken,
      refreshTokenExpiresAt: refreshExpiry,
    );
  }

  @override
  Future<void> save(StoredTokens tokens) async {
    await _storage.write(key: _accessToken, value: tokens.accessToken);
    await _storage.write(key: _accessTokenExpiresAt, value: tokens.accessTokenExpiresAt.toUtc().toIso8601String());
    await _storage.write(key: _refreshToken, value: tokens.refreshToken);
    await _storage.write(key: _refreshTokenExpiresAt, value: tokens.refreshTokenExpiresAt.toUtc().toIso8601String());
  }

  @override
  Future<void> clear() async {
    for (final key in [_accessToken, _accessTokenExpiresAt, _refreshToken, _refreshTokenExpiresAt]) {
      await _storage.delete(key: key);
    }
  }
}
