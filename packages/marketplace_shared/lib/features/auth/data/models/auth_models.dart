import '../../domain/entities/auth_session.dart';

class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.id,
    required super.role,
    required super.name,
    required super.email,
    required super.phone,
    required super.avatarUrl,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] as String,
      role: json['role'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'name': name,
        'email': email,
        'phone': phone,
        'avatarUrl': avatarUrl,
      };
}

class AuthSessionModel extends AuthSession {
  const AuthSessionModel({
    required super.user,
    required super.accessToken,
    required super.refreshToken,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      user: AuthUserModel.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'user': (user as AuthUserModel).toJson(),
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}
