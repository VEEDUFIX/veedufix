import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../../domain/entities/worker_wallet.dart';
import '../../data/worker_wallet_repository.dart';

final workerWalletRepositoryProvider = Provider<WorkerWalletRepository>((ref) {
  return WorkerWalletRepository(ref.watch(apiClientProvider));
});

final workerWalletProvider = FutureProvider.autoDispose<WorkerWallet>((ref) async {
  final repo = ref.watch(workerWalletRepositoryProvider);
  return await repo.fetchWallet();
});

final payoutRequestProvider = StateNotifierProvider<_PayoutNotifier, AsyncValue<void>>((ref) {
  return _PayoutNotifier(ref);
});

class _PayoutNotifier extends StateNotifier<AsyncValue<void>> {
  _PayoutNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> requestPayout(double amount, {String? upiId}) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(workerWalletRepositoryProvider);
      await repo.requestPayout(amount, upiId: upiId);
      state = const AsyncValue.data(null);
      _ref.invalidate(workerWalletProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
