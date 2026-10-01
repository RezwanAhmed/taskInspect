import 'package:taskinspect/features/requirements/domain/entities/answer.dart';

/// The worker's answers, stored on the device first (ADR-0004).
abstract interface class AnswerRepository {
  /// The saved answers of a task by requirement ID, updated live.
  Stream<Map<String, Answer>> watchAnswers(String taskId);

  /// Saves an answer on the device, marked to be sent to the server.
  Future<void> saveAnswer({required String taskId, required String requirementId, required Answer answer});
}
