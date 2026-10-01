import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/review/domain/submission.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';

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

  /// Approves the submitted task (final); an optional comment for the worker.
  Future<Result<Task>> approve(String taskId, {String? comment});

  /// Sends the whole task back to the worker, with a reason.
  Future<Result<Task>> reject(String taskId, {required String reason});

  /// Loads the task from the server and stores it (e.g. it changed
  /// meanwhile and the decision was refused).
  Future<Result<Task>> refreshTask(String taskId);

  /// Sends back only the marked requirements (requirement ID -> comment).
  Future<Result<Task>> requestCorrection(String taskId, {String? reason, required Map<String, String> requirements});
}
