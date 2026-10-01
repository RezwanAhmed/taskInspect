import 'package:equatable/equatable.dart';

/// An evidence file stored on the device for a requirement.
class EvidenceItem extends Equatable {
  const EvidenceItem({
    required this.id,
    required this.taskId,
    required this.requirementId,
    required this.localPath,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    this.uploaded = false,
  });

  /// Created on the device, so it stays the same when uploaded.
  final String id;
  final String taskId;
  final String requirementId;
  final String localPath;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  /// Whether the file reached the server (Phase 6 / 8).
  final bool uploaded;

  @override
  List<Object?> get props => [id, taskId, requirementId, localPath, mimeType, sizeBytes, createdAt, uploaded];
}
