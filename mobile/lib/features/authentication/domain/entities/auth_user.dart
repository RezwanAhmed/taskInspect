import 'package:taskinspect/features/authentication/domain/entities/user_role.dart';

/// The logged-in user.
class AuthUser {
  const AuthUser({required this.id, required this.email, required this.fullName, required this.roles});

  final String id;
  final String email;
  final String fullName;
  final Set<UserRole> roles;

  bool hasRole(UserRole role) => roles.contains(role);

  /// Managers create, assign and review tasks.
  bool get isManager => hasRole(UserRole.manager);

  /// Workers execute tasks.
  bool get isWorker => hasRole(UserRole.worker);

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.email == email && other.fullName == fullName &&
      other.roles.length == roles.length && other.roles.containsAll(roles);

  @override
  int get hashCode => Object.hash(id, email, fullName, Object.hashAllUnordered(roles));
}
