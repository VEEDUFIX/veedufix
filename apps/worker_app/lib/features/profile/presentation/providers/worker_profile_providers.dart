import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../../data/worker_profile_repository.dart';

final workerProfileRepositoryProvider = Provider<WorkerProfileRepository>((ref) {
  return WorkerProfileRepository(ref.watch(apiClientProvider));
});

final workerAccountProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(workerProfileRepositoryProvider);
  return await repo.fetchMyAccount();
});

final workerEditProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(workerProfileRepositoryProvider);
  return await repo.fetchWorkerProfile();
});

final workerPublicProfileProvider = FutureProvider.autoDispose.family<WorkerPublicProfile, String>((ref, workerId) async {
  final repo = ref.watch(workerProfileRepositoryProvider);
  return await repo.fetchPublicProfile(workerId);
});

final workerSkillCategoriesProvider = FutureProvider.autoDispose<List<CatalogCategory>>((ref) async {
  final repo = ref.watch(workerProfileRepositoryProvider);
  return await repo.fetchCategories();
});

final workerDocumentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(workerProfileRepositoryProvider);
  return await repo.fetchDocuments();
});

final workerProfileUpdateProvider = StateNotifierProvider<_WorkerProfileUpdateNotifier, AsyncValue<void>>((ref) {
  return _WorkerProfileUpdateNotifier(ref);
});

class _WorkerProfileUpdateNotifier extends StateNotifier<AsyncValue<void>> {
  _WorkerProfileUpdateNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> update(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(workerProfileRepositoryProvider);
      await repo.updateProfile(data);
      state = const AsyncValue.data(null);
      _ref.invalidate(workerEditProfileProvider);
      _ref.invalidate(workerAccountProfileProvider);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
