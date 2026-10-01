import 'dart:async';

import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:taskinspect/core/network/connectivity_monitor.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_manager.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';

/// What the user sees about synchronization (docs/architecture.md, "Sync
/// Status in the App").
class SyncStatus extends Equatable {
  const SyncStatus({
    this.online = true,
    this.syncing = false,
    this.unsent = 0,
    this.failed = 0,
    this.failureCode,
    this.unsentTaskIds = const {},
  });

  final bool online;
  final bool syncing;

  /// Changes and files that are not on the server yet, failed ones included.
  final int unsent;

  /// How many of them failed.
  final int failed;

  /// Why the oldest failed one failed: a server error code, or e.g.
  /// NETWORK_ERROR / FILE_MISSING.
  final String? failureCode;

  /// Tasks with changes or files that are not on the server yet.
  final Set<String> unsentTaskIds;

  @override
  List<Object?> get props => [online, syncing, unsent, failed, failureCode, unsentTaskIds];
}

abstract interface class SyncStatusSource {
  /// The current status, then every change.
  Stream<SyncStatus> watch();
}

/// [SyncStatusSource] on the connection, the sync queue, the evidence
/// upload queue and the running sync.
class DatabaseSyncStatusSource implements SyncStatusSource {
  const DatabaseSyncStatusSource(this._db, this._connectivity, this._manager);

  final AppDatabase _db;
  final ConnectivityMonitor _connectivity;
  final SyncManager _manager;

  @override
  Stream<SyncStatus> watch() {
    // Unknown until checked: nothing is shown before, so an offline start
    // doesn't flash "waiting to sync" first.
    bool? online;
    var syncing = false;
    var operations = <SyncOperationRow>[];
    var files = <EvidenceRow>[];
    final subscriptions = <StreamSubscription<Object?>>[];
    late final StreamController<SyncStatus> controller;
    void update() {
      if (online != null && !controller.isClosed) {
        controller.add(_status(online: online!, syncing: syncing, operations: operations, files: files));
      }
    }

    controller = StreamController<SyncStatus>(
      onListen: () {
        syncing = _manager.isSyncing;
        subscriptions
          ..add(_connectivity.onlineChanges.listen((value) {
            online = value;
            update();
          }))
          ..add(_manager.syncingChanges.listen((value) {
            syncing = value;
            update();
          }))
          ..add(_db.select(_db.localSyncOperations).watch().listen((rows) {
            operations = rows;
            update();
          }))
          ..add((_db.select(_db.localEvidence)..where((e) => e.uploadStatus.equals('UPLOADED').not()))
              .watch()
              .listen((rows) {
            files = rows;
            update();
          }));
        unawaited(_connectivity.isOnline().then((value) {
          online = value;
          update();
        }));
      },
      onCancel: () async {
        await Future.wait(subscriptions.map((s) => s.cancel()));
        await controller.close();
      },
    );
    return controller.stream;
  }

  static SyncStatus _status({
    required bool online,
    required bool syncing,
    required List<SyncOperationRow> operations,
    required List<EvidenceRow> files,
  }) {
    // A file whose registration is still queued counts once, as that change.
    final queuedFiles = {
      for (final operation in operations)
        if (operation.entityType == SyncEntity.evidence.apiName) operation.entityId,
    };
    final waitingFiles = files.where((file) => !queuedFiles.contains(file.id)).toList();
    final failures = [
      for (final operation in operations)
        if (operation.status == 'FAILED') (operation.createdAt, operation.lastError),
      for (final file in waitingFiles)
        if (file.uploadStatus == 'FAILED') (file.createdAt, file.uploadError),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return SyncStatus(
      online: online,
      syncing: syncing,
      unsent: operations.length + waitingFiles.length,
      failed: failures.length,
      failureCode: failures.firstOrNull?.$2,
      unsentTaskIds: {for (final operation in operations) operation.taskId, for (final file in files) file.taskId},
    );
  }
}
