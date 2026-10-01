import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:taskinspect/features/tasks/data/local/task_tables.dart';

part 'app_database.g.dart';

/// The app's local SQLite database — the source of truth for the UI, so
/// the app works the same online and offline (ADR-0004).
///
/// Every schema change raises [schemaVersion] and adds a step to
/// [migration], because devices keep their database between app updates.
@DriftDatabase(tables: [LocalTasks, LocalRequirements, LocalRequirementOptions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  @override
  int get schemaVersion => 2;

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
        },
        beforeOpen: (details) async {
          // SQLite does not check foreign keys unless asked to.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openDefault() => driftDatabase(name: 'taskinspect');
}
