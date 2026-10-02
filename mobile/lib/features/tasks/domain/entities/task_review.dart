import 'package:equatable/equatable.dart';

/// What the reviewer decided.
enum ReviewResult {
  approved('APPROVED'),
  rejected('REJECTED'),
  correctionRequested('CORRECTION_REQUESTED');

  const ReviewResult(this.apiName);

  final String apiName;

  /// `null` for a result this app version doesn't know.
  static ReviewResult? tryFromApi(String name) => values.where((result) => result.apiName == name).firstOrNull;

  static ReviewResult fromApi(String name) => tryFromApi(name)!;
}

/// A task's latest review, as the sync pull brings it: why it came back
/// to the worker, and which requirements to fix.
class TaskReview extends Equatable {
  const TaskReview({
    required this.result,
    required this.reviewerName,
    required this.createdAt,
    this.reason,
    this.markedRequirements = const {},
  });

  final ReviewResult result;
  final String reviewerName;
  final DateTime createdAt;

  /// The reason of a reject, the comment of an approval or the general
  /// note of a correction request.
  final String? reason;

  /// Requirement ID -> what to fix (correction requests only).
  final Map<String, String> markedRequirements;

  @override
  List<Object?> get props => [result, reviewerName, createdAt, reason, markedRequirements];
}
