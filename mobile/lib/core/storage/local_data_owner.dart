import 'package:taskinspect/core/storage/app_database.dart';

/// Remembers whose data the local database holds. Then an expired session
/// can keep the user's unsent changes until they sign in again (task 6.9),
/// while another user signing in on the same device never sees them.
///
/// Stored in the sync state table, so it is cleared with the data.
class LocalDataOwner {
  const LocalDataOwner(this._db);

  static const key = 'ownerId';

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
  Future<void> claim(String userId, {required Future<void> Function() clear}) async {
    final owner = await read();
    if (owner != null && owner != userId) {
      await clear();
    }
    await _db.into(_db.localSyncState).insertOnConflictUpdate(LocalSyncStateCompanion.insert(key: key, value: userId));
  }
}
