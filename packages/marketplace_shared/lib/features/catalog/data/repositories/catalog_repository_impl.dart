import '../../domain/entities/service_catalog_entities.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_remote_datasource.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  const CatalogRepositoryImpl({
    required this.remoteDataSource,
  });

  final CatalogRemoteDataSource remoteDataSource;

  @override
  Future<HomeCatalogResult> getHomeCatalog() async {
    final data = await remoteDataSource.getHomeCatalog();
    return HomeCatalogResult(
      categories: _decodeList(data['categories'], CatalogCategory.fromJson),
      trending: _decodeList(data['trendingServices'] ?? data['trending'], CatalogService.fromJson),
      recommended: _decodeList(data['recommendedServices'] ?? data['recommended'], CatalogService.fromJson),
    );
  }

  @override
  Future<CatalogService> getServiceDetails(String slug) async {
    final data = await remoteDataSource.getServiceDetails(slug);
    return CatalogService.fromJson(data);
  }

  @override
  Future<List<CatalogService>> searchCatalog(String query) async {
    final data = await remoteDataSource.searchCatalog(query);
    return _decodeList(data['results'] ?? data['data'] ?? data['items'] ?? data, CatalogService.fromJson);
  }

  @override
  Future<List<CatalogService>> getTrendingCatalog() async {
    final data = await remoteDataSource.getTrendingCatalog();
    return _decodeList(data['data'] ?? data, CatalogService.fromJson);
  }

  List<T> _decodeList<T>(dynamic value, T Function(Map<String, dynamic>) builder) {
    if (value is! List) return <T>[];
    return value.whereType<Map<String, dynamic>>().map(builder).toList(growable: false);
  }
}
