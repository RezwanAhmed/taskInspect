import 'package:drift/drift.dart';
import 'package:taskinspect/features/tasks/data/local/task_tables.dart';

/// The worker's answers stored on the device, one per requirement.
@DataClassName('ResponseRow')
class LocalResponses extends Table {
  TextColumn get requirementId => text().references(LocalRequirements, #id, onDelete: KeyAction.cascade)();
  TextColumn get taskId => text().references(LocalTasks, #id, onDelete: KeyAction.cascade)();
  BoolColumn get booleanValue => boolean().nullable()();
  TextColumn get textValue => text().nullable()();
  RealColumn get numberValue => real().nullable()();

  /// Selected option IDs as a JSON array.
  TextColumn get selectedOptionIds => text().withDefault(const Constant('[]'))();
  TextColumn get comment => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  /// PENDING until the answer has reached the server (Phase 6), then SYNCED.
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();

  @override
  Set<Column<Object>> get primaryKey => {requirementId};
}
