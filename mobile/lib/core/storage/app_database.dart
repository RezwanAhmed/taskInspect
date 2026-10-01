import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:taskinspect/core/synchronization/sync_queue_table.dart';
import 'package:taskinspect/core/synchronization/sync_state_table.dart';
import 'package:taskinspect/features/evidence/data/local/evidence_tables.dart';
import 'package:taskinspect/features/requirements/data/local/response_tables.dart';
import 'package:taskinspect/features/tasks/data/local/task_tables.dart';

part 'app_database.g.dart';

/// The app's local SQLite database — the source of truth for the UI, so
/// the app works the same online and offline (ADR-0004).
///
/// Every schema change raises [schemaVersion] and adds a step to
/// [migration], because devices keep their database between app updates.
@DriftDatabase(tables: [LocalTasks, LocalRequirements, LocalRequirementOptions, LocalResponses, LocalEvidence, LocalSyncOperations, LocalSyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            // Version 1 had no tables yet.
            await migrator.createTable(localTasks);
            await migrator.createTable(localRequirements);
            await migrator.createTable(localRequirementOptions);
          }
          if (from < 3) {
            await migrator.createTable(localResponses);
          }
          if (from < 4) {
            // Created with every current column, including file_name.
            await migrator.createTable(localEvidence);
          } else if (from < 5) {
            await migrator.addColumn(localEvidence, localEvidence.fileName);
          }
          if (from < 6) {
            await migrator.createTable(localSyncOperations);
          }
          if (from < 7) {
            await migrator.createTable(localSyncState);
          }
        },
        beforeOpen: (details) async {
          // SQLite does not check foreign keys unless asked to.
          await customStatement('PRAGMA foreign_keys = ON');
          // The background sync (task 6.11) opens its own connection: wait
          // for its writes instead of failing with "database is locked",
          // and let reads go on while it writes.
          await customStatement('PRAGMA busy_timeout = 5000');
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );

  /// Deletes all user data (tasks, requirements, answers, sync queue and state),
  /// e.g. at sign out, so the next user of the device cannot see it.
  Future<void> clearUserData() {
    return transaction(() async {
      for (final table in allTables.toList().reversed) {
        await delete(table).go();
      }
    });
  }

  static QueryExecutor _openDefault() => driftDatabase(name: 'taskinspect');
}
