import 'dart:async';

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
            connectTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 60),
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
            // ── Mutex: only one refresh in-flight at a time ──────────────────
            // If a refresh is already running, wait for it to complete and
            // reuse the token it resolved with instead of starting a second
            // concurrent refresh (which would use a rotated refresh token and
            // sign the user out).
            if (_refreshCompleter != null) {
              final newToken = await _refreshCompleter!.future;
              if (newToken != null) {
                final request = error.requestOptions;
                request.headers['Authorization'] = 'Bearer $newToken';
                request.extra['skipAuth'] = true;
                try {
                  final retryResponse = await dio.fetch(request);
                  handler.resolve(retryResponse);
                  return;
                } on DioException catch (retryError) {
                  if (retryError.response?.statusCode == 401) {
                    try {
                      await _secureStore.clearTokens();
                    } catch (_) {
                      // Session expiry still needs to be surfaced to the app.
                    }
                    if (!_sessionExpiredController.isClosed) {
                      _sessionExpiredController.add(null);
                    }
                  }
                  // Fall through to reject.
                } catch (_) {
                  // Fall through to reject.
                }
              }
              handler.next(error);
              return;
            }

            final refreshCompleter = Completer<String?>();
            _refreshCompleter = refreshCompleter;
            String? nextAccessToken;
            var invalidateSession = false;
            try {
              final refreshToken = await _secureStore.readRefreshToken();
              if (refreshToken == null || refreshToken.isEmpty) {
                invalidateSession = true;
              } else {
                final response = await dio.post<Map<String, dynamic>>(
                  '/auth/refresh',
                  data: {'refreshToken': refreshToken},
                  options: Options(extra: {'skipAuth': true}),
                );
                final data = response.data ?? <String, dynamic>{};
                final accessToken = data['accessToken'] as String?;
                final nextRefreshToken = data['refreshToken'] as String?;
                if (accessToken != null && nextRefreshToken != null) {
                  await _secureStore.saveTokens(
                    accessToken: accessToken,
                    refreshToken: nextRefreshToken,
                  );
                  nextAccessToken = accessToken;
                } else {
                  invalidateSession = true;
                }
              }
            } on DioException catch (refreshError) {
              final statusCode = refreshError.response?.statusCode;
              // Network errors and 5xx responses do not prove the refresh token
              // is invalid, so retain it for the next request.
              invalidateSession = statusCode == 401 || statusCode == 403;
            } catch (_) {
              // Storage and transport failures are transient session failures.
            }

            if (invalidateSession) {
              try {
                await _secureStore.clearTokens();
              } catch (_) {
                // Still notify the app; no usable backend session remains.
              }
              if (!_sessionExpiredController.isClosed) {
                _sessionExpiredController.add(null);
              }
            }

            _refreshCompleter = null;
            refreshCompleter.complete(nextAccessToken);
            if (nextAccessToken != null) {
              final request = error.requestOptions;
              request.headers['Authorization'] = 'Bearer $nextAccessToken';
              request.extra['skipAuth'] = true;
              try {
                final retryResponse = await dio.fetch(request);
                handler.resolve(retryResponse);
                return;
              } on DioException catch (retryError) {
                if (retryError.response?.statusCode == 401) {
                  try {
                    await _secureStore.clearTokens();
                  } catch (_) {
                    // Session expiry still needs to be surfaced to the app.
                  }
                  if (!_sessionExpiredController.isClosed) {
                    _sessionExpiredController.add(null);
                  }
                }
              } catch (_) {
                // Keep refreshed credentials when the retried request fails transiently.
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
  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();

  Stream<void> get sessionExpired => _sessionExpiredController.stream;

  /// Non-null while a token refresh is in-flight.  Concurrent 401s wait on
  /// this Completer rather than starting a parallel refresh request.
  Completer<String?>? _refreshCompleter;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    final res = await dio.get<Map<String, dynamic>>(path, queryParameters: queryParameters, options: options);
    return res.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    final res = await dio.post<Map<String, dynamic>>(path, data: data, queryParameters: queryParameters, options: options);
    return res.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    final res = await dio.patch<Map<String, dynamic>>(path, data: data, queryParameters: queryParameters, options: options);
    return res.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    final res = await dio.delete<Map<String, dynamic>>(path, data: data, queryParameters: queryParameters, options: options);
    return res.data ?? <String, dynamic>{};
  }
}
