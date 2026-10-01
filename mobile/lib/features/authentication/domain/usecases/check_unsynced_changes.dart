import 'package:taskinspect/features/authentication/domain/entities/unsynced_changes.dart';
import 'package:taskinspect/features/authentication/domain/repositories/auth_repository.dart';

/// Unsynced changes left on the device, e.g. after a session expired.
class CheckUnsyncedChanges {
  const CheckUnsyncedChanges(this._repository);

  final AuthRepository _repository;

  Future<UnsyncedChanges?> call() => _repository.unsyncedChanges();
}
