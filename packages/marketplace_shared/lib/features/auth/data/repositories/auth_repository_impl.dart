import '../../../../core/storage/secure_store.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStore secureStore,
  })  : _remoteDataSource = remoteDataSource,
        _secureStore = secureStore;

  final AuthRemoteDataSource _remoteDataSource;
  final SecureStore _secureStore;

  @override
  Future<Map<String, dynamic>> requestOtp({
    required String channel,
    required String identifier,
  }) {
    return _remoteDataSource.requestOtp(
      channel: channel,
      identifier: identifier,
    );
  }

  @override
  Future<AuthSession> verifyOtp({
    required String channel,
    required String identifier,
    required String otp,
    required String role,
    String? name,
  }) async {
    final session = await _remoteDataSource.verifyOtp(
      channel: channel,
      identifier: identifier,
      otp: otp,
      role: role,
      name: name,
    );
    await _secureStore.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    return session;
  }

  @override
  Future<AuthSession> signInWithGoogle({
    required String idToken,
    required String role,
  }) async {
    final session = await _remoteDataSource.signInWithGoogle(
      idToken: idToken,
      role: role,
    );
    await _secureStore.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    return session;
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final refreshToken = await _secureStore.readRefreshToken();
    if (refreshToken == null) {
      return null;
    }
    try {
      final session = await _remoteDataSource.refreshSession(refreshToken);
      await _secureStore.saveTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      return session;
    } catch (_) {
      await _secureStore.clearTokens();
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    final refreshToken = await _secureStore.readRefreshToken();
    if (refreshToken != null) {
      await _remoteDataSource.signOut(refreshToken);
    }
    await _secureStore.clearTokens();
  }
}
