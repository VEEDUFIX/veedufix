import '../entities/service_catalog_entities.dart';

class HomeCatalogResult {
  const HomeCatalogResult({
    required this.categories,
    required this.trending,
    required this.recommended,
  });

  final List<CatalogCategory> categories;
  final List<CatalogService> trending;
  final List<CatalogService> recommended;
}

abstract class CatalogRepository {
  Future<HomeCatalogResult> getHomeCatalog();
  Future<CatalogService> getServiceDetails(String slug);
  Future<List<CatalogService>> searchCatalog(String query);
  Future<List<CatalogService>> getTrendingCatalog();
}
