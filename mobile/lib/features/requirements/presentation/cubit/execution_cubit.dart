import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/features/evidence/domain/evidence_item.dart';
import 'package:taskinspect/features/evidence/domain/evidence_picker.dart';
import 'package:taskinspect/features/evidence/domain/evidence_repository.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/requirements/domain/repositories/answer_repository.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';

class ExecutionState extends Equatable {
  const ExecutionState({
    this.task,
    this.requirements = const [],
    this.answers = const {},
    this.photos = const {},
    this.photoError,
    this.index = 0,
    this.isLoading = true,
  });

  final Task? task;
  final List<Requirement> requirements;

  /// Answers by requirement ID.
  final Map<String, Answer> answers;

  /// Evidence stored on the device, by requirement ID.
  final Map<String, List<EvidenceItem>> photos;

  /// Set when a photo could not be stored.
  final String? photoError;

  /// The requirement on screen.
  final int index;
  final bool isLoading;

  Requirement? get current => requirements.isEmpty ? null : requirements[index];

  bool get isFirst => index == 0;

  bool get isLast => index >= requirements.length - 1;

  Answer answerFor(Requirement requirement) => answers[requirement.id] ?? const Answer();

  List<EvidenceItem> photosFor(Requirement requirement) => photos[requirement.id] ?? const [];

  bool isComplete(Requirement requirement) => requirement.type == RequirementType.photo
      ? photosFor(requirement).isNotEmpty
      : answerFor(requirement).completes(requirement);

  int get completedCount => requirements.where(isComplete).length;

  ExecutionState copyWith({
    Task? task,
    List<Requirement>? requirements,
    Map<String, Answer>? answers,
    Map<String, List<EvidenceItem>>? photos,
    String? Function()? photoError,
    int? index,
    bool? isLoading,
  }) {
    return ExecutionState(
      task: task ?? this.task,
      requirements: requirements ?? this.requirements,
      answers: answers ?? this.answers,
      photos: photos ?? this.photos,
      photoError: photoError != null ? photoError() : this.photoError,
      index: index ?? this.index,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [task, requirements, answers, photos, photoError, index, isLoading];
}

/// Walks the worker through a task's requirements one at a time. Answers
/// are saved on the device as they change.
class ExecutionCubit extends Cubit<ExecutionState> {
  ExecutionCubit(WatchTaskDetails watch, this._answers, this._picker, this._evidence, this.taskId)
      : super(const ExecutionState()) {
    _evidenceSubscription = _evidence.watchEvidence(taskId).listen((photos) => emit(state.copyWith(photos: photos)));
    _task = watch.task(taskId).listen((task) => emit(state.copyWith(task: task)));
    // Saved answers are read once; after that this screen is the only one
    // changing them, so a slower write can never undo newer typing.
    unawaited(_answers.watchAnswers(taskId).first.then((saved) {
      if (!isClosed) {
        emit(state.copyWith(answers: {...saved, ...state.answers}));
      }
    }));
    _requirements = watch.requirements(taskId).listen((requirements) {
      final index = requirements.isEmpty ? 0 : state.index.clamp(0, requirements.length - 1);
      emit(state.copyWith(requirements: requirements, index: index, isLoading: false));
    });
  }

  final AnswerRepository _answers;
  final EvidencePicker _picker;
  final EvidenceRepository _evidence;
  late final StreamSubscription<Map<String, List<EvidenceItem>>> _evidenceSubscription;
  final String taskId;
  Future<void> _saving = Future.value();
  late final StreamSubscription<Task?> _task;
  late final StreamSubscription<List<Requirement>> _requirements;

  void goTo(int index) {
    if (index >= 0 && index < state.requirements.length) {
      emit(state.copyWith(index: index));
    }
  }

  /// Changes the answer to a requirement, starting from its latest value,
  /// and saves it on the device (saves run one after another, in order).
  void answer(Requirement requirement, Answer Function(Answer current) update) {
    final changed = update(state.answerFor(requirement));
    emit(state.copyWith(answers: {...state.answers, requirement.id: changed}));
    _saving = _saving.then(
      (_) => _answers.saveAnswer(taskId: taskId, requirementId: requirement.id, answer: changed),
    );
  }

  /// Takes a photo with the camera (or chooses one from the gallery) for a
  /// PHOTO requirement. Nothing changes when the worker cancels.
  Future<void> addPhoto(Requirement requirement, {required bool fromCamera}) async {
    final path = fromCamera ? await _picker.takePhoto() : await _picker.chooseFromGallery();
    if (path == null || isClosed) {
      return;
    }
    try {
      // Stored and compressed on the device; the screen updates from the database.
      await _evidence.addPhoto(taskId: taskId, requirementId: requirement.id, sourcePath: path);
      if (!isClosed) {
        emit(state.copyWith(photoError: () => null));
      }
    } on Object {
      if (!isClosed) {
        emit(state.copyWith(photoError: () => 'The photo could not be saved. Please try again.'));
      }
    }
  }

  /// Completes when every answer so far is saved.
  Future<void> get saved => _saving;

  void next() => goTo(state.index + 1);

  void previous() => goTo(state.index - 1);

  @override
  Future<void> close() async {
    await _saving;
    await _evidenceSubscription.cancel();
    await _task.cancel();
    await _requirements.cancel();
    return super.close();
  }
}
