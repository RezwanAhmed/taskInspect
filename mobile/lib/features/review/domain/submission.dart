import 'package:equatable/equatable.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';

/// A photo or document the worker submitted, as the server has it.
class SubmittedFile extends Equatable {
  const SubmittedFile({
    required this.id,
    required this.requirementId,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.uploaded,
  });

  final String id;
  final String requirementId;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  /// Only uploaded files can be viewed.
  final bool uploaded;

  bool get isPhoto => contentType.startsWith('image/');

  @override
  List<Object?> get props => [id, requirementId, fileName, contentType, sizeBytes, uploaded];
}

/// What the worker submitted: answers and files by requirement ID.
class Submission extends Equatable {
  const Submission({this.answers = const {}, this.files = const {}});

  final Map<String, Answer> answers;
  final Map<String, List<SubmittedFile>> files;

  @override
  List<Object?> get props => [answers, files];
}
