import 'dart:convert';

import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/features/tasks/data/remote/task_remote_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';

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

/// What changed on the server since the last pull.
class PullResult {
  const PullResult({required this.cursor, required this.taskIds, required this.tasks});

  /// Sent as `since` in the next pull.
  final String cursor;

  /// Every task the user may see now; the others are removed.
  final Set<String> taskIds;

  /// The tasks that changed, with their requirements.
  final List<(Task, List<Requirement>)> tasks;
}

/// `POST /api/sync/push` sends queued operations, in order; `GET
/// /api/sync/pull` loads what changed on the server.
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

  /// Everything when [since] is `null`, else the changes since that cursor.
  Future<Result<PullResult>> pull({String? since}) {
    return _api.send(
      (dio) => dio.get<Object?>('/api/sync/pull', queryParameters: {'since': ?since}),
      (body) {
        final json = body! as Map<String, Object?>;
        return PullResult(
          cursor: json['cursor']! as String,
          taskIds: (json['taskIds']! as List<Object?>).cast<String>().toSet(),
          tasks: [
            for (final pulled in (json['tasks']! as List<Object?>).cast<Map<String, Object?>>())
              _pulledTask(pulled),
          ],
        );
      },
    );
  }

  static (Task, List<Requirement>) _pulledTask(Map<String, Object?> json) {
    final task = TaskRemoteDataSource.taskFromJson(json['task']! as Map<String, Object?>);
    return (
      task,
      [
        for (final requirement in (json['requirements']! as List<Object?>).cast<Map<String, Object?>>())
          TaskRemoteDataSource.requirementFromJson(task.id, requirement),
      ],
    );
  }
}
