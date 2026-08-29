import 'package:dio/dio.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class WorkerProfileRepository {
  WorkerProfileRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> fetchMyAccount() async {
    try {
      return await _api.get('/users/me');
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to load account.');
    }
  }

  Future<Map<String, dynamic>> fetchWorkerProfile() async {
    try {
      return await _api.get('/users/me/worker/profile');
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to load profile.');
    }
  }

  Future<WorkerPublicProfile> fetchPublicProfile(String workerId) async {
    try {
      final response = await _api.get('/users/workers/$workerId/profile');
      return WorkerPublicProfile.fromJson(response['profile'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to load public profile.');
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      await _api.patch('/users/me/worker/profile', data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to update profile.');
    }
  }

  Future<String?> uploadAvatar(String imagePath, String filename) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/media/avatar',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(imagePath, filename: filename),
        }),
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
      final data = response.data ?? <String, dynamic>{};
      return data['avatarUrl'] as String?;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to upload avatar.');
    }
  }

  Future<void> uploadPortfolioPhoto(String imagePath, String filename) async {
    try {
      await _api.dio.post<Map<String, dynamic>>(
        '/media/workers/portfolio',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(imagePath, filename: filename),
        }),
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to upload portfolio photo.');
    }
  }

  Future<void> addSkill(String categoryId) async {
    try {
      await _api.post('/worker/onboarding/skills', data: {'categoryId': categoryId});
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to add skill.');
    }
  }

  Future<List<Map<String, dynamic>>> fetchDocuments() async {
    try {
      final response = await _api.get('/users/me/worker/documents');
      final docs = response['documents'] as List<dynamic>? ?? [];
      return docs.whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to fetch documents.');
    }
  }

  Future<void> uploadDocument(String type, String url) async {
    try {
      await _api.post('/users/me/worker/documents', data: {
        'type': type,
        'url': url,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to upload document.');
    }
  }

  Future<List<CatalogCategory>> fetchCategories() async {
    try {
      final response = await _api.get('/catalog');
      final categories = response['categories'];
      if (categories is! List) return const [];
      return categories
          .whereType<Map<String, dynamic>>()
          .map(CatalogCategory.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to fetch categories.');
    }
  }

  Exception _handleError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] as String?;
      if (message != null && message.isNotEmpty) {
        return Exception(message);
      }
    }
    return Exception(e.message ?? 'An unknown network error occurred');
  }
}
