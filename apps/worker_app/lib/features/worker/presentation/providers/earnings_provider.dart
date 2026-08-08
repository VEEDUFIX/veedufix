import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../../domain/entities/worker_earnings.dart';
import '../../data/worker_earnings_api.dart';
import '../../data/worker_earnings_repository.dart';

final workerEarningsApiProvider = Provider<WorkerEarningsApi>((ref) {
  return WorkerEarningsApi(ref.watch(apiClientProvider).dio);
});

final workerEarningsRepositoryProvider = Provider<WorkerEarningsRepository>((ref) {
  return WorkerEarningsRepository(ref.watch(workerEarningsApiProvider));
});

final workerEarningsPageProvider = FutureProvider.autoDispose<WorkerEarningsPageData>((ref) async {
  final repo = ref.watch(workerEarningsRepositoryProvider);
  final summary = await repo.fetchSummary();
  final transactionsPage = await repo.fetchTransactions();

  return WorkerEarningsPageData(
    summary: summary,
    transactions: transactionsPage.items,
  );
});
