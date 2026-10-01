import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';

void main() {
  late AppDatabase db;
  late SyncQueue queue;
  late DateTime now;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 1, 9);
    queue = SyncQueue(db, now: () => now);
  });

  tearDown(() => db.close());

  Future<List<SyncOperationRow>> queued() {
    final query = db.select(db.localSyncOperations)..orderBy([(o) => OrderingTerm(expression: o.createdAt)]);
    return query.get();
  }

  Future<void> update(String entityId, Map<String, Object?> payload) => queue.add(
        entity: SyncEntity.taskResponse,
        entityId: entityId,
        taskId: 't1',
        operation: SyncOperation.update,
        payload: payload,
      );

  test('adds a PENDING operation with a new ID, the time and the JSON payload', () async {
    await queue.add(
      entity: SyncEntity.task,
      entityId: 't1',
      taskId: 't1',
      operation: SyncOperation.start,
      payload: {'version': 3},
    );

    final row = (await queued()).single;

    expect(row.id, hasLength(36));
    expect(row.entityType, 'Task');
    expect(row.entityId, 't1');
    expect(row.taskId, 't1');
    expect(row.operation, 'START');
    expect(jsonDecode(row.payload), {'version': 3});
    expect(row.createdAt.toUtc(), DateTime.utc(2026, 10, 1, 9));
    expect(row.status, 'PENDING');
    expect(row.retryCount, 0);
    expect(row.lastError, isNull);
  });

  test('a new update of the same record replaces the pending one and moves to the end', () async {
    await update('r1', {'textValue': 'a'});
    now = now.add(const Duration(minutes: 1));
    await update('r2', {'textValue': 'other'});
    now = now.add(const Duration(minutes: 1));
    await update('r1', {'textValue': 'ab'});

    final rows = await queued();

    expect(rows.map((o) => o.entityId), ['r2', 'r1']);
    expect(jsonDecode(rows.last.payload), {'textValue': 'ab'});
  });

  test('an update being sent or failed is kept; the new one is added after it', () async {
    await update('r1', {'textValue': 'a'});
    await db.update(db.localSyncOperations).write(const LocalSyncOperationsCompanion(status: Value('FAILED')));
    now = now.add(const Duration(minutes: 1));
    await update('r1', {'textValue': 'ab'});

    final rows = await queued();

    expect(rows.map((o) => o.status), ['FAILED', 'PENDING']);
    expect(jsonDecode(rows.last.payload), {'textValue': 'ab'});
  });

  test('other operations are never merged', () async {
    for (final operation in [SyncOperation.create, SyncOperation.delete]) {
      await queue.add(entity: SyncEntity.evidence, entityId: 'e1', taskId: 't1', operation: operation);
    }
    await queue.add(entity: SyncEntity.evidence, entityId: 'e1', taskId: 't1', operation: SyncOperation.create);

    expect(await queued(), hasLength(3));
  });

  test('a change and its queue entry are rolled back together', () async {
    await expectLater(
      db.transaction(() async {
        await update('r1', {'textValue': 'a'});
        throw StateError('saving the change failed');
      }),
      throwsStateError,
    );

    expect(await queued(), isEmpty);
  });

  test('removePending removes only a PENDING operation of that record', () async {
    await queue.add(entity: SyncEntity.evidence, entityId: 'e1', taskId: 't1', operation: SyncOperation.create);
    await queue.add(entity: SyncEntity.evidence, entityId: 'e2', taskId: 't1', operation: SyncOperation.create);

    final removed = await queue.removePending(
      entity: SyncEntity.evidence,
      entityId: 'e1',
      operation: SyncOperation.create,
    );
    final again = await queue.removePending(
      entity: SyncEntity.evidence,
      entityId: 'e1',
      operation: SyncOperation.create,
    );

    expect(removed, isTrue);
    expect(again, isFalse);
    expect((await queued()).map((o) => o.entityId), ['e2']);
  });
}
