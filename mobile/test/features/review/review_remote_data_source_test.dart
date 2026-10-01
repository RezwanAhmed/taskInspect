import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/review/data/review_remote_data_source.dart';
import 'package:taskinspect/features/review/domain/submission.dart';

import '../../helpers/fake_server.dart';

void main() {
  late ApiClient api;
  late ReviewRemoteDataSource source;
  late bool online;

  setUp(() {
    online = true;
    api = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    api.dio.httpClientAdapter = FakeServer((request) async {
      if (!online) {
        return (0, null);
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
    source = ReviewRemoteDataSource(api, temporaryDirectory: () async => Directory.systemTemp);
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

  test('offline: a network failure', () async {
    online = false;

    final result = await source.loadSubmission('t1');

    expect(result, isA<Err<Submission>>().having((e) => e.failure, 'failure', isA<NetworkFailure>()));
  });
}
