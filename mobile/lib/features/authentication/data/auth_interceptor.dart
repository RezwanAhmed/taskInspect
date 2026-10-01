import 'package:dio/dio.dart';
import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/features/authentication/data/token_refresher.dart';

/// Adds the access token to every API call and keeps it fresh:
///
/// * a token that has expired (or expires within [refreshMargin]) is
///   refreshed before the request is sent;
/// * if the server still answers 401, the token is refreshed once and the
///   request is sent again;
/// * if the server refuses the refresh token, [onSessionExpired] is called
///   so the app can return to the login screen.
///
/// The login, refresh and logout endpoints are sent without a token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this._storage,
    required this._refresher,
    required this._onSessionExpired,
    DateTime Function()? now,
    this.refreshMargin = const Duration(seconds: 30),
  }) : _now = now ?? DateTime.now;

  /// The client this interceptor belongs to; used to send a request again.
  final Dio dio;
  final Duration refreshMargin;
  final TokenStorage _storage;

  /// Looked up when first needed: the refresher itself calls the API
  /// through the client this interceptor belongs to.
  final TokenRefresher Function() _refresher;
  final void Function() _onSessionExpired;
  final DateTime Function() _now;

  static const _retried = 'auth_retried';

  static bool _isAuthEndpoint(RequestOptions options) =>
      options.path.startsWith('/api/auth/') && !options.path.startsWith('/api/auth/me');

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_isAuthEndpoint(options)) {
      return handler.next(options);
    }
    var tokens = await _storage.read();
    if (tokens != null && tokens.isAccessTokenExpired(_now().add(refreshMargin))) {
      final outcome = await _refresher().refresh();
      if (outcome == RefreshOutcome.refused) {
        _onSessionExpired();
      }
      tokens = await _storage.read();
    }
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || _isAuthEndpoint(options) || options.extra[_retried] == true) {
      return handler.next(err);
    }
    switch (await _refresher().refresh()) {
      case RefreshOutcome.refreshed:
        final tokens = await _storage.read();
        options.extra[_retried] = true;
        options.headers['Authorization'] = 'Bearer ${tokens!.accessToken}';
        try {
          handler.resolve(await dio.fetch<Object?>(options));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      case RefreshOutcome.refused:
        _onSessionExpired();
        handler.next(err);
      case RefreshOutcome.unavailable:
        handler.next(err);
    }
  }
}
