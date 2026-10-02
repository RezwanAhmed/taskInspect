import 'dart:convert';

import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:taskinspect/features/authentication/data/models/session_model.dart';
import 'package:taskinspect/features/authentication/data/token_refresher.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/entities/unsynced_changes.dart';
import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';

/// [AuthRepository] backed by the API and secure storage. The session (and
/// the user's profile) is kept on the device, so a logged-in worker can
/// open the app and keep working without a connection.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._remote,
    this._storage,
    this._refresher, {
    DateTime Function()? now,
    Future<void> Function()? clearLocalData,
    Future<void> Function(AuthUser user)? claimLocalData,
    Future<UnsyncedChanges?> Function()? unsyncedChanges,
  }) : _now = now ?? DateTime.now,
       _clearLocalData = clearLocalData ?? _nothing,
       _claimLocalData = claimLocalData ?? _nobody,
       _unsyncedChanges = unsyncedChanges ?? _none;

  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;
  final TokenRefresher _refresher;
  final DateTime Function() _now;

  /// Removes the user's data from the device at sign out.
  final Future<void> Function() _clearLocalData;

  /// Makes the device's data the signed-in user's; another user's data is
  /// removed first (see LocalDataOwner).
  final Future<void> Function(AuthUser user) _claimLocalData;

  /// Unsynced changes on the device and whose they are (LocalDataOwner).
  final Future<UnsyncedChanges?> Function() _unsyncedChanges;

  static Future<void> _nothing() async {}

  static Future<void> _nobody(AuthUser user) async {}

  static Future<UnsyncedChanges?> _none() async => null;

  @override
  Future<Result<AuthUser>> login({
    required String email,
    required String password,
  }) async {
    final result = await _remote.login(email: email, password: password);
    switch (result) {
      case Ok(:final value):
        await _claimLocalData(value.user);
        await _refresher.save(value);
        return Ok(value.user);
      case Err(:final failure):
        return Err(failure);
    }
  }

  @override
  Future<Result<AuthUser?>> restoreSession() async {
    final tokens = await _storage.read();
    final user = await _readUser();
    final now = _now();
    if (tokens == null || user == null || tokens.isRefreshTokenExpired(now)) {
      await _storage.clear();
      return const Ok(null);
    }
    if (!tokens.isAccessTokenExpired(now)) {
      await _claimLocalData(user);
      return Ok(user);
    }

    final restored = switch (await _refresher.refresh()) {
      RefreshOutcome.refreshed => await _readUser(),
      // Offline (or the server is down): keep working with the saved session.
      RefreshOutcome.unavailable => user,
      // The server refused the refresh token or the account: logged out.
      RefreshOutcome.refused => null,
    };
    if (restored != null) {
      await _claimLocalData(restored);
    }
    return Ok(restored);
  }

  @override
  Future<void> logout() async {
    final tokens = await _storage.read();
    await _storage.clear();
    // The dashboard warns first when changes are not synced yet (6.13b).
    await _clearLocalData();
    if (tokens != null) {
      // Best effort: the token is already gone from the device.
      await _remote.logout(tokens.refreshToken);
    }
  }

  @override
  Future<void> endExpiredSession() => _storage.clear();

  @override
  Future<UnsyncedChanges?> unsyncedChanges() => _unsyncedChanges();

  Future<AuthUser?> _readUser() async {
    final json = await _storage.readUserProfile();
    if (json == null) {
      return null;
    }
    try {
      return UserModel.fromJson(jsonDecode(json) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }
}
