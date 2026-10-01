import 'package:drift/drift.dart';

/// Changes made on the device that still have to reach the server, in the
/// order they were made (docs/architecture.md, "Sync Queue").
///
/// No foreign keys: a queued change must survive even if its task or
/// record is removed from the device, so it is never lost unsent.
@DataClassName('SyncOperationRow')
class LocalSyncOperations extends Table {
  /// UUID created on the device; the server uses it as idempotency key.
  TextColumn get id => text()();

  /// What changed, e.g. `TaskResponse`.
  TextColumn get entityType => text()();

  /// Which record changed.
  TextColumn get entityId => text()();

  /// The task the change belongs to; later changes of a task wait while
  /// an earlier one has failed.
  TextColumn get taskId => text()();

  /// CREATE, UPDATE, DELETE or a task action (START, SUBMIT).
  TextColumn get operation => text()();

  /// The data to send, as JSON.
  TextColumn get payload => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Why the last attempt failed, e.g. `NETWORK_TIMEOUT`.
  TextColumn get lastError => text().nullable()();

  /// PENDING, SYNCING or FAILED. Once the server has applied an operation
  /// (SYNCED), the SyncManager removes it from the queue.
  TextColumn get status => text().withDefault(const Constant('PENDING'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
