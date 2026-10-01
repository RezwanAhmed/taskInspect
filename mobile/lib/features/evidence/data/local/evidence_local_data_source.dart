import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/features/evidence/data/image_compressor.dart';
import 'package:taskinspect/features/evidence/domain/evidence_item.dart';
import 'package:taskinspect/features/evidence/domain/evidence_repository.dart';
import 'package:uuid/uuid.dart';

/// [EvidenceRepository] on the local database and the app's files. Files
/// live in `<documents>/evidence/<taskId>/<id>.jpg`, outside the database.
class EvidenceLocalDataSource implements EvidenceRepository {
  EvidenceLocalDataSource(
    this._db,
    this._compressor, {
    required Future<Directory> Function() documentsDirectory,
    DateTime Function()? now,
    Uuid? uuid,
  })  : _documents = documentsDirectory,
        _now = now ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final ImageCompressor _compressor;
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
    final folder = Directory(p.join((await _documents()).path, 'evidence', taskId));
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, '$id.jpg'));
    await file.writeAsBytes(bytes, flush: true);

    final item = EvidenceItem(
      id: id,
      taskId: taskId,
      requirementId: requirementId,
      localPath: file.path,
      mimeType: 'image/jpeg',
      sizeBytes: bytes.length,
      createdAt: _now().toUtc(),
    );
    try {
      await _db.into(_db.localEvidence).insert(LocalEvidenceCompanion.insert(
            id: item.id,
            taskId: item.taskId,
            requirementId: item.requirementId,
            localPath: item.localPath,
            mimeType: item.mimeType,
            sizeBytes: item.sizeBytes,
            createdAt: item.createdAt,
          ));
    } on Object {
      // Don't leave an unrecorded file behind.
      await file.delete();
      rethrow;
    }
    return item;
  }

  static EvidenceItem _toItem(EvidenceRow row) => EvidenceItem(
        id: row.id,
        taskId: row.taskId,
        requirementId: row.requirementId,
        localPath: row.localPath,
        mimeType: row.mimeType,
        sizeBytes: row.sizeBytes,
        createdAt: row.createdAt.toUtc(),
        uploaded: row.uploadStatus == 'UPLOADED',
      );
}
