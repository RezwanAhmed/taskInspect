import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/storage/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<void> queue(String id, DateTime createdAt, {String taskId = 't1'}) {
    return database.into(database.localSyncOperations).insert(LocalSyncOperationsCompanion.insert(
          id: id,
          entityType: 'TaskResponse',
          entityId: 'r1',
          taskId: taskId,
          operation: 'UPDATE',
          createdAt: createdAt,
        ));
  }

  test('a new operation is PENDING with no retries, no error and an empty payload', () async {
    await queue('op1', DateTime.utc(2026, 10, 1, 9, 30));

    final row = await database.select(database.localSyncOperations).getSingle();

    expect(row.status, 'PENDING');
    expect(row.retryCount, 0);
    expect(row.lastError, isNull);
    expect(row.payload, '{}');
    expect(row.createdAt.toUtc(), DateTime.utc(2026, 10, 1, 9, 30));
  });

  test('keeps the payload, retry count and last error', () async {
    await database.into(database.localSyncOperations).insert(LocalSyncOperationsCompanion.insert(
          id: 'op1',
          entityType: 'TaskResponse',
          entityId: 'r1',
          taskId: 't1',
          operation: 'UPDATE',
          createdAt: DateTime.utc(2026, 10, 1),
          payload: const Value('{"booleanValue":true}'),
          retryCount: const Value(2),
          lastError: const Value('NETWORK_TIMEOUT'),
          status: const Value('FAILED'),
        ));

    final row = await database.select(database.localSyncOperations).getSingle();

    expect(row.payload, '{"booleanValue":true}');
    expect(row.retryCount, 2);
    expect(row.lastError, 'NETWORK_TIMEOUT');
    expect(row.status, 'FAILED');
  });

  test('an operation ID can be queued only once', () async {
    await queue('op1', DateTime.utc(2026, 10, 1));

    await expectLater(queue('op1', DateTime.utc(2026, 10, 2)), throwsA(isA<SqliteException>()));
  });

  test('operations of tasks that are not on the device are kept', () async {
    // No foreign keys: an unsent change must never be dropped with its task.
    await queue('op1', DateTime.utc(2026, 10, 1), taskId: 'unknown-task');

    expect(await database.select(database.localSyncOperations).get(), hasLength(1));
  });

  test('operations can be read in the order they were made', () async {
    await queue('later', DateTime.utc(2026, 10, 1, 10));
    await queue('earlier', DateTime.utc(2026, 10, 1, 9));

    final query = database.select(database.localSyncOperations)
      ..orderBy([(o) => OrderingTerm(expression: o.createdAt)]);
    final ids = (await query.get()).map((row) => row.id);

    expect(ids, ['earlier', 'later']);
  });
}
