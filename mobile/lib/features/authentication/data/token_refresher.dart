import 'dart:async';
import 'dart:convert';

import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/security/refresh_lock.dart';
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
/// used only once (ADR-0003), so calls that overlap share one request, and
/// [RefreshLock] keeps the app and the background sync (another isolate)
/// from refreshing at the same time.
class TokenRefresher {
  TokenRefresher(this._remote, this._storage, {this._lock = const NoRefreshLock()});

  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;
  final RefreshLock _lock;
  Future<RefreshOutcome>? _running;

  Future<RefreshOutcome> refresh() => _running ??= _refresh().whenComplete(() => _running = null);

  Future<RefreshOutcome> _refresh() async {
    final seen = (await _storage.read())?.refreshToken;
    return _lock.run(() async {
      final tokens = await _storage.read();
      if (tokens == null) {
        return RefreshOutcome.refused;
      }
      if (seen != null && tokens.refreshToken != seen) {
        // The other isolate refreshed while this one waited for the lock.
        return RefreshOutcome.refreshed;
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
    });
  }

  /// Saves a new session (tokens and the user's profile).
  Future<void> save(SessionModel session) async {
    await _storage.save(session.tokens);
    await _storage.saveUserProfile(jsonEncode(UserModel.toJson(session.user)));
  }
}
