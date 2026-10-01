import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';
import 'package:taskinspect/features/tasks/data/remote/task_remote_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/history_entry.dart';

import '../../../helpers/fake_server.dart';

void main() {
  test('parses the history: event, who, when (UTC) and reason; unknown events and missing users are kept', () async {
    final api = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    api.dio.httpClientAdapter = FakeServer((request) async => (200, [
          {
            'event': 'REJECTED',
            'fromStatus': 'SUBMITTED',
            'toStatus': 'REJECTED',
            'by': {'id': 'm1', 'fullName': 'Mia Manager'},
            'at': '2026-10-01T11:00:00+06:00',
            'reason': 'Wrong kitchen',
          },
          {'event': 'ESCALATED', 'by': null, 'at': '2026-10-01T12:00:00Z', 'reason': null},
        ]));

    final result = await TaskRemoteDataSource(api).fetchHistory('t1');

    final entries = (result as Ok<List<HistoryEntry>>).value;
    expect(entries[0], HistoryEntry(
      event: HistoryEvent.rejected,
      byName: 'Mia Manager',
      at: DateTime.utc(2026, 10, 1, 5),
      reason: 'Wrong kitchen',
    ));
    expect(entries[0].at.isUtc, isTrue);
    expect(entries[1], HistoryEntry(event: null, byName: '', at: DateTime.utc(2026, 10, 1, 12)));
  });
}
