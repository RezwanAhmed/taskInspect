import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/storage/local_data_owner.dart';

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
}
