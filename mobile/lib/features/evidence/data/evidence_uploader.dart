import 'dart:io';

import 'package:drift/drift.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/features/evidence/data/remote/evidence_remote_data_source.dart';

/// The upload queue of evidence files (task 6.12; docs/architecture.md,
/// "Sync Cycle"). A file is uploaded once the server knows it, i.e. once
/// its Evidence CREATE has left the sync queue (applied). Uploads use the
/// same statuses and retries as the sync queue: a temporary failure (no
/// connection, server error) is retried automatically, any other one waits
/// for the Retry button. The file stays on the device either way.
class EvidenceUploader {
  EvidenceUploader(this._db, this._remote);

  static const fileMissing = 'FILE_MISSING';
  static const _alreadyUploaded = 'EVIDENCE_ALREADY_UPLOADED';

  /// `uploadError`s retried automatically.
  static const temporaryErrors = [...SyncErrors.temporary, EvidenceRemoteDataSource.urlExpired];

  final AppDatabase _db;
  final EvidenceRemoteDataSource _remote;

  /// Uploads every file that may go now, oldest first. Returns the first
  /// temporary failure (so the sync is retried), or an expired login.
  Future<Result<void>> uploadAll() async {
    Failure? temporary;
    for (final evidence in await _ready()) {
      switch (await _upload(evidence)) {
        case Err(failure: final UnauthorizedFailure failure):
          // Sign in again first; the file stays PENDING.
          return Err(failure);
        case Err(failure: NetworkFailure() && final failure):
          // Offline: the other files would fail the same way.
          return Err(failure);
        case Err(:final failure) when _isTemporary(failure):
          temporary ??= failure;
        case _:
      }
    }
    return temporary == null ? const Ok(null) : Err(temporary);
  }

  /// Uploads left UPLOADING because the app was closed go back to PENDING.
  Future<void> resetInterrupted() => _setStatus(_db.localEvidence.uploadStatus.equals('UPLOADING'), 'PENDING');

  /// Temporarily failed uploads go back to PENDING (automatic retry).
  Future<void> retryTemporaryFailures() => _setStatus(
        _db.localEvidence.uploadStatus.equals('FAILED') & _db.localEvidence.uploadError.isIn(temporaryErrors),
        'PENDING',
      );

  /// Every failed upload goes back to PENDING: the user tapped Retry.
  Future<void> retryFailed() => _setStatus(_db.localEvidence.uploadStatus.equals('FAILED'), 'PENDING');

  /// PENDING files whose registration was applied (no CREATE left in the queue).
  Future<List<EvidenceRow>> _ready() {
    final queue = _db.localSyncOperations;
    final unregistered = _db.selectOnly(queue)
      ..addColumns([queue.entityId])
      ..where(queue.entityType.equals(SyncEntity.evidence.apiName) & queue.operation.equals(SyncOperation.create.apiName));
    final query = _db.select(_db.localEvidence)
      ..where((e) => e.uploadStatus.equals('PENDING') & e.id.isNotInQuery(unregistered))
      ..orderBy([(e) => OrderingTerm(expression: e.createdAt)]);
    return query.get();
  }

  Future<Result<void>> _upload(EvidenceRow evidence) async {
    await _write(evidence.id, const LocalEvidenceCompanion(uploadStatus: Value('UPLOADING')));
    final file = File(evidence.localPath);
    if (!file.existsSync()) {
      await _write(evidence.id, LocalEvidenceCompanion(
        uploadStatus: const Value('FAILED'),
        uploadRetryCount: Value(evidence.uploadRetryCount + 1),
        uploadError: const Value(fileMissing),
      ));
      return const Ok(null);
    }
    final result = await _send(evidence, file);
    switch (result) {
      case Ok():
        await _write(evidence.id, const LocalEvidenceCompanion(uploadStatus: Value('UPLOADED'), uploadError: Value(null)));
      case Err(failure: UnauthorizedFailure()):
        await _write(evidence.id, const LocalEvidenceCompanion(uploadStatus: Value('PENDING')));
      case Err(:final failure):
        await _write(evidence.id, LocalEvidenceCompanion(
          uploadStatus: const Value('FAILED'),
          uploadRetryCount: Value(evidence.uploadRetryCount + 1),
          uploadError: Value(_errorCode(failure)),
        ));
    }
    return result;
  }

  /// Upload URL, file, complete. A file the server already has (an earlier
  /// upload whose answer was lost) only needs `complete`.
  Future<Result<void>> _send(EvidenceRow evidence, File file) async {
    final ids = (taskId: evidence.taskId, evidenceId: evidence.id);
    switch (await _remote.uploadUrl(taskId: ids.taskId, evidenceId: ids.evidenceId)) {
      case Err(failure: ServerFailure(code: _alreadyUploaded)):
        break;
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (await _remote.uploadFile(value, file) case Err(:final failure)) {
          return Err(failure);
        }
    }
    return _remote.complete(taskId: ids.taskId, evidenceId: ids.evidenceId);
  }

  static bool _isTemporary(Failure failure) => temporaryErrors.contains(_errorCode(failure));

  static String _errorCode(Failure failure) => switch (failure) {
        NetworkFailure() => SyncErrors.network,
        ServerFailure(isServerError: true) => SyncErrors.server,
        ServerFailure(:final code) => code ?? 'REJECTED',
        UnexpectedFailure(error: FileSystemException()) => fileMissing,
        _ => 'REJECTED',
      };

  Future<void> _write(String id, LocalEvidenceCompanion values) {
    return (_db.update(_db.localEvidence)..where((e) => e.id.equals(id))).write(values);
  }

  Future<void> _setStatus(Expression<bool> where, String status) {
    return (_db.update(_db.localEvidence)..where((_) => where)).write(LocalEvidenceCompanion(uploadStatus: Value(status)));
  }
}
