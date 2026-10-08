import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/catalog_remote_datasource.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../domain/entities/service_catalog_entities.dart';
import '../../domain/entities/worker_public_profile.dart';
import '../../domain/repositories/catalog_repository.dart';

final catalogRemoteDataSourceProvider =
    Provider<CatalogRemoteDataSource>((ref) {
  return CatalogRemoteDataSource(ref.watch(apiClientProvider).dio);
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepositoryImpl(
    remoteDataSource: ref.watch(catalogRemoteDataSourceProvider),
  );
});

final homeCatalogProvider =
    FutureProvider.autoDispose<HomeCatalogResult>((ref) async {
  return ref.watch(catalogRepositoryProvider).getHomeCatalog();
});

final homeCatalogSectionsProvider =
    FutureProvider.autoDispose<List<HomeCatalogSection>>((ref) async {
  final response =
      await ref.watch(apiClientProvider).get('/catalog/home-sections');
  final sections = response['sections'];
  if (sections is! List) return const [];
  return sections
      .whereType<Map<String, dynamic>>()
      .map(HomeCatalogSection.fromJson)
      .toList(growable: false);
});

final catalogCategoryProvider = FutureProvider.autoDispose
    .family<CatalogCategory, String>((ref, slug) async {
  final payload = await ref.watch(apiClientProvider).get(
        '/catalog/categories/${Uri.encodeComponent(slug)}',
      );
  final category = payload['category'];
  if (category is! Map<String, dynamic>) {
    throw const FormatException('The catalog category response was invalid.');
  }
  return CatalogCategory.fromJson(category);
});

final catalogSubcategoryServicesProvider = FutureProvider.autoDispose
    .family<CatalogServicePage, CatalogServiceQuery>((ref, query) async {
  final payload = await ref.watch(apiClientProvider).get(
    '/catalog/search',
    queryParameters: {
      'categorySlug': query.categorySlug,
      'subcategorySlug': query.subcategorySlug,
      'page': query.page,
      'pageSize': query.pageSize,
      if (query.search.trim().isNotEmpty) 'q': query.search.trim(),
    },
  );
  final rawItems = payload['items'];
  final items = rawItems is List
      ? rawItems
          .whereType<Map<String, dynamic>>()
          .map(CatalogService.fromJson)
          .toList(growable: false)
      : const <CatalogService>[];
  return CatalogServicePage(
    items: items,
    total: (payload['total'] as num?)?.toInt() ?? items.length,
  );
});

class CatalogServiceQuery {
  const CatalogServiceQuery({
    required this.categorySlug,
    required this.subcategorySlug,
    this.search = '',
    this.page = 1,
    this.pageSize = 20,
  });

  final String categorySlug;
  final String subcategorySlug;
  final String search;
  final int page;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      other is CatalogServiceQuery &&
      other.categorySlug == categorySlug &&
      other.subcategorySlug == subcategorySlug &&
      other.search == search &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(
        categorySlug,
        subcategorySlug,
        search,
        page,
        pageSize,
      );
}

class CatalogServicePage {
  const CatalogServicePage({required this.items, required this.total});

  final List<CatalogService> items;
  final int total;
}

final serviceDetailProvider = FutureProvider.autoDispose
    .family<CatalogService, String>((ref, slug) async {
  return ref.watch(catalogRepositoryProvider).getServiceDetails(slug);
});

final workerProfileProvider =
    FutureProvider.family<WorkerPublicProfile, String>((ref, workerId) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/users/workers/$workerId/profile');
  return WorkerPublicProfile.fromJson(
      response['profile'] as Map<String, dynamic>);
});

final searchCatalogProvider = FutureProvider.autoDispose
    .family<List<CatalogService>, String>((ref, query) async {
  if (query.isEmpty) return const [];
  return ref.watch(catalogRepositoryProvider).searchCatalog(query);
});

final trendingCatalogProvider =
    FutureProvider.autoDispose<List<CatalogService>>((ref) async {
  return ref.watch(catalogRepositoryProvider).getTrendingCatalog();
});
