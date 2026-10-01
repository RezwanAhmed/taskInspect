import 'package:taskinspect/features/evidence/domain/evidence_item.dart';

/// Largest PDF document the server accepts (20 MB).
const maxDocumentBytes = 20 * 1024 * 1024;

/// An evidence file that cannot be used; [message] is shown to the worker.
class EvidenceRejected implements Exception {
  const EvidenceRejected(this.message);

  final String message;

  @override
  String toString() => 'EvidenceRejected: $message';
}

/// Evidence files of a task, stored on the device first.
abstract interface class EvidenceRepository {
  /// Evidence of a task by requirement ID, oldest first, updated live.
  Stream<Map<String, List<EvidenceItem>>> watchEvidence(String taskId);

  /// Compresses the photo at [sourcePath], stores the copy in the app's
  /// files and records it (waiting for upload).
  Future<EvidenceItem> addPhoto({required String taskId, required String requirementId, required String sourcePath});

  /// Stores a copy of the PDF document at [sourcePath] in the app's files
  /// and records it (waiting for upload). Throws [EvidenceRejected] when it
  /// is not a PDF or is larger than [maxDocumentBytes].
  Future<EvidenceItem> addDocument({
    required String taskId,
    required String requirementId,
    required String sourcePath,
    required String fileName,
  });

  /// Removes an evidence file from the device (record and file).
  Future<void> remove(EvidenceItem item);
}
