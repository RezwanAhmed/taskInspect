import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A fake HTTP server for Dio: [handle] answers every request with a status
/// and a JSON body (status 0 = no connection). It records what was sent.
class FakeServer implements HttpClientAdapter {
  FakeServer(this.handle);

  final Future<(int, Object?)> Function(RequestOptions request) handle;

  /// Path, query and Authorization header of every request, as sent.
  final List<({String path, Map<String, Object?> query, Object? auth})> requests = [];

  int count(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add((path: options.path, query: Map.of(options.queryParameters), auth: options.headers['Authorization']));
    final (status, body) = await handle(options);
    if (status == 0) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
