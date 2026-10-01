import 'dart:convert';

import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:taskinspect/features/authentication/data/models/session_model.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';

/// [AuthRepository] backed by the API and secure storage. The session (and
/// the user's profile) is kept on the device, so a logged-in worker can
/// open the app and keep working without a connection.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._storage, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;
  final DateTime Function() _now;

  @override
  Future<Result<AuthUser>> login({required String email, required String password}) async {
    final result = await _remote.login(email: email, password: password);
    switch (result) {
      case Ok(:final value):
        await _save(value);
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
      return Ok(user);
    }

    final refreshed = await _remote.refresh(tokens.refreshToken);
    switch (refreshed) {
      case Ok(:final value):
        await _save(value);
        return Ok(value.user);
      // Offline (or the server is down): keep working with the saved session.
      case Err(failure: NetworkFailure()):
      case Err(failure: ServerFailure(isServerError: true)):
        return Ok(user);
      // The server refused the refresh token or the account: log out.
      case Err():
        await _storage.clear();
        return const Ok(null);
    }
  }

  @override
  Future<void> logout() async {
    final tokens = await _storage.read();
    await _storage.clear();
    if (tokens != null) {
      // Best effort: the token is already gone from the device.
      await _remote.logout(tokens.refreshToken);
    }
  }

  Future<void> _save(SessionModel session) async {
    await _storage.save(session.tokens);
    await _storage.saveUserProfile(jsonEncode(UserModel.toJson(session.user)));
  }

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
