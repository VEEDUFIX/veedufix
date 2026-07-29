import 'package:dio/dio.dart';

class CatalogRemoteDataSource {
  CatalogRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getHomeCatalog() async {
    final response = await _dio.get<Map<String, dynamic>>('/catalog/home');
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> getServiceDetails(String slug) async {
    final response = await _dio.get<Map<String, dynamic>>('/catalog/services/$slug');
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> searchCatalog(String query) async {
    final response = await _dio.get<Map<String, dynamic>>('/catalog/search', queryParameters: {'q': query});
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> getTrendingCatalog() async {
    final response = await _dio.get<Map<String, dynamic>>('/catalog/trending');
    return response.data ?? {};
  }
}
