import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/review/domain/review_repository.dart';
import 'package:taskinspect/features/review/domain/submission.dart';
import 'package:taskinspect/features/tasks/data/remote/task_remote_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';

/// [ReviewRepository] on the API: GET .../responses, .../evidence and
/// .../evidence/{id}/download-url. Files are downloaded from the signed
/// URL without the login (the signature is the permission).
class ReviewRemoteDataSource implements ReviewRepository {
  ReviewRemoteDataSource(this._api, {required this._temporaryDirectory, required this._storeTask, Dio? files})
      : _files = files ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  final ApiClient _api;

  /// Saves the task the server returns after a decision on the device, so
  /// the screens show its new status at once.
  final Future<void> Function(Task task) _storeTask;
  final Future<Directory> Function() _temporaryDirectory;
  final Dio _files;

  @override
  Future<Result<Submission>> loadSubmission(String taskId) async {
    final responses = await _api.send(
      (dio) => dio.get<Object?>('/api/tasks/$taskId/responses'),
      (body) => {
        for (final json in (body! as List<Object?>).cast<Map<String, Object?>>())
          json['requirementId']! as String: Answer(
            booleanValue: json['booleanValue'] as bool?,
            textValue: json['textValue'] as String?,
            numberValue: json['numberValue'] as num?,
            selectedOptionIds: (json['selectedOptionIds'] as List<Object?>? ?? []).cast<String>(),
            comment: json['comment'] as String?,
          ),
      },
    );
    if (responses case Err(:final failure)) {
      return Err(failure);
    }
    final evidence = await _api.send(
      (dio) => dio.get<Object?>('/api/tasks/$taskId/evidence'),
      (body) {
        final files = <String, List<SubmittedFile>>{};
        for (final json in (body! as List<Object?>).cast<Map<String, Object?>>()) {
          final file = SubmittedFile(
            id: json['id']! as String,
            requirementId: json['requirementId']! as String,
            fileName: json['fileName']! as String,
            contentType: json['contentType']! as String,
            sizeBytes: json['sizeBytes']! as int,
            uploaded: json['status'] == 'UPLOADED',
          );
          (files[file.requirementId] ??= []).add(file);
        }
        return files;
      },
    );
    final answers = (responses as Ok<Map<String, Answer>>).value;
    return switch (evidence) {
      Ok(value: final files) => Ok(Submission(answers: answers, files: files)),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<String>> fileUrl(String taskId, SubmittedFile file) {
    return _api.send(
      (dio) => dio.get<Object?>('/api/tasks/$taskId/evidence/${file.id}/download-url'),
      (body) => (body! as Map<String, Object?>)['url']! as String,
    );
  }

  @override
  Future<Result<String>> downloadFile(String taskId, SubmittedFile file) async {
    switch (await fileUrl(taskId, file)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final url):
        final path = p.join((await _folder(taskId)).path, '${file.id}${p.extension(file.fileName)}');
        try {
          await Directory(p.dirname(path)).create(recursive: true);
          await _files.download(url, path);
          return Ok(path);
        } on DioException catch (e) {
          await _deletePartial(path);
          return Err(mapDioException(e));
        } on FileSystemException catch (e) {
          await _deletePartial(path);
          return Err(UnexpectedFailure(e));
        }
    }
  }

  @override
  Future<void> clearDownloads(String taskId) async {
    final folder = await _folder(taskId);
    if (folder.existsSync()) {
      await folder.delete(recursive: true);
    }
  }

  @override
  Future<Result<Task>> approve(String taskId, {String? comment}) =>
      _decide(taskId, 'approve', {if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim()});

  @override
  Future<Result<Task>> reject(String taskId, {required String reason}) =>
      _decide(taskId, 'reject', {'reason': reason.trim()});

  @override
  Future<Result<Task>> requestCorrection(String taskId, {String? reason, required Map<String, String> requirements}) {
    return _decide(taskId, 'request-correction', {
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      'requirements': [
        for (final MapEntry(:key, :value) in requirements.entries) {'requirementId': key, 'comment': value.trim()},
      ],
    });
  }

  Future<Result<Task>> _decide(String taskId, String action, Map<String, Object?> body) async {
    final result = await _api.send(
      (dio) => dio.post<Object?>('/api/tasks/$taskId/$action', data: body),
      (json) => TaskRemoteDataSource.taskFromJson(json! as Map<String, Object?>),
    );
    if (result case Ok(value: final task)) {
      await _store(task);
    }
    return result;
  }

  @override
  Future<Result<Task>> refreshTask(String taskId) async {
    final result = await _api.send(
      (dio) => dio.get<Object?>('/api/tasks/$taskId'),
      (json) => TaskRemoteDataSource.taskFromJson(json! as Map<String, Object?>),
    );
    if (result case Ok(value: final task)) {
      await _store(task);
    }
    return result;
  }

  /// The server has the decision either way; the next sync pull stores the
  /// task if this fails.
  Future<void> _store(Task task) async {
    try {
      await _storeTask(task);
    } on Object {
      // Ignored on purpose (see above).
    }
  }

  Future<Directory> _folder(String taskId) async => Directory(p.join((await _temporaryDirectory()).path, 'review', taskId));

  static Future<void> _deletePartial(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
