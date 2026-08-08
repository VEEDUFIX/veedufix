import 'package:dio/dio.dart';
import '../domain/entities/worker_earnings.dart';

class WorkerEarningsApi {
  WorkerEarningsApi(this._dio);

  final Dio _dio;

  Future<WorkerEarningsSummary> fetchSummary() async {
    final response = await _dio.get<Map<String, dynamic>>('/worker/earnings/summary');
    return WorkerEarningsSummary.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<WorkerEarningsTransactionPage> fetchTransactions({
    int page = 1,
    int limit = 6,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/worker/earnings/transactions',
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
        if (status != null) 'status': status,
        if (fromDate != null) 'fromDate': _formatDate(fromDate),
        if (toDate != null) 'toDate': _formatDate(toDate),
      },
    );

    final data = response.data ?? <String, dynamic>{};
    final items = data['items'];
    if (items is! List) {
      return const WorkerEarningsTransactionPage(
        items: <WorkerEarningsTransaction>[],
        page: 1,
        limit: 6,
        total: 0,
        totalPages: 1,
      );
    }

    return WorkerEarningsTransactionPage(
      items: items
          .whereType<Map<String, dynamic>>()
          .map(WorkerEarningsTransaction.fromJson)
          .toList(growable: false),
      page: (data['page'] as num?)?.toInt() ?? page,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
      total: (data['total'] as num?)?.toInt() ?? 0,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
