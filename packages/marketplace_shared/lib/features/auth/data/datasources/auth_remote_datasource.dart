import 'package:dio/dio.dart';

import '../models/auth_models.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> requestOtp({
    required String channel,
    required String identifier,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/otp/request',
      data: {
        'channel': channel,
        'identifier': identifier,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<AuthSessionModel> verifyOtp({
    required String channel,
    required String identifier,
    required String otp,
    required String role,
    String? name,
    String? referralCode,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/otp/verify',
      data: {
        'channel': channel,
        'identifier': identifier,
        'otp': otp,
        'role': role,
        'name': name,
        if (referralCode != null && referralCode.isNotEmpty)
          'referralCode': referralCode,
      },
    );

    return AuthSessionModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AuthSessionModel> signInWithGoogle({
    required String idToken,
    required String role,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/google',
      data: {
        'provider': 'GOOGLE',
        'idToken': idToken,
        'role': role,
      },
    );

    return AuthSessionModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AuthSessionModel> refreshSession(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(extra: {'skipAuth': true}),
    );
    return AuthSessionModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<void> signOut(String refreshToken) async {
    await _dio.post<void>(
      '/auth/signout',
      data: {'refreshToken': refreshToken},
    );
  }
}
