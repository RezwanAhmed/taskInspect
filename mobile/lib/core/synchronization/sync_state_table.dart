import 'package:drift/drift.dart';

/// Small values the synchronization keeps between app starts, e.g. the
/// cursor of the last pull. Cleared at sign out, so the next user starts
/// with a full pull.
@DataClassName('SyncStateRow')
class LocalSyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
