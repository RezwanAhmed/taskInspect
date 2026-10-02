import 'package:equatable/equatable.dart';

/// Changes on the device that are not on the server yet, and whose they
/// are. Signing in with another account deletes them (privacy first), so
/// the login screen warns about them.
class UnsyncedChanges extends Equatable {
  const UnsyncedChanges({required this.ownerEmail, required this.count});

  /// `null` when not known (data from before emails were kept).
  final String? ownerEmail;
  final int count;

  /// Whether signing in with [email] may delete them; always when the
  /// owner is not known.
  bool belongToAnother(String email) =>
      ownerEmail == null || email.trim().toLowerCase() != ownerEmail!.trim().toLowerCase();

  /// "worker@example.com", or "the previous user" when not known.
  String get ownerName => ownerEmail ?? 'the previous user';

  @override
  List<Object?> get props => [ownerEmail, count];
}
