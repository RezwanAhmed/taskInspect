import 'package:drift/drift.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';

/// Remembers whose data the local database holds. Then an expired session
/// can keep the user's unsent changes until they sign in again (task 6.9),
/// while another user signing in on the same device never sees them.
///
/// Stored in the sync state table, so it is cleared with the data.
class LocalDataOwner {
  const LocalDataOwner(this._db);

  static const key = 'ownerId';
  static const emailKey = 'ownerEmail';

  final AppDatabase _db;

  Future<String?> read() {
    return (_db.select(_db.localSyncState)..where((s) => s.key.equals(key)))
        .map((row) => row.value)
        .getSingleOrNull();
  }

  /// Makes the local data [userId]'s. Data of another user is removed first
  /// with [clear]. Data without an owner (from before owners were recorded)
  /// is kept: until then it was always removed at sign out, so it can only
  /// be the current user's.
  ///
  /// [email] is kept too, so the login screen can say whose unsynced
  /// changes are on the device (task 6.13c).
  Future<void> claim(String userId, {String? email, required Future<void> Function() clear}) async {
    final owner = await read();
    if (owner != null && owner != userId) {
      await clear();
    }
    await _db.into(_db.localSyncState).insertOnConflictUpdate(LocalSyncStateCompanion.insert(key: key, value: userId));
    if (email != null) {
      await _db
          .into(_db.localSyncState)
          .insertOnConflictUpdate(LocalSyncStateCompanion.insert(key: emailKey, value: email));
    }
  }

  /// The owner's email and how many changes and files are not on the
  /// server yet; `null` when there are none. The email is `null` when the
  /// data was claimed before emails were kept (then the login screen
  /// warns about "the previous user").
  Future<({String? email, int count})?> unsynced() async {
    final email = await (_db.select(_db.localSyncState)..where((s) => s.key.equals(emailKey)))
        .map((row) => row.value)
        .getSingleOrNull();
    final operations = await _db.select(_db.localSyncOperations).get();
    final queuedFiles = {
      for (final operation in operations)
        if (operation.entityType == SyncEntity.evidence.apiName) operation.entityId,
    };
    final files = await (_db.select(_db.localEvidence)
          ..where((e) => e.uploadStatus.equals('UPLOADED').not() & e.id.isNotIn(queuedFiles)))
        .get();
    final count = operations.length + files.length;
    return count == 0 ? null : (email: email, count: count);
  }
}
