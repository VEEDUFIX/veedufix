class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatarUrl,
  });

  final String id;
  final String role;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
}
