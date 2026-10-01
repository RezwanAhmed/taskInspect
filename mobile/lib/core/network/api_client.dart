import 'dart:math';

import 'package:dio/dio.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';

/// HTTP client for the TaskInspect API. Every call gets an `X-Request-Id`
/// header, and every error is turned into a [Failure] (see [send]).
class ApiClient {
  ApiClient(this.dio);

  /// Creates the client for the configured backend.
  factory ApiClient.forConfig(AppConfig config) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    dio.interceptors.add(RequestIdInterceptor());
    return ApiClient(dio);
  }

  final Dio dio;

  /// Runs [request] and parses the response body with [parse]. Network
  /// problems and error responses come back as [Err] with a [Failure].
  Future<Result<T>> send<T>(
    Future<Response<Object?>> Function(Dio dio) request,
    T Function(Object? body) parse,
  ) async {
    try {
      final response = await request(dio);
      return Ok(parse(response.data));
    } on DioException catch (e) {
      return Err(mapDioException(e));
    } on FormatException catch (e) {
      return Err(UnexpectedFailure(e));
    } on TypeError catch (e) {
      return Err(UnexpectedFailure(e));
    }
  }
}

/// Adds a unique `X-Request-Id` to every request; the backend logs it and
/// returns it in error responses.
class RequestIdInterceptor extends Interceptor {
  static const header = 'X-Request-Id';
  static final Random _random = Random.secure();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent(header, _newId);
    handler.next(options);
  }

  static String _newId() {
    return List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Maps a Dio error to a [Failure], reading the backend's error body
/// (`code`, `message`, `requestId`, `errors`) when there is one.
Failure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      return _fromResponse(e.response);
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.unknown:
      return UnexpectedFailure(e);
  }
}

Failure _fromResponse(Response<Object?>? response) {
  final status = response?.statusCode ?? 0;
  final body = response?.data;
  final json = body is Map<String, Object?> ? body : const <String, Object?>{};
  final code = json['code'] as String?;
  final message = json['message'] as String?;
  if (status == 401) {
    return UnauthorizedFailure(code: code, message: message);
  }
  final errors = json['errors'];
  final fieldErrors = <String, String>{
    if (errors is List<Object?>)
      for (final error in errors.whereType<Map<String, Object?>>())
        if (error['field'] is String) error['field']! as String: (error['message'] as String?) ?? 'is invalid',
  };
  return ServerFailure(
    statusCode: status,
    code: code,
    message: message,
    requestId: json['requestId'] as String?,
    fieldErrors: fieldErrors,
  );
}
