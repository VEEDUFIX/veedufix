import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<Map<String, dynamic>> requestOtp({
    required String channel,
    required String identifier,
  });

  Future<AuthSession> verifyOtp({
    required String channel,
    required String identifier,
    required String otp,
    required String role,
    String? name,
    String? referralCode,
  });

  Future<AuthSession> signInWithGoogle({
    required String idToken,
    required String role,
  });

  Future<AuthSession?> restoreSession();

  Future<void> signOut();
}
