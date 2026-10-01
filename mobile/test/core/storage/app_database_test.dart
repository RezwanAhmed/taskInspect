import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/storage/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('opens with foreign keys switched on', () async {
    final row = await database.customSelect('PRAGMA foreign_keys').getSingle();

    expect(row.read<int>('foreign_keys'), 1);
  });

  test('runs statements in a transaction', () async {
    await database.customStatement('CREATE TABLE t (v INTEGER)');

    await expectLater(
      database.transaction(() async {
        await database.customStatement('INSERT INTO t VALUES (1)');
        throw StateError('roll back');
      }),
      throwsStateError,
    );

    final count = await database.customSelect('SELECT COUNT(*) AS c FROM t').getSingle();
    expect(count.read<int>('c'), 0);
  });

  test('is at schema version 9', () {
    expect(database.schemaVersion, 9);
  });

  test('a version 1 database (no tables) is upgraded with all tables', () async {
    final old = AppDatabase(NativeDatabase.memory(setup: (raw) => raw.execute('PRAGMA user_version = 1')));
    addTearDown(old.close);

    final tables = await old
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'local_%' ORDER BY name")
        .map((row) => row.read<String>('name'))
        .get();

    expect(tables, [
      'local_evidence',
      'local_requirement_options',
      'local_requirements',
      'local_responses',
      'local_sync_operations',
      'local_sync_state',
      'local_task_reviews',
      'local_tasks',
    ]);
    final version = await old.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 9);
  });

  test('a version 4 database gets the evidence file_name column', () async {
    final old = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw
        ..execute('CREATE TABLE local_evidence (id TEXT NOT NULL PRIMARY KEY, task_id TEXT NOT NULL, '
            'requirement_id TEXT NOT NULL, local_path TEXT NOT NULL, mime_type TEXT NOT NULL, '
            "size_bytes INTEGER NOT NULL, created_at INTEGER NOT NULL, upload_status TEXT NOT NULL DEFAULT 'PENDING')")
        ..execute("INSERT INTO local_evidence VALUES ('e1', 't1', 'r1', '/x.jpg', 'image/jpeg', 5, 0, 'PENDING')")
        ..execute('PRAGMA user_version = 4');
    }));
    addTearDown(old.close);

    final columns = await old
        .customSelect('PRAGMA table_info(local_evidence)')
        .map((row) => row.read<String>('name'))
        .get();
    final kept = await old.customSelect('SELECT id, file_name FROM local_evidence').getSingle();

    expect(columns, contains('file_name'));
    expect(kept.read<String>('id'), 'e1');
    expect(kept.read<String?>('file_name'), isNull);
  });

  test('a version 5 database gets the sync queue and keeps its data', () async {
    final old = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw
        ..execute('CREATE TABLE local_evidence (id TEXT NOT NULL PRIMARY KEY, task_id TEXT NOT NULL, '
            'requirement_id TEXT NOT NULL, local_path TEXT NOT NULL, mime_type TEXT NOT NULL, '
            'size_bytes INTEGER NOT NULL, created_at INTEGER NOT NULL, file_name TEXT, '
            "upload_status TEXT NOT NULL DEFAULT 'PENDING')")
        ..execute("INSERT INTO local_evidence VALUES ('e1', 't1', 'r1', '/x.pdf', 'application/pdf', 5, 0, 'a.pdf', 'PENDING')")
        ..execute('PRAGMA user_version = 5');
    }));
    addTearDown(old.close);

    final queued = await old.select(old.localSyncOperations).get();
    final kept = await old.customSelect('SELECT file_name FROM local_evidence').getSingle();

    expect(queued, isEmpty);
    expect(kept.read<String>('file_name'), 'a.pdf');
  });

  test('a version 6 database gets the sync state table', () async {
    // Like a real version 6 database: it has the evidence table.
    final old = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw
        ..execute('CREATE TABLE local_evidence (id TEXT NOT NULL PRIMARY KEY, task_id TEXT NOT NULL, '
            'requirement_id TEXT NOT NULL, local_path TEXT NOT NULL, mime_type TEXT NOT NULL, '
            'size_bytes INTEGER NOT NULL, created_at INTEGER NOT NULL, file_name TEXT, '
            "upload_status TEXT NOT NULL DEFAULT 'PENDING')")
        ..execute('PRAGMA user_version = 6');
    }));
    addTearDown(old.close);

    await old.into(old.localSyncState).insert(LocalSyncStateCompanion.insert(key: 'pullCursor', value: 'c1'));

    expect((await old.select(old.localSyncState).getSingle()).value, 'c1');
  });

  test('a version 7 database gets the upload queue columns and keeps its evidence', () async {
    final old = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw
        ..execute('CREATE TABLE local_evidence (id TEXT NOT NULL PRIMARY KEY, task_id TEXT NOT NULL, '
            'requirement_id TEXT NOT NULL, local_path TEXT NOT NULL, mime_type TEXT NOT NULL, '
            'size_bytes INTEGER NOT NULL, created_at INTEGER NOT NULL, file_name TEXT, '
            "upload_status TEXT NOT NULL DEFAULT 'PENDING')")
        ..execute("INSERT INTO local_evidence VALUES ('e1', 't1', 'r1', '/x.jpg', 'image/jpeg', 5, 0, NULL, 'PENDING')")
        // Like a real version 7 database: it has the sync state table.
        ..execute('CREATE TABLE local_sync_state (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)')
        ..execute('PRAGMA user_version = 7');
    }));
    addTearDown(old.close);

    final kept = await old.customSelect('SELECT id, upload_retry_count, upload_error FROM local_evidence').getSingle();

    expect(kept.read<String>('id'), 'e1');
    expect(kept.read<int>('upload_retry_count'), 0);
    expect(kept.read<String?>('upload_error'), isNull);
  });

  test('a version 8 database gets the review table and loads everything again at the next pull', () async {
    final old = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw
        ..execute('CREATE TABLE local_evidence (id TEXT NOT NULL PRIMARY KEY, task_id TEXT NOT NULL, '
            'requirement_id TEXT NOT NULL, local_path TEXT NOT NULL, mime_type TEXT NOT NULL, '
            'size_bytes INTEGER NOT NULL, created_at INTEGER NOT NULL, file_name TEXT, '
            "upload_status TEXT NOT NULL DEFAULT 'PENDING', upload_retry_count INTEGER NOT NULL DEFAULT 0, "
            'upload_error TEXT)')
        ..execute('CREATE TABLE local_sync_state (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)')
        ..execute("INSERT INTO local_sync_state VALUES ('pullCursor', 'c1'), ('ownerId', 'u1')")
        ..execute('PRAGMA user_version = 8');
    }));
    addTearDown(old.close);

    final keys = await old.select(old.localSyncState).map((row) => row.key).get();

    expect(keys, ['ownerId'], reason: 'the cursor is gone, the owner stays');
    expect(await old.select(old.localTaskReviews).get(), isEmpty);
  });

  test('clearUserData removes every row', () async {
    await database.customStatement(
        "INSERT INTO local_tasks VALUES ('t1', 'Kitchen', NULL, 'HIGH', 'ASSIGNED', 0, 'm', 'M', 'm', 'M', NULL, NULL, 1, 0)");
    await database.customStatement(
        "INSERT INTO local_requirements VALUES ('r1', 't1', 'Ok?', NULL, 'YES_NO', 1, 0, NULL)");
    await database.into(database.localSyncOperations).insert(LocalSyncOperationsCompanion.insert(
          id: 'op1',
          entityType: 'TaskResponse',
          entityId: 'r1',
          taskId: 't1',
          operation: 'UPDATE',
          createdAt: DateTime.utc(2026, 10, 1),
        ));
    await database.into(database.localSyncState).insert(LocalSyncStateCompanion.insert(key: 'pullCursor', value: 'c1'));

    await database.clearUserData();

    for (final table in ['local_tasks', 'local_requirements', 'local_responses', 'local_evidence', 'local_sync_operations', 'local_sync_state']) {
      final count = await database.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle();
      expect(count.read<int>('c'), 0, reason: table);
    }
  });
}
