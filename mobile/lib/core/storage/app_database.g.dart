// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalTasksTable extends LocalTasks
    with TableInfo<$LocalTasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByIdMeta = const VerificationMeta(
    'createdById',
  );
  @override
  late final GeneratedColumn<String> createdById = GeneratedColumn<String>(
    'created_by_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByNameMeta = const VerificationMeta(
    'createdByName',
  );
  @override
  late final GeneratedColumn<String> createdByName = GeneratedColumn<String>(
    'created_by_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewerIdMeta = const VerificationMeta(
    'reviewerId',
  );
  @override
  late final GeneratedColumn<String> reviewerId = GeneratedColumn<String>(
    'reviewer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewerNameMeta = const VerificationMeta(
    'reviewerName',
  );
  @override
  late final GeneratedColumn<String> reviewerName = GeneratedColumn<String>(
    'reviewer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assigneeIdMeta = const VerificationMeta(
    'assigneeId',
  );
  @override
  late final GeneratedColumn<String> assigneeId = GeneratedColumn<String>(
    'assignee_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assigneeNameMeta = const VerificationMeta(
    'assigneeName',
  );
  @override
  late final GeneratedColumn<String> assigneeName = GeneratedColumn<String>(
    'assignee_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    priority,
    status,
    dueDate,
    createdById,
    createdByName,
    reviewerId,
    reviewerName,
    assigneeId,
    assigneeName,
    version,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('created_by_id')) {
      context.handle(
        _createdByIdMeta,
        createdById.isAcceptableOrUnknown(
          data['created_by_id']!,
          _createdByIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByIdMeta);
    }
    if (data.containsKey('created_by_name')) {
      context.handle(
        _createdByNameMeta,
        createdByName.isAcceptableOrUnknown(
          data['created_by_name']!,
          _createdByNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByNameMeta);
    }
    if (data.containsKey('reviewer_id')) {
      context.handle(
        _reviewerIdMeta,
        reviewerId.isAcceptableOrUnknown(data['reviewer_id']!, _reviewerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewerIdMeta);
    }
    if (data.containsKey('reviewer_name')) {
      context.handle(
        _reviewerNameMeta,
        reviewerName.isAcceptableOrUnknown(
          data['reviewer_name']!,
          _reviewerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reviewerNameMeta);
    }
    if (data.containsKey('assignee_id')) {
      context.handle(
        _assigneeIdMeta,
        assigneeId.isAcceptableOrUnknown(data['assignee_id']!, _assigneeIdMeta),
      );
    }
    if (data.containsKey('assignee_name')) {
      context.handle(
        _assigneeNameMeta,
        assigneeName.isAcceptableOrUnknown(
          data['assignee_name']!,
          _assigneeNameMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      )!,
      createdById: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_id'],
      )!,
      createdByName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_name'],
      )!,
      reviewerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reviewer_id'],
      )!,
      reviewerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reviewer_name'],
      )!,
      assigneeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assignee_id'],
      ),
      assigneeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assignee_name'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalTasksTable createAlias(String alias) {
    return $LocalTasksTable(attachedDatabase, alias);
  }
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  final String id;
  final String title;
  final String? description;
  final String priority;
  final String status;
  final DateTime dueDate;
  final String createdById;
  final String createdByName;
  final String reviewerId;
  final String reviewerName;
  final String? assigneeId;
  final String? assigneeName;
  final int version;
  final DateTime updatedAt;
  const TaskRow({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.createdById,
    required this.createdByName,
    required this.reviewerId,
    required this.reviewerName,
    this.assigneeId,
    this.assigneeName,
    required this.version,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['priority'] = Variable<String>(priority);
    map['status'] = Variable<String>(status);
    map['due_date'] = Variable<DateTime>(dueDate);
    map['created_by_id'] = Variable<String>(createdById);
    map['created_by_name'] = Variable<String>(createdByName);
    map['reviewer_id'] = Variable<String>(reviewerId);
    map['reviewer_name'] = Variable<String>(reviewerName);
    if (!nullToAbsent || assigneeId != null) {
      map['assignee_id'] = Variable<String>(assigneeId);
    }
    if (!nullToAbsent || assigneeName != null) {
      map['assignee_name'] = Variable<String>(assigneeName);
    }
    map['version'] = Variable<int>(version);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalTasksCompanion toCompanion(bool nullToAbsent) {
    return LocalTasksCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      priority: Value(priority),
      status: Value(status),
      dueDate: Value(dueDate),
      createdById: Value(createdById),
      createdByName: Value(createdByName),
      reviewerId: Value(reviewerId),
      reviewerName: Value(reviewerName),
      assigneeId: assigneeId == null && nullToAbsent
          ? const Value.absent()
          : Value(assigneeId),
      assigneeName: assigneeName == null && nullToAbsent
          ? const Value.absent()
          : Value(assigneeName),
      version: Value(version),
      updatedAt: Value(updatedAt),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      priority: serializer.fromJson<String>(json['priority']),
      status: serializer.fromJson<String>(json['status']),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
      createdById: serializer.fromJson<String>(json['createdById']),
      createdByName: serializer.fromJson<String>(json['createdByName']),
      reviewerId: serializer.fromJson<String>(json['reviewerId']),
      reviewerName: serializer.fromJson<String>(json['reviewerName']),
      assigneeId: serializer.fromJson<String?>(json['assigneeId']),
      assigneeName: serializer.fromJson<String?>(json['assigneeName']),
      version: serializer.fromJson<int>(json['version']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'priority': serializer.toJson<String>(priority),
      'status': serializer.toJson<String>(status),
      'dueDate': serializer.toJson<DateTime>(dueDate),
      'createdById': serializer.toJson<String>(createdById),
      'createdByName': serializer.toJson<String>(createdByName),
      'reviewerId': serializer.toJson<String>(reviewerId),
      'reviewerName': serializer.toJson<String>(reviewerName),
      'assigneeId': serializer.toJson<String?>(assigneeId),
      'assigneeName': serializer.toJson<String?>(assigneeName),
      'version': serializer.toJson<int>(version),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TaskRow copyWith({
    String? id,
    String? title,
    Value<String?> description = const Value.absent(),
    String? priority,
    String? status,
    DateTime? dueDate,
    String? createdById,
    String? createdByName,
    String? reviewerId,
    String? reviewerName,
    Value<String?> assigneeId = const Value.absent(),
    Value<String?> assigneeName = const Value.absent(),
    int? version,
    DateTime? updatedAt,
  }) => TaskRow(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    dueDate: dueDate ?? this.dueDate,
    createdById: createdById ?? this.createdById,
    createdByName: createdByName ?? this.createdByName,
    reviewerId: reviewerId ?? this.reviewerId,
    reviewerName: reviewerName ?? this.reviewerName,
    assigneeId: assigneeId.present ? assigneeId.value : this.assigneeId,
    assigneeName: assigneeName.present ? assigneeName.value : this.assigneeName,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TaskRow copyWithCompanion(LocalTasksCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      priority: data.priority.present ? data.priority.value : this.priority,
      status: data.status.present ? data.status.value : this.status,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      createdById: data.createdById.present
          ? data.createdById.value
          : this.createdById,
      createdByName: data.createdByName.present
          ? data.createdByName.value
          : this.createdByName,
      reviewerId: data.reviewerId.present
          ? data.reviewerId.value
          : this.reviewerId,
      reviewerName: data.reviewerName.present
          ? data.reviewerName.value
          : this.reviewerName,
      assigneeId: data.assigneeId.present
          ? data.assigneeId.value
          : this.assigneeId,
      assigneeName: data.assigneeName.present
          ? data.assigneeName.value
          : this.assigneeName,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('dueDate: $dueDate, ')
          ..write('createdById: $createdById, ')
          ..write('createdByName: $createdByName, ')
          ..write('reviewerId: $reviewerId, ')
          ..write('reviewerName: $reviewerName, ')
          ..write('assigneeId: $assigneeId, ')
          ..write('assigneeName: $assigneeName, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    priority,
    status,
    dueDate,
    createdById,
    createdByName,
    reviewerId,
    reviewerName,
    assigneeId,
    assigneeName,
    version,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.priority == this.priority &&
          other.status == this.status &&
          other.dueDate == this.dueDate &&
          other.createdById == this.createdById &&
          other.createdByName == this.createdByName &&
          other.reviewerId == this.reviewerId &&
          other.reviewerName == this.reviewerName &&
          other.assigneeId == this.assigneeId &&
          other.assigneeName == this.assigneeName &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt);
}

class LocalTasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> priority;
  final Value<String> status;
  final Value<DateTime> dueDate;
  final Value<String> createdById;
  final Value<String> createdByName;
  final Value<String> reviewerId;
  final Value<String> reviewerName;
  final Value<String?> assigneeId;
  final Value<String?> assigneeName;
  final Value<int> version;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalTasksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.createdById = const Value.absent(),
    this.createdByName = const Value.absent(),
    this.reviewerId = const Value.absent(),
    this.reviewerName = const Value.absent(),
    this.assigneeId = const Value.absent(),
    this.assigneeName = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTasksCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    required String priority,
    required String status,
    required DateTime dueDate,
    required String createdById,
    required String createdByName,
    required String reviewerId,
    required String reviewerName,
    this.assigneeId = const Value.absent(),
    this.assigneeName = const Value.absent(),
    required int version,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       priority = Value(priority),
       status = Value(status),
       dueDate = Value(dueDate),
       createdById = Value(createdById),
       createdByName = Value(createdByName),
       reviewerId = Value(reviewerId),
       reviewerName = Value(reviewerName),
       version = Value(version),
       updatedAt = Value(updatedAt);
  static Insertable<TaskRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? priority,
    Expression<String>? status,
    Expression<DateTime>? dueDate,
    Expression<String>? createdById,
    Expression<String>? createdByName,
    Expression<String>? reviewerId,
    Expression<String>? reviewerName,
    Expression<String>? assigneeId,
    Expression<String>? assigneeName,
    Expression<int>? version,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (dueDate != null) 'due_date': dueDate,
      if (createdById != null) 'created_by_id': createdById,
      if (createdByName != null) 'created_by_name': createdByName,
      if (reviewerId != null) 'reviewer_id': reviewerId,
      if (reviewerName != null) 'reviewer_name': reviewerName,
      if (assigneeId != null) 'assignee_id': assigneeId,
      if (assigneeName != null) 'assignee_name': assigneeName,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<String>? priority,
    Value<String>? status,
    Value<DateTime>? dueDate,
    Value<String>? createdById,
    Value<String>? createdByName,
    Value<String>? reviewerId,
    Value<String>? reviewerName,
    Value<String?>? assigneeId,
    Value<String?>? assigneeName,
    Value<int>? version,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalTasksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (createdById.present) {
      map['created_by_id'] = Variable<String>(createdById.value);
    }
    if (createdByName.present) {
      map['created_by_name'] = Variable<String>(createdByName.value);
    }
    if (reviewerId.present) {
      map['reviewer_id'] = Variable<String>(reviewerId.value);
    }
    if (reviewerName.present) {
      map['reviewer_name'] = Variable<String>(reviewerName.value);
    }
    if (assigneeId.present) {
      map['assignee_id'] = Variable<String>(assigneeId.value);
    }
    if (assigneeName.present) {
      map['assignee_name'] = Variable<String>(assigneeName.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTasksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('dueDate: $dueDate, ')
          ..write('createdById: $createdById, ')
          ..write('createdByName: $createdByName, ')
          ..write('reviewerId: $reviewerId, ')
          ..write('reviewerName: $reviewerName, ')
          ..write('assigneeId: $assigneeId, ')
          ..write('assigneeName: $assigneeName, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalRequirementsTable extends LocalRequirements
    with TableInfo<$LocalRequirementsTable, RequirementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRequirementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isRequiredMeta = const VerificationMeta(
    'isRequired',
  );
  @override
  late final GeneratedColumn<bool> isRequired = GeneratedColumn<bool>(
    'is_required',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_required" IN (0, 1))',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    title,
    description,
    type,
    isRequired,
    position,
    unit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_requirements';
  @override
  VerificationContext validateIntegrity(
    Insertable<RequirementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('is_required')) {
      context.handle(
        _isRequiredMeta,
        isRequired.isAcceptableOrUnknown(data['is_required']!, _isRequiredMeta),
      );
    } else if (isInserting) {
      context.missing(_isRequiredMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RequirementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RequirementRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      isRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_required'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
    );
  }

  @override
  $LocalRequirementsTable createAlias(String alias) {
    return $LocalRequirementsTable(attachedDatabase, alias);
  }
}

class RequirementRow extends DataClass implements Insertable<RequirementRow> {
  final String id;
  final String taskId;
  final String title;
  final String? description;
  final String type;
  final bool isRequired;
  final int position;
  final String? unit;
  const RequirementRow({
    required this.id,
    required this.taskId,
    required this.title,
    this.description,
    required this.type,
    required this.isRequired,
    required this.position,
    this.unit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['type'] = Variable<String>(type);
    map['is_required'] = Variable<bool>(isRequired);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    return map;
  }

  LocalRequirementsCompanion toCompanion(bool nullToAbsent) {
    return LocalRequirementsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      type: Value(type),
      isRequired: Value(isRequired),
      position: Value(position),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
    );
  }

  factory RequirementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RequirementRow(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      type: serializer.fromJson<String>(json['type']),
      isRequired: serializer.fromJson<bool>(json['isRequired']),
      position: serializer.fromJson<int>(json['position']),
      unit: serializer.fromJson<String?>(json['unit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'type': serializer.toJson<String>(type),
      'isRequired': serializer.toJson<bool>(isRequired),
      'position': serializer.toJson<int>(position),
      'unit': serializer.toJson<String?>(unit),
    };
  }

  RequirementRow copyWith({
    String? id,
    String? taskId,
    String? title,
    Value<String?> description = const Value.absent(),
    String? type,
    bool? isRequired,
    int? position,
    Value<String?> unit = const Value.absent(),
  }) => RequirementRow(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    type: type ?? this.type,
    isRequired: isRequired ?? this.isRequired,
    position: position ?? this.position,
    unit: unit.present ? unit.value : this.unit,
  );
  RequirementRow copyWithCompanion(LocalRequirementsCompanion data) {
    return RequirementRow(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      type: data.type.present ? data.type.value : this.type,
      isRequired: data.isRequired.present
          ? data.isRequired.value
          : this.isRequired,
      position: data.position.present ? data.position.value : this.position,
      unit: data.unit.present ? data.unit.value : this.unit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RequirementRow(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('type: $type, ')
          ..write('isRequired: $isRequired, ')
          ..write('position: $position, ')
          ..write('unit: $unit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    title,
    description,
    type,
    isRequired,
    position,
    unit,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RequirementRow &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.title == this.title &&
          other.description == this.description &&
          other.type == this.type &&
          other.isRequired == this.isRequired &&
          other.position == this.position &&
          other.unit == this.unit);
}

class LocalRequirementsCompanion extends UpdateCompanion<RequirementRow> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> type;
  final Value<bool> isRequired;
  final Value<int> position;
  final Value<String?> unit;
  final Value<int> rowid;
  const LocalRequirementsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.type = const Value.absent(),
    this.isRequired = const Value.absent(),
    this.position = const Value.absent(),
    this.unit = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalRequirementsCompanion.insert({
    required String id,
    required String taskId,
    required String title,
    this.description = const Value.absent(),
    required String type,
    required bool isRequired,
    required int position,
    this.unit = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       title = Value(title),
       type = Value(type),
       isRequired = Value(isRequired),
       position = Value(position);
  static Insertable<RequirementRow> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? type,
    Expression<bool>? isRequired,
    Expression<int>? position,
    Expression<String>? unit,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (type != null) 'type': type,
      if (isRequired != null) 'is_required': isRequired,
      if (position != null) 'position': position,
      if (unit != null) 'unit': unit,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRequirementsCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? title,
    Value<String?>? description,
    Value<String>? type,
    Value<bool>? isRequired,
    Value<int>? position,
    Value<String?>? unit,
    Value<int>? rowid,
  }) {
    return LocalRequirementsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      isRequired: isRequired ?? this.isRequired,
      position: position ?? this.position,
      unit: unit ?? this.unit,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (isRequired.present) {
      map['is_required'] = Variable<bool>(isRequired.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRequirementsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('type: $type, ')
          ..write('isRequired: $isRequired, ')
          ..write('position: $position, ')
          ..write('unit: $unit, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalRequirementOptionsTable extends LocalRequirementOptions
    with TableInfo<$LocalRequirementOptionsTable, RequirementOptionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRequirementOptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requirementIdMeta = const VerificationMeta(
    'requirementId',
  );
  @override
  late final GeneratedColumn<String> requirementId = GeneratedColumn<String>(
    'requirement_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_requirements (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, requirementId, label, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_requirement_options';
  @override
  VerificationContext validateIntegrity(
    Insertable<RequirementOptionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('requirement_id')) {
      context.handle(
        _requirementIdMeta,
        requirementId.isAcceptableOrUnknown(
          data['requirement_id']!,
          _requirementIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requirementIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RequirementOptionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RequirementOptionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      requirementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}requirement_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $LocalRequirementOptionsTable createAlias(String alias) {
    return $LocalRequirementOptionsTable(attachedDatabase, alias);
  }
}

class RequirementOptionRow extends DataClass
    implements Insertable<RequirementOptionRow> {
  final String id;
  final String requirementId;
  final String label;
  final int position;
  const RequirementOptionRow({
    required this.id,
    required this.requirementId,
    required this.label,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['requirement_id'] = Variable<String>(requirementId);
    map['label'] = Variable<String>(label);
    map['position'] = Variable<int>(position);
    return map;
  }

  LocalRequirementOptionsCompanion toCompanion(bool nullToAbsent) {
    return LocalRequirementOptionsCompanion(
      id: Value(id),
      requirementId: Value(requirementId),
      label: Value(label),
      position: Value(position),
    );
  }

  factory RequirementOptionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RequirementOptionRow(
      id: serializer.fromJson<String>(json['id']),
      requirementId: serializer.fromJson<String>(json['requirementId']),
      label: serializer.fromJson<String>(json['label']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'requirementId': serializer.toJson<String>(requirementId),
      'label': serializer.toJson<String>(label),
      'position': serializer.toJson<int>(position),
    };
  }

  RequirementOptionRow copyWith({
    String? id,
    String? requirementId,
    String? label,
    int? position,
  }) => RequirementOptionRow(
    id: id ?? this.id,
    requirementId: requirementId ?? this.requirementId,
    label: label ?? this.label,
    position: position ?? this.position,
  );
  RequirementOptionRow copyWithCompanion(
    LocalRequirementOptionsCompanion data,
  ) {
    return RequirementOptionRow(
      id: data.id.present ? data.id.value : this.id,
      requirementId: data.requirementId.present
          ? data.requirementId.value
          : this.requirementId,
      label: data.label.present ? data.label.value : this.label,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RequirementOptionRow(')
          ..write('id: $id, ')
          ..write('requirementId: $requirementId, ')
          ..write('label: $label, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, requirementId, label, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RequirementOptionRow &&
          other.id == this.id &&
          other.requirementId == this.requirementId &&
          other.label == this.label &&
          other.position == this.position);
}

class LocalRequirementOptionsCompanion
    extends UpdateCompanion<RequirementOptionRow> {
  final Value<String> id;
  final Value<String> requirementId;
  final Value<String> label;
  final Value<int> position;
  final Value<int> rowid;
  const LocalRequirementOptionsCompanion({
    this.id = const Value.absent(),
    this.requirementId = const Value.absent(),
    this.label = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalRequirementOptionsCompanion.insert({
    required String id,
    required String requirementId,
    required String label,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       requirementId = Value(requirementId),
       label = Value(label),
       position = Value(position);
  static Insertable<RequirementOptionRow> custom({
    Expression<String>? id,
    Expression<String>? requirementId,
    Expression<String>? label,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (requirementId != null) 'requirement_id': requirementId,
      if (label != null) 'label': label,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRequirementOptionsCompanion copyWith({
    Value<String>? id,
    Value<String>? requirementId,
    Value<String>? label,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return LocalRequirementOptionsCompanion(
      id: id ?? this.id,
      requirementId: requirementId ?? this.requirementId,
      label: label ?? this.label,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (requirementId.present) {
      map['requirement_id'] = Variable<String>(requirementId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRequirementOptionsCompanion(')
          ..write('id: $id, ')
          ..write('requirementId: $requirementId, ')
          ..write('label: $label, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalResponsesTable extends LocalResponses
    with TableInfo<$LocalResponsesTable, ResponseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalResponsesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _requirementIdMeta = const VerificationMeta(
    'requirementId',
  );
  @override
  late final GeneratedColumn<String> requirementId = GeneratedColumn<String>(
    'requirement_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_requirements (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _booleanValueMeta = const VerificationMeta(
    'booleanValue',
  );
  @override
  late final GeneratedColumn<bool> booleanValue = GeneratedColumn<bool>(
    'boolean_value',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("boolean_value" IN (0, 1))',
    ),
  );
  static const VerificationMeta _textValueMeta = const VerificationMeta(
    'textValue',
  );
  @override
  late final GeneratedColumn<String> textValue = GeneratedColumn<String>(
    'text_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _numberValueMeta = const VerificationMeta(
    'numberValue',
  );
  @override
  late final GeneratedColumn<double> numberValue = GeneratedColumn<double>(
    'number_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selectedOptionIdsMeta = const VerificationMeta(
    'selectedOptionIds',
  );
  @override
  late final GeneratedColumn<String> selectedOptionIds =
      GeneratedColumn<String>(
        'selected_option_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    requirementId,
    taskId,
    booleanValue,
    textValue,
    numberValue,
    selectedOptionIds,
    comment,
    updatedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResponseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('requirement_id')) {
      context.handle(
        _requirementIdMeta,
        requirementId.isAcceptableOrUnknown(
          data['requirement_id']!,
          _requirementIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requirementIdMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('boolean_value')) {
      context.handle(
        _booleanValueMeta,
        booleanValue.isAcceptableOrUnknown(
          data['boolean_value']!,
          _booleanValueMeta,
        ),
      );
    }
    if (data.containsKey('text_value')) {
      context.handle(
        _textValueMeta,
        textValue.isAcceptableOrUnknown(data['text_value']!, _textValueMeta),
      );
    }
    if (data.containsKey('number_value')) {
      context.handle(
        _numberValueMeta,
        numberValue.isAcceptableOrUnknown(
          data['number_value']!,
          _numberValueMeta,
        ),
      );
    }
    if (data.containsKey('selected_option_ids')) {
      context.handle(
        _selectedOptionIdsMeta,
        selectedOptionIds.isAcceptableOrUnknown(
          data['selected_option_ids']!,
          _selectedOptionIdsMeta,
        ),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {requirementId};
  @override
  ResponseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResponseRow(
      requirementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}requirement_id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      booleanValue: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}boolean_value'],
      ),
      textValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_value'],
      ),
      numberValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}number_value'],
      ),
      selectedOptionIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_option_ids'],
      )!,
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $LocalResponsesTable createAlias(String alias) {
    return $LocalResponsesTable(attachedDatabase, alias);
  }
}

class ResponseRow extends DataClass implements Insertable<ResponseRow> {
  final String requirementId;
  final String taskId;
  final bool? booleanValue;
  final String? textValue;
  final double? numberValue;

  /// Selected option IDs as a JSON array.
  final String selectedOptionIds;
  final String? comment;
  final DateTime updatedAt;

  /// PENDING until the answer has reached the server (Phase 6), then SYNCED.
  final String syncStatus;
  const ResponseRow({
    required this.requirementId,
    required this.taskId,
    this.booleanValue,
    this.textValue,
    this.numberValue,
    required this.selectedOptionIds,
    this.comment,
    required this.updatedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['requirement_id'] = Variable<String>(requirementId);
    map['task_id'] = Variable<String>(taskId);
    if (!nullToAbsent || booleanValue != null) {
      map['boolean_value'] = Variable<bool>(booleanValue);
    }
    if (!nullToAbsent || textValue != null) {
      map['text_value'] = Variable<String>(textValue);
    }
    if (!nullToAbsent || numberValue != null) {
      map['number_value'] = Variable<double>(numberValue);
    }
    map['selected_option_ids'] = Variable<String>(selectedOptionIds);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  LocalResponsesCompanion toCompanion(bool nullToAbsent) {
    return LocalResponsesCompanion(
      requirementId: Value(requirementId),
      taskId: Value(taskId),
      booleanValue: booleanValue == null && nullToAbsent
          ? const Value.absent()
          : Value(booleanValue),
      textValue: textValue == null && nullToAbsent
          ? const Value.absent()
          : Value(textValue),
      numberValue: numberValue == null && nullToAbsent
          ? const Value.absent()
          : Value(numberValue),
      selectedOptionIds: Value(selectedOptionIds),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory ResponseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResponseRow(
      requirementId: serializer.fromJson<String>(json['requirementId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      booleanValue: serializer.fromJson<bool?>(json['booleanValue']),
      textValue: serializer.fromJson<String?>(json['textValue']),
      numberValue: serializer.fromJson<double?>(json['numberValue']),
      selectedOptionIds: serializer.fromJson<String>(json['selectedOptionIds']),
      comment: serializer.fromJson<String?>(json['comment']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'requirementId': serializer.toJson<String>(requirementId),
      'taskId': serializer.toJson<String>(taskId),
      'booleanValue': serializer.toJson<bool?>(booleanValue),
      'textValue': serializer.toJson<String?>(textValue),
      'numberValue': serializer.toJson<double?>(numberValue),
      'selectedOptionIds': serializer.toJson<String>(selectedOptionIds),
      'comment': serializer.toJson<String?>(comment),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  ResponseRow copyWith({
    String? requirementId,
    String? taskId,
    Value<bool?> booleanValue = const Value.absent(),
    Value<String?> textValue = const Value.absent(),
    Value<double?> numberValue = const Value.absent(),
    String? selectedOptionIds,
    Value<String?> comment = const Value.absent(),
    DateTime? updatedAt,
    String? syncStatus,
  }) => ResponseRow(
    requirementId: requirementId ?? this.requirementId,
    taskId: taskId ?? this.taskId,
    booleanValue: booleanValue.present ? booleanValue.value : this.booleanValue,
    textValue: textValue.present ? textValue.value : this.textValue,
    numberValue: numberValue.present ? numberValue.value : this.numberValue,
    selectedOptionIds: selectedOptionIds ?? this.selectedOptionIds,
    comment: comment.present ? comment.value : this.comment,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  ResponseRow copyWithCompanion(LocalResponsesCompanion data) {
    return ResponseRow(
      requirementId: data.requirementId.present
          ? data.requirementId.value
          : this.requirementId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      booleanValue: data.booleanValue.present
          ? data.booleanValue.value
          : this.booleanValue,
      textValue: data.textValue.present ? data.textValue.value : this.textValue,
      numberValue: data.numberValue.present
          ? data.numberValue.value
          : this.numberValue,
      selectedOptionIds: data.selectedOptionIds.present
          ? data.selectedOptionIds.value
          : this.selectedOptionIds,
      comment: data.comment.present ? data.comment.value : this.comment,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResponseRow(')
          ..write('requirementId: $requirementId, ')
          ..write('taskId: $taskId, ')
          ..write('booleanValue: $booleanValue, ')
          ..write('textValue: $textValue, ')
          ..write('numberValue: $numberValue, ')
          ..write('selectedOptionIds: $selectedOptionIds, ')
          ..write('comment: $comment, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    requirementId,
    taskId,
    booleanValue,
    textValue,
    numberValue,
    selectedOptionIds,
    comment,
    updatedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResponseRow &&
          other.requirementId == this.requirementId &&
          other.taskId == this.taskId &&
          other.booleanValue == this.booleanValue &&
          other.textValue == this.textValue &&
          other.numberValue == this.numberValue &&
          other.selectedOptionIds == this.selectedOptionIds &&
          other.comment == this.comment &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus);
}

class LocalResponsesCompanion extends UpdateCompanion<ResponseRow> {
  final Value<String> requirementId;
  final Value<String> taskId;
  final Value<bool?> booleanValue;
  final Value<String?> textValue;
  final Value<double?> numberValue;
  final Value<String> selectedOptionIds;
  final Value<String?> comment;
  final Value<DateTime> updatedAt;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const LocalResponsesCompanion({
    this.requirementId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.booleanValue = const Value.absent(),
    this.textValue = const Value.absent(),
    this.numberValue = const Value.absent(),
    this.selectedOptionIds = const Value.absent(),
    this.comment = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalResponsesCompanion.insert({
    required String requirementId,
    required String taskId,
    this.booleanValue = const Value.absent(),
    this.textValue = const Value.absent(),
    this.numberValue = const Value.absent(),
    this.selectedOptionIds = const Value.absent(),
    this.comment = const Value.absent(),
    required DateTime updatedAt,
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : requirementId = Value(requirementId),
       taskId = Value(taskId),
       updatedAt = Value(updatedAt);
  static Insertable<ResponseRow> custom({
    Expression<String>? requirementId,
    Expression<String>? taskId,
    Expression<bool>? booleanValue,
    Expression<String>? textValue,
    Expression<double>? numberValue,
    Expression<String>? selectedOptionIds,
    Expression<String>? comment,
    Expression<DateTime>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (requirementId != null) 'requirement_id': requirementId,
      if (taskId != null) 'task_id': taskId,
      if (booleanValue != null) 'boolean_value': booleanValue,
      if (textValue != null) 'text_value': textValue,
      if (numberValue != null) 'number_value': numberValue,
      if (selectedOptionIds != null) 'selected_option_ids': selectedOptionIds,
      if (comment != null) 'comment': comment,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalResponsesCompanion copyWith({
    Value<String>? requirementId,
    Value<String>? taskId,
    Value<bool?>? booleanValue,
    Value<String?>? textValue,
    Value<double?>? numberValue,
    Value<String>? selectedOptionIds,
    Value<String?>? comment,
    Value<DateTime>? updatedAt,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return LocalResponsesCompanion(
      requirementId: requirementId ?? this.requirementId,
      taskId: taskId ?? this.taskId,
      booleanValue: booleanValue ?? this.booleanValue,
      textValue: textValue ?? this.textValue,
      numberValue: numberValue ?? this.numberValue,
      selectedOptionIds: selectedOptionIds ?? this.selectedOptionIds,
      comment: comment ?? this.comment,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (requirementId.present) {
      map['requirement_id'] = Variable<String>(requirementId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (booleanValue.present) {
      map['boolean_value'] = Variable<bool>(booleanValue.value);
    }
    if (textValue.present) {
      map['text_value'] = Variable<String>(textValue.value);
    }
    if (numberValue.present) {
      map['number_value'] = Variable<double>(numberValue.value);
    }
    if (selectedOptionIds.present) {
      map['selected_option_ids'] = Variable<String>(selectedOptionIds.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalResponsesCompanion(')
          ..write('requirementId: $requirementId, ')
          ..write('taskId: $taskId, ')
          ..write('booleanValue: $booleanValue, ')
          ..write('textValue: $textValue, ')
          ..write('numberValue: $numberValue, ')
          ..write('selectedOptionIds: $selectedOptionIds, ')
          ..write('comment: $comment, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalTasksTable localTasks = $LocalTasksTable(this);
  late final $LocalRequirementsTable localRequirements =
      $LocalRequirementsTable(this);
  late final $LocalRequirementOptionsTable localRequirementOptions =
      $LocalRequirementOptionsTable(this);
  late final $LocalResponsesTable localResponses = $LocalResponsesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localTasks,
    localRequirements,
    localRequirementOptions,
    localResponses,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_requirements', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_requirements',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('local_requirement_options', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_requirements',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_responses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_responses', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LocalTasksTableCreateCompanionBuilder = LocalTasksCompanion Function({
  required String id,
  required String title,
  Value<String?> description,
  required String priority,
  required String status,
  required DateTime dueDate,
  required String createdById,
  required String createdByName,
  required String reviewerId,
  required String reviewerName,
  Value<String?> assigneeId,
  Value<String?> assigneeName,
  required int version,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalTasksTableUpdateCompanionBuilder = LocalTasksCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String?> description,
  Value<String> priority,
  Value<String> status,
  Value<DateTime> dueDate,
  Value<String> createdById,
  Value<String> createdByName,
  Value<String> reviewerId,
  Value<String> reviewerName,
  Value<String?> assigneeId,
  Value<String?> assigneeName,
  Value<int> version,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$LocalTasksTableReferences
    extends BaseReferences<_$AppDatabase, $LocalTasksTable, TaskRow> {
  $$LocalTasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LocalRequirementsTable, List<RequirementRow>>
  _localRequirementsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localRequirements,
        aliasName: 'local_tasks__id__local_requirements__task_id',
      );

  $$LocalRequirementsTableProcessedTableManager get localRequirementsRefs {
    final manager = $$LocalRequirementsTableTableManager(
      $_db,
      $_db.localRequirements,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localRequirementsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LocalResponsesTable, List<ResponseRow>>
  _localResponsesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.localResponses,
    aliasName: 'local_tasks__id__local_responses__task_id',
  );

  $$LocalResponsesTableProcessedTableManager get localResponsesRefs {
    final manager = $$LocalResponsesTableTableManager(
      $_db,
      $_db.localResponses,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_localResponsesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalTasksTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTasksTable> {
  $$LocalTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdById => $composableBuilder(
    column: $table.createdById,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByName => $composableBuilder(
    column: $table.createdByName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewerId => $composableBuilder(
    column: $table.reviewerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewerName => $composableBuilder(
    column: $table.reviewerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assigneeId => $composableBuilder(
    column: $table.assigneeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assigneeName => $composableBuilder(
    column: $table.assigneeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localRequirementsRefs(
    Expression<bool> Function($$LocalRequirementsTableFilterComposer f) f,
  ) {
    final $$LocalRequirementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localRequirements,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalRequirementsTableFilterComposer(
            $db: $db,
            $table: $db.localRequirements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> localResponsesRefs(
    Expression<bool> Function($$LocalResponsesTableFilterComposer f) f,
  ) {
    final $$LocalResponsesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localResponses,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalResponsesTableFilterComposer(
            $db: $db,
            $table: $db.localResponses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTasksTable> {
  $$LocalTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdById => $composableBuilder(
    column: $table.createdById,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByName => $composableBuilder(
    column: $table.createdByName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewerId => $composableBuilder(
    column: $table.reviewerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewerName => $composableBuilder(
    column: $table.reviewerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assigneeId => $composableBuilder(
    column: $table.assigneeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assigneeName => $composableBuilder(
    column: $table.assigneeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTasksTable> {
  $$LocalTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get createdById => $composableBuilder(
    column: $table.createdById,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdByName => $composableBuilder(
    column: $table.createdByName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reviewerId => $composableBuilder(
    column: $table.reviewerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reviewerName => $composableBuilder(
    column: $table.reviewerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assigneeId => $composableBuilder(
    column: $table.assigneeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assigneeName => $composableBuilder(
    column: $table.assigneeName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> localRequirementsRefs<T extends Object>(
    Expression<T> Function($$LocalRequirementsTableAnnotationComposer a) f,
  ) {
    final $$LocalRequirementsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localRequirements,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalRequirementsTableAnnotationComposer(
                $db: $db,
                $table: $db.localRequirements,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> localResponsesRefs<T extends Object>(
    Expression<T> Function($$LocalResponsesTableAnnotationComposer a) f,
  ) {
    final $$LocalResponsesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localResponses,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalResponsesTableAnnotationComposer(
            $db: $db,
            $table: $db.localResponses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTasksTable,
          TaskRow,
          $$LocalTasksTableFilterComposer,
          $$LocalTasksTableOrderingComposer,
          $$LocalTasksTableAnnotationComposer,
          $$LocalTasksTableCreateCompanionBuilder,
          $$LocalTasksTableUpdateCompanionBuilder,
          (TaskRow, $$LocalTasksTableReferences),
          TaskRow,
          PrefetchHooks Function({
            bool localRequirementsRefs,
            bool localResponsesRefs,
          })
        > {
  $$LocalTasksTableTableManager(_$AppDatabase db, $LocalTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<String> createdById = const Value.absent(),
                Value<String> createdByName = const Value.absent(),
                Value<String> reviewerId = const Value.absent(),
                Value<String> reviewerName = const Value.absent(),
                Value<String?> assigneeId = const Value.absent(),
                Value<String?> assigneeName = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTasksCompanion(
                id: id,
                title: title,
                description: description,
                priority: priority,
                status: status,
                dueDate: dueDate,
                createdById: createdById,
                createdByName: createdByName,
                reviewerId: reviewerId,
                reviewerName: reviewerName,
                assigneeId: assigneeId,
                assigneeName: assigneeName,
                version: version,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> description = const Value.absent(),
                required String priority,
                required String status,
                required DateTime dueDate,
                required String createdById,
                required String createdByName,
                required String reviewerId,
                required String reviewerName,
                Value<String?> assigneeId = const Value.absent(),
                Value<String?> assigneeName = const Value.absent(),
                required int version,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalTasksCompanion.insert(
                id: id,
                title: title,
                description: description,
                priority: priority,
                status: status,
                dueDate: dueDate,
                createdById: createdById,
                createdByName: createdByName,
                reviewerId: reviewerId,
                reviewerName: reviewerName,
                assigneeId: assigneeId,
                assigneeName: assigneeName,
                version: version,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalTasksTable, TaskRow>(table),
                  $$LocalTasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({localRequirementsRefs = false, localResponsesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (localRequirementsRefs) db.localRequirements,
                    if (localResponsesRefs) db.localResponses,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (localRequirementsRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $LocalTasksTable,
                          RequirementRow
                        >(
                          currentTable: table,
                          referencedTable: $$LocalTasksTableReferences
                              ._localRequirementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalTasksTableReferences(
                                db,
                                table,
                                p0,
                              ).localRequirementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (localResponsesRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $LocalTasksTable,
                          ResponseRow
                        >(
                          currentTable: table,
                          referencedTable: $$LocalTasksTableReferences
                              ._localResponsesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalTasksTableReferences(
                                db,
                                table,
                                p0,
                              ).localResponsesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LocalTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTasksTable,
      TaskRow,
      $$LocalTasksTableFilterComposer,
      $$LocalTasksTableOrderingComposer,
      $$LocalTasksTableAnnotationComposer,
      $$LocalTasksTableCreateCompanionBuilder,
      $$LocalTasksTableUpdateCompanionBuilder,
      (TaskRow, $$LocalTasksTableReferences),
      TaskRow,
      PrefetchHooks Function({
        bool localRequirementsRefs,
        bool localResponsesRefs,
      })
    >;
typedef $$LocalRequirementsTableCreateCompanionBuilder =
    LocalRequirementsCompanion Function({
      required String id,
      required String taskId,
      required String title,
      Value<String?> description,
      required String type,
      required bool isRequired,
      required int position,
      Value<String?> unit,
      Value<int> rowid,
    });
typedef $$LocalRequirementsTableUpdateCompanionBuilder =
    LocalRequirementsCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<String> title,
      Value<String?> description,
      Value<String> type,
      Value<bool> isRequired,
      Value<int> position,
      Value<String?> unit,
      Value<int> rowid,
    });

final class $$LocalRequirementsTableReferences
    extends
        BaseReferences<_$AppDatabase, $LocalRequirementsTable, RequirementRow> {
  $$LocalRequirementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalTasksTable _taskIdTable(_$AppDatabase db) =>
      db.localTasks.createAlias('local_requirements__task_id__local_tasks__id');

  $$LocalTasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$LocalTasksTableTableManager(
      $_db,
      $_db.localTasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $LocalRequirementOptionsTable,
    List<RequirementOptionRow>
  >
  _localRequirementOptionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localRequirementOptions,
        aliasName:
            'local_requirements__id__local_requirement_options__requirement_id',
      );

  $$LocalRequirementOptionsTableProcessedTableManager
  get localRequirementOptionsRefs {
    final manager = $$LocalRequirementOptionsTableTableManager(
      $_db,
      $_db.localRequirementOptions,
    ).filter((f) => f.requirementId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localRequirementOptionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LocalResponsesTable, List<ResponseRow>>
  _localResponsesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.localResponses,
    aliasName: 'local_requirements__id__local_responses__requirement_id',
  );

  $$LocalResponsesTableProcessedTableManager get localResponsesRefs {
    final manager = $$LocalResponsesTableTableManager(
      $_db,
      $_db.localResponses,
    ).filter((f) => f.requirementId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_localResponsesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalRequirementsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalRequirementsTable> {
  $$LocalRequirementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalTasksTableFilterComposer get taskId {
    final $$LocalTasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.localTasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTasksTableFilterComposer(
            $db: $db,
            $table: $db.localTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> localRequirementOptionsRefs(
    Expression<bool> Function($$LocalRequirementOptionsTableFilterComposer f) f,
  ) {
    final $$LocalRequirementOptionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localRequirementOptions,
          getReferencedColumn: (t) => t.requirementId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalRequirementOptionsTableFilterComposer(
                $db: $db,
                $table: $db.localRequirementOptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> localResponsesRefs(
    Expression<bool> Function($$LocalResponsesTableFilterComposer f) f,
  ) {
    final $$LocalResponsesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localResponses,
      getReferencedColumn: (t) => t.requirementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalResponsesTableFilterComposer(
            $db: $db,
            $table: $db.localResponses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalRequirementsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalRequirementsTable> {
  $$LocalRequirementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalTasksTableOrderingComposer get taskId {
    final $$LocalTasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.localTasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTasksTableOrderingComposer(
            $db: $db,
            $table: $db.localTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalRequirementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalRequirementsTable> {
  $$LocalRequirementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  $$LocalTasksTableAnnotationComposer get taskId {
    final $$LocalTasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.localTasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTasksTableAnnotationComposer(
            $db: $db,
            $table: $db.localTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> localRequirementOptionsRefs<T extends Object>(
    Expression<T> Function($$LocalRequirementOptionsTableAnnotationComposer a)
    f,
  ) {
    final $$LocalRequirementOptionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localRequirementOptions,
          getReferencedColumn: (t) => t.requirementId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalRequirementOptionsTableAnnotationComposer(
                $db: $db,
                $table: $db.localRequirementOptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> localResponsesRefs<T extends Object>(
    Expression<T> Function($$LocalResponsesTableAnnotationComposer a) f,
  ) {
    final $$LocalResponsesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localResponses,
      getReferencedColumn: (t) => t.requirementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalResponsesTableAnnotationComposer(
            $db: $db,
            $table: $db.localResponses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalRequirementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalRequirementsTable,
          RequirementRow,
          $$LocalRequirementsTableFilterComposer,
          $$LocalRequirementsTableOrderingComposer,
          $$LocalRequirementsTableAnnotationComposer,
          $$LocalRequirementsTableCreateCompanionBuilder,
          $$LocalRequirementsTableUpdateCompanionBuilder,
          (RequirementRow, $$LocalRequirementsTableReferences),
          RequirementRow,
          PrefetchHooks Function({
            bool taskId,
            bool localRequirementOptionsRefs,
            bool localResponsesRefs,
          })
        > {
  $$LocalRequirementsTableTableManager(
    _$AppDatabase db,
    $LocalRequirementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRequirementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalRequirementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalRequirementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<bool> isRequired = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRequirementsCompanion(
                id: id,
                taskId: taskId,
                title: title,
                description: description,
                type: type,
                isRequired: isRequired,
                position: position,
                unit: unit,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required String title,
                Value<String?> description = const Value.absent(),
                required String type,
                required bool isRequired,
                required int position,
                Value<String?> unit = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRequirementsCompanion.insert(
                id: id,
                taskId: taskId,
                title: title,
                description: description,
                type: type,
                isRequired: isRequired,
                position: position,
                unit: unit,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalRequirementsTable, RequirementRow>(table),
                  $$LocalRequirementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                taskId = false,
                localRequirementOptionsRefs = false,
                localResponsesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (localRequirementOptionsRefs) db.localRequirementOptions,
                    if (localResponsesRefs) db.localResponses,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (taskId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.taskId,
                            referencedTable: $$LocalRequirementsTableReferences
                                ._taskIdTable(db),
                            referencedColumn: $$LocalRequirementsTableReferences
                                ._taskIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (localRequirementOptionsRefs)
                        await $_getPrefetchedData<
                          RequirementRow,
                          $LocalRequirementsTable,
                          RequirementOptionRow
                        >(
                          currentTable: table,
                          referencedTable: $$LocalRequirementsTableReferences
                              ._localRequirementOptionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalRequirementsTableReferences(
                                db,
                                table,
                                p0,
                              ).localRequirementOptionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.requirementId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (localResponsesRefs)
                        await $_getPrefetchedData<
                          RequirementRow,
                          $LocalRequirementsTable,
                          ResponseRow
                        >(
                          currentTable: table,
                          referencedTable: $$LocalRequirementsTableReferences
                              ._localResponsesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalRequirementsTableReferences(
                                db,
                                table,
                                p0,
                              ).localResponsesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.requirementId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LocalRequirementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalRequirementsTable,
      RequirementRow,
      $$LocalRequirementsTableFilterComposer,
      $$LocalRequirementsTableOrderingComposer,
      $$LocalRequirementsTableAnnotationComposer,
      $$LocalRequirementsTableCreateCompanionBuilder,
      $$LocalRequirementsTableUpdateCompanionBuilder,
      (RequirementRow, $$LocalRequirementsTableReferences),
      RequirementRow,
      PrefetchHooks Function({
        bool taskId,
        bool localRequirementOptionsRefs,
        bool localResponsesRefs,
      })
    >;
typedef $$LocalRequirementOptionsTableCreateCompanionBuilder =
    LocalRequirementOptionsCompanion Function({
      required String id,
      required String requirementId,
      required String label,
      required int position,
      Value<int> rowid,
    });
typedef $$LocalRequirementOptionsTableUpdateCompanionBuilder =
    LocalRequirementOptionsCompanion Function({
      Value<String> id,
      Value<String> requirementId,
      Value<String> label,
      Value<int> position,
      Value<int> rowid,
    });

final class $$LocalRequirementOptionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalRequirementOptionsTable,
          RequirementOptionRow
        > {
  $$LocalRequirementOptionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalRequirementsTable _requirementIdTable(_$AppDatabase db) =>
      db.localRequirements.createAlias(
        'local_requirement_options__requirement_id__local_requirements__id',
      );

  $$LocalRequirementsTableProcessedTableManager get requirementId {
    final $_column = $_itemColumn<String>('requirement_id')!;

    final manager = $$LocalRequirementsTableTableManager(
      $_db,
      $_db.localRequirements,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_requirementIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalRequirementOptionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalRequirementOptionsTable> {
  $$LocalRequirementOptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalRequirementsTableFilterComposer get requirementId {
    final $$LocalRequirementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requirementId,
      referencedTable: $db.localRequirements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalRequirementsTableFilterComposer(
            $db: $db,
            $table: $db.localRequirements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalRequirementOptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalRequirementOptionsTable> {
  $$LocalRequirementOptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalRequirementsTableOrderingComposer get requirementId {
    final $$LocalRequirementsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requirementId,
      referencedTable: $db.localRequirements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalRequirementsTableOrderingComposer(
            $db: $db,
            $table: $db.localRequirements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalRequirementOptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalRequirementOptionsTable> {
  $$LocalRequirementOptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$LocalRequirementsTableAnnotationComposer get requirementId {
    final $$LocalRequirementsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.requirementId,
          referencedTable: $db.localRequirements,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalRequirementsTableAnnotationComposer(
                $db: $db,
                $table: $db.localRequirements,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LocalRequirementOptionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalRequirementOptionsTable,
          RequirementOptionRow,
          $$LocalRequirementOptionsTableFilterComposer,
          $$LocalRequirementOptionsTableOrderingComposer,
          $$LocalRequirementOptionsTableAnnotationComposer,
          $$LocalRequirementOptionsTableCreateCompanionBuilder,
          $$LocalRequirementOptionsTableUpdateCompanionBuilder,
          (RequirementOptionRow, $$LocalRequirementOptionsTableReferences),
          RequirementOptionRow,
          PrefetchHooks Function({bool requirementId})
        > {
  $$LocalRequirementOptionsTableTableManager(
    _$AppDatabase db,
    $LocalRequirementOptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRequirementOptionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalRequirementOptionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalRequirementOptionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> requirementId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRequirementOptionsCompanion(
                id: id,
                requirementId: requirementId,
                label: label,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String requirementId,
                required String label,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => LocalRequirementOptionsCompanion.insert(
                id: id,
                requirementId: requirementId,
                label: label,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalRequirementOptionsTable,
                    RequirementOptionRow
                  >(table),
                  $$LocalRequirementOptionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({requirementId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (requirementId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.requirementId,
                        referencedTable:
                            $$LocalRequirementOptionsTableReferences
                                ._requirementIdTable(db),
                        referencedColumn:
                            $$LocalRequirementOptionsTableReferences
                                ._requirementIdTable(db)
                                .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalRequirementOptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalRequirementOptionsTable,
      RequirementOptionRow,
      $$LocalRequirementOptionsTableFilterComposer,
      $$LocalRequirementOptionsTableOrderingComposer,
      $$LocalRequirementOptionsTableAnnotationComposer,
      $$LocalRequirementOptionsTableCreateCompanionBuilder,
      $$LocalRequirementOptionsTableUpdateCompanionBuilder,
      (RequirementOptionRow, $$LocalRequirementOptionsTableReferences),
      RequirementOptionRow,
      PrefetchHooks Function({bool requirementId})
    >;
typedef $$LocalResponsesTableCreateCompanionBuilder =
    LocalResponsesCompanion Function({
      required String requirementId,
      required String taskId,
      Value<bool?> booleanValue,
      Value<String?> textValue,
      Value<double?> numberValue,
      Value<String> selectedOptionIds,
      Value<String?> comment,
      required DateTime updatedAt,
      Value<String> syncStatus,
      Value<int> rowid,
    });
typedef $$LocalResponsesTableUpdateCompanionBuilder =
    LocalResponsesCompanion Function({
      Value<String> requirementId,
      Value<String> taskId,
      Value<bool?> booleanValue,
      Value<String?> textValue,
      Value<double?> numberValue,
      Value<String> selectedOptionIds,
      Value<String?> comment,
      Value<DateTime> updatedAt,
      Value<String> syncStatus,
      Value<int> rowid,
    });

final class $$LocalResponsesTableReferences
    extends BaseReferences<_$AppDatabase, $LocalResponsesTable, ResponseRow> {
  $$LocalResponsesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalRequirementsTable _requirementIdTable(_$AppDatabase db) => db
      .localRequirements
      .createAlias('local_responses__requirement_id__local_requirements__id');

  $$LocalRequirementsTableProcessedTableManager get requirementId {
    final $_column = $_itemColumn<String>('requirement_id')!;

    final manager = $$LocalRequirementsTableTableManager(
      $_db,
      $_db.localRequirements,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_requirementIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LocalTasksTable _taskIdTable(_$AppDatabase db) =>
      db.localTasks.createAlias('local_responses__task_id__local_tasks__id');

  $$LocalTasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$LocalTasksTableTableManager(
      $_db,
      $_db.localTasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalResponsesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalResponsesTable> {
  $$LocalResponsesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<bool> get booleanValue => $composableBuilder(
    column: $table.booleanValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textValue => $composableBuilder(
    column: $table.textValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get numberValue => $composableBuilder(
    column: $table.numberValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedOptionIds => $composableBuilder(
    column: $table.selectedOptionIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalRequirementsTableFilterComposer get requirementId {
    final $$LocalRequirementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requirementId,
      referencedTable: $db.localRequirements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalRequirementsTableFilterComposer(
            $db: $db,
            $table: $db.localRequirements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocalTasksTableFilterComposer get taskId {
    final $$LocalTasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.localTasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTasksTableFilterComposer(
            $db: $db,
            $table: $db.localTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalResponsesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalResponsesTable> {
  $$LocalResponsesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<bool> get booleanValue => $composableBuilder(
    column: $table.booleanValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textValue => $composableBuilder(
    column: $table.textValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get numberValue => $composableBuilder(
    column: $table.numberValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedOptionIds => $composableBuilder(
    column: $table.selectedOptionIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalRequirementsTableOrderingComposer get requirementId {
    final $$LocalRequirementsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requirementId,
      referencedTable: $db.localRequirements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalRequirementsTableOrderingComposer(
            $db: $db,
            $table: $db.localRequirements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocalTasksTableOrderingComposer get taskId {
    final $$LocalTasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.localTasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTasksTableOrderingComposer(
            $db: $db,
            $table: $db.localTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalResponsesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalResponsesTable> {
  $$LocalResponsesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<bool> get booleanValue => $composableBuilder(
    column: $table.booleanValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textValue =>
      $composableBuilder(column: $table.textValue, builder: (column) => column);

  GeneratedColumn<double> get numberValue => $composableBuilder(
    column: $table.numberValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedOptionIds => $composableBuilder(
    column: $table.selectedOptionIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$LocalRequirementsTableAnnotationComposer get requirementId {
    final $$LocalRequirementsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.requirementId,
          referencedTable: $db.localRequirements,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalRequirementsTableAnnotationComposer(
                $db: $db,
                $table: $db.localRequirements,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$LocalTasksTableAnnotationComposer get taskId {
    final $$LocalTasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.localTasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTasksTableAnnotationComposer(
            $db: $db,
            $table: $db.localTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalResponsesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalResponsesTable,
          ResponseRow,
          $$LocalResponsesTableFilterComposer,
          $$LocalResponsesTableOrderingComposer,
          $$LocalResponsesTableAnnotationComposer,
          $$LocalResponsesTableCreateCompanionBuilder,
          $$LocalResponsesTableUpdateCompanionBuilder,
          (ResponseRow, $$LocalResponsesTableReferences),
          ResponseRow,
          PrefetchHooks Function({bool requirementId, bool taskId})
        > {
  $$LocalResponsesTableTableManager(
    _$AppDatabase db,
    $LocalResponsesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalResponsesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalResponsesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalResponsesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> requirementId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<bool?> booleanValue = const Value.absent(),
                Value<String?> textValue = const Value.absent(),
                Value<double?> numberValue = const Value.absent(),
                Value<String> selectedOptionIds = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalResponsesCompanion(
                requirementId: requirementId,
                taskId: taskId,
                booleanValue: booleanValue,
                textValue: textValue,
                numberValue: numberValue,
                selectedOptionIds: selectedOptionIds,
                comment: comment,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String requirementId,
                required String taskId,
                Value<bool?> booleanValue = const Value.absent(),
                Value<String?> textValue = const Value.absent(),
                Value<double?> numberValue = const Value.absent(),
                Value<String> selectedOptionIds = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                required DateTime updatedAt,
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalResponsesCompanion.insert(
                requirementId: requirementId,
                taskId: taskId,
                booleanValue: booleanValue,
                textValue: textValue,
                numberValue: numberValue,
                selectedOptionIds: selectedOptionIds,
                comment: comment,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalResponsesTable, ResponseRow>(table),
                  $$LocalResponsesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({requirementId = false, taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (requirementId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.requirementId,
                        referencedTable: $$LocalResponsesTableReferences
                            ._requirementIdTable(db),
                        referencedColumn: $$LocalResponsesTableReferences
                            ._requirementIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$LocalResponsesTableReferences
                            ._taskIdTable(db),
                        referencedColumn: $$LocalResponsesTableReferences
                            ._taskIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalResponsesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalResponsesTable,
      ResponseRow,
      $$LocalResponsesTableFilterComposer,
      $$LocalResponsesTableOrderingComposer,
      $$LocalResponsesTableAnnotationComposer,
      $$LocalResponsesTableCreateCompanionBuilder,
      $$LocalResponsesTableUpdateCompanionBuilder,
      (ResponseRow, $$LocalResponsesTableReferences),
      ResponseRow,
      PrefetchHooks Function({bool requirementId, bool taskId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalTasksTableTableManager get localTasks =>
      $$LocalTasksTableTableManager(_db, _db.localTasks);
  $$LocalRequirementsTableTableManager get localRequirements =>
      $$LocalRequirementsTableTableManager(_db, _db.localRequirements);
  $$LocalRequirementOptionsTableTableManager get localRequirementOptions =>
      $$LocalRequirementOptionsTableTableManager(
        _db,
        _db.localRequirementOptions,
      );
  $$LocalResponsesTableTableManager get localResponses =>
      $$LocalResponsesTableTableManager(_db, _db.localResponses);
}
