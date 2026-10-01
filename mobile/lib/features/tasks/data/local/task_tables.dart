import 'package:drift/drift.dart';

/// Tasks stored on the device (copies of the server's tasks).
@DataClassName('TaskRow')
class LocalTasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get priority => text()();
  TextColumn get status => text()();
  DateTimeColumn get dueDate => dateTime()();
  TextColumn get createdById => text()();
  TextColumn get createdByName => text()();
  TextColumn get reviewerId => text()();
  TextColumn get reviewerName => text()();
  TextColumn get assigneeId => text().nullable()();
  TextColumn get assigneeName => text().nullable()();
  IntColumn get version => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RequirementRow')
class LocalRequirements extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(LocalTasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get type => text()();
  BoolColumn get isRequired => boolean()();
  IntColumn get position => integer()();
  TextColumn get unit => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RequirementOptionRow')
class LocalRequirementOptions extends Table {
  TextColumn get id => text()();
  TextColumn get requirementId => text().references(LocalRequirements, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The latest review of a task (task 7.8a), from the sync pull.
@DataClassName('TaskReviewRow')
class LocalTaskReviews extends Table {
  TextColumn get taskId => text().references(LocalTasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get result => text()();
  TextColumn get reason => text().nullable()();
  TextColumn get reviewerName => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// Marked requirements as a JSON object: requirement ID -> comment.
  TextColumn get markedRequirements => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {taskId};
}
