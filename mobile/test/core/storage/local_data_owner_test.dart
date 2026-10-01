import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/storage/local_data_owner.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';

void main() {
  late AppDatabase db;
  late LocalDataOwner owner;
  late int cleared;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    owner = LocalDataOwner(db);
    cleared = 0;
  });

  tearDown(() => db.close());

  Future<void> claim(String userId) => owner.claim(userId, clear: () async {
        cleared++;
        await db.clearUserData();
      });

  test('the first user claims the data', () async {
    await claim('u1');

    expect(await owner.read(), 'u1');
    expect(cleared, 0);
  });

  test('the same user signing in again keeps the data', () async {
    await claim('u1');
    await claim('u1');

    expect(cleared, 0);
  });

  test('another user signing in removes the data of the previous one first', () async {
    await claim('u1');

    await claim('u2');

    expect(cleared, 1);
    expect(await owner.read(), 'u2');
  });

  test('sign out removes the owner with the data', () async {
    await claim('u1');

    await db.clearUserData();

    expect(await owner.read(), isNull);
  });

  test("the owner's email is kept, with the number of changes not on the server yet", () async {
    await owner.claim('u1', email: 'worker@example.com', clear: () async {});
    expect(await owner.unsynced(), isNull, reason: 'nothing unsent');

    await db.customStatement(
        "INSERT INTO local_tasks VALUES ('t1', 'Kitchen', NULL, 'HIGH', 'IN_PROGRESS', 0, 'm', 'M', 'm', 'M', 'u1', 'W', 1, 0)");
    await db.customStatement("INSERT INTO local_requirements VALUES ('r1', 't1', 'Photo', NULL, 'PHOTO', 1, 0, NULL)");
    await SyncQueue(db).add(entity: SyncEntity.taskResponse, entityId: 'r1', taskId: 't1', operation: SyncOperation.update);
    for (final (id, status) in [('e1', 'PENDING'), ('e2', 'UPLOADED'), ('e3', 'FAILED')]) {
      await db.into(db.localEvidence).insert(LocalEvidenceCompanion.insert(
            id: id,
            taskId: 't1',
            requirementId: 'r1',
            localPath: '/$id.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 5,
            createdAt: DateTime.utc(2026, 10, 1),
            uploadStatus: Value(status),
          ));
    }
    await SyncQueue(db).add(entity: SyncEntity.evidence, entityId: 'e1', taskId: 't1', operation: SyncOperation.create);

    final unsynced = await owner.unsynced();

    expect(unsynced?.email, 'worker@example.com');
    expect(unsynced?.count, 3, reason: 'answer + e1 (counted once, its CREATE) + e3; e2 is uploaded');
  });

  test('data claimed before emails were kept: still reported, with an unknown owner', () async {
    await owner.claim('u1', clear: () async {});
    await db.customStatement(
        "INSERT INTO local_tasks VALUES ('t1', 'Kitchen', NULL, 'HIGH', 'IN_PROGRESS', 0, 'm', 'M', 'm', 'M', 'u1', 'W', 1, 0)");
    await SyncQueue(db).add(entity: SyncEntity.task, entityId: 't1', taskId: 't1', operation: SyncOperation.start);

    final unsynced = await owner.unsynced();

    expect(unsynced?.email, isNull);
    expect(unsynced?.count, 1);
  });
}
