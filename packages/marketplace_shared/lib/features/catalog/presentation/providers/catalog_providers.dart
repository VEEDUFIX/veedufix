import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/catalog_remote_datasource.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../domain/entities/service_catalog_entities.dart';
import '../../domain/entities/worker_public_profile.dart';
import '../../domain/repositories/catalog_repository.dart';

final catalogRemoteDataSourceProvider = Provider<CatalogRemoteDataSource>((ref) {
  return CatalogRemoteDataSource(ref.watch(apiClientProvider).dio);
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepositoryImpl(
    remoteDataSource: ref.watch(catalogRemoteDataSourceProvider),
  );
});

final homeCatalogProvider = FutureProvider.autoDispose<HomeCatalogResult>((ref) async {
  return ref.watch(catalogRepositoryProvider).getHomeCatalog();
});

final serviceDetailProvider = FutureProvider.autoDispose.family<CatalogService, String>((ref, slug) async {
  return ref.watch(catalogRepositoryProvider).getServiceDetails(slug);
});

final workerProfileProvider = FutureProvider.family<WorkerPublicProfile, String>((ref, workerId) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/users/workers/$workerId/profile');
  return WorkerPublicProfile.fromJson(response['profile'] as Map<String, dynamic>);
});

final searchCatalogProvider = FutureProvider.autoDispose.family<List<CatalogService>, String>((ref, query) async {
  if (query.isEmpty) return const [];
  return ref.watch(catalogRepositoryProvider).searchCatalog(query);
});

final trendingCatalogProvider = FutureProvider.autoDispose<List<CatalogService>>((ref) async {
  return ref.watch(catalogRepositoryProvider).getTrendingCatalog();
});
