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
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/features/evidence/data/evidence_uploader.dart';
import 'package:taskinspect/features/evidence/data/remote/evidence_remote_data_source.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/fake_tasks.dart';

void main() {
  late AppDatabase db;
  late ApiClient api;
  late Dio files;
  late EvidenceUploader uploader;
  late Directory folder;

  /// Status code per API path end (`upload-url`, `complete`) and for the file upload.
  late Map<String, int> statusOf;
  late Map<String, String> codeOf;

  /// File uploads as received: URL, content type, size and all headers.
  late List<({String url, Object? contentType, Object? length, Map<String, dynamic> headers})> uploads;

  /// The signed URL the API hands out (local storage by default; S3 style in one test).
  late Map<String, Object?> signedUpload;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    api = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    files = Dio();
    statusOf = {};
    codeOf = {};
    uploads = [];
    signedUpload = {
      'method': 'PUT',
      'headers': {'Content-Type': 'image/jpeg'},
      'expiresAt': '2026-10-01T09:10:00Z',
    };
    api.dio.httpClientAdapter = FakeServer((request) async {
      final step = request.path.split('/').last;
      final status = statusOf[step] ?? 200;
      if (status != 200) {
        return (status, {'code': codeOf[step], 'message': 'refused'});
      }
      return switch (step) {
        'upload-url' => (200, {
            'url': 'http://files.test/api/files/${request.path.split('/')[5]}.jpg?signature=s',
            ...signedUpload,
          }),
        _ => (200, {'id': request.path.split('/')[5], 'status': 'UPLOADED'}),
      };
    });
    files.httpClientAdapter = FakeServer((request) async {
      uploads.add((
        url: request.uri.toString(),
        contentType: request.contentType,
        length: request.headers[Headers.contentLengthHeader],
        headers: request.headers,
      ));
      return (statusOf['file'] ?? 200, null);
    });
    uploader = EvidenceUploader(db, EvidenceRemoteDataSource(api, files: files));
    folder = await Directory.systemTemp.createTemp('evidence_upload_test');
    await TaskLocalDataSource(db).saveTask(fakeTask('t1', status: TaskStatus.inProgress), [
      const Requirement(id: 'r1', taskId: 't1', title: 'Photo', type: RequirementType.photo, required: true, position: 0),
    ]);
  });

  tearDown(() async {
    await db.close();
    await folder.delete(recursive: true);
  });

  /// A photo on the device; [registered] = its CREATE was applied (left the queue).
  Future<void> photo(String id, {bool registered = true, bool fileExists = true, int minute = 0}) async {
    final file = File('${folder.path}/$id.jpg');
    if (fileExists) {
      await file.writeAsBytes(List.filled(5, 1));
    }
    await db.into(db.localEvidence).insert(LocalEvidenceCompanion.insert(
          id: id,
          taskId: 't1',
          requirementId: 'r1',
          localPath: file.path,
          mimeType: 'image/jpeg',
          sizeBytes: 5,
          createdAt: DateTime.utc(2026, 10, 1, 9, minute),
        ));
    if (!registered) {
      await SyncQueue(db).add(entity: SyncEntity.evidence, entityId: id, taskId: 't1', operation: SyncOperation.create);
    }
  }

  Future<EvidenceRow> row(String id) => (db.select(db.localEvidence)..where((e) => e.id.equals(id))).getSingle();

  test('an S3 pre-signed URL gets its signed headers, one length and no login (task 8.3)', () async {
    signedUpload = {
      'url': 'https://evidence.s3.eu-central-1.amazonaws.com/tasks/t1/e1.jpg?X-Amz-Signature=abc',
      'method': 'PUT',
      'headers': {'Content-Type': 'image/jpeg', 'Content-Length': '5'},
      'expiresAt': '2026-10-01T09:10:00Z',
    };
    await photo('e1');

    expect(await uploader.uploadAll(), isA<Ok<void>>());

    final upload = uploads.single;
    expect(upload.url, startsWith('https://evidence.s3.eu-central-1.amazonaws.com/tasks/t1/e1.jpg'));
    expect(upload.contentType, 'image/jpeg');
    expect(upload.length, 5);
    expect([for (final key in upload.headers.keys) key.toLowerCase()].where((k) => k == 'content-length'), hasLength(1));
    expect(upload.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
  });

  test('an upload refused twice in a row is not retried automatically any more', () async {
    await photo('e1');
    statusOf['file'] = 403;

    await uploader.uploadAll();
    expect((await row('e1')).uploadError, EvidenceRemoteDataSource.urlExpired);
    await uploader.retryTemporaryFailures();
    final second = await uploader.uploadAll();

    expect((await row('e1')).uploadError, EvidenceUploader.uploadRefused);
    expect(second, isA<Ok<void>>(), reason: 'not a temporary failure for the sync');
    await uploader.retryTemporaryFailures();
    expect((await row('e1')).uploadStatus, 'FAILED');

    statusOf['file'] = 200;
    await uploader.retryFailed();
    await uploader.uploadAll();
    expect((await row('e1')).uploadStatus, 'UPLOADED');
  });

  test('uploads a registered file: upload URL, file (with its type and size), complete', () async {
    await photo('e1');

    expect(await uploader.uploadAll(), isA<Ok<void>>());

    expect(uploads.single.url, startsWith('http://files.test/api/files/e1.jpg'));
    expect(uploads.single.contentType, 'image/jpeg');
    expect(uploads.single.length, 5);
    expect((await row('e1')).uploadStatus, 'UPLOADED');
  });

  test('waits until the server knows the file (its CREATE is still queued)', () async {
    await photo('e1', registered: false);

    await uploader.uploadAll();

    expect(uploads, isEmpty);
    expect((await row('e1')).uploadStatus, 'PENDING');
  });

  test('offline: FAILED with NETWORK_ERROR, the other files wait, automatic retry puts it back', () async {
    await photo('e1');
    await photo('e2', minute: 1);
    statusOf['file'] = 0;

    final result = await uploader.uploadAll();

    expect(result, isA<Err<void>>().having((e) => e.failure, 'failure', isA<NetworkFailure>()));
    expect(uploads, hasLength(1), reason: 'stops after the first one');
    final failed = await row('e1');
    expect((failed.uploadStatus, failed.uploadError, failed.uploadRetryCount), ('FAILED', 'NETWORK_ERROR', 1));
    expect((await row('e2')).uploadStatus, 'PENDING');

    await uploader.retryTemporaryFailures();
    expect((await row('e1')).uploadStatus, 'PENDING');
  });

  test('a server error is retried automatically too, and the next files still go', () async {
    await photo('e1');
    await photo('e2', minute: 1);
    statusOf['complete'] = 503;

    final result = await uploader.uploadAll();

    expect(result, isA<Err<void>>());
    expect(uploads, hasLength(2));
    expect((await row('e2')).uploadError, 'SERVER_ERROR');
  });

  test("a refusal (e.g. the task was cancelled) keeps the server's reason and waits for Retry", () async {
    await photo('e1');
    statusOf['upload-url'] = 409;
    codeOf['upload-url'] = 'EVIDENCE_LOCKED';

    expect(await uploader.uploadAll(), isA<Ok<void>>(), reason: 'nothing to retry automatically');

    final failed = await row('e1');
    expect((failed.uploadStatus, failed.uploadError), ('FAILED', 'EVIDENCE_LOCKED'));
    await uploader.retryTemporaryFailures();
    expect((await row('e1')).uploadStatus, 'FAILED');
    await uploader.retryFailed();
    expect((await row('e1')).uploadStatus, 'PENDING');
  });

  test('a file the server already has is only confirmed', () async {
    await photo('e1');
    statusOf['upload-url'] = 409;
    codeOf['upload-url'] = 'EVIDENCE_ALREADY_UPLOADED';

    await uploader.uploadAll();

    expect(uploads, isEmpty);
    expect((await row('e1')).uploadStatus, 'UPLOADED');
  });

  test('a file missing on the device fails with FILE_MISSING and is not sent', () async {
    await photo('e1', fileExists: false);

    await uploader.uploadAll();

    expect(uploads, isEmpty);
    expect((await row('e1')).uploadError, EvidenceUploader.fileMissing);
  });

  test('an expired login stops the uploads and leaves the file PENDING', () async {
    await photo('e1');
    statusOf['upload-url'] = 401;

    final result = await uploader.uploadAll();

    expect(result, isA<Err<void>>().having((e) => e.failure, 'failure', isA<UnauthorizedFailure>()));
    expect((await row('e1')).uploadStatus, 'PENDING');
  });

  test('an upload interrupted by closing the app goes back to PENDING', () async {
    await photo('e1');
    await db.update(db.localEvidence).write(const LocalEvidenceCompanion(uploadStatus: Value('UPLOADING')));

    await uploader.resetInterrupted();

    expect((await row('e1')).uploadStatus, 'PENDING');
  });

  test('a connection lost during the upload is a network error (retried automatically)', () async {
    await photo('e1');
    files.httpClientAdapter = _Throwing(const SocketException('Connection reset by peer'));

    final result = await uploader.uploadAll();

    expect(result, isA<Err<void>>().having((e) => e.failure, 'failure', isA<NetworkFailure>()));
    expect((await row('e1')).uploadError, 'NETWORK_ERROR');
  });

  test('a refused upload URL (expired, or the server restarted) is retried with a new one', () async {
    await photo('e1');
    statusOf['file'] = 403;

    final result = await uploader.uploadAll();

    expect(result, isA<Err<void>>(), reason: 'the sync is retried');
    expect((await row('e1')).uploadError, EvidenceRemoteDataSource.urlExpired);
    await uploader.retryTemporaryFailures();
    expect((await row('e1')).uploadStatus, 'PENDING');
  });

  test('a file removed during the upload fails with FILE_MISSING instead of breaking the sync', () async {
    await photo('e1');
    files.httpClientAdapter = _Throwing(const FileSystemException('Cannot open file', '/gone.jpg'));

    expect(await uploader.uploadAll(), isA<Ok<void>>());

    expect((await row('e1')).uploadError, EvidenceUploader.fileMissing);
  });

  test('waits while a DELETE of the file is queued after a still unsent CREATE', () async {
    await photo('e1', registered: false);
    await SyncQueue(db).add(entity: SyncEntity.evidence, entityId: 'e1', taskId: 't1', operation: SyncOperation.delete);

    await uploader.uploadAll();

    expect(uploads, isEmpty);
  });
}

/// A file server whose connection fails with [error].
class _Throwing implements HttpClientAdapter {
  _Throwing(this.error);

  final Object error;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      Future.error(error);

  @override
  void close({bool force = false}) {}
}
