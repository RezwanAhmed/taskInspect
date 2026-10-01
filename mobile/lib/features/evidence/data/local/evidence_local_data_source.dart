import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/features/evidence/data/evidence_uploader.dart';
import 'package:taskinspect/features/evidence/data/image_compressor.dart';
import 'package:taskinspect/features/evidence/domain/evidence_item.dart';
import 'package:taskinspect/features/evidence/domain/evidence_repository.dart';
import 'package:uuid/uuid.dart';

/// [EvidenceRepository] on the local database and the app's files. Files
/// live in `<documents>/evidence/<taskId>/<id>.jpg` (or `.pdf`), outside the
/// database. Every added or removed file is queued in the sync queue.
class EvidenceLocalDataSource implements EvidenceRepository {
  EvidenceLocalDataSource(
    this._db,
    this._compressor,
    this._queue, {
    required Future<Directory> Function() documentsDirectory,
    DateTime Function()? now,
    Uuid? uuid,
  })  : _documents = documentsDirectory,
        _now = now ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final ImageCompressor _compressor;
  final SyncQueue _queue;
  final Future<Directory> Function() _documents;
  final DateTime Function() _now;
  final Uuid _uuid;

  @override
  Stream<Map<String, List<EvidenceItem>>> watchEvidence(String taskId) {
    final query = _db.select(_db.localEvidence)
      ..where((e) => e.taskId.equals(taskId))
      ..orderBy([(e) => OrderingTerm(expression: e.createdAt)]);
    return query.watch().map((rows) {
      final byRequirement = <String, List<EvidenceItem>>{};
      for (final row in rows) {
        (byRequirement[row.requirementId] ??= []).add(_toItem(row));
      }
      return byRequirement;
    });
  }

  @override
  Future<EvidenceItem> addPhoto({
    required String taskId,
    required String requirementId,
    required String sourcePath,
  }) async {
    final id = _uuid.v4();
    final bytes = await _compressor.compressToJpeg(sourcePath);
    final file = await _newFile(taskId, '$id.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return _record(EvidenceItem(
      id: id,
      taskId: taskId,
      requirementId: requirementId,
      localPath: file.path,
      mimeType: 'image/jpeg',
      sizeBytes: bytes.length,
      createdAt: _now().toUtc(),
    ));
  }

  @override
  Future<EvidenceItem> addDocument({
    required String taskId,
    required String requirementId,
    required String sourcePath,
    required String fileName,
  }) async {
    final source = File(sourcePath);
    final size = await source.length();
    if (size > maxDocumentBytes) {
      throw const EvidenceRejected('The PDF is larger than 20 MB.');
    }
    if (size == 0 || !await _startsWithPdfHeader(source)) {
      throw const EvidenceRejected('This file is not a PDF document.');
    }
    final id = _uuid.v4();
    final file = await source.copy((await _newFile(taskId, '$id.pdf')).path);
    return _record(EvidenceItem(
      id: id,
      taskId: taskId,
      requirementId: requirementId,
      localPath: file.path,
      mimeType: 'application/pdf',
      sizeBytes: size,
      createdAt: _now().toUtc(),
      fileName: fileName,
    ));
  }

  Future<File> _newFile(String taskId, String name) async {
    final folder = Directory(p.join((await _documents()).path, 'evidence', taskId));
    await folder.create(recursive: true);
    return File(p.join(folder.path, name));
  }

  /// Every PDF file starts with `%PDF-`.
  static Future<bool> _startsWithPdfHeader(File file) async {
    final header = await file.openRead(0, 5).expand((chunk) => chunk).toList();
    return String.fromCharCodes(header) == '%PDF-';
  }

  /// Records [item] and queues it for the server; its file is deleted
  /// again if that fails.
  Future<EvidenceItem> _record(EvidenceItem item) async {
    try {
      await _db.transaction(() async {
        await _db.into(_db.localEvidence).insert(LocalEvidenceCompanion.insert(
              id: item.id,
              taskId: item.taskId,
              requirementId: item.requirementId,
              localPath: item.localPath,
              mimeType: item.mimeType,
              sizeBytes: item.sizeBytes,
              createdAt: item.createdAt,
              fileName: Value(item.fileName),
            ));
        // The body of POST /api/tasks/{taskId}/requirements/{requirementId}/evidence.
        await _queue.add(
          entity: SyncEntity.evidence,
          entityId: item.id,
          taskId: item.taskId,
          operation: SyncOperation.create,
          payload: {
            'requirementId': item.requirementId,
            'id': item.id,
            'fileName': item.fileName ?? p.basename(item.localPath),
            'contentType': item.mimeType,
            'sizeBytes': item.sizeBytes,
          },
        );
      });
    } on Object {
      // Don't leave an unrecorded file behind.
      await File(item.localPath).delete();
      rethrow;
    }
    return item;
  }

  @override
  Future<void> remove(EvidenceItem item) async {
    await _db.transaction(() async {
      await (_db.delete(_db.localEvidence)..where((e) => e.id.equals(item.id))).go();
      // Not sent yet: the server never has to hear about it.
      final neverSent = await _queue.removePending(
        entity: SyncEntity.evidence,
        entityId: item.id,
        operation: SyncOperation.create,
      );
      if (!neverSent) {
        await _queue.add(
          entity: SyncEntity.evidence,
          entityId: item.id,
          taskId: item.taskId,
          operation: SyncOperation.delete,
        );
      }
    });
    final file = File(item.localPath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Deletes every evidence file of every task (sign out).
  Future<void> deleteAllFiles() async {
    final folder = Directory(p.join((await _documents()).path, 'evidence'));
    if (folder.existsSync()) {
      await folder.delete(recursive: true);
    }
  }

  static EvidenceItem _toItem(EvidenceRow row) => EvidenceItem(
        id: row.id,
        taskId: row.taskId,
        requirementId: row.requirementId,
        localPath: row.localPath,
        mimeType: row.mimeType,
        sizeBytes: row.sizeBytes,
        createdAt: row.createdAt.toUtc(),
        fileName: row.fileName,
        uploaded: row.uploadStatus == 'UPLOADED',
        fileMissing: row.uploadStatus == 'FAILED' && row.uploadError == EvidenceUploader.fileMissing,
      );
}
