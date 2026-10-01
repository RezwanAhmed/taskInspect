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

  test('starts at schema version 1', () {
    expect(database.schemaVersion, 1);
  });
}
