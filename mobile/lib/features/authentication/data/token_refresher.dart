import 'dart:async';
import 'dart:convert';

import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:taskinspect/features/authentication/data/models/session_model.dart';

enum RefreshOutcome {
  /// New tokens are saved.
  refreshed,

  /// The server refused the refresh token or the account; the saved
  /// session was removed and the user must sign in again.
  refused,

  /// The server could not be reached; the saved session is kept.
  unavailable,
}

/// Exchanges the saved refresh token for new tokens. A refresh token can be
/// used only once (ADR-0003), so calls that overlap share one request.
class TokenRefresher {
  TokenRefresher(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;
  Future<RefreshOutcome>? _running;

  Future<RefreshOutcome> refresh() => _running ??= _refresh().whenComplete(() => _running = null);

  Future<RefreshOutcome> _refresh() async {
    final tokens = await _storage.read();
    if (tokens == null) {
      return RefreshOutcome.refused;
    }
    final result = await _remote.refresh(tokens.refreshToken);
    switch (result) {
      case Ok(:final value):
        await save(value);
        return RefreshOutcome.refreshed;
      case Err(failure: NetworkFailure()):
      case Err(failure: ServerFailure(isServerError: true)):
        return RefreshOutcome.unavailable;
      case Err():
        await _storage.clear();
        return RefreshOutcome.refused;
    }
  }

  /// Saves a new session (tokens and the user's profile).
  Future<void> save(SessionModel session) async {
    await _storage.save(session.tokens);
    await _storage.saveUserProfile(jsonEncode(UserModel.toJson(session.user)));
  }
}
