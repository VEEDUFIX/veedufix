import 'package:dio/dio.dart';

import '../config/environment.dart';
import '../storage/secure_store.dart';

class ApiClient {
  ApiClient({
    required AppEnvironment environment,
    required SecureStore secureStore,
  })  : _secureStore = secureStore,
        dio = Dio(
          BaseOptions(
            baseUrl: environment.apiBaseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] == true) {
            handler.next(options);
            return;
          }
          final accessToken = await _secureStore.readAccessToken();
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['skipAuth'] != true) {
            final refreshToken = await _secureStore.readRefreshToken();
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                final response = await dio.post<Map<String, dynamic>>(
                  '/auth/refresh',
                  data: {'refreshToken': refreshToken},
                  options: Options(extra: {'skipAuth': true}),
                );
                final data = response.data ?? <String, dynamic>{};
                final nextAccessToken = data['accessToken'] as String?;
                final nextRefreshToken = data['refreshToken'] as String?;
                if (nextAccessToken != null && nextRefreshToken != null) {
                  await _secureStore.saveTokens(
                    accessToken: nextAccessToken,
                    refreshToken: nextRefreshToken,
                  );
                  final request = error.requestOptions;
                  request.headers['Authorization'] = 'Bearer $nextAccessToken';
                  request.extra['skipAuth'] = true;
                  final retryResponse = await dio.fetch(request);
                  handler.resolve(retryResponse);
                  return;
                }
              } catch (_) {
                await _secureStore.clearTokens();
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final SecureStore _secureStore;
  final Dio dio;
}
