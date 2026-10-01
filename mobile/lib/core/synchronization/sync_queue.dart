import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:uuid/uuid.dart';

/// What a queued change is about.
enum SyncEntity {
  task('Task'),
  taskResponse('TaskResponse'),
  evidence('Evidence');

  const SyncEntity(this.apiName);

  final String apiName;
}

/// What a queued change does.
enum SyncOperation {
  create('CREATE'),
  update('UPDATE'),
  delete('DELETE'),
  start('START'),
  submit('SUBMIT');

  const SyncOperation(this.apiName);

  final String apiName;
}

/// Adds local changes to the sync queue ([LocalSyncOperations]).
///
/// Call [add] inside the same transaction that saves the change, so the
/// change and its queue entry are stored together or not at all.
class SyncQueue {
  SyncQueue(this._db, {DateTime Function()? now, Uuid? uuid})
      : _now = now ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _now;
  final Uuid _uuid;

  /// Queues a change. An UPDATE replaces a still PENDING update of the same
  /// record: the payload always holds the whole new state, so only the
  /// latest one has to be sent (and typing doesn't fill the queue). It
  /// moves to the end of the queue, after the changes made in between.
  Future<void> add({
    required SyncEntity entity,
    required String entityId,
    required String taskId,
    required SyncOperation operation,
    Map<String, Object?> payload = const {},
  }) async {
    if (operation == SyncOperation.update) {
      await removePending(entity: entity, entityId: entityId, operation: operation);
    }
    await _db.into(_db.localSyncOperations).insert(LocalSyncOperationsCompanion.insert(
          id: _uuid.v4(),
          entityType: entity.apiName,
          entityId: entityId,
          taskId: taskId,
          operation: operation.apiName,
          payload: Value(jsonEncode(payload)),
          createdAt: _now().toUtc(),
        ));
  }

  /// Removes a still PENDING [operation] of a record, e.g. the CREATE of
  /// evidence that is removed again before it was sent. Returns whether
  /// there was one.
  Future<bool> removePending({
    required SyncEntity entity,
    required String entityId,
    required SyncOperation operation,
  }) async {
    final removed = await (_db.delete(_db.localSyncOperations)
          ..where((o) =>
              o.entityType.equals(entity.apiName) &
              o.entityId.equals(entityId) &
              o.operation.equals(operation.apiName) &
              o.status.equals('PENDING')))
        .go();
    return removed > 0;
  }
}
