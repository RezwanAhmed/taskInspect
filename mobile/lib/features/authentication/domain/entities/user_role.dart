/// The roles a user can have (backend: ADMINISTRATOR, MANAGER, WORKER).
enum UserRole {
  administrator,
  manager,
  worker;

  /// Parses a role name from the API; unknown names are ignored.
  static UserRole? tryParse(String name) {
    for (final role in values) {
      if (role.name == name.toLowerCase()) {
        return role;
      }
    }
    return null;
  }
}
