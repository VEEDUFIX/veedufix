import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../../data/support_repository.dart';
import '../../domain/entities/worker_support_ticket.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(apiClientProvider));
});

final workerSupportTicketsProvider = FutureProvider.autoDispose<List<WorkerSupportTicket>>((ref) async {
  final repo = ref.watch(supportRepositoryProvider);
  return await repo.fetchMyTickets();
});
