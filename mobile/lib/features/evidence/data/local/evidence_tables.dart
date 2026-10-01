import 'package:drift/drift.dart';
import 'package:taskinspect/features/tasks/data/local/task_tables.dart';

/// Evidence files stored on the device.
@DataClassName('EvidenceRow')
class LocalEvidence extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(LocalTasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get requirementId => text().references(LocalRequirements, #id, onDelete: KeyAction.cascade)();
  TextColumn get localPath => text()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer()();
  DateTimeColumn get createdAt => dateTime()();

  /// PENDING until the file is uploaded, then UPLOADED.
  TextColumn get uploadStatus => text().withDefault(const Constant('PENDING'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
