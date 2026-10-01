import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/requirements/domain/repositories/answer_repository.dart';

/// [AnswerRepository] on the local database. Every save is marked PENDING
/// and queued in the sync queue, which sends it to the server.
class AnswerLocalDataSource implements AnswerRepository {
  AnswerLocalDataSource(this._db, this._queue, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final SyncQueue _queue;
  final DateTime Function() _now;

  @override
  Stream<Map<String, Answer>> watchAnswers(String taskId) {
    final query = _db.select(_db.localResponses)..where((r) => r.taskId.equals(taskId));
    return query.watch().map((rows) => {for (final row in rows) row.requirementId: _toAnswer(row)});
  }

  @override
  Future<void> saveAnswer({required String taskId, required String requirementId, required Answer answer}) {
    return _db.transaction(() async {
      await _db.into(_db.localResponses).insertOnConflictUpdate(LocalResponsesCompanion.insert(
            requirementId: requirementId,
            taskId: taskId,
            booleanValue: Value(answer.booleanValue),
            textValue: Value(answer.textValue),
            numberValue: Value(answer.numberValue?.toDouble()),
            selectedOptionIds: Value(jsonEncode(answer.selectedOptionIds)),
            comment: Value(answer.comment),
            updatedAt: _now().toUtc(),
            syncStatus: const Value('PENDING'),
          ));
      // The body of PUT /api/tasks/{taskId}/requirements/{requirementId}/response.
      await _queue.add(
        entity: SyncEntity.taskResponse,
        entityId: requirementId,
        taskId: taskId,
        operation: SyncOperation.update,
        payload: {
          'booleanValue': answer.booleanValue,
          'textValue': answer.textValue,
          'numberValue': answer.numberValue,
          'selectedOptionIds': answer.selectedOptionIds,
          'comment': answer.comment,
        },
      );
    });
  }

  /// Answers waiting to be sent, for the sync queue and tests.
  Future<List<String>> pendingRequirementIds(String taskId) {
    final query = _db.select(_db.localResponses)
      ..where((r) => r.taskId.equals(taskId) & r.syncStatus.equals('PENDING'));
    return query.map((row) => row.requirementId).get();
  }

  static Answer _toAnswer(ResponseRow row) {
    final number = row.numberValue;
    return Answer(
      booleanValue: row.booleanValue,
      textValue: row.textValue,
      // Whole numbers come back as int, e.g. 4 instead of 4.0.
      numberValue: number == null ? null : (number == number.roundToDouble() ? number.toInt() : number),
      selectedOptionIds: (jsonDecode(row.selectedOptionIds) as List<Object?>).cast<String>(),
      comment: row.comment,
    );
  }
}
