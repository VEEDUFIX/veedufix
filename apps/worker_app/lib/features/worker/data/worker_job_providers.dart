import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import 'worker_job_api.dart';
import 'worker_job_repository.dart';

final workerJobApiProvider = Provider<WorkerJobApi>((ref) {
  return WorkerJobApi(ref.watch(apiClientProvider).dio);
});

final workerJobRepositoryProvider = Provider<WorkerJobRepository>((ref) {
  return WorkerJobRepository(ref.watch(workerJobApiProvider));
});
