import 'dart:convert';

import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/storage/app_database.dart';

/// What the server did with one pushed operation.
enum SyncResultStatus {
  /// Applied now, or already applied by an earlier push.
  applied('APPLIED'),

  /// Refused by the server's rules; sending it again would fail again.
  rejected('REJECTED'),

  /// Not tried, because an earlier operation of the same task was rejected.
  skipped('SKIPPED');

  const SyncResultStatus(this.apiName);

  final String apiName;

  static SyncResultStatus fromApi(String name) => values.firstWhere((status) => status.apiName == name);
}

class SyncResult {
  const SyncResult({required this.id, required this.status, this.code, this.message});

  final String id;
  final SyncResultStatus status;

  /// Why it was rejected or skipped, e.g. `TASK_INVALID_TRANSITION`.
  final String? code;
  final String? message;
}

/// `POST /api/sync/push`: sends queued operations, in order.
class SyncRemoteDataSource {
  const SyncRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<List<SyncResult>>> push(List<SyncOperationRow> operations) {
    return _api.send(
      (dio) => dio.post<Object?>('/api/sync/push', data: {
        'operations': [
          for (final operation in operations)
            {
              'id': operation.id,
              'entityType': operation.entityType,
              'entityId': operation.entityId,
              'taskId': operation.taskId,
              'operation': operation.operation,
              'payload': jsonDecode(operation.payload),
            },
        ],
      }),
      (body) => ((body! as Map<String, Object?>)['results']! as List<Object?>).map((json) {
        final result = json! as Map<String, Object?>;
        return SyncResult(
          id: result['id']! as String,
          status: SyncResultStatus.fromApi(result['status']! as String),
          code: result['code'] as String?,
          message: result['message'] as String?,
        );
      }).toList(),
    );
  }
}
