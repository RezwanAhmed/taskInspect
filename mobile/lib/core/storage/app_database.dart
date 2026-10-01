import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// The app's local SQLite database — the source of truth for the UI, so
/// the app works the same online and offline (ADR-0004).
///
/// Tables are added by the tasks that need them (tasks and requirements
/// in Phase 5, the sync queue in Phase 6). Every schema change raises
/// [schemaVersion] and adds a step to [migration].
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        beforeOpen: (details) async {
          // SQLite does not check foreign keys unless asked to.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openDefault() => driftDatabase(name: 'taskinspect');
}
