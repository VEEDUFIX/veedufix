import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class WorkerEarningsChartPoint {
  const WorkerEarningsChartPoint({
    required this.date,
    required this.amount,
  });

  final DateTime date;
  final double amount;

  factory WorkerEarningsChartPoint.fromJson(Map<String, dynamic> json) {
    return WorkerEarningsChartPoint(
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class WorkerEarningsSummary {
  const WorkerEarningsSummary({
    required this.todayTotal,
    required this.weeklyTotal,
    required this.monthlyTotal,
    required this.chartData,
  });

  final double todayTotal;
  final double weeklyTotal;
  final double monthlyTotal;
  final List<WorkerEarningsChartPoint> chartData;

  factory WorkerEarningsSummary.fromJson(Map<String, dynamic> json) {
    final chartItems = json['chartData'];
    return WorkerEarningsSummary(
      todayTotal: (json['todayTotal'] as num?)?.toDouble() ?? 0,
      weeklyTotal: (json['weeklyTotal'] as num?)?.toDouble() ?? 0,
      monthlyTotal: (json['monthlyTotal'] as num?)?.toDouble() ?? 0,
      chartData: chartItems is List
          ? chartItems
              .whereType<Map<String, dynamic>>()
              .map(WorkerEarningsChartPoint.fromJson)
              .toList(growable: false)
          : const <WorkerEarningsChartPoint>[],
    );
  }
}

class WorkerEarningsTransaction {
  const WorkerEarningsTransaction({
    required this.bookingId,
    required this.bookingCode,
    required this.serviceName,
    required this.amount,
    required this.commissionAmount,
    required this.status,
    required this.date,
  });

  final String bookingId;
  final String? bookingCode;
  final String serviceName;
  final double amount;
  final double commissionAmount;
  final String status;
  final DateTime date;

  factory WorkerEarningsTransaction.fromJson(Map<String, dynamic> json) {
    return WorkerEarningsTransaction(
      bookingId: json['bookingId'] as String? ?? '',
      bookingCode: json['bookingCode'] as String?,
      serviceName: json['serviceName'] as String? ?? 'Service booking',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class WorkerEarningsPageData {
  const WorkerEarningsPageData({
    required this.summary,
    required this.transactions,
  });

  final WorkerEarningsSummary summary;
  final List<WorkerEarningsTransaction> transactions;
}

class WorkerEarningsTransactionPage {
  const WorkerEarningsTransactionPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<WorkerEarningsTransaction> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

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

final workerEarningsApiProvider = Provider<WorkerEarningsApi>((ref) {
  return WorkerEarningsApi(ref.watch(apiClientProvider).dio);
});

final workerEarningsPageProvider = FutureProvider.autoDispose<WorkerEarningsPageData>((ref) async {
  final api = ref.watch(workerEarningsApiProvider);
  final summary = await api.fetchSummary();
  final transactionsPage = await api.fetchTransactions();

  return WorkerEarningsPageData(
    summary: summary,
    transactions: transactionsPage.items,
  );
});
