import 'dart:async';

import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/synchronization/sync_status.dart';
import 'package:taskinspect/core/synchronization/sync_status_cubit.dart';
import 'package:taskinspect/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:taskinspect/features/evidence/domain/document_opener.dart';
import 'package:taskinspect/features/evidence/domain/evidence_item.dart';
import 'package:taskinspect/features/evidence/domain/evidence_picker.dart';
import 'package:taskinspect/features/evidence/domain/evidence_repository.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/requirements/domain/repositories/answer_repository.dart';
import 'package:taskinspect/features/tasks/domain/entities/history_entry.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_review.dart';
import 'package:taskinspect/features/tasks/domain/entities/team_task.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';
import 'package:taskinspect/features/tasks/domain/usecases/load_task_history.dart';
import 'package:taskinspect/features/tasks/domain/usecases/refresh_tasks.dart';
import 'package:taskinspect/features/tasks/domain/usecases/start_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/submit_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_tasks.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_team_tasks.dart';

Task fakeTask(String id, {TaskStatus status = TaskStatus.assigned, DateTime? due, String? title}) => Task(
      id: id,
      title: title ?? 'Task $id',
      priority: TaskPriority.medium,
      status: status,
      dueDate: due ?? DateTime.utc(2099),
      createdBy: const PersonRef(id: 'm1', name: 'Mia Manager'),
      reviewer: const PersonRef(id: 'm1', name: 'Mia Manager'),
      assignee: const PersonRef(id: 'u1', name: 'Wendy Worker'),
      version: 1,
      updatedAt: DateTime.utc(2026, 10, 1),
    );

/// An in-memory [TaskRepository] for widget and cubit tests.
class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository([List<Task> tasks = const []]) : current = tasks;

  final List<StreamController<List<Task>>> _watchers = [];
  List<Task> current;
  Map<String, List<Requirement>> requirements = {};
  Failure? refreshFailure;
  int refreshes = 0;

  /// When set, starting a task fails with this.
  Failure? startFailure;

  /// The team members' tasks (tiles) on the "device".
  List<TeamTask> teamTasks = [];

  /// Changes the tasks on the "device"; every watcher sees the change.
  void emit(List<Task> tasks) {
    current = tasks;
    for (final watcher in _watchers) {
      watcher.add(tasks);
    }
  }

  /// Like the local database: the current tasks first, then every change.
  @override
  Stream<List<Task>> watchTasks({TaskStatus? status}) {
    late final StreamController<List<Task>> controller;
    controller = StreamController<List<Task>>(
      onListen: () {
        _watchers.add(controller);
        controller.add(current);
      },
      onCancel: () => _watchers.remove(controller),
    );
    return controller.stream
        .map((tasks) => status == null ? tasks : tasks.where((t) => t.status == status).toList());
  }

  @override
  Stream<List<TeamTask>> watchTeamTasks() => Stream.value(teamTasks);

  @override
  Stream<Task?> watchTask(String id) =>
      watchTasks().map((tasks) => tasks.where((t) => t.id == id).firstOrNull);

  @override
  Stream<List<Requirement>> watchRequirements(String taskId) async* {
    yield requirements[taskId] ?? const [];
  }

  @override
  Future<Result<Task>> start(String taskId) async {
    if (startFailure != null) {
      return Err(startFailure!);
    }
    final task = current.firstWhere((t) => t.id == taskId);
    final started = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      priority: task.priority,
      status: TaskStatus.inProgress,
      dueDate: task.dueDate,
      createdBy: task.createdBy,
      reviewer: task.reviewer,
      assignee: task.assignee,
      version: task.version + 1,
      updatedAt: task.updatedAt,
    );
    emit([for (final t in current) t.id == taskId ? started : t]);
    return Ok(started);
  }

  /// The history [loadHistory] returns, or [historyFailure].
  List<HistoryEntry> history = [];
  Failure? historyFailure;

  @override
  Future<Result<List<HistoryEntry>>> loadHistory(String taskId) async =>
      historyFailure == null ? Ok(history) : Err(historyFailure!);

  /// Latest reviews by task ID (set by tests).
  Map<String, TaskReview> reviews = {};

  @override
  Stream<TaskReview?> watchReview(String taskId) => Stream.value(reviews[taskId]);

  /// Task IDs submitted through [submit].
  final List<String> submitted = [];

  @override
  Future<Result<Task>> submit(String taskId) async {
    submitted.add(taskId);
    final task = current.firstWhere((t) => t.id == taskId);
    final done = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      priority: task.priority,
      status: TaskStatus.submitted,
      dueDate: task.dueDate,
      createdBy: task.createdBy,
      reviewer: task.reviewer,
      assignee: task.assignee,
      version: task.version,
      updatedAt: task.updatedAt,
    );
    emit([for (final t in current) t.id == taskId ? done : t]);
    return Ok(done);
  }

  @override
  Future<Result<void>> refresh() async {
    refreshes++;
    return refreshFailure == null ? const Ok(null) : Err(refreshFailure!);
  }
}

/// In-memory [AnswerRepository] for widget tests.
class FakeAnswerRepository implements AnswerRepository {
  final Map<String, Map<String, Answer>> saved = {};

  @override
  Stream<Map<String, Answer>> watchAnswers(String taskId) async* {
    yield Map.of(saved[taskId] ?? const {});
  }

  @override
  Future<void> saveAnswer({required String taskId, required String requirementId, required Answer answer}) async {
    (saved[taskId] ??= {})[requirementId] = answer;
  }
}

/// [EvidencePicker] for widget tests: returns the next queued path
/// (`null` = the worker cancelled).
class FakeEvidencePicker implements EvidencePicker {
  final List<String?> next = [];
  int cameraUses = 0;
  int galleryUses = 0;

  /// Documents returned by [chooseDocument], in order (`null` = cancelled).
  final List<PickedDocument?> nextDocuments = [];

  @override
  Future<String?> takePhoto() async {
    cameraUses++;
    return next.isEmpty ? null : next.removeAt(0);
  }

  @override
  Future<String?> chooseFromGallery() async {
    galleryUses++;
    return next.isEmpty ? null : next.removeAt(0);
  }

  @override
  Future<PickedDocument?> chooseDocument() async => nextDocuments.isEmpty ? null : nextDocuments.removeAt(0);
}

/// In-memory [EvidenceRepository] for widget tests (no compression).
class FakeEvidenceRepository implements EvidenceRepository {
  final List<EvidenceItem> items = [];
  final List<StreamController<Map<String, List<EvidenceItem>>>> _watchers = [];

  /// When set, adding a photo or document fails with this.
  Object? addError;

  Map<String, List<EvidenceItem>> _of(String taskId) {
    final byRequirement = <String, List<EvidenceItem>>{};
    for (final item in items.where((i) => i.taskId == taskId)) {
      (byRequirement[item.requirementId] ??= []).add(item);
    }
    return byRequirement;
  }

  @override
  Stream<Map<String, List<EvidenceItem>>> watchEvidence(String taskId) {
    late final StreamController<Map<String, List<EvidenceItem>>> controller;
    controller = StreamController(
      onListen: () {
        _watchers.add(controller);
        controller.add(_of(taskId));
      },
      onCancel: () => _watchers.remove(controller),
    );
    return controller.stream;
  }

  @override
  Future<EvidenceItem> addPhoto({
    required String taskId,
    required String requirementId,
    required String sourcePath,
  }) async {
    if (addError != null) {
      throw addError!;
    }
    final item = EvidenceItem(
      id: 'e${items.length + 1}',
      taskId: taskId,
      requirementId: requirementId,
      localPath: sourcePath,
      mimeType: 'image/jpeg',
      sizeBytes: 100,
      createdAt: DateTime.utc(2026, 10, 1),
    );
    items.add(item);
    _notify(taskId);
    return item;
  }

  @override
  Future<EvidenceItem> addDocument({
    required String taskId,
    required String requirementId,
    required String sourcePath,
    required String fileName,
  }) async {
    if (addError != null) {
      throw addError!;
    }
    final item = EvidenceItem(
      id: 'e${items.length + 1}',
      taskId: taskId,
      requirementId: requirementId,
      localPath: sourcePath,
      mimeType: 'application/pdf',
      sizeBytes: 2048,
      createdAt: DateTime.utc(2026, 10, 1),
      fileName: fileName,
    );
    items.add(item);
    _notify(taskId);
    return item;
  }

  @override
  Future<void> remove(EvidenceItem item) async {
    items.removeWhere((i) => i.id == item.id);
    _notify(item.taskId);
  }

  void _notify(String taskId) {
    for (final watcher in _watchers) {
      watcher.add(_of(taskId));
    }
  }
}

/// [DocumentOpener] for widget tests: records what was opened.
class FakeDocumentOpener implements DocumentOpener {
  final List<String> opened = [];

  /// Whether an app is available to open documents.
  bool canOpen = true;

  @override
  Future<bool> open(String path, {required String mimeType}) async {
    opened.add(path);
    return canOpen;
  }
}

/// A [SyncStatusSource] the test sets: [status] first, then [emit]ted ones.
class FakeSyncStatusSource implements SyncStatusSource {
  FakeSyncStatusSource([this.status = const SyncStatus()]);

  SyncStatus status;
  final _changes = StreamController<SyncStatus>.broadcast();
  int retries = 0;

  void emit(SyncStatus next) {
    status = next;
    _changes.add(next);
  }

  @override
  Stream<SyncStatus> watch() async* {
    yield status;
    yield* _changes.stream;
  }
}

/// Registers the task screens' dependencies with [repository] in the
/// service locator, as the app does.
void registerFakeTasks(
  FakeTaskRepository repository, {
  FakeAnswerRepository? answers,
  FakeEvidencePicker? picker,
  FakeEvidenceRepository? evidence,
  FakeDocumentOpener? opener,
  FakeSyncStatusSource? syncStatus,
}) {
  if (getIt.isRegistered<DashboardCubit>()) {
    getIt.unregister<DashboardCubit>();
  }
  if (getIt.isRegistered<WatchTasks>()) {
    getIt.unregister<WatchTasks>();
  }
  if (getIt.isRegistered<WatchTeamTasks>()) {
    getIt.unregister<WatchTeamTasks>();
  }
  for (final unregister in [
    () => getIt.isRegistered<WatchTaskDetails>() ? getIt.unregister<WatchTaskDetails>() : null,
    () => getIt.isRegistered<StartTask>() ? getIt.unregister<StartTask>() : null,
    () => getIt.isRegistered<SubmitTask>() ? getIt.unregister<SubmitTask>() : null,
    () => getIt.isRegistered<LoadTaskHistory>() ? getIt.unregister<LoadTaskHistory>() : null,
    () => getIt.isRegistered<AnswerRepository>() ? getIt.unregister<AnswerRepository>() : null,
    () => getIt.isRegistered<EvidencePicker>() ? getIt.unregister<EvidencePicker>() : null,
    () => getIt.isRegistered<EvidenceRepository>() ? getIt.unregister<EvidenceRepository>() : null,
    () => getIt.isRegistered<DocumentOpener>() ? getIt.unregister<DocumentOpener>() : null,
    () => getIt.isRegistered<SyncStatusCubit>() ? getIt.unregister<SyncStatusCubit>() : null,
  ]) {
    unregister();
  }
  getIt
    ..registerFactory(() => DashboardCubit(repository, RefreshTasks(repository)))
    ..registerFactory(() => WatchTasks(repository))
    ..registerFactory(() => WatchTeamTasks(repository))
    ..registerFactory(() => WatchTaskDetails(repository))
    ..registerFactory(() => StartTask(repository))
    ..registerFactory(() => SubmitTask(repository))
    ..registerFactory(() => LoadTaskHistory(repository))
    ..registerSingleton<AnswerRepository>(answers ?? FakeAnswerRepository())
    ..registerSingleton<EvidencePicker>(picker ?? FakeEvidencePicker())
    ..registerSingleton<EvidenceRepository>(evidence ?? FakeEvidenceRepository())
    ..registerSingleton<DocumentOpener>(opener ?? FakeDocumentOpener());
  final source = syncStatus ?? FakeSyncStatusSource();
  getIt.registerFactory(() => SyncStatusCubit(source, () async => source.retries++));
}
