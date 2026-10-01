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

  /// Original name of a picked document; `null` for photos.
  TextColumn get fileName => text().nullable()();

  /// The file's upload (task 6.12): PENDING -> UPLOADING -> UPLOADED, or
  /// FAILED with [uploadError] (retried like the sync queue).
  TextColumn get uploadStatus => text().withDefault(const Constant('PENDING'))();

  IntColumn get uploadRetryCount => integer().withDefault(const Constant(0))();

  /// Why the last upload failed: NETWORK_ERROR / SERVER_ERROR (retried
  /// automatically), FILE_MISSING or the server's error code.
  TextColumn get uploadError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
