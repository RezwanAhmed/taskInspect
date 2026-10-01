import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/features/authentication/data/models/session_model.dart';

/// Calls the backend's `/api/auth` endpoints.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<SessionModel>> login({required String email, required String password}) {
    return _api.send(
      (dio) => dio.post<Object?>('/api/auth/login', data: {'email': email, 'password': password}),
      (body) => SessionModel.fromJson(body! as Map<String, Object?>),
    );
  }

  Future<Result<SessionModel>> refresh(String refreshToken) {
    return _api.send(
      (dio) => dio.post<Object?>('/api/auth/refresh', data: {'refreshToken': refreshToken}),
      (body) => SessionModel.fromJson(body! as Map<String, Object?>),
    );
  }

  Future<Result<void>> logout(String refreshToken) {
    return _api.send(
      (dio) => dio.post<Object?>('/api/auth/logout', data: {'refreshToken': refreshToken}),
      (_) {},
    );
  }
}
