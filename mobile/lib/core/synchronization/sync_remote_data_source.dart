import 'dart:convert';

import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/features/tasks/data/remote/task_remote_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_review.dart';
import 'package:taskinspect/features/tasks/domain/entities/team_task.dart';

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
  const PullResult({
    required this.cursor,
    required this.taskIds,
    required this.tasks,
    this.reviews = const {},
    this.teamTaskIds = const {},
    this.teamTasks = const [],
    this.teamVersion,
  });

  /// Sent as `since` in the next pull.
  final String cursor;

  /// Every task the user may see now; the others are removed.
  final Set<String> taskIds;

  /// The tasks that changed, with their requirements.
  final List<(Task, List<Requirement>)> tasks;

  /// The latest review of each changed task (`null`: none).
  final Map<String, TaskReview?> reviews;

  /// Every team member's task (tile) the user may see now; the others are removed.
  final Set<String> teamTaskIds;

  /// The tiles that changed.
  final List<TeamTask> teamTasks;

  /// Changes whenever the user's team changes; then everything is pulled
  /// again (`null` from a server before Phase 7A).
  final String? teamVersion;
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
          reviews: {
            for (final pulled in (json['tasks']! as List<Object?>).cast<Map<String, Object?>>())
              (pulled['task']! as Map<String, Object?>)['id']! as String:
                  _review(pulled['latestReview'] as Map<String, Object?>?),
          },
          teamTaskIds: (json['tileIds'] as List<Object?>? ?? []).cast<String>().toSet(),
          teamTasks: [
            for (final tile in (json['tiles'] as List<Object?>? ?? []).cast<Map<String, Object?>>())
              ?_teamTask(tile),
          ],
          teamVersion: json['teamVersion'] as String?,
        );
      },
    );
  }

  /// A tile, or `null` when its status or priority is one this app version
  /// doesn't know: a teammate's tile must not break the user's own pull.
  static TeamTask? _teamTask(Map<String, Object?> json) {
    final assignee = json['assignee'] as Map<String, Object?>?;
    final status = TaskStatus.values.where((s) => s.apiName == json['status']).firstOrNull;
    final priority = TaskPriority.values.where((p) => p.apiName == json['priority']).firstOrNull;
    if (status == null || priority == null) {
      return null;
    }
    return TeamTask(
      id: json['id']! as String,
      title: json['title']! as String,
      priority: priority,
      status: status,
      dueDate: DateTime.parse(json['dueDate']! as String).toUtc(),
      assignee: assignee == null
          ? null
          : PersonRef(id: assignee['id']! as String, name: assignee['fullName']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
    );
  }

  static TaskReview? _review(Map<String, Object?>? json) {
    final result = json == null ? null : ReviewResult.tryFromApi(json['result']! as String);
    if (json == null || result == null) {
      // None, or one this app version doesn't know: nothing to show.
      return null;
    }
    return TaskReview(
      result: result,
      reason: json['reason'] as String?,
      reviewerName: ((json['reviewer'] as Map<String, Object?>?)?['fullName'] as String?) ?? '',
      createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
      markedRequirements: {
        for (final item in (json['requirements'] as List<Object?>? ?? []).cast<Map<String, Object?>>())
          item['requirementId']! as String: item['comment']! as String,
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
