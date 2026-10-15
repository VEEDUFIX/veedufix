import 'package:dio/dio.dart';

class CatalogRemoteDataSource {
  CatalogRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getHomeCatalog({String? pincode}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/catalog/home',
      queryParameters: {if (pincode != null) 'pincode': pincode},
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> getServiceDetails(
    String slug, {
    String? pincode,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/catalog/services/$slug',
      queryParameters: {if (pincode != null) 'pincode': pincode},
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> searchCatalog(
    String query, {
    String? pincode,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/catalog/search',
      queryParameters: {
        'q': query,
        if (pincode != null) 'pincode': pincode,
      },
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> getTrendingCatalog({String? pincode}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/catalog/trending',
      queryParameters: {if (pincode != null) 'pincode': pincode},
    );
    return response.data ?? {};
  }
}
