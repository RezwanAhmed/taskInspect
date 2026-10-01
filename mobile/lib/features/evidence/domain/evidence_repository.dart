import 'package:taskinspect/features/evidence/domain/evidence_item.dart';

/// Evidence files of a task, stored on the device first.
abstract interface class EvidenceRepository {
  /// Evidence of a task by requirement ID, oldest first, updated live.
  Stream<Map<String, List<EvidenceItem>>> watchEvidence(String taskId);

  /// Compresses the photo at [sourcePath], stores the copy in the app's
  /// files and records it (waiting for upload).
  Future<EvidenceItem> addPhoto({required String taskId, required String requirementId, required String sourcePath});

  /// Removes an evidence file from the device (record and file).
  Future<void> remove(EvidenceItem item);
}
