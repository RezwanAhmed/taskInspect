import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/core/synchronization/sync_remote_data_source.dart';
import 'package:taskinspect/features/evidence/data/evidence_uploader.dart';
import 'package:taskinspect/features/evidence/data/remote/evidence_remote_data_source.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// Sends the sync queue to the server (docs/architecture.md, "Sync Cycle").
///
/// PENDING operations go out in the order they were made, in batches. An
/// applied operation is removed from the queue (the server keeps its
/// record). A rejected one becomes FAILED with the server's error code, and
/// the later operations of its task wait, so a change never overtakes one
/// it depends on. If the push itself fails for a temporary reason (no
/// connection, server error), the operations become FAILED with
/// [networkError] or [serverError]; the SyncScheduler retries those with
/// a growing delay. Nothing is ever dropped.
///
/// A sync cycle then uploads the evidence files the server now knows
/// (EvidenceUploader), and [pull] loads what changed on the server since
/// the last pull.
class SyncManager {
  SyncManager(this._db, this._remote, this._tasks, this._uploads, {this.batchSize = 100});

  static const pullCursorKey = 'pullCursor';

  /// `lastError` of operations whose push failed for a temporary reason.
  static const networkError = SyncErrors.network;
  static const serverError = SyncErrors.server;

  /// Whether a failed sync is worth retrying automatically: no connection,
  /// a server error or an expired upload URL (a new one will work). A
  /// business error would fail again.
  static bool isTemporary(Failure failure) =>
      failure is NetworkFailure ||
      (failure is ServerFailure && (failure.isServerError || failure.code == EvidenceRemoteDataSource.urlExpired));

  final AppDatabase _db;
  final SyncRemoteDataSource _remote;
  final TaskLocalDataSource _tasks;
  final EvidenceUploader _uploads;
  final int batchSize;
  Future<Result<void>>? _running;
  Future<Result<void>>? _syncing;
  final _syncingChanges = StreamController<bool>.broadcast();

  /// Whether a sync cycle is running.
  bool get isSyncing => _syncing != null;

  /// Emits `true` when a sync cycle starts and `false` when it ends.
  Stream<bool> get syncingChanges => _syncingChanges.stream;

  Future<void> dispose() => _syncingChanges.close();

  /// Sends every PENDING operation that may go now. Only one push runs at a
  /// time; calling again meanwhile returns the running one.
  Future<Result<void>> push() => _running ??= _pushAll().whenComplete(() => _running = null);

  /// A full sync cycle: push the local changes first, then upload the
  /// evidence files, then pull the server's changes. If the push fails
  /// (e.g. offline), nothing else is tried. A failed upload doesn't stop
  /// the pull, but its failure is returned (so the sync is retried). Only
  /// one cycle runs at a time.
  Future<Result<void>> sync() {
    if (_syncing case final running?) {
      return running;
    }
    _syncingChanges.add(true);
    return _syncing = _syncOnce().whenComplete(() {
      _syncing = null;
      _syncingChanges.add(false);
    });
  }

  Future<Result<void>> _syncOnce() async {
    final pushed = await push();
    if (pushed is Err<void>) {
      return pushed;
    }
    final uploaded = await _uploads.uploadAll();
    if (uploaded case Err(failure: UnauthorizedFailure())) {
      return uploaded;
    }
    if (uploaded is Ok<void>) {
      // Submits that waited for these files can go now.
      final submitted = await push();
      if (submitted is Err<void>) {
        return submitted;
      }
    }
    final pulled = await pull();
    return pulled is Err<void> ? pulled : uploaded;
  }

  /// Loads what changed on the server since the last pull (everything the
  /// first time) and stores it. The new cursor is stored in the same
  /// transaction as the changes, so a failure half-way loads them again.
  Future<Result<void>> pull() async {
    final cursor = await (_db.select(_db.localSyncState)..where((s) => s.key.equals(pullCursorKey)))
        .map((row) => row.value)
        .getSingleOrNull();
    switch (await _remote.pull(since: cursor)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        await _db.transaction(() async {
          await _tasks.applyServerChanges(value.tasks, value.taskIds, reviews: value.reviews);
          await _db
              .into(_db.localSyncState)
              .insertOnConflictUpdate(LocalSyncStateCompanion.insert(key: pullCursorKey, value: value.cursor));
        });
        return const Ok(null);
    }
  }

  /// Operations and uploads that failed for a temporary reason go back to
  /// PENDING, for the automatic retry.
  Future<void> retryTemporaryFailures() async {
    await (_db.update(_db.localSyncOperations)
          ..where((o) => o.status.equals('FAILED') & o.lastError.isIn(SyncErrors.temporary)))
        .write(const LocalSyncOperationsCompanion(status: Value('PENDING')));
    await _uploads.retryTemporaryFailures();
  }

  /// Every FAILED operation and upload goes back to PENDING: the user
  /// tapped Retry. A START refused because the task changed on the server
  /// is sent with the task's version from the last pull, so it can succeed
  /// now.
  Future<void> retryFailed() {
    return _db.transaction(() async {
      await _uploads.retryFailed();
      final failedStarts = await (_db.select(_db.localSyncOperations)
            ..where((o) => o.status.equals('FAILED') & o.operation.equals(SyncOperation.start.apiName)))
          .get();
      for (final operation in failedStarts) {
        final task = await (_db.select(_db.localTasks)..where((t) => t.id.equals(operation.taskId)))
            .getSingleOrNull();
        if (task != null) {
          await (_db.update(_db.localSyncOperations)..where((o) => o.id.equals(operation.id)))
              .write(LocalSyncOperationsCompanion(payload: Value(jsonEncode({'version': task.version}))));
        }
      }
      // A submit the server refused is not sent again as it was: the task
      // is back with the worker, who submits it again when it is complete.
      // (One that failed for a temporary reason is sent again like others.)
      await (_db.delete(_db.localSyncOperations)
            ..where((o) =>
                o.status.equals('FAILED') &
                o.operation.equals(SyncOperation.submit.apiName) &
                o.lastError.isNotIn(SyncErrors.temporary)))
          .go();
      await (_db.update(_db.localSyncOperations)..where((o) => o.status.equals('FAILED')))
          .write(const LocalSyncOperationsCompanion(status: Value('PENDING')));
    });
  }

  /// Operations left SYNCING (and uploads left UPLOADING) because the app
  /// was closed during a sync go back to PENDING. Sending them again is
  /// safe: the server doesn't apply an operation twice, and an upload is
  /// only confirmed once the whole file arrived.
  Future<void> resetInterrupted() async {
    if (_running != null || _syncing != null) {
      return;
    }
    await (_db.update(_db.localSyncOperations)..where((o) => o.status.equals('SYNCING')))
        .write(const LocalSyncOperationsCompanion(status: Value('PENDING')));
    await _uploads.resetInterrupted();
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
          await _failTemporarily(batch, failure);
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

  /// The oldest PENDING operations, except those of tasks with a FAILED
  /// one, and except a SUBMIT while files of its task are not uploaded yet
  /// (docs/architecture.md "Sync Cycle": a task is never submitted with
  /// evidence the server cannot find).
  Future<List<SyncOperationRow>> _nextBatch() {
    final queue = _db.localSyncOperations;
    // A refused submit doesn't block: the worker fixes the task and submits again.
    final blockedTasks = _db.selectOnly(queue)
      ..addColumns([queue.taskId])
      ..where(queue.status.equals('FAILED') & queue.operation.equals(SyncOperation.submit.apiName).not());
    final evidence = _db.localEvidence;
    final tasksWithFilesToUpload = _db.selectOnly(evidence)
      ..addColumns([evidence.taskId])
      ..where(evidence.uploadStatus.equals('UPLOADED').not());
    final query = _db.select(queue)
      ..where((o) =>
          o.status.equals('PENDING') &
          o.taskId.isNotInQuery(blockedTasks) &
          (o.operation.equals(SyncOperation.submit.apiName).not() | o.taskId.isNotInQuery(tasksWithFilesToUpload)))
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
            if (operation.operation == SyncOperation.submit.apiName) {
              await _reopenRefusedSubmit(operation);
            }
          case SyncResultStatus.skipped || null:
            // Waits for the operation of its task that failed.
            await _setStatus([operation.id], 'PENDING');
        }
      }
      return progressed;
    });
  }

  /// The server refused a submit (e.g. a required requirement is missing):
  /// the task is back IN_PROGRESS on the device, so the worker can fix it
  /// and submit again. The refused SUBMIT stays FAILED to show the reason,
  /// but it doesn't hold back the task's other changes, and the next
  /// submit replaces it.
  Future<void> _reopenRefusedSubmit(SyncOperationRow operation) {
    return (_db.update(_db.localTasks)
          ..where((t) => t.id.equals(operation.taskId) & t.status.equals(TaskStatus.submitted.apiName)))
        .write(LocalTasksCompanion(status: Value(TaskStatus.inProgress.apiName)));
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

  /// A temporary failure makes the batch FAILED (retried automatically);
  /// any other failure of the whole push (e.g. an expired login, task 6.9)
  /// leaves it PENDING.
  Future<void> _failTemporarily(List<SyncOperationRow> batch, Failure failure) {
    if (!isTemporary(failure)) {
      return _setStatus(batch.map((o) => o.id), 'PENDING');
    }
    return _db.transaction(() async {
      for (final operation in batch) {
        await (_db.update(_db.localSyncOperations)..where((o) => o.id.equals(operation.id))).write(
          LocalSyncOperationsCompanion(
            status: const Value('FAILED'),
            retryCount: Value(operation.retryCount + 1),
            lastError: Value(failure is NetworkFailure ? networkError : serverError),
          ),
        );
      }
    });
  }

  Future<void> _setStatus(Iterable<String> ids, String status) {
    return (_db.update(_db.localSyncOperations)..where((o) => o.id.isIn(ids)))
        .write(LocalSyncOperationsCompanion(status: Value(status)));
  }
}
