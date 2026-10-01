import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/review/domain/submission.dart';

/// Reviewing reads the submitted task from the server (reviewing stays
/// online, docs/architecture.md "Offline Synchronization").
abstract interface class ReviewRepository {
  /// The submitted answers and files of a task.
  Future<Result<Submission>> loadSubmission(String taskId);

  /// A short-lived URL to view an uploaded file (e.g. to show a photo).
  Future<Result<String>> fileUrl(String taskId, SubmittedFile file);

  /// Downloads a file to the device (e.g. to open a PDF); returns its path.
  Future<Result<String>> downloadFile(String taskId, SubmittedFile file);

  /// Deletes the files downloaded for a task's review.
  Future<void> clearDownloads(String taskId);
}
