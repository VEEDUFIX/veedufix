import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/worker_job_entities.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

export '../../domain/entities/worker_job_entities.dart';

// tab: 'incoming' | 'accepted' | 'active' | 'completed'
final workerJobsProvider =
    FutureProvider.autoDispose.family<List<WorkerJob>, String>((ref, tab) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/users/me/worker/jobs?tab=$tab');
  final list = response['jobs'] as List<dynamic>? ?? [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(WorkerJob.fromJson)
      .toList(growable: false);
});

final workerDashboardStatsProvider =
    FutureProvider.autoDispose<WorkerDashboardStats>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/users/me/worker/stats');
  final stats = response['stats'];
  final todayJobsList = response['todayJobs'] as List<dynamic>? ?? [];
  return WorkerDashboardStats.fromJson({
    ...stats,
    'todayJobs': todayJobsList,
  });
});
