import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_store.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

final environmentProvider = Provider<AppEnvironment>((ref) {
  return AppEnvironment.fromDartDefines();
});

final secureStoreProvider = Provider<SecureStore>((ref) {
  return SecureStore.create();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    environment: ref.watch(environmentProvider),
    secureStore: ref.watch(secureStoreProvider),
  );
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider).dio);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    secureStore: ref.watch(secureStoreProvider),
  );
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthSession?> build() async {
    return _repository.restoreSession();
  }

  Future<Map<String, dynamic>> requestOtp({
    required String channel,
    required String identifier,
  }) async {
    return _repository.requestOtp(channel: channel, identifier: identifier);
  }

  Future<void> verifyOtp({
    required String channel,
    required String identifier,
    required String otp,
    required String role,
    String? name,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _repository.verifyOtp(
        channel: channel,
        identifier: identifier,
        otp: otp,
        role: role,
        name: name,
      );
    });
  }

  Future<void> signInWithGoogle({
    required String idToken,
    required String role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _repository.signInWithGoogle(
        idToken: idToken,
        role: role,
      );
    });
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AsyncData(null);
  }
}
