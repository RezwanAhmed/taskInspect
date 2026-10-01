import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_manager.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/core/synchronization/sync_remote_data_source.dart';
import 'package:taskinspect/features/evidence/data/evidence_uploader.dart';
import 'package:taskinspect/features/evidence/data/image_compressor.dart';
import 'package:taskinspect/features/evidence/data/local/evidence_local_data_source.dart';
import 'package:taskinspect/features/evidence/data/remote/evidence_remote_data_source.dart';
import 'package:taskinspect/features/requirements/data/local/answer_local_data_source.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/fake_tasks.dart';

/// The worker's offline flow end to end on the device (task 6.14): the
/// real local database, data sources, sync queue, SyncManager and upload
/// queue, against [_Backend], which behaves like the server's sync API
/// (docs/architecture.md, "Offline Synchronization").
void main() {
  late AppDatabase db;
  late _Backend backend;
  late SyncManager manager;
  late TaskLocalDataSource tasks;
  late AnswerLocalDataSource answers;
  late EvidenceLocalDataSource evidence;
  late Directory documents;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    backend = _Backend();
    final api = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    api.dio.httpClientAdapter = FakeServer(backend.handle);
    final files = Dio()..httpClientAdapter = FakeServer(backend.handleFile);
    var tick = 0;
    final queue = SyncQueue(db, now: () => DateTime.utc(2026, 10, 1, 9, 0, tick++));
    tasks = TaskLocalDataSource(db, queue: queue);
    answers = AnswerLocalDataSource(db, queue);
    documents = await Directory.systemTemp.createTemp('offline_sync_scenario');
    evidence = EvidenceLocalDataSource(db, _FakeCompressor(), queue, documentsDirectory: () async => documents);
    manager = SyncManager(
      db,
      SyncRemoteDataSource(api),
      tasks,
      EvidenceUploader(db, EvidenceRemoteDataSource(api, files: files)),
    );
    await tasks.saveTask(fakeTask('t1'), const [
      Requirement(id: 'r1', taskId: 't1', title: 'Clean?', type: RequirementType.yesNo, required: true, position: 0),
      Requirement(id: 'r2', taskId: 't1', title: 'Photo', type: RequirementType.photo, required: true, position: 1),
    ]);
  });

  tearDown(() async {
    await db.close();
    await documents.delete(recursive: true);
  });

  /// The worker starts the task, answers and takes a photo, all offline.
  Future<void> workOffline() async {
    await tasks.start('t1');
    await answers.saveAnswer(taskId: 't1', requirementId: 'r1', answer: const Answer(booleanValue: true));
    await answers.saveAnswer(
      taskId: 't1',
      requirementId: 'r1',
      answer: const Answer(booleanValue: true, comment: 'Done'),
    );
    final source = File('${documents.path}/camera.jpg')..writeAsBytesSync([1, 2, 3]);
    await evidence.addPhoto(taskId: 't1', requirementId: 'r2', sourcePath: source.path);
  }

  Future<List<SyncOperationRow>> queued() => db.select(db.localSyncOperations).get();

  test('work done offline reaches the server once the phone is back online, in order and once', () async {
    await workOffline();
    backend.online = false;

    final offline = await manager.sync();

    expect(offline, isA<Err<void>>().having((e) => e.failure, 'failure', isA<NetworkFailure>()));
    expect(await queued(), hasLength(3), reason: 'start, the latest answer, the photo - nothing lost');
    expect((await queued()).every((o) => o.status == 'FAILED' && o.lastError == 'NETWORK_ERROR'), isTrue);

    backend.online = true;
    await manager.retryTemporaryFailures();
    expect(await manager.sync(), isA<Ok<void>>());

    expect(backend.applied, ['Task START', 'TaskResponse UPDATE', 'Evidence CREATE']);
    expect(backend.answers['r1'], {'booleanValue': true, 'comment': 'Done'}, reason: 'the last answer wins');
    expect(backend.uploadedFiles, hasLength(1));
    expect(backend.completed, hasLength(1));
    expect(await queued(), isEmpty);
    expect((await db.select(db.localResponses).getSingle()).syncStatus, 'SYNCED');
    expect((await db.select(db.localEvidence).getSingle()).uploadStatus, 'UPLOADED');
    expect((await tasks.watchTask('t1').first)!.status, TaskStatus.inProgress, reason: 'pulled from the server');
    expect(await db.select(db.localResponses).get(), hasLength(1), reason: 'the pull keeps the answers on the device');
    expect(await db.select(db.localEvidence).get(), hasLength(1), reason: 'and the photo');
  });

  test('submitted offline with a photo: the submit reaches the server only after the photo', () async {
    await workOffline();
    await tasks.submit('t1');
    expect((await tasks.watchTask('t1').first)!.status, TaskStatus.submitted, reason: 'submitted locally');

    expect(await manager.sync(), isA<Ok<void>>());

    expect(backend.applied, ['Task START', 'TaskResponse UPDATE', 'Evidence CREATE', 'Task SUBMIT']);
    expect(backend.timeline.indexOf('complete'), lessThan(backend.timeline.indexOf('Task SUBMIT')));
    expect(backend.taskStatus, 'SUBMITTED');
    expect(await queued(), isEmpty);
    expect((await tasks.watchTask('t1').first)!.status, TaskStatus.submitted);
  });

  test('while the photo cannot be uploaded the submit waits on the device', () async {
    await workOffline();
    await tasks.submit('t1');
    backend.filesOnline = false;

    await manager.sync();

    expect(backend.applied, isNot(contains('Task SUBMIT')));
    final submit = (await queued()).singleWhere((o) => o.operation == 'SUBMIT');
    expect(submit.status, 'PENDING');
    expect((await tasks.watchTask('t1').first)!.status, TaskStatus.submitted, reason: 'kept until it is sent');
  });

  test('a refused submit sends the task back to the worker, who fixes it and submits again', () async {
    await workOffline();
    await tasks.submit('t1');
    backend.refuseSubmit = 'REQUIREMENTS_MISSING';

    await manager.sync();

    final refused = (await queued()).singleWhere((o) => o.operation == 'SUBMIT');
    expect((refused.status, refused.lastError), ('FAILED', 'REQUIREMENTS_MISSING'));
    expect((await tasks.watchTask('t1').first)!.status, TaskStatus.inProgress, reason: 'back with the worker');

    // The worker changes an answer: it is not held back by the refused submit.
    await answers.saveAnswer(taskId: 't1', requirementId: 'r1', answer: const Answer(booleanValue: false));
    await manager.sync();
    expect(backend.answers['r1'], {'booleanValue': false});

    backend.refuseSubmit = null;
    await tasks.submit('t1');
    expect((await queued()).where((o) => o.operation == 'SUBMIT'), hasLength(1), reason: 'the new one replaces it');
    await manager.sync();
    expect(backend.taskStatus, 'SUBMITTED');
    expect(await queued(), isEmpty);
  });

  test('Retry does not send a refused submit again as it was', () async {
    await workOffline();
    await tasks.submit('t1');
    backend.refuseSubmit = 'REQUIREMENTS_MISSING';
    await manager.sync();

    await manager.retryFailed();

    expect((await queued()).where((o) => o.operation == 'SUBMIT'), isEmpty);
    expect(await tasks.submit('t1'), isNotNull, reason: 'the worker can submit again');
  });

  test('a submit that failed only because of the network is sent again by Retry', () async {
    await workOffline();
    await tasks.submit('t1');
    backend.online = false;
    await manager.sync();
    backend.online = true;

    await manager.retryFailed();
    await manager.sync();

    expect(backend.taskStatus, 'SUBMITTED');
    expect(await queued(), isEmpty);
  });

  test('a task can only be submitted while in progress (no double submit)', () async {
    await workOffline();

    expect(await tasks.submit('t1'), isNotNull);
    expect(await tasks.submit('t1'), isNull);
    expect((await queued()).where((o) => o.operation == 'SUBMIT'), hasLength(1));
  });

  test('an answer lost on the way back is sent again, but the server applies nothing twice', () async {
    await workOffline();
    backend.loseNextPushAnswer = true;

    await manager.sync();
    expect(backend.applied, hasLength(3), reason: 'applied, but the app never heard');
    expect(await queued(), hasLength(3));

    await manager.retryTemporaryFailures();
    await manager.sync();

    expect(backend.applied, hasLength(3), reason: 'the repeated operation IDs were not applied again');
    expect(await queued(), isEmpty);
  });

  test('the manager cancelled the task meanwhile: the server wins, the refused change stays with its reason', () async {
    await workOffline();
    backend.taskStatus = 'CANCELLED';

    await manager.sync();

    final start = (await queued()).firstWhere((o) => o.operation == 'START');
    expect((start.status, start.lastError), ('FAILED', 'TASK_INVALID_TRANSITION'));
    expect(
      (await queued()).where((o) => o.operation != 'START').every((o) => o.status == 'PENDING'),
      isTrue,
      reason: 'later changes of the task wait instead of being sent',
    );
    expect(backend.applied, isEmpty);
    expect((await tasks.watchTask('t1').first)!.status, TaskStatus.cancelled);
    expect(await db.select(db.localResponses).get(), hasLength(1), reason: "the worker's answers stay on the device");
    expect(await db.select(db.localEvidence).get(), hasLength(1), reason: 'and the photo');
  });

  test('the manager edited the task meanwhile: refused as outdated, then Retry sends the new version and succeeds',
      () async {
    await workOffline();
    backend.taskVersion = 2;

    await manager.sync();
    final refused = (await queued()).firstWhere((o) => o.operation == 'START');
    expect(refused.lastError, 'VERSION_CONFLICT');
    expect((await tasks.watchTask('t1').first)!.version, 2, reason: "the server's version is stored");

    await manager.retryFailed();
    await manager.sync();

    expect(backend.applied, ['Task START', 'TaskResponse UPDATE', 'Evidence CREATE']);
    expect(await queued(), isEmpty);
    expect((await tasks.watchTask('t1').first)!.status, TaskStatus.inProgress);
  });

  test('a task taken away after a refused change stays on the device with its changes and the failure', () async {
    await workOffline();
    backend
      ..taskStatus = 'CANCELLED'
      ..taskVisible = false;

    await manager.sync();

    expect(await tasks.watchTask('t1').first, isNotNull);
    expect(await db.select(db.localResponses).get(), hasLength(1));
    expect(await db.select(db.localEvidence).get(), hasLength(1));
    expect(await queued(), hasLength(3), reason: 'nothing dropped silently');
  });

  test('the app was closed during a sync: interrupted changes go out again, once', () async {
    await workOffline();
    await db.update(db.localSyncOperations).write(const LocalSyncOperationsCompanion(status: Value('SYNCING')));
    await db.update(db.localEvidence).write(const LocalEvidenceCompanion(uploadStatus: Value('UPLOADING')));

    expect(await manager.sync(), isA<Ok<void>>());
    expect(backend.applied, isEmpty, reason: 'nothing PENDING until reset');

    await manager.resetInterrupted();
    await manager.sync();

    expect(backend.applied, hasLength(3));
    expect(await queued(), isEmpty);
    expect((await db.select(db.localEvidence).getSingle()).uploadStatus, 'UPLOADED');
  });
}

class _FakeCompressor implements ImageCompressor {
  @override
  Future<Uint8List> compressToJpeg(String path) async => Uint8List.fromList([9, 9, 9, 9]);
}

/// The server's sync API in memory: applies each operation ID once, keeps
/// the task's status (and refuses a START unless the task is ASSIGNED),
/// registers and receives evidence files, and answers pulls.
class _Backend {
  bool online = true;

  /// When set, every SUBMIT is refused with this code.
  String? refuseSubmit;

  /// Whether the file storage can be reached (the API still can).
  bool filesOnline = true;

  /// Operations and file confirmations in the order the server got them.
  final List<String> timeline = [];

  /// The next push is applied, but its answer never reaches the app.
  bool loseNextPushAnswer = false;

  String taskStatus = 'ASSIGNED';
  int taskVersion = 1;

  /// Whether the pull still shows the task to the worker.
  bool taskVisible = true;
  final List<String> applied = [];
  final Set<String> appliedIds = {};
  final Map<String, Map<String, Object?>> answers = {};
  final Set<String> registered = {};
  final List<String> uploadedFiles = [];
  final Set<String> completed = {};

  Future<(int, Object?)> handle(RequestOptions request) async {
    if (!online) {
      return (0, null);
    }
    final path = request.path;
    if (path == '/api/sync/push') {
      final results = _push(((request.data as Map)['operations'] as List).cast<Map<String, Object?>>());
      if (loseNextPushAnswer) {
        loseNextPushAnswer = false;
        return (0, null);
      }
      return (200, {'results': results});
    }
    if (path == '/api/sync/pull') {
      return (200, {
        'cursor': 'c1',
        'taskIds': [if (taskVisible) 't1'],
        'tasks': [
          if (taskVisible)
          {
            'task': {
              'id': 't1',
              'title': 'Task t1',
              'priority': 'MEDIUM',
              'status': taskStatus,
              'dueDate': '2099-01-01T00:00:00Z',
              'createdBy': {'id': 'm1', 'fullName': 'Mia Manager'},
              'reviewer': {'id': 'm1', 'fullName': 'Mia Manager'},
              'assignee': {'id': 'u1', 'fullName': 'Wendy Worker'},
              'version': taskVersion,
              'updatedAt': '2026-10-01T09:30:00Z',
            },
            'requirements': [
              {'id': 'r1', 'title': 'Clean?', 'type': 'YES_NO', 'required': true, 'position': 0},
              {'id': 'r2', 'title': 'Photo', 'type': 'PHOTO', 'required': true, 'position': 1},
            ],
          },
        ],
      });
    }
    final evidenceId = path.split('/')[5];
    if (path.endsWith('/upload-url')) {
      return registered.contains(evidenceId)
          ? (200, {'url': 'http://files.test/$evidenceId.jpg', 'method': 'PUT', 'headers': {'Content-Type': 'image/jpeg'}})
          : (404, {'code': 'EVIDENCE_NOT_FOUND'});
    }
    if (path.endsWith('/complete')) {
      if (!uploadedFiles.contains(evidenceId)) {
        return (409, {'code': 'UPLOAD_INCOMPLETE'});
      }
      completed.add(evidenceId);
      timeline.add('complete');
      return (200, {'id': evidenceId, 'status': 'UPLOADED'});
    }
    return (404, {'code': 'NOT_FOUND'});
  }

  Future<(int, Object?)> handleFile(RequestOptions request) async {
    if (!online || !filesOnline) {
      return (0, null);
    }
    uploadedFiles.add(request.uri.pathSegments.last.split('.').first);
    return (200, null);
  }

  List<Map<String, Object?>> _push(List<Map<String, Object?>> operations) {
    final rejectedTasks = <String>{};
    return [
      for (final operation in operations) _apply(operation, rejectedTasks),
    ];
  }

  Map<String, Object?> _apply(Map<String, Object?> operation, Set<String> rejectedTasks) {
    final id = operation['id']! as String;
    final taskId = operation['taskId']! as String;
    if (appliedIds.contains(id)) {
      return {'id': id, 'status': 'APPLIED'};
    }
    if (rejectedTasks.contains(taskId)) {
      return {'id': id, 'status': 'SKIPPED', 'code': 'EARLIER_OPERATION_REJECTED'};
    }
    final kind = '${operation['entityType']} ${operation['operation']}';
    final payload = (operation['payload'] as Map?)?.cast<String, Object?>() ?? {};
    switch (kind) {
      case 'Task START':
        // Like the real server: an old version first, then the state machine.
        if (payload['version'] != taskVersion) {
          rejectedTasks.add(taskId);
          return {'id': id, 'status': 'REJECTED', 'code': 'VERSION_CONFLICT'};
        }
        if (taskStatus != 'ASSIGNED') {
          rejectedTasks.add(taskId);
          return {'id': id, 'status': 'REJECTED', 'code': 'TASK_INVALID_TRANSITION'};
        }
        taskStatus = 'IN_PROGRESS';
        taskVersion++;
      case 'TaskResponse UPDATE':
        answers[operation['entityId']! as String] = {
          for (final MapEntry(:key, :value) in payload.entries)
            if (value != null && !(value is List && value.isEmpty)) key: value,
        };
      case 'Evidence CREATE':
        registered.add(operation['entityId']! as String);
      case 'Task SUBMIT':
        if (refuseSubmit != null) {
          rejectedTasks.add(taskId);
          return {'id': id, 'status': 'REJECTED', 'code': refuseSubmit};
        }
        if (registered.any((id) => !completed.contains(id))) {
          rejectedTasks.add(taskId);
          return {'id': id, 'status': 'REJECTED', 'code': 'EVIDENCE_NOT_UPLOADED'};
        }
        taskStatus = 'SUBMITTED';
    }
    appliedIds.add(id);
    applied.add(kind);
    timeline.add(kind);
    return {'id': id, 'status': 'APPLIED'};
  }
}
