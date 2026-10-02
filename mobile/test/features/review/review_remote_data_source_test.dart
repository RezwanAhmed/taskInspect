import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/review/data/review_remote_data_source.dart';
import 'package:taskinspect/features/review/domain/submission.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_server.dart';

void main() {
  late ApiClient api;
  late ReviewRemoteDataSource source;
  late bool online;
  late List<Task> stored;
  late List<(String, Object?)> posted;

  setUp(() {
    online = true;
    posted = [];
    api = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    api.dio.httpClientAdapter = FakeServer((request) async {
      if (!online) {
        return (0, null);
      }
      if (request.method == 'POST') {
        posted.add((request.path, request.data));
        return (200, {
          'id': 't1', 'title': 'Kitchen', 'priority': 'HIGH', 'status': 'APPROVED',
          'dueDate': '2026-10-02T09:00:00Z', 'createdBy': {'id': 'm1', 'fullName': 'Mia Manager'},
          'reviewer': {'id': 'm1', 'fullName': 'Mia Manager'}, 'assignee': {'id': 'u1', 'fullName': 'Wendy Worker'},
          'version': 5, 'updatedAt': '2026-10-01T10:00:00Z',
        });
      }
      return switch (request.path) {
        '/api/tasks/t1/responses' => (200, [
            {'id': 'x1', 'requirementId': 'r1', 'booleanValue': true, 'comment': 'All fine'},
            {'id': 'x2', 'requirementId': 'r2', 'numberValue': 4.5},
            {'id': 'x3', 'requirementId': 'r3', 'selectedOptionIds': ['o1', 'o2']},
          ]),
        '/api/tasks/t1/evidence' => (200, [
            {'id': 'e1', 'requirementId': 'r4', 'fileName': 'fridge.jpg', 'contentType': 'image/jpeg',
              'sizeBytes': 200, 'status': 'UPLOADED'},
            {'id': 'e2', 'requirementId': 'r4', 'fileName': 'door.jpg', 'contentType': 'image/jpeg',
              'sizeBytes': 300, 'status': 'PENDING'},
          ]),
        '/api/tasks/t1/evidence/e1/download-url' => (200, {'url': 'http://files.test/e1.jpg', 'method': 'GET'}),
        _ => (404, {'code': 'NOT_FOUND'}),
      };
    });
    stored = [];
    source = ReviewRemoteDataSource(api, temporaryDirectory: () async => Directory.systemTemp,
        storeTask: (task) async => stored.add(task));
  });

  test('loads the submitted answers and files by requirement', () async {
    final result = await source.loadSubmission('t1');

    final submission = (result as Ok<Submission>).value;
    expect(submission.answers['r1'], const Answer(booleanValue: true, comment: 'All fine'));
    expect(submission.answers['r2']!.numberValue, 4.5);
    expect(submission.answers['r3']!.selectedOptionIds, ['o1', 'o2']);
    expect(submission.files['r4']!.map((f) => (f.fileName, f.uploaded, f.isPhoto)),
        [('fridge.jpg', true, true), ('door.jpg', false, true)]);
  });

  test('the signed URL of a file', () async {
    const file = SubmittedFile(id: 'e1', requirementId: 'r4', fileName: 'fridge.jpg', contentType: 'image/jpeg',
        sizeBytes: 200, uploaded: true);

    expect((await source.fileUrl('t1', file) as Ok<String>).value, 'http://files.test/e1.jpg');
  });

  test('a decision is sent and the returned task is stored on the device', () async {
    final result = await source.approve('t1', comment: ' Well done ');

    expect((result as Ok<Task>).value.status, TaskStatus.approved);
    expect(posted.single.$1, '/api/tasks/t1/approve');
    expect(posted.single.$2, {'comment': 'Well done'});
    expect(stored.single.version, 5);
  });

  test('reject sends the reason; a correction sends the marked requirements with comments', () async {
    await source.reject('t1', reason: 'Wrong kitchen');
    await source.requestCorrection('t1', reason: '', requirements: {'r3': ' Retake it '});

    expect(posted[0].$1, '/api/tasks/t1/reject');
    expect(posted[0].$2, {'reason': 'Wrong kitchen'});
    expect(posted[1].$1, '/api/tasks/t1/request-correction');
    expect(posted[1].$2, {
      'requirements': [
        {'requirementId': 'r3', 'comment': 'Retake it'},
      ],
    });
  });

  test('offline: a network failure', () async {
    online = false;

    final result = await source.loadSubmission('t1');

    expect(result, isA<Err<Submission>>().having((e) => e.failure, 'failure', isA<NetworkFailure>()));
  });
}
