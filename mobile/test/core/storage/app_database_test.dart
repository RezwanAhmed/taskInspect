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

  test('is at schema version 3', () {
    expect(database.schemaVersion, 3);
  });

  test('a version 1 database (no tables) is upgraded with all tables', () async {
    final old = AppDatabase(NativeDatabase.memory(setup: (raw) => raw.execute('PRAGMA user_version = 1')));
    addTearDown(old.close);

    final tables = await old
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'local_%' ORDER BY name")
        .map((row) => row.read<String>('name'))
        .get();

    expect(tables, ['local_requirement_options', 'local_requirements', 'local_responses', 'local_tasks']);
    final version = await old.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 3);
  });

  test('clearUserData removes every row', () async {
    await database.customStatement(
        "INSERT INTO local_tasks VALUES ('t1', 'Kitchen', NULL, 'HIGH', 'ASSIGNED', 0, 'm', 'M', 'm', 'M', NULL, NULL, 1, 0)");
    await database.customStatement(
        "INSERT INTO local_requirements VALUES ('r1', 't1', 'Ok?', NULL, 'YES_NO', 1, 0, NULL)");

    await database.clearUserData();

    for (final table in ['local_tasks', 'local_requirements', 'local_responses']) {
      final count = await database.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle();
      expect(count.read<int>('c'), 0, reason: table);
    }
  });
}
