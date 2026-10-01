import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/failure_messages.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/evidence/domain/document_opener.dart';
import 'package:taskinspect/features/review/domain/review_repository.dart';
import 'package:taskinspect/features/review/domain/submission.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';

class ReviewState extends Equatable {
  const ReviewState({
    this.task,
    this.requirements = const [],
    this.submission,
    this.isLoading = true,
    this.error,
    this.canRetry = false,
    this.opening = const {},
    this.isDeciding = false,
    this.decided,
    this.message,
  });

  final Task? task;
  final List<Requirement> requirements;

  /// `null` until loaded from the server.
  final Submission? submission;
  final bool isLoading;

  /// Why the submission could not be loaded (e.g. offline).
  final String? error;

  /// Whether trying again can help (a connection problem).
  final bool canRetry;

  /// Files being downloaded to be opened.
  final Set<String> opening;

  /// An approve, reject or correction request is being sent.
  final bool isDeciding;

  /// The task after the reviewer's decision (then the screen closes).
  final Task? decided;

  /// Shown once, e.g. a document that could not be opened.
  final String? message;

  ReviewState copyWith({
    Task? task,
    List<Requirement>? requirements,
    Submission? submission,
    bool? isLoading,
    String? Function()? error,
    bool? canRetry,
    Set<String>? opening,
    bool? isDeciding,
    Task? decided,
    String? Function()? message,
  }) {
    return ReviewState(
      task: task ?? this.task,
      requirements: requirements ?? this.requirements,
      submission: submission ?? this.submission,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      canRetry: canRetry ?? this.canRetry,
      opening: opening ?? this.opening,
      isDeciding: isDeciding ?? this.isDeciding,
      decided: decided ?? this.decided,
      message: message != null ? message() : this.message,
    );
  }

  @override
  List<Object?> get props =>
      [task, requirements, submission, isLoading, error, canRetry, opening, isDeciding, decided, message];
}

/// The reviewer's view of a submitted task: the task and its requirements
/// from the device, the submitted answers and files from the server.
class ReviewCubit extends Cubit<ReviewState> {
  ReviewCubit(WatchTaskDetails watch, this._repository, this._opener, this.taskId, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(const ReviewState()) {
    _task = watch.task(taskId).listen((task) => emit(state.copyWith(task: task)));
    _requirements = watch.requirements(taskId).listen((r) => emit(state.copyWith(requirements: r)));
    unawaited(load());
  }

  final ReviewRepository _repository;
  final DocumentOpener _opener;
  final String taskId;
  late final StreamSubscription<Task?> _task;
  late final StreamSubscription<List<Requirement>> _requirements;
  final DateTime Function() _now;

  /// Photo URLs with the time they were asked for; a signed URL works for
  /// 10 minutes.
  final Map<String, (DateTime, Future<Result<String>>)> _photoUrls = {};
  static const _urlLifetime = Duration(minutes: 9);

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, error: () => null));
    final result = await _repository.loadSubmission(taskId);
    if (isClosed) {
      return;
    }
    emit(switch (result) {
      Ok(:final value) => state.copyWith(submission: value, isLoading: false),
      Err(failure: NetworkFailure()) => state.copyWith(
          isLoading: false, canRetry: true, error: () => 'Reviewing needs an internet connection.'),
      Err(:final failure) => state.copyWith(isLoading: false, canRetry: false, error: () => userMessage(failure)),
    });
  }

  /// The URL to show a photo. Asked again when it is about to expire or
  /// failed (e.g. offline).
  Future<Result<String>> photoUrl(SubmittedFile file) {
    final cached = _photoUrls[file.id];
    if (cached != null && _now().difference(cached.$1) < _urlLifetime) {
      return cached.$2;
    }
    final url = _repository.fileUrl(taskId, file).then((result) {
      if (result is Err<String>) {
        forgetPhotoUrl(file);
      }
      return result;
    });
    _photoUrls[file.id] = (_now(), url);
    return url;
  }

  /// The photo could not be shown with its URL (e.g. it expired): ask again next time.
  void forgetPhotoUrl(SubmittedFile file) => _photoUrls.remove(file.id);

  /// Downloads a document and shows it in the device's PDF viewer.
  Future<void> openFile(SubmittedFile file) async {
    if (state.opening.contains(file.id)) {
      return;
    }
    emit(state.copyWith(opening: {...state.opening, file.id}));
    final downloaded = await _repository.downloadFile(taskId, file);
    if (isClosed) {
      return;
    }
    emit(state.copyWith(opening: {...state.opening}..remove(file.id)));
    switch (downloaded) {
      case Err(:final failure):
        emit(state.copyWith(message: () => userMessage(failure)));
      case Ok(value: final path):
        if (!await _opener.open(path, mimeType: file.contentType) && !isClosed) {
          emit(state.copyWith(message: () => 'No app on this device can open this document.'));
        }
    }
  }

  Future<void> approve({String? comment}) => _decide(() => _repository.approve(taskId, comment: comment));

  Future<void> reject(String reason) => _decide(() => _repository.reject(taskId, reason: reason));

  Future<void> requestCorrection(Map<String, String> requirements, {String? reason}) =>
      _decide(() => _repository.requestCorrection(taskId, reason: reason, requirements: requirements));

  /// Reviewing needs the server; on failure the reviewer sees why and can try again.
  Future<void> _decide(Future<Result<Task>> Function() action) async {
    if (state.isDeciding) {
      return;
    }
    emit(state.copyWith(isDeciding: true, message: () => null));
    final result = await action();
    if (isClosed) {
      return;
    }
    if (result case Err(failure: ServerFailure(statusCode: 409))) {
      // The task changed meanwhile (e.g. reviewed already): show its real status.
      await _repository.refreshTask(taskId);
      if (isClosed) {
        return;
      }
    }
    emit(switch (result) {
      Ok(:final value) => state.copyWith(isDeciding: false, decided: value),
      Err(failure: NetworkFailure()) =>
        state.copyWith(isDeciding: false, message: () => 'No connection. Your decision was not sent; try again.'),
      Err(:final failure) => state.copyWith(isDeciding: false, message: () => userMessage(failure)),
    });
  }

  void clearMessage() => emit(state.copyWith(message: () => null));

  @override
  Future<void> close() async {
    // Downloaded documents are only needed while the review is open.
    unawaited(_repository.clearDownloads(taskId));
    await _task.cancel();
    await _requirements.cancel();
    return super.close();
  }
}
