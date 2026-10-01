import 'dart:io';

import 'package:dio/dio.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';

/// Where to send a file: [method] to [url] with [headers] (a pre-signed
/// URL, ADR-0005).
class SignedUrl {
  const SignedUrl({required this.url, required this.method, required this.headers});

  final String url;
  final String method;
  final Map<String, String> headers;
}

/// Uploads evidence files: get a signed upload URL from the API, send the
/// file to it, then confirm with `complete` (docs/architecture.md, "Sync
/// Cycle").
class EvidenceRemoteDataSource {
  EvidenceRemoteDataSource(this._api, {Dio? files}) : _files = files ?? _filesClient();

  /// The upload URL was refused (403): it expired, or the backend restarted
  /// with a new signing key. A new URL will work, so it is retried.
  static const urlExpired = 'UPLOAD_URL_EXPIRED';

  final ApiClient _api;

  /// Sends files to the signed URLs: no base URL and no login (the
  /// signature is the permission). No send timeout: Dio applies it to the
  /// whole file, and a 20 MB PDF on a weak connection needs minutes.
  final Dio _files;

  static Dio _filesClient() => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ));

  Future<Result<SignedUrl>> uploadUrl({required String taskId, required String evidenceId}) {
    return _api.send(
      (dio) => dio.post<Object?>('/api/tasks/$taskId/evidence/$evidenceId/upload-url'),
      (body) {
        final json = body! as Map<String, Object?>;
        return SignedUrl(
          url: json['url']! as String,
          method: json['method']! as String,
          headers: (json['headers']! as Map<String, Object?>).cast<String, String>(),
        );
      },
    );
  }

  /// Sends [file] to [target]. A connection lost on the way is a
  /// NetworkFailure; a file that disappeared (removed meanwhile) is an
  /// UnexpectedFailure with the FileSystemException.
  Future<Result<void>> uploadFile(SignedUrl target, File file) async {
    final headers = {for (final MapEntry(:key, :value) in target.headers.entries) key.toLowerCase(): value};
    try {
      await _files.request<Object?>(
        target.url,
        data: file.openRead(),
        options: Options(
          method: target.method,
          contentType: headers.remove(Headers.contentTypeHeader),
          headers: {...headers, Headers.contentLengthHeader: await file.length()},
        ),
      );
      return const Ok(null);
    } on FileSystemException catch (e) {
      return Err(UnexpectedFailure(e));
    } on DioException catch (e) {
      return Err(switch (e) {
        DioException(error: SocketException() || HttpException()) => const NetworkFailure(),
        DioException(error: final FileSystemException error) => UnexpectedFailure(error),
        DioException(response: Response(statusCode: 403)) => const ServerFailure(statusCode: 403, code: urlExpired),
        _ => mapDioException(e),
      });
    }
  }

  Future<Result<void>> complete({required String taskId, required String evidenceId}) {
    return _api.send(
      (dio) => dio.post<Object?>('/api/tasks/$taskId/evidence/$evidenceId/complete'),
      (_) {},
    );
  }
}
