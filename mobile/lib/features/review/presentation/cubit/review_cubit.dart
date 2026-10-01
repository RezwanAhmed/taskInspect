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
      message: message != null ? message() : this.message,
    );
  }

  @override
  List<Object?> get props => [task, requirements, submission, isLoading, error, canRetry, opening, message];
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
