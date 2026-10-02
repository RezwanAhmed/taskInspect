import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/synchronization/sync_status.dart';

/// The sync status for the screens, and the Retry button.
class SyncStatusCubit extends Cubit<SyncStatus> {
  SyncStatusCubit(this._source, this._retry) : super(const SyncStatus());

  final SyncStatusSource _source;
  final Future<void> Function() _retry;
  StreamSubscription<SyncStatus>? _subscription;

  void start() {
    _subscription ??= _source.watch().listen((status) {
      if (!isClosed) {
        emit(status);
      }
    });
  }

  /// Sends every failed change and file again.
  Future<void> retry() => _retry();

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
