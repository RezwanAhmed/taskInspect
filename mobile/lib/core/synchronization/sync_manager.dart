import 'package:drift/drift.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/core/synchronization/sync_remote_data_source.dart';

/// Sends the sync queue to the server (docs/architecture.md, "Sync Cycle").
///
/// PENDING operations go out in the order they were made, in batches. An
/// applied operation is removed from the queue (the server keeps its
/// record). A rejected one becomes FAILED with the server's error code, and
/// the later operations of its task wait, so a change never overtakes one
/// it depends on. If the push itself fails (e.g. no connection), the
/// operations stay PENDING for the next try.
class SyncManager {
  SyncManager(this._db, this._remote, {this.batchSize = 100});

  final AppDatabase _db;
  final SyncRemoteDataSource _remote;
  final int batchSize;
  Future<Result<void>>? _running;

  /// Sends every PENDING operation that may go now. Only one push runs at a
  /// time; calling again meanwhile returns the running one.
  Future<Result<void>> push() => _running ??= _pushAll().whenComplete(() => _running = null);

  /// Operations left SYNCING because the app was closed during a push go
  /// back to PENDING. Sending them again is safe: the server doesn't apply
  /// an operation twice.
  Future<void> resetInterrupted() async {
    if (_running != null) {
      return;
    }
    await (_db.update(_db.localSyncOperations)..where((o) => o.status.equals('SYNCING')))
        .write(const LocalSyncOperationsCompanion(status: Value('PENDING')));
  }

  /// When the newest queued change was made; emits again whenever a change
  /// is queued (or the queue is emptied), but not when only statuses change.
  Stream<DateTime?> watchLatestChange() {
    final latest = _db.localSyncOperations.createdAt.max();
    final query = _db.selectOnly(_db.localSyncOperations)..addColumns([latest]);
    return query.map((row) => row.read(latest)).watchSingle().distinct();
  }

  Future<Result<void>> _pushAll() async {
    while (true) {
      final batch = await _nextBatch();
      if (batch.isEmpty) {
        return const Ok(null);
      }
      await _setStatus(batch.map((o) => o.id), 'SYNCING');
      switch (await _remote.push(batch)) {
        case Err(:final failure):
          await _setStatus(batch.map((o) => o.id), 'PENDING');
          return Err(failure);
        case Ok(:final value):
          final progressed = await _apply(batch, value);
          if (!progressed) {
            // Nothing was applied or rejected; trying again now would loop.
            return const Ok(null);
          }
      }
    }
  }

  /// The oldest PENDING operations, except those of tasks with a FAILED one.
  Future<List<SyncOperationRow>> _nextBatch() {
    final queue = _db.localSyncOperations;
    final blockedTasks = _db.selectOnly(queue)
      ..addColumns([queue.taskId])
      ..where(queue.status.equals('FAILED'));
    final query = _db.select(queue)
      ..where((o) => o.status.equals('PENDING') & o.taskId.isNotInQuery(blockedTasks))
      ..orderBy([(o) => OrderingTerm(expression: o.createdAt)])
      ..limit(batchSize);
    return query.get();
  }

  /// Stores the server's results; returns whether any operation was applied
  /// or rejected.
  Future<bool> _apply(List<SyncOperationRow> batch, List<SyncResult> results) {
    final byId = {for (final result in results) result.id: result};
    return _db.transaction(() async {
      var progressed = false;
      for (final operation in batch) {
        final result = byId[operation.id];
        switch (result?.status) {
          case SyncResultStatus.applied:
            progressed = true;
            await (_db.delete(_db.localSyncOperations)..where((o) => o.id.equals(operation.id))).go();
            await _markEntitySynced(operation);
          case SyncResultStatus.rejected:
            progressed = true;
            await (_db.update(_db.localSyncOperations)..where((o) => o.id.equals(operation.id))).write(
              LocalSyncOperationsCompanion(
                status: const Value('FAILED'),
                retryCount: Value(operation.retryCount + 1),
                lastError: Value(result!.code ?? 'REJECTED'),
              ),
            );
          case SyncResultStatus.skipped || null:
            // Waits for the operation of its task that failed.
            await _setStatus([operation.id], 'PENDING');
        }
      }
      return progressed;
    });
  }

  /// An answer counts as synced once no change of it is left in the queue.
  Future<void> _markEntitySynced(SyncOperationRow operation) async {
    if (operation.entityType != SyncEntity.taskResponse.apiName) {
      return;
    }
    final queue = _db.localSyncOperations;
    final unsent = await (_db.select(queue)
          ..where((o) => o.entityType.equals(operation.entityType) & o.entityId.equals(operation.entityId)))
        .get();
    if (unsent.isEmpty) {
      await (_db.update(_db.localResponses)..where((r) => r.requirementId.equals(operation.entityId)))
          .write(const LocalResponsesCompanion(syncStatus: Value('SYNCED')));
    }
  }

  Future<void> _setStatus(Iterable<String> ids, String status) {
    return (_db.update(_db.localSyncOperations)..where((o) => o.id.isIn(ids)))
        .write(LocalSyncOperationsCompanion(status: Value(status)));
  }
}
