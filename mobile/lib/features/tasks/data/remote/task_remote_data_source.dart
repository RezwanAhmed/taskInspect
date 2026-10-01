import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/features/tasks/domain/entities/history_entry.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// Loads tasks from the backend. The server decides which tasks the user
/// may see (a worker gets the tasks assigned to them).
class TaskRemoteDataSource {
  const TaskRemoteDataSource(this._api, {this.pageSize = 100});

  final ApiClient _api;
  final int pageSize;

  /// All visible tasks, page by page.
  Future<Result<List<Task>>> fetchTasks() async {
    final tasks = <Task>[];
    for (var page = 0;; page++) {
      final result = await _api.send(
        (dio) => dio.get<Object?>('/api/tasks', queryParameters: {'page': page, 'size': pageSize}),
        (body) => body! as Map<String, Object?>,
      );
      switch (result) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final content = value['content']! as List<Object?>;
          tasks.addAll(content.map((json) => taskFromJson(json! as Map<String, Object?>)));
          if (page + 1 >= (value['totalPages']! as int)) {
            return Ok(tasks);
          }
      }
    }
  }

  Future<Result<List<Requirement>>> fetchRequirements(String taskId) {
    return _api.send(
      (dio) => dio.get<Object?>('/api/tasks/$taskId/requirements'),
      (body) => (body! as List<Object?>)
          .map((json) => requirementFromJson(taskId, json! as Map<String, Object?>))
          .toList(),
    );
  }

  /// The task's history, oldest first (GET /api/tasks/{id}/history).
  Future<Result<List<HistoryEntry>>> fetchHistory(String taskId) {
    return _api.send(
      (dio) => dio.get<Object?>('/api/tasks/$taskId/history'),
      (body) => [
        for (final json in (body! as List<Object?>).cast<Map<String, Object?>>())
          HistoryEntry(
            event: HistoryEvent.tryFromApi(json['event']! as String),
            byName: ((json['by'] as Map<String, Object?>?)?['fullName'] as String?) ?? '',
            at: DateTime.parse(json['at']! as String).toUtc(),
            reason: json['reason'] as String?,
          ),
      ],
    );
  }

  Future<Result<Task>> start(String taskId) {
    return _api.send(
      (dio) => dio.post<Object?>('/api/tasks/$taskId/start'),
      (body) => taskFromJson(body! as Map<String, Object?>),
    );
  }

  static Task taskFromJson(Map<String, Object?> json) => Task(
        id: json['id']! as String,
        title: json['title']! as String,
        description: json['description'] as String?,
        priority: TaskPriority.fromApi(json['priority']! as String),
        status: TaskStatus.fromApi(json['status']! as String),
        dueDate: DateTime.parse(json['dueDate']! as String).toUtc(),
        createdBy: _person(json['createdBy'])!,
        reviewer: _person(json['reviewer'])!,
        assignee: _person(json['assignee']),
        version: json['version']! as int,
        updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
      );

  static Requirement requirementFromJson(String taskId, Map<String, Object?> json) => Requirement(
        id: json['id']! as String,
        taskId: taskId,
        title: json['title']! as String,
        description: json['description'] as String?,
        type: RequirementType.fromApi(json['type']! as String),
        required: json['required']! as bool,
        position: json['position']! as int,
        unit: json['unit'] as String?,
        options: [
          for (final option in (json['options'] as List<Object?>? ?? []).cast<Map<String, Object?>>())
            RequirementOption(
              id: option['id']! as String,
              label: option['label']! as String,
              position: option['position']! as int,
            ),
        ],
      );

  static PersonRef? _person(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    return PersonRef(id: json['id']! as String, name: json['fullName']! as String);
  }
}
