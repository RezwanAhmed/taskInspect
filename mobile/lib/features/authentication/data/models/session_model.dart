import 'package:taskinspect/core/security/token_storage.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/authentication/domain/entities/user_role.dart';

/// The answer of `POST /api/auth/login` and `/refresh`: tokens and user.
class SessionModel {
  const SessionModel({required this.tokens, required this.user});

  factory SessionModel.fromJson(Map<String, Object?> json) {
    return SessionModel(
      tokens: StoredTokens(
        accessToken: json['accessToken']! as String,
        accessTokenExpiresAt: DateTime.parse(json['expiresAt']! as String),
        refreshToken: json['refreshToken']! as String,
        refreshTokenExpiresAt: DateTime.parse(json['refreshTokenExpiresAt']! as String),
      ),
      user: UserModel.fromJson(json['user']! as Map<String, Object?>),
    );
  }

  final StoredTokens tokens;
  final AuthUser user;
}

/// Converts the user between the API / stored JSON and [AuthUser].
abstract final class UserModel {
  static AuthUser fromJson(Map<String, Object?> json) {
    return AuthUser(
      id: json['id']! as String,
      email: json['email']! as String,
      fullName: json['fullName']! as String,
      roles: (json['roles']! as List<Object?>)
          .whereType<String>()
          .map(UserRole.tryParse)
          .whereType<UserRole>()
          .toSet(),
    );
  }

  static Map<String, Object?> toJson(AuthUser user) => {
        'id': user.id,
        'email': user.email,
        'fullName': user.fullName,
        'roles': [for (final role in user.roles) role.name.toUpperCase()],
      };
}
